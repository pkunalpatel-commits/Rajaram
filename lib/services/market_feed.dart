import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

/// DhanHQ Live Market Feed — WebSocket ONLY
/// Docs: https://dhanhq.co/docs/v2/live-market-feed/
///
/// URL:
///   wss://api-feed.dhan.co?version=2&token={ACCESS_TOKEN}&clientId={CLIENT_ID}&authType=2
///
/// Subscribe (JSON):
///   RequestCode 15 = Ticker, 17 = Quote, 21 = Full (LTP+OI+Depth)
///
/// Responses are BINARY (little-endian). Header = 8 bytes.
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

  void Function(double ltp, int? oi)? onTick;

  /// Connect WebSocket (official Dhan v2 Data API feed)
  Future<void> connect({
    required String clientId,
    required String accessToken,
    required String securityId,
    required String exchangeSegment, // e.g. NSE_FNO
  }) async {
    await disconnect();
    lastError = null;
    notifyListeners();

    // Official URL from https://dhanhq.co/docs/v2/live-market-feed/
    final uri = Uri.parse(
      'wss://api-feed.dhan.co'
      '?version=2'
      '&token=${Uri.encodeComponent(accessToken)}'
      '&clientId=${Uri.encodeComponent(clientId)}'
      '&authType=2',
    );

    try {
      debugPrint('WS connecting: ${uri.toString().replaceAll(accessToken, "***")}');
      _channel = IOWebSocketChannel.connect(
        uri,
        pingInterval: const Duration(seconds: 10), // respond to server ping
      );

      // Subscribe AFTER connection opens — Full mode (RequestCode 21) has OI
      // SDK: Ticker=15, Quote=17, Full=21
      final subscribeMsg = jsonEncode({
        'RequestCode': 21, // Full packet → LTP + OI + depth
        'InstrumentCount': 1,
        'InstrumentList': [
          {
            'ExchangeSegment': exchangeSegment,
            'SecurityId': securityId,
          }
        ],
      });

      _channel!.sink.add(subscribeMsg);
      debugPrint('WS subscribe sent: $subscribeMsg');

      isConnected = true;
      notifyListeners();

      _sub = _channel!.stream.listen(
        (data) {
          if (data is List<int>) {
            _parseBinary(Uint8List.fromList(data));
          } else if (data is String) {
            debugPrint('WS text: $data');
            // Some servers send error as text
            if (data.toLowerCase().contains('error') ||
                data.toLowerCase().contains('invalid')) {
              lastError = data;
              notifyListeners();
            }
          }
        },
        onError: (e) {
          lastError = e.toString();
          isConnected = false;
          debugPrint('WS error: $e');
          notifyListeners();
        },
        onDone: () {
          isConnected = false;
          lastError ??= 'WebSocket closed by server';
          debugPrint('WS closed');
          notifyListeners();
        },
        cancelOnError: false,
      );
    } catch (e) {
      lastError = e.toString();
      isConnected = false;
      debugPrint('WS connect failed: $e');
      notifyListeners();
    }
  }

  /// Binary parser — Little Endian (official DhanHQ docs)
  /// Header (8 bytes):
  ///   [0]     = feed response code
  ///   [1-2]   = message length (int16)
  ///   [3]     = exchange segment
  ///   [4-7]   = security id (int32)
  void _parseBinary(Uint8List bytes) {
    if (bytes.length < 9) return;

    final bd = ByteData.sublistView(bytes);
    final code = bytes[0];

    try {
      switch (code) {
        case 2: // Ticker
          if (bytes.length >= 17) {
            ltp = bd.getFloat32(9, Endian.little);
            onTick?.call(ltp!, oi);
            notifyListeners();
          }
          break;

        case 4: // Quote
          if (bytes.length >= 51) {
            ltp = bd.getFloat32(9, Endian.little);
            volume = bd.getInt32(23, Endian.little).toDouble();
            dayOpen = bd.getFloat32(35, Endian.little);
            dayClose = bd.getFloat32(39, Endian.little);
            dayHigh = bd.getFloat32(43, Endian.little);
            dayLow = bd.getFloat32(47, Endian.little);
            onTick?.call(ltp!, oi);
            notifyListeners();
          }
          break;

        case 5: // OI packet (with Quote subscription)
          if (bytes.length >= 13) {
            oi = bd.getInt32(9, Endian.little);
            if (ltp != null) onTick?.call(ltp!, oi);
            notifyListeners();
          }
          break;

        case 6: // Prev close
          if (bytes.length >= 17) {
            // prev close float32 @ 9, prev OI int32 @ 13
          }
          break;

        case 8: // Full packet (LTP + OI + depth)
          // Docs Full packet offsets:
          // 9-12   LTP float32
          // 13-14  LTQ int16
          // 15-18  LTT int32
          // 19-22  ATP float32
          // 23-26  Volume int32
          // 27-30  Total Sell int32
          // 31-34  Total Buy int32
          // 35-38  OI int32
          // 39-42  OI day high int32
          // 43-46  OI day low int32
          // 47-50  Day Open float32
          // 51-54  Day Close float32
          // 55-58  Day High float32
          // 59-62  Day Low float32
          if (bytes.length >= 63) {
            ltp = bd.getFloat32(9, Endian.little);
            volume = bd.getInt32(23, Endian.little).toDouble();
            oi = bd.getInt32(35, Endian.little);
            oiDayHigh = bd.getInt32(39, Endian.little);
            oiDayLow = bd.getInt32(43, Endian.little);
            dayOpen = bd.getFloat32(47, Endian.little);
            dayClose = bd.getFloat32(51, Endian.little);
            dayHigh = bd.getFloat32(55, Endian.little);
            dayLow = bd.getFloat32(59, Endian.little);
            onTick?.call(ltp!, oi);
            notifyListeners();
          }
          break;

        case 50: // Disconnect
          if (bytes.length >= 11) {
            final reason = bd.getInt16(9, Endian.little);
            lastError = 'Server disconnect code $reason';
            isConnected = false;
            notifyListeners();
          }
          break;

        default:
          debugPrint('WS unknown code=$code len=${bytes.length}');
      }
    } catch (e) {
      debugPrint('Binary parse error code=$code: $e');
    }
  }

  Future<void> disconnect() async {
    try {
      // Official disconnect request
      _channel?.sink.add(jsonEncode({'RequestCode': 12}));
    } catch (_) {}
    await _sub?.cancel();
    await _channel?.sink.close();
    _channel = null;
    _sub = null;
    isConnected = false;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
