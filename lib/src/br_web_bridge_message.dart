import 'dart:convert';

class BRWebBridgeMessage {
  const BRWebBridgeMessage({
    required this.id,
    required this.action,
    this.params = const <String, dynamic>{},
  });

  final String id;
  final String action;
  final Map<String, dynamic> params;

  factory BRWebBridgeMessage.fromArgs(List<dynamic> args) {
    if (args.isEmpty) {
      throw const FormatException('Bridge message is empty.');
    }

    final dynamic first = args.first;
    final Map<String, dynamic> json;
    if (first is String) {
      json = jsonDecode(first) as Map<String, dynamic>;
    } else if (first is Map) {
      json = Map<String, dynamic>.from(first);
    } else {
      throw FormatException('Unsupported bridge payload: ${first.runtimeType}');
    }

    return BRWebBridgeMessage(
      id:
          json['id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      action: json['action']?.toString() ?? '',
      params: Map<String, dynamic>.from(
        json['params'] as Map? ?? const <String, dynamic>{},
      ),
    );
  }

  Map<String, dynamic> ok(dynamic data) => <String, dynamic>{
    'id': id,
    'ok': true,
    'data': data,
  };

  Map<String, dynamic> fail(Object error) => <String, dynamic>{
    'id': id,
    'ok': false,
    'error': error.toString(),
  };
}
