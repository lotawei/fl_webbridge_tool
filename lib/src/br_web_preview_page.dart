import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// 文件类型枚举，用于预览页面自动匹配 UI
enum BRWebFileType {
  image,
  video,
  audio,
  unknown;
}

/// 从文件路径或 MIME 类型推断 [BRWebFileType]
BRWebFileType inferFileType(String path, [String? mimeType]) {
  if (mimeType != null) {
    if (mimeType.startsWith('image/')) return BRWebFileType.image;
    if (mimeType.startsWith('video/')) return BRWebFileType.video;
    if (mimeType.startsWith('audio/')) return BRWebFileType.audio;
  }

  final ext = path.split('.').last.toLowerCase();
  const imageExts = {
    'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg', 'heic', 'heif',
  };
  const videoExts = {
    'mp4', 'mov', 'm4v', 'avi', 'mkv', 'wmv', 'flv', '3gp', 'webm',
  };
  const audioExts = {
    'mp3', 'aac', 'm4a', 'wav', 'ogg', 'flac', 'wma', 'opus', 'aiff',
  };

  if (imageExts.contains(ext)) return BRWebFileType.image;
  if (videoExts.contains(ext)) return BRWebFileType.video;
  if (audioExts.contains(ext)) return BRWebFileType.audio;
  return BRWebFileType.unknown;
}

/// 格式化文件大小
String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

/// 全屏文件预览页面——支持图片、视频、音频预览
class BRWebPreviewPage extends StatefulWidget {
  const BRWebPreviewPage({
    super.key,
    required this.filePath,
    this.fileType,
    this.title,
    this.mimeType,
    this.fileSize,
  });

  /// 本地文件路径（支持 file:// 协议）
  final String filePath;

  /// 文件类型，不传则自动从路径/MIME推断
  final BRWebFileType? fileType;

  /// 预览标题
  final String? title;

  /// MIME 类型（可选，用于协助类型推断）
  final String? mimeType;

  /// 文件大小（字节），传了则在底部显示
  final int? fileSize;

  @override
  State<BRWebPreviewPage> createState() => _BRWebPreviewPageState();
}

class _BRWebPreviewPageState extends State<BRWebPreviewPage> {
  late final BRWebFileType _type;
  late final String _displayPath;

  // ---- Video ----
  VideoPlayerController? _videoController;
  bool _videoInitialized = false;
  bool _videoError = false;

  // ---- Audio ----
  AudioPlayer? _audioPlayer;
  PlayerState _audioState = PlayerState.stopped;
  Duration _audioPosition = Duration.zero;
  Duration _audioDuration = Duration.zero;
  bool _audioError = false;

  @override
  void initState() {
    super.initState();
    _type = widget.fileType ??
        inferFileType(widget.filePath, widget.mimeType);
    _displayPath = widget.filePath.startsWith('file://')
        ? widget.filePath.substring(7)
        : widget.filePath;

    if (_type == BRWebFileType.video) {
      _initVideo();
    } else if (_type == BRWebFileType.audio) {
      _initAudio();
    }
  }

