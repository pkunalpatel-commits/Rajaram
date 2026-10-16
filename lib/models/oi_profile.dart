import 'dart:math';

/// Option Premium OI Profile
/// Y-axis = Option Premium bins
/// Horizontal bars = total OI or ΔOI at that premium level
class OiProfile {
  final double binSize;
  final Map<double, double> bins; // premiumBin → OI (or ΔOI)
  double? poc; // Point of Control (premium with max OI)
  List<double> highOiNodes = []; // HOIN
  List<double> lowOiNodes = []; // LOIN

  OiProfile({this.binSize = 2.0}) : bins = {};

  void add(double premium, double oiValue) {
    final bin = (premium / binSize).floor() * binSize;
    bins[bin] = (bins[bin] ?? 0) + oiValue;
    _recalculate();
  }

  void set(double premium, double oiValue) {
    final bin = (premium / binSize).floor() * binSize;
    bins[bin] = oiValue;
    _recalculate();
  }

  void _recalculate() {
    if (bins.isEmpty) {
      poc = null;
      highOiNodes = [];
      lowOiNodes = [];
      return;
    }

    // POC
    poc = bins.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    final values = bins.values.toList();
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance =
        values.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) / values.length;
    final std = sqrt(variance);

    highOiNodes = bins.entries
        .where((e) => e.value > mean + 1.2 * std)
        .map((e) => e.key)
        .toList()
      ..sort();

    lowOiNodes = bins.entries
        .where((e) => e.value < mean * 0.3)
        .map((e) => e.key)
        .toList()
      ..sort();
  }

  double get maxOi =>
      bins.isEmpty ? 0 : bins.values.reduce((a, b) => a > b ? a : b);

  List<MapEntry<double, double>> get sortedBins {
    final list = bins.entries.toList();
    list.sort((a, b) => a.key.compareTo(b.key));
    return list;
  }
}
