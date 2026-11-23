DateTime nowUtc() => DateTime.fromMillisecondsSinceEpoch(
  DateTime.now().millisecondsSinceEpoch,
  isUtc: true,
);
