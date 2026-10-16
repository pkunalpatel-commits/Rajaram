import 'package:flutter/foundation.dart';
import '../models/oi_profile.dart';

class OiProfileService extends ChangeNotifier {
  OiProfile profile = OiProfile(binSize: 2.0);

  void updateBinSize(double size) {
    // Rebuild with new bin size
    final old = Map<double, double>.from(profile.bins);
    profile = OiProfile(binSize: size);
    old.forEach((prem, oi) => profile.add(prem, oi));
    notifyListeners();
  }

  /// Called on every live tick
  void onLiveTick(double premium, int? currentOi) {
    if (currentOi == null) return;
    // For simplicity we set absolute OI at the current premium bin.
    // For true volume-profile style you would accumulate ΔOI or trade volume.
    profile.set(premium, currentOi.toDouble());
    notifyListeners();
  }

  /// Feed historical candles that contain OI
  void buildFromCandles(List<dynamic> candles) {
    profile = OiProfile(binSize: profile.binSize);
    for (final c in candles) {
      if (c.oi != null) {
        profile.add(c.close, c.oi.toDouble());
      }
    }
    notifyListeners();
  }

  void clear() {
    profile = OiProfile(binSize: profile.binSize);
    notifyListeners();
  }
}
