import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/candle.dart';

/// REST helpers for DhanHQ v2 Data APIs
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

  /// Intraday historical candles (1min, 5min, etc.)
  Future<List<Candle>> getIntradayCandles({
    required String securityId,
    required String exchangeSegment, // NSE_FNO
    required String instrument, // OPTIDX
    required String fromDate, // yyyy-MM-dd
    required String toDate,
    int interval = 1, // minutes
  }) async {
    final body = {
      'securityId': securityId,
      'exchangeSegment': exchangeSegment,
      'instrument': instrument,
      'expiryCode': 0,
      'oi': true,
      'fromDate': fromDate,
      'toDate': toDate,
    };

    final res = await http.post(
      Uri.parse('$base/charts/intraday'),
      headers: _headers,
      body: jsonEncode(body),
    );

    if (res.statusCode != 200) {
      throw Exception('Intraday API ${res.statusCode}: ${res.body}');
    }

    final data = jsonDecode(res.body)['data'] as Map<String, dynamic>?;
    if (data == null) return [];

    final opens = List<num>.from(data['open'] ?? []);
    final highs = List<num>.from(data['high'] ?? []);
    final lows = List<num>.from(data['low'] ?? []);
    final closes = List<num>.from(data['close'] ?? []);
    final volumes = List<num>.from(data['volume'] ?? []);
    final timestamps = List<int>.from(data['timestamp'] ?? []);
    final ois = data['open_interest'] != null
        ? List<int>.from(data['open_interest'])
        : null;

    final candles = <Candle>[];
    for (var i = 0; i < timestamps.length; i++) {
      candles.add(Candle(
        time: DateTime.fromMillisecondsSinceEpoch(timestamps[i] * 1000),
        open: opens[i].toDouble(),
        high: highs[i].toDouble(),
        low: lows[i].toDouble(),
        close: closes[i].toDouble(),
        volume: volumes[i].toDouble(),
        oi: ois != null && i < ois.length ? ois[i] : null,
      ));
    }
    return candles;
  }

  /// Daily historical
  Future<List<Candle>> getDailyCandles({
    required String securityId,
    required String exchangeSegment,
    required String instrument,
    required String fromDate,
    required String toDate,
  }) async {
    final body = {
      'securityId': securityId,
      'exchangeSegment': exchangeSegment,
      'instrument': instrument,
      'expiryCode': 0,
      'oi': true,
      'fromDate': fromDate,
      'toDate': toDate,
    };

    final res = await http.post(
      Uri.parse('$base/charts/historical'),
      headers: _headers,
      body: jsonEncode(body),
    );

    if (res.statusCode != 200) {
      throw Exception('Daily API ${res.statusCode}: ${res.body}');
    }

    final data = jsonDecode(res.body)['data'] as Map<String, dynamic>?;
    if (data == null) return [];

    // Same parsing as intraday
    final opens = List<num>.from(data['open'] ?? []);
    final highs = List<num>.from(data['high'] ?? []);
    final lows = List<num>.from(data['low'] ?? []);
    final closes = List<num>.from(data['close'] ?? []);
    final volumes = List<num>.from(data['volume'] ?? []);
    final timestamps = List<int>.from(data['timestamp'] ?? []);
    final ois = data['open_interest'] != null
        ? List<int>.from(data['open_interest'])
        : null;

    final candles = <Candle>[];
    for (var i = 0; i < timestamps.length; i++) {
      candles.add(Candle(
        time: DateTime.fromMillisecondsSinceEpoch(timestamps[i] * 1000),
        open: opens[i].toDouble(),
        high: highs[i].toDouble(),
        low: lows[i].toDouble(),
        close: closes[i].toDouble(),
        volume: volumes[i].toDouble(),
        oi: ois != null && i < ois.length ? ois[i] : null,
      ));
    }
    return candles;
  }

  /// Option Chain (for bulk OI context)
  Future<Map<String, dynamic>> getOptionChain({
    required String underlyingScrip,
    required String underlyingSeg, // IDX_I
    required String expiry,
  }) async {
    final body = {
      'UnderlyingScrip': int.tryParse(underlyingScrip) ?? 13,
      'UnderlyingSeg': underlyingSeg,
      'Expiry': expiry,
    };

    final res = await http.post(
      Uri.parse('$base/optionchain'),
      headers: _headers,
      body: jsonEncode(body),
    );

    if (res.statusCode != 200) {
      throw Exception('OptionChain ${res.statusCode}: ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
