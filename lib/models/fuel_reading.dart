enum ReadingSession { morning, evening }

class FuelReading {
  final String value;
  final DateTime timestamp;
  final ReadingSession session;

  FuelReading({
    required this.value,
    required this.timestamp,
    required this.session,
  });

  Map<String, dynamic> toJson() => {
    'value': value,
    'timestamp': timestamp.toIso8601String(),
    'session': session.name,
  };

  factory FuelReading.fromJson(Map<String, dynamic> json) => FuelReading(
    value: json['value'],
    timestamp: DateTime.parse(json['timestamp']),
    session: ReadingSession.values.byName(json['session']),
  );
}
