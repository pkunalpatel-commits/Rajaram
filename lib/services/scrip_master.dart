import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/option_contract.dart';
import '../utils/app_log.dart';

/// Instrument loader — does NOT use images.dhan.co (DNS fails on many phones).
/// Uses same approach as kunalapk: hardcoded underlyings + api.dhan.co option chain.
class ScripMasterService extends ChangeNotifier {
  static const _underlyings = <String, _Underlying>{
    'NIFTY': _Underlying(13, 'IDX_I'),
    'BANKNIFTY': _Underlying(25, 'IDX_I'),
    'FINNIFTY': _Underlying(27, 'IDX_I'),
    'MIDCPNIFTY': _Underlying(442, 'IDX_I'),
    'SENSEX': _Underlying(51, 'IDX_I'),
  };

  List<Map<String, dynamic>> _rows = [];
  bool isLoading = false;
  String? error;
  bool usedOfflineFallback = false;

  List<Map<String, dynamic>> get rows => _rows;

  /// Load expiries + option contracts via api.dhan.co (works when images.dhan.co DNS fails)
  Future<void> load() async {
    isLoading = true;
    error = null;
    usedOfflineFallback = false;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final clientId = prefs.getString('clientId')?.trim() ?? '';
    final token = prefs.getString('accessToken')?.trim() ?? '';

    if (clientId.isEmpty || token.isEmpty) {
      error =
          'Set Client ID + Access Token in Settings first.\n'
          'Then tap Reconnect to load live contracts from api.dhan.co';
      _rows = _demoRows();
      usedOfflineFallback = true;
      isLoading = false;
      notifyListeners();
      return;
    }

    try {
      final allRows = <Map<String, dynamic>>[];

      for (final entry in _underlyings.entries) {
        final name = entry.key;
        final u = entry.value;

        // 1) Expiry list
        final expiries = await _postList(
          clientId,
          token,
          '/optionchain/expirylist',
          {
            'UnderlyingScrip': u.scrip,
            'UnderlyingSeg': u.seg,
          },
        );

        if (expiries.isEmpty) continue;

        // Take nearest 2 expiries (like kunalapk default)
        final useExpiries = expiries.take(2).toList();

        for (final exp in useExpiries) {
          // 2) Full option chain for this expiry
          final chain = await _postMap(
            clientId,
            token,
            '/optionchain',
            {
              'UnderlyingScrip': u.scrip,
              'UnderlyingSeg': u.seg,
              'Expiry': exp,
            },
          );

          final oc = chain['oc'] as Map<String, dynamic>? ?? {};
          oc.forEach((strikeStr, data) {
            if (data is! Map) return;
            final strike = double.tryParse(strikeStr) ?? 0;
            for (final ot in ['ce', 'pe']) {
              final leg = data[ot];
              if (leg is! Map) continue;
              final secId = leg['security_id']?.toString() ??
                  leg['securityId']?.toString() ??
                  '';
              if (secId.isEmpty) continue;
              allRows.add({
                'SEM_SMST_SECURITY_ID': secId,
                'SEM_TRADING_SYMBOL': '$name $exp $strike ${ot.toUpperCase()}',
                'SEM_CUSTOM_SYMBOL': '$name $exp $strike ${ot.toUpperCase()}',
                'SEM_INSTRUMENT_NAME': 'OPTIDX',
                'SEM_EXPIRY_DATE': exp,
                'SEM_STRIKE_PRICE': strike.toString(),
                'SEM_OPTION_TYPE': ot.toUpperCase(),
                'SEM_TICK_SIZE': '0.05',
                'SEM_LOT_UNITS': name.contains('BANK') ? '15' : '25',
              });
            }
          });
        }
      }

      if (allRows.isEmpty) {
        throw Exception(
          'No contracts returned. Check Data API plan and token.',
        );
      }

      _rows = allRows;
      usedOfflineFallback = false;
      error = null;
      AppLog.i('Loaded ${_rows.length} contracts from api.dhan.co');
    } catch (e) {
      AppLog.e('Scrip load error: $e');
      error = e.toString();
      _rows = _demoRows();
      usedOfflineFallback = true;
    }

    isLoading = false;
    notifyListeners();
  }