  void _initVideo() {
    _videoController = VideoPlayerController.file(File(_displayPath))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _videoInitialized = true);
        _videoController?.play();
      }).catchError((_) {
        if (!mounted) return;
        setState(() => _videoError = true);
      });
  }

  void _initAudio() {
    _audioPlayer = AudioPlayer();
    _audioPlayer!.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _audioState = state);
    });
    _audioPlayer!.onPositionChanged.listen((pos) {
      if (!mounted) return;
      setState(() => _audioPosition = pos);
    });
    _audioPlayer!.onDurationChanged.listen((dur) {
      if (!mounted) return;
      setState(() => _audioDuration = dur);
    });
    _audioPlayer!.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() => _audioPosition = Duration.zero);
    });

    _audioPlayer!.setSourceDeviceFile(_displayPath).catchError((_) {
      if (!mounted) return;
      setState(() => _audioError = true);
    });
  }

  @override
  void dispose() {
    _videoController?.pause();
    _videoController?.dispose();
    _audioPlayer?.stop();
    _audioPlayer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fileName = _displayPath.split('/').last;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title ?? fileName,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_type == BRWebFileType.video && _videoInitialized)
            IconButton(
              icon: const Icon(Icons.replay),
              tooltip: '重播',
              onPressed: () {
                _videoController?.seekTo(Duration.zero);
                _videoController?.play();
              },
            ),
        ],
      ),
      backgroundColor: Colors.black,
      body: _buildBody(theme, fileName),
    );
  }

  Widget _buildBody(ThemeData theme, String fileName) {
    switch (_type) {
      case BRWebFileType.image:
        return _buildImagePreview(theme, fileName);
      case BRWebFileType.video:
        return _buildVideoPreview(theme, fileName);
      case BRWebFileType.audio:
        return _buildAudioPreview(theme, fileName);
      case BRWebFileType.unknown:
        return _buildUnknownPreview(theme, fileName);
    }
  }

  Widget _buildImagePreview(ThemeData theme, String fileName) {
    final file = File(_displayPath);
    if (!file.existsSync()) {
      return _buildError('文件不存在: $_displayPath');
    }

    return Column(
      children: [
        Expanded(
          child: InteractiveViewer(
            minScale: 1.0,
            maxScale: 5.0,
            child: Center(
              child: Image.file(
                file,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) =>
                    const Center(child: Icon(Icons.broken_image, size: 64)),
              ),
            ),
          ),
        ),
        _buildInfoBar(theme, fileName),
      ],
    );
  }

  Widget _buildVideoPreview(ThemeData theme, String fileName) {
    if (_videoError) {
      return _buildError('视频加载失败');
    }
    if (!_videoInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    final controller = _videoController!;
    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                controller.value.isPlaying
                    ? controller.pause()
                    : controller.play();
              });
            },
            child: Center(
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    VideoPlayer(controller),
                    if (!controller.value.isPlaying)
                      Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black38,
                        ),
                        padding: const EdgeInsets.all(16),
                        child: const Icon(
                          Icons.play_arrow,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        _buildVideoProgress(controller),
        _buildInfoBar(theme, fileName),
      ],
    );
  }

  Widget _buildVideoProgress(VideoPlayerController controller) {
    return VideoProgressIndicator(
      controller,
      allowScrubbing: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      colors: const VideoProgressColors(
        playedColor: Colors.blue,
        bufferedColor: Colors.white24,
        backgroundColor: Colors.white10,
      ),
    );
  }

  Widget _buildAudioPreview(ThemeData theme, String fileName) {
    if (_audioError) {
      return _buildError('音频加载失败');
    }

    return Column(
      children: [
        const Spacer(),
        // 音频图标
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.audiotrack,
            size: 48,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 32),
        // 文件名
        Text(
          fileName,
          style: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 16),
        // 进度条
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: theme.colorScheme.primary,
              inactiveTrackColor: Colors.white24,
              thumbColor: theme.colorScheme.primary,
              overlayColor:
                  theme.colorScheme.primary.withValues(alpha: 0.12),
            ),
            child: Slider(
              min: 0,
              max: _audioDuration.inMilliseconds.toDouble().clamp(1, double.infinity),
              value: _audioPosition.inMilliseconds
                  .toDouble()
                  .clamp(0, _audioDuration.inMilliseconds.toDouble()),
              onChanged: (v) {
                _audioPlayer?.seek(Duration(milliseconds: v.toInt()));
              },
            ),
          ),
        ),
        // 时间显示
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(_audioPosition),
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
              Text(
                _formatDuration(_audioDuration),
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // 播放/暂停
        FloatingActionButton(
          heroTag: 'audio_play',
          onPressed: () {
            if (_audioState == PlayerState.playing) {
              _audioPlayer?.pause();
            } else {
              _audioPlayer?.resume();
            }
          },
          child: Icon(
            _audioState == PlayerState.playing
                ? Icons.pause
                : Icons.play_arrow,
          ),
        ),
        const Spacer(),
        _buildInfoBar(theme, fileName),
      ],
    );
  }

  Widget _buildUnknownPreview(ThemeData theme, String fileName) {
    return Column(
      children: [
        const Spacer(),
        const Icon(Icons.insert_drive_file, size: 80, color: Colors.white38),
        const SizedBox(height: 16),
        Text(
          '不支持预览此文件类型',
          style: theme.textTheme.titleMedium?.copyWith(color: Colors.white60),
        ),
        const Spacer(),
        _buildInfoBar(theme, fileName),
      ],
    );
  }

  Widget _buildInfoBar(ThemeData theme, String fileName) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        border: Border(top: BorderSide(color: Colors.grey.shade800)),
      ),
      child: Row(
        children: [
          Icon(
            _typeIcon(),
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              fileName,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (widget.fileSize != null) ...[
            const SizedBox(width: 8),
            Text(
              formatFileSize(widget.fileSize!),
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  IconData _typeIcon() {
    return switch (_type) {
      BRWebFileType.image => Icons.image_outlined,
      BRWebFileType.video => Icons.videocam_outlined,
      BRWebFileType.audio => Icons.audiotrack_outlined,
      BRWebFileType.unknown => Icons.insert_drive_file_outlined,
    };
  }

  String _formatDuration(Duration d) {
    final min = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final sec = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$min:$sec';
  }
}
