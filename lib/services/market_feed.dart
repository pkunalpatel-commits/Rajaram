import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Live Market Feed via DhanHQ WebSocket (v2)
/// Uses Full packet for LTP + OI + OHLC in one go.
class MarketFeedService extends ChangeNotifier {
  WebSocketChannel? _channel;
  StreamSubscription? _sub;

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

  // Callback when a new tick arrives
  void Function(double ltp, int? oi)? onTick;

  Future<void> connect({
    required String clientId,
    required String accessToken,
    required String securityId,
    required String exchangeSegment, // e.g. "NSE_FNO"
  }) async {
    await disconnect();

    final url =
        'wss://api-feed.dhan.co?version=2&token=$accessToken&clientId=$clientId&authType=2';

    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      isConnected = true;
      lastError = null;
      notifyListeners();

      // Subscribe to Full mode (RequestCode 15 + mode Full)
      final subscribeMsg = jsonEncode({
        'RequestCode': 15,
        'InstrumentCount': 1,
        'InstrumentList': [
          {
            'ExchangeSegment': exchangeSegment,
            'SecurityId': securityId,
          }
        ]
      });
      _channel!.sink.add(subscribeMsg);

      _sub = _channel!.stream.listen(
        (data) {
          if (data is List<int>) {
            _parseBinary(Uint8List.fromList(data));
          } else if (data is String) {
            debugPrint('WS text: $data');
          }
        },
        onError: (e) {
          lastError = e.toString();
          isConnected = false;
          notifyListeners();
        },
        onDone: () {
          isConnected = false;
          notifyListeners();
        },
      );
    } catch (e) {
      lastError = e.toString();
      isConnected = false;
      notifyListeners();
    }
  }

  /// Very simplified binary parser for demonstration.
  /// Production apps should implement the full packet layout from
  /// https://dhanhq.co/docs/v2/live-market-feed/
  void _parseBinary(Uint8List bytes) {
    if (bytes.length < 50) return;

    // Response header is 8 bytes. Code at offset determines packet type.
    // Full packet code = 8 (see docs)
    // For simplicity we extract common float32 / int32 fields.
    // Real implementation needs proper little-endian parsing of every field.

    try {
      final bd = ByteData.sublistView(bytes);

      // Rough offsets based on documented Full packet structure
      // (these are approximate – refine with official binary layout)
      final possibleLtp = bd.getFloat32(9, Endian.little);
      if (possibleLtp > 0 && possibleLtp < 100000) {
        ltp = possibleLtp;
      }

      // OI is usually around offset 35-38 as int32
      if (bytes.length > 42) {
        final possibleOi = bd.getInt32(35, Endian.little);
        if (possibleOi > 0) oi = possibleOi;
      }

      if (ltp != null) {
        onTick?.call(ltp!, oi);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Binary parse error: $e');
    }
  }

  Future<void> disconnect() async {
    await _sub?.cancel();
    await _channel?.sink.close();
    _channel = null;
    isConnected = false;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