  Future<List<String>> _postList(
    String clientId,
    String token,
    String path,
    Map<String, dynamic> body,
  ) async {
    final res = await http
        .post(
          Uri.parse('https://api.dhan.co/v2$path'),
          headers: {
            'Content-Type': 'application/json',
            'access-token': token,
            'client-id': clientId,
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));

    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${res.body.take(150)}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final data = json['data'];
    if (data is List) return data.map((e) => e.toString()).toList();
    return [];
  }

  Future<Map<String, dynamic>> _postMap(
    String clientId,
    String token,
    String path,
    Map<String, dynamic> body,
  ) async {
    final res = await http
        .post(
          Uri.parse('https://api.dhan.co/v2$path'),
          headers: {
            'Content-Type': 'application/json',
            'access-token': token,
            'client-id': clientId,
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));

    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${res.body.take(150)}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final data = json['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return json;
  }

  List<Map<String, dynamic>> _demoRows() {
    final rows = <Map<String, dynamic>>[];
    var id = 50000;
    for (final name in ['NIFTY', 'BANKNIFTY']) {
      final atm = name == 'NIFTY' ? 24000.0 : 52000.0;
      final step = name == 'NIFTY' ? 50.0 : 100.0;
      for (final exp in ['2026-10-28', '2026-11-25']) {
        for (var k = -5; k <= 5; k++) {
          final strike = atm + k * step;
          for (final ot in ['CE', 'PE']) {
            rows.add({
              'SEM_SMST_SECURITY_ID': '${id++}',
              'SEM_TRADING_SYMBOL': '$name $exp $strike $ot',
              'SEM_CUSTOM_SYMBOL': '$name $exp $strike $ot',
              'SEM_INSTRUMENT_NAME': 'OPTIDX',
              'SEM_EXPIRY_DATE': exp,
              'SEM_STRIKE_PRICE': strike.toString(),
              'SEM_OPTION_TYPE': ot,
              'SEM_TICK_SIZE': '0.05',
              'SEM_LOT_UNITS': name == 'NIFTY' ? '25' : '15',
            });
          }
        }
      }
    }
    return rows;
  }

  List<OptionContract> getIndexOptions({
    String? underlying,
    String? expiry,
    String? optionType,
  }) {
    return _rows
        .where((r) {
          if (r['SEM_INSTRUMENT_NAME']?.toString() != 'OPTIDX') return false;
          if (underlying != null &&
              !(r['SEM_CUSTOM_SYMBOL']?.toString().toUpperCase() ?? '')
                  .contains(underlying.toUpperCase())) {
            return false;
          }
          if (expiry != null &&
              (r['SEM_EXPIRY_DATE']?.toString() ?? '') != expiry) {
            return false;
          }
          if (optionType != null &&
              (r['SEM_OPTION_TYPE']?.toString() ?? '') != optionType) {
            return false;
          }
          return true;
        })
        .map((r) => OptionContract.fromScripRow(r))
        .toList();
  }

  List<String> getAvailableUnderlyings() {
    final set = <String>{};
    for (final r in _rows) {
      if (r['SEM_INSTRUMENT_NAME']?.toString() == 'OPTIDX') {
        final sym = r['SEM_CUSTOM_SYMBOL']?.toString() ?? '';
        if (sym.isNotEmpty) set.add(sym.split(' ').first);
      }
    }
    return set.toList()..sort();
  }

  List<String> getExpiries(String underlying) {
    final set = <String>{};
    for (final r in _rows) {
      if (r['SEM_INSTRUMENT_NAME']?.toString() == 'OPTIDX' &&
          (r['SEM_CUSTOM_SYMBOL']?.toString().toUpperCase() ?? '')
              .contains(underlying.toUpperCase())) {
        final exp = r['SEM_EXPIRY_DATE']?.toString() ?? '';
        if (exp.isNotEmpty) set.add(exp);
      }
    }
    return set.toList()..sort();
  }
}

class _Underlying {
  final int scrip;
  final String seg;
  const _Underlying(this.scrip, this.seg);
}

extension on String {
  String take(int n) => length <= n ? this : substring(0, n);
}
