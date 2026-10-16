import '../models/candle.dart';

class VwapCalculator {
  /// Classic session VWAP from a list of candles
  static double? calculate(List<Candle> candles) {
    if (candles.isEmpty) return null;
    double cumPV = 0;
    double cumVol = 0;
    for (final c in candles) {
      final typical = (c.high + c.low + c.close) / 3;
      cumPV += typical * c.volume;
      cumVol += c.volume;
    }
    if (cumVol == 0) return null;
    return cumPV / cumVol;
  }

  /// Daily / Weekly / Monthly VWAP can be calculated by filtering candles
  /// by the desired period before calling calculate().
}
