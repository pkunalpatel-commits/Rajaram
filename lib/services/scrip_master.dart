import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:csv/csv.dart';
import '../models/option_contract.dart';

class ScripMasterService extends ChangeNotifier {
  static const String detailedUrl =
      'https://images.dhan.co/api-data/api-scrip-master-detailed.csv';
  static const String compactUrl =
      'https://images.dhan.co/api-data/api-scrip-master.csv';

  List<Map<String, dynamic>> _rows = [];
  bool isLoading = false;
  String? error;
  bool usedOfflineFallback = false;

  List<Map<String, dynamic>> get rows => _rows;

  Future<void> load() async {
    isLoading = true;
    error = null;
    usedOfflineFallback = false;
    notifyListeners();

    // Try detailed first, then compact
    final urls = [detailedUrl, compactUrl];
    Exception? lastError;

    for (final url in urls) {
      try {
        debugPrint('Trying scrip master: $url');
        final response = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 45));

        if (response.statusCode != 200) {
          throw Exception('HTTP ${response.statusCode}');
        }

        final csvTable = const CsvToListConverter().convert(response.body);
        if (csvTable.isEmpty) throw Exception('Empty CSV');

        final headers = csvTable.first.map((e) => e.toString()).toList();
        _rows = csvTable.skip(1).map((row) {
          final map = <String, dynamic>{};
          for (var i = 0; i < headers.length && i < row.length; i++) {
            map[headers[i]] = row[i];
          }
          return map;
        }).toList();

        debugPrint('Scrip master loaded: ${_rows.length} instruments from $url');
        isLoading = false;
        notifyListeners();
        return;
      } catch (e) {
        lastError = Exception(e.toString());
        debugPrint('Failed $url: $e');
      }
    }

    // Offline demo fallback so the UI is usable
    debugPrint('Using offline demo instruments');
    _rows = _demoRows();
    usedOfflineFallback = true;
    error =
        'Could not reach images.dhan.co (DNS/network).\n'
        'Showing DEMO contracts so you can explore the app.\n'
        'Fix: Settings → Network → Private DNS → Off, then Retry.\n'
        'Detail: ${lastError?.toString() ?? "unknown"}';
    isLoading = false;
    notifyListeners();
  }

  /// Minimal demo OPTIDX rows so the app works without network
  List<Map<String, dynamic>> _demoRows() {
    final expiries = ['2026-10-28', '2026-11-25'];
    final underlyings = [
      ('NIFTY', 24000.0, 50.0),
      ('BANKNIFTY', 52000.0, 100.0),
    ];
    final rows = <Map<String, dynamic>>[];
    var id = 50000;

    for (final u in underlyings) {
      final name = u.$1;
      final atm = u.$2;
      final step = u.$3;
      for (final exp in expiries) {
        for (var k = -5; k <= 5; k++) {
          final strike = atm + k * step;
          for (final ot in ['CE', 'PE']) {
            rows.add({
              'SEM_SMST_SECURITY_ID': '${id++}',
              'SEM_TRADING_SYMBOL': '$name ${exp.substring(5)} $strike $ot',
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
          final instr = r['SEM_INSTRUMENT_NAME']?.toString() ?? '';
          if (instr != 'OPTIDX') return false;
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
