class Candle {
  final DateTime time;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;
  final int? oi; // Open Interest (for options)

  Candle({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
    this.oi,
  });

  factory Candle.fromJson(Map<String, dynamic> json) {
    return Candle(
      time: DateTime.fromMillisecondsSinceEpoch(
          (json['timestamp'] as int) * 1000),
      open: (json['open'] as num).toDouble(),
      high: (json['high'] as num).toDouble(),
      low: (json['low'] as num).toDouble(),
      close: (json['close'] as num).toDouble(),
      volume: (json['volume'] as num?)?.toDouble() ?? 0,
      oi: json['open_interest'] as int?,
    );
  }
}
