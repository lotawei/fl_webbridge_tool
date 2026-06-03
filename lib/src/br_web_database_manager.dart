import 'dart:convert';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'br_web_logger.dart';

/// 通用数据库管理器
///
/// H5 通过 bridge `database.{table}.query|insert|update|delete|getById` 调用。
///
/// ```dart
/// final orderDB = NativeDataBaseManager<WorkOrder>(
///   tableName: 'work_orders',
///   fromMap: (row) => WorkOrder.fromDb(row),
///   toMap: (item) => item.toDb(),
/// );
/// await orderDB.init();
/// ```
class NativeDataBaseManager<T> {
  NativeDataBaseManager({
    required this.tableName,
    required this.fromMap,
    required this.toMap,
    this.logger,
  });

  final String tableName;
  final T Function(Map<String, dynamic>) fromMap;
  final Map<String, dynamic> Function(T) toMap;
  final BRWebLogger? logger;

  Database? _db;

  Future<void> init({BRWebLogger? logger}) async {
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, 'br_web_data.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
    logger?.native('DB init', detail: '$tableName ready');
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        data TEXT NOT NULL,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');
    logger?.native('DB table created', detail: tableName);
  }

  Future<List<T>> query({
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final db = await _ensureDb();
    final rows = await db.query(
      tableName,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy ?? 'id DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map((row) {
      final data = jsonDecode(row['data'] as String) as Map<String, dynamic>;
      data['id'] = row['id'];
      data['created_at'] = row['created_at'];
      data['updated_at'] = row['updated_at'];
      return fromMap(data);
    }).toList();
  }

  Future<T?> getById(int id) async {
    final db = await _ensureDb();
    final rows = await db.query(tableName, where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    final row = rows.first;
    final data = jsonDecode(row['data'] as String) as Map<String, dynamic>;
    data['id'] = row['id'];
    return fromMap(data);
  }

  Future<int> insert(T item) async {
    final db = await _ensureDb();
    final map = toMap(item);
    map.remove('id');
    final data = jsonEncode(map);
    final now = DateTime.now().toIso8601String();
    return await db.insert(tableName, {'data': data, 'created_at': now, 'updated_at': now});
  }

  Future<int> update(int id, T item) async {
    final db = await _ensureDb();
    final map = toMap(item);
    map.remove('id');
    final data = jsonEncode(map);
    return await db.update(
      tableName,
      {'data': data, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _ensureDb();
    return await db.delete(tableName, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> count({String? where, List<dynamic>? whereArgs}) async {
    final db = await _ensureDb();
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM $tableName${where != null ? ' WHERE $where' : ''}',
      whereArgs,
    );
    return result.first['cnt'] as int;
  }

  Future<Database> _ensureDb() async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, 'br_web_data.db');
    _db = await openDatabase(path, version: 1, onCreate: _onCreate);
    return _db!;
  }
}

// ═══════════════════════════════════════════════════
// 工单数据模型
// ═══════════════════════════════════════════════════

class WorkOrder {
  final int? id;
  final String title;
  final String description;
  final String status;    // pending | in_progress | completed
  final String priority;  // low | medium | high
  final String? assignee;
  final String? address;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const WorkOrder({
    this.id,
    required this.title,
    this.description = '',
    this.status = 'pending',
    this.priority = 'medium',
    this.assignee,
    this.address,
    this.createdAt,
    this.updatedAt,
  });

  factory WorkOrder.fromDb(Map<String, dynamic> map) => WorkOrder(
        id: map['id'] as int?,
        title: map['title'] as String? ?? '',
        description: map['description'] as String? ?? '',
        status: map['status'] as String? ?? 'pending',
        priority: map['priority'] as String? ?? 'medium',
        assignee: map['assignee'] as String?,
        address: map['address'] as String?,
        createdAt: map['created_at'] != null
            ? DateTime.tryParse(map['created_at'] as String)
            : null,
        updatedAt: map['updated_at'] != null
            ? DateTime.tryParse(map['updated_at'] as String)
            : null,
      );

  Map<String, dynamic> toDb() => {
        if (id != null) 'id': id,
        'title': title,
        'description': description,
        'status': status,
        'priority': priority,
        if (assignee != null) 'assignee': assignee,
        if (address != null) 'address': address,
      };

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'title': title,
        'description': description,
        'status': status,
        'priority': priority,
        if (assignee != null) 'assignee': assignee,
        if (address != null) 'address': address,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
        if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      };

  WorkOrder copyWith({
    int? id,
    String? title,
    String? description,
    String? status,
    String? priority,
    String? assignee,
    String? address,
  }) =>
      WorkOrder(
        id: id ?? this.id,
        title: title ?? this.title,
        description: description ?? this.description,
        status: status ?? this.status,
        priority: priority ?? this.priority,
        assignee: assignee ?? this.assignee,
        address: address ?? this.address,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}

/// 预置工单管理器
class WorkOrderManager {
  WorkOrderManager({this.logger});
  final BRWebLogger? logger;

  static final NativeDataBaseManager<WorkOrder> _db = NativeDataBaseManager<WorkOrder>(
    tableName: 'work_orders',
    fromMap: (row) => WorkOrder.fromDb(row),
    toMap: (item) => item.toDb(),
  );

  NativeDataBaseManager<WorkOrder> get db => _db;

  Future<void> init() => _db.init(logger: logger);

  /// 插入示例数据（首次运行）
  Future<void> seedIfEmpty() async {
    final count = await _db.count();
    if (count > 0) return;

    final samples = [
      const WorkOrder(
        title: '更换变压器 A-12 号机组',
        description: '检测到变压器油温异常，需停机更换。优先级高。',
        status: 'pending',
        priority: 'high',
        assignee: '张工',
        address: '光明路 128 号 国网变电站',
      ),
      const WorkOrder(
        title: '季度线路巡检 — 北区 7 条线路',
        description: '常规季度巡检。检查瓷绝缘子、导线弧垂、塔杆基础。',
        status: 'pending',
        priority: 'medium',
        assignee: '李工',
        address: '北区 龙华大道 — 观澜段',
      ),
      const WorkOrder(
        title: '智能电表更换 — 翡翠花园 3 栋',
        description: '老旧电表升级为国网智能电表，涉及 120 户。',
        status: 'in_progress',
        priority: 'medium',
        assignee: '王工',
        address: '翡翠花园 3 栋 1-4 单元',
      ),
      const WorkOrder(
        title: '电缆故障抢修 — 南城 10kV 线路',
        description: '昨晚暴雨导致线路跳闸，已定位故障点。',
        status: 'pending',
        priority: 'high',
        assignee: '赵工',
        address: '南城区 工业大道 与 科技路交叉口',
      ),
      const WorkOrder(
        title: '配电柜防雷检测 — 全市 12 个站点',
        description: '入汛前完成全市配电柜防雷接地检测。',
        status: 'completed',
        priority: 'low',
        assignee: '孙工',
        address: '全市 12 个配电柜站点',
      ),
      const WorkOrder(
        title: '用户投诉 — 电压不稳',
        description: '翡翠花园 2 栋多户反映晚间电压波动大。',
        status: 'pending',
        priority: 'medium',
        assignee: null,
        address: '翡翠花园 2 栋',
      ),
    ];

    for (final order in samples) {
      await _db.insert(order);
    }
    logger?.native('WorkOrder seed', detail: '${samples.length} samples inserted');
  }
}
