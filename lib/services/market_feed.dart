import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import '../utils/app_log.dart';

/// DhanHQ Live Market Feed — WebSocket ONLY
/// Docs: https://dhanhq.co/docs/v2/live-market-feed/
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

  Future<void> connect({
    required String clientId,
    required String accessToken,
    required String securityId,
    required String exchangeSegment,
  }) async {
    await disconnect();
    lastError = null;
    notifyListeners();

    if (clientId.trim().isEmpty || accessToken.trim().isEmpty) {
      lastError = 'Client ID or Access Token is empty. Open Settings.';
      AppLog.e(lastError!);
      notifyListeners();
      return;
    }

    final uri = Uri.parse(
      'wss://api-feed.dhan.co'
      '?version=2'
      '&token=${Uri.encodeComponent(accessToken.trim())}'
      '&clientId=${Uri.encodeComponent(clientId.trim())}'
      '&authType=2',
    );

    try {
      AppLog.i('WS connect clientId=$clientId secId=$securityId seg=$exchangeSegment');
      _channel = IOWebSocketChannel.connect(
        uri,
        pingInterval: const Duration(seconds: 10),
      );

      final subscribeMsg = jsonEncode({
        'RequestCode': 21,
        'InstrumentCount': 1,
        'InstrumentList': [
          {
            'ExchangeSegment': exchangeSegment,
            'SecurityId': securityId,
          }
        ],
      });

      _channel!.sink.add(subscribeMsg);
      AppLog.i('WS subscribe: $subscribeMsg');

      isConnected = true;
      notifyListeners();

      _sub = _channel!.stream.listen(
        (data) {
          if (data is List<int>) {
            _parseBinary(Uint8List.fromList(data));
          } else if (data is String) {
            AppLog.w('WS text: $data');
            if (data.toLowerCase().contains('error') ||
                data.toLowerCase().contains('invalid') ||
                data.toLowerCase().contains('missing')) {
              lastError = data;
              notifyListeners();
            }
          }
        },
        onError: (e) {
          lastError = e.toString();
          isConnected = false;
          AppLog.e('WS error: $e');
          notifyListeners();
        },
        onDone: () {
          isConnected = false;
          lastError ??= 'WebSocket closed by server';
          AppLog.w('WS closed: $lastError');
          notifyListeners();
        },
        cancelOnError: false,
      );
    } catch (e) {
      lastError = e.toString();
      isConnected = false;
      AppLog.e('WS connect failed: $e');
      notifyListeners();
    }
  }

  void _parseBinary(Uint8List bytes) {
    if (bytes.length < 9) return;
    final bd = ByteData.sublistView(bytes);
    final code = bytes[0];

    try {
      switch (code) {
        case 2:
          if (bytes.length >= 17) {
            ltp = bd.getFloat32(9, Endian.little);
            onTick?.call(ltp!, oi);
            notifyListeners();
          }
          break;
        case 4:
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
        case 5:
          if (bytes.length >= 13) {
            oi = bd.getInt32(9, Endian.little);
            if (ltp != null) onTick?.call(ltp!, oi);
            notifyListeners();
          }
          break;
        case 8:
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
            AppLog.i('Full tick LTP=$ltp OI=$oi');
            onTick?.call(ltp!, oi);
            notifyListeners();
          }
          break;
        case 50:
          if (bytes.length >= 11) {
            final reason = bd.getInt16(9, Endian.little);
            lastError = 'Server disconnect code $reason';
            isConnected = false;
            AppLog.e(lastError!);
            notifyListeners();
          }
          break;
        default:
          AppLog.w('WS unknown code=$code len=${bytes.length}');
      }
    } catch (e) {
      AppLog.e('Binary parse code=$code: $e');
    }
  }

  Future<void> disconnect() async {
    try {
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
