import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Live market data via Dhan REST API (same approach as kunalapk).
/// Avoids WebSocket api-feed.dhan.co which fails DNS on many networks.
class MarketFeedService extends ChangeNotifier {
  double? ltp;
  double? dayOpen;
  double? dayHigh;
  double? dayLow;
  double? dayClose;
  int? oi;
  int? oiDayHigh;
  int? oiDayLow;
  double? volume;
  bool isConnected = false;
  String? lastError;

  void Function(double ltp, int? oi)? onTick;

  Timer? _pollTimer;
  String? _clientId;
  String? _accessToken;
  String? _securityId;
  String? _exchangeSegment;

  Future<void> connect({
    required String clientId,
    required String accessToken,
    required String securityId,
    required String exchangeSegment,
  }) async {
    await disconnect();

    _clientId = clientId;
    _accessToken = accessToken;
    _securityId = securityId;
    _exchangeSegment = exchangeSegment;

    final ok = await _fetchQuote();
    if (!ok) {
      isConnected = false;
      notifyListeners();
      return;
    }

    isConnected = true;
    lastError = null;
    notifyListeners();

    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      await _fetchQuote();
    });
  }

  Future<bool> _fetchQuote() async {
    if (_clientId == null || _accessToken == null || _securityId == null) {
      return false;
    }

    try {
      // Try LTP endpoint first (lighter), then full quote
      final endpoints = [
        'https://api.dhan.co/v2/marketfeed/ltp',
        'https://api.dhan.co/v2/marketfeed/quote',
        'https://api.dhan.co/v2/marketfeed/ohlc',
      ];

      final body = jsonEncode({
        _exchangeSegment ?? 'NSE_FNO': [int.tryParse(_securityId!) ?? _securityId],
      });

      http.Response? res;
      for (final url in endpoints) {
        try {
          res = await http
              .post(
                Uri.parse(url),
                headers: {
                  'Content-Type': 'application/json',
                  'access-token': _accessToken!,
                  'client-id': _clientId!,
                },
                body: body,
              )
              .timeout(const Duration(seconds: 20));
          if (res.statusCode == 200) break;
        } catch (e) {
          debugPrint('Endpoint $url failed: $e');
        }
      }

      if (res == null || res.statusCode != 200) {
        lastError =
            'Quote failed HTTP ${res?.statusCode}: ${res?.body.substring(0, (res?.body.length ?? 0).clamp(0, 120)) ?? "no response"}';
        notifyListeners();
        return false;
      }

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final data = json['data'] as Map<String, dynamic>? ?? json;

      Map<String, dynamic>? quote;
      // Shape: data[segment][securityId] = {...}
      for (final entry in data.entries) {
        final v = entry.value;
        if (v is Map) {
          if (v.containsKey(_securityId)) {
            final q = v[_securityId];
            if (q is Map) {
              quote = Map<String, dynamic>.from(q);
              break;
            }
          }
          // single instrument nested
          if (v.containsKey('last_price') || v.containsKey('LTP') || v.containsKey('last_price')) {
            quote = Map<String, dynamic>.from(v);
            break;
          }
          // first child
          for (final child in v.values) {
            if (child is Map &&
                (child.containsKey('last_price') ||
                    child.containsKey('LTP') ||
                    child.containsKey('lastPrice'))) {
              quote = Map<String, dynamic>.from(child);
              break;
            }
          }
        }
      }

      if (quote == null &&
          (data.containsKey('last_price') || data.containsKey('LTP'))) {
        quote = data;
      }

      if (quote == null) {
        lastError = 'Parse error: ${res.body.substring(0, res.body.length.clamp(0, 200))}';
        notifyListeners();
        return false;
      }

      final newLtp = _toDouble(
          quote['last_price'] ?? quote['LTP'] ?? quote['lastPrice'] ?? quote['ltp']);
      final newOi = _toInt(
          quote['oi'] ?? quote['OI'] ?? quote['open_interest'] ?? quote['openInterest']);

      if (newLtp != null) {
        ltp = newLtp;
        oi = newOi;
        volume = _toDouble(quote['volume'] ?? quote['Volume']);
        dayOpen = _toDouble(quote['open'] ?? quote['Open']);
        dayHigh = _toDouble(quote['high'] ?? quote['High']);
        dayLow = _toDouble(quote['low'] ?? quote['Low']);
        dayClose = _toDouble(quote['close'] ?? quote['Close']);
        lastError = null;
        onTick?.call(newLtp, newOi);
        notifyListeners();
        return true;
      }

      lastError = 'No LTP in response';
      notifyListeners();
      return false;
    } catch (e) {
      lastError = e.toString();
      debugPrint('Quote error: $e');
      notifyListeners();
      return false;
    }
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  Future<void> disconnect() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    isConnected = false;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
