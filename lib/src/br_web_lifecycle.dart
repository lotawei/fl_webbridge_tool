enum BRWebLifecycleType {
  created,
  loadStart,
  loadStop,
  progress,
  historyUpdate,
  titleChanged,
  console,
  error,
  disposed,
}

class BRWebLifecycleEvent {
  const BRWebLifecycleEvent({
    required this.type,
    required this.timestamp,
    this.url,
    this.title,
    this.progress,
    this.message,
  });

  final BRWebLifecycleType type;
  final DateTime timestamp;
  final String? url;
  final String? title;
  final int? progress;
  final String? message;
}
