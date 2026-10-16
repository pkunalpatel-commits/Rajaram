import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/candle.dart';

/// REST helpers aligned with working kunalapk (https://github.com/pkunalpatel-commits/kunalapk)
class DhanApi {
  static const String base = 'https://api.dhan.co/v2';

  final String clientId;
  final String accessToken;

  DhanApi({required this.clientId, required this.accessToken});

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'access-token': accessToken,
        'client-id': clientId,
      };

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final res = await http
        .post(
          Uri.parse('$base$path'),
          headers: _headers,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));

    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${res.body.substring(0, res.body.length.clamp(0, 300))}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    if (json['status'] != null && json['status'] != 'success') {
      throw Exception('API error: ${res.body.substring(0, res.body.length.clamp(0, 300))}');
    }
    return json;
  }

  /// Option chain (LTP + OI + greeks for all strikes) — same as kunalapk
  Future<Map<String, dynamic>> getOptionChain({
    required int underlyingScrip,
    required String underlyingSeg,
    required String expiry,
  }) async {
    final json = await _post('/optionchain', {
      'UnderlyingScrip': underlyingScrip,
      'UnderlyingSeg': underlyingSeg,
      'Expiry': expiry,
    });
    return json['data'] as Map<String, dynamic>? ?? json;
  }

  Future<List<String>> getExpiryList({
    required int underlyingScrip,
    required String underlyingSeg,
  }) async {
    final json = await _post('/optionchain/expirylist', {
      'UnderlyingScrip': underlyingScrip,
      'UnderlyingSeg': underlyingSeg,
    });
    final data = json['data'];
    if (data is List) return data.map((e) => e.toString()).toList();
    return [];
  }

  Future<List<Candle>> getIntradayCandles({
    required String securityId,
    required String exchangeSegment,
    required String instrument,
    required String fromDate,
    required String toDate,
    String interval = '1',
  }) async {
    final res = await http
        .post(
          Uri.parse('$base/charts/intraday'),
          headers: _headers,
          body: jsonEncode({
            'securityId': securityId,
            'exchangeSegment': exchangeSegment,
            'instrument': instrument,
            'interval': interval,
            'oi': true,
            'fromDate': fromDate,
            'toDate': toDate,
          }),
        )
        .timeout(const Duration(seconds: 45));

    if (res.statusCode != 200) {
      throw Exception('Intraday ${res.statusCode}: ${res.body.substring(0, 200)}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    // Historical responses may be flat (timestamp arrays) or nested under data
    final root = data.containsKey('timestamp') ? data : (data['data'] as Map<String, dynamic>? ?? data);

    final opens = List<num>.from(root['open'] ?? []);
    final highs = List<num>.from(root['high'] ?? []);
    final lows = List<num>.from(root['low'] ?? []);
    final closes = List<num>.from(root['close'] ?? []);
    final volumes = List<num>.from(root['volume'] ?? []);
    final timestamps = List<int>.from(root['timestamp'] ?? []);
    final ois = root['open_interest'] != null
        ? List<int>.from(root['open_interest'])
        : null;

    final candles = <Candle>[];
    for (var i = 0; i < timestamps.length; i++) {
      candles.add(Candle(
        time: DateTime.fromMillisecondsSinceEpoch(timestamps[i] * 1000),
        open: opens[i].toDouble(),
        high: highs[i].toDouble(),
        low: lows[i].toDouble(),
        close: closes[i].toDouble(),
        volume: i < volumes.length ? volumes[i].toDouble() : 0,
        oi: ois != null && i < ois.length ? ois[i] : null,
      ));
    }
    return candles;
  }
}
