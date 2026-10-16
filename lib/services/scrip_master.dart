import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:csv/csv.dart';
import '../models/option_contract.dart';

class ScripMasterService extends ChangeNotifier {
  static const String detailedUrl =
      'https://images.dhan.co/api-data/api-scrip-master-detailed.csv';

  List<Map<String, dynamic>> _rows = [];
  bool isLoading = false;
  String? error;

  List<Map<String, dynamic>> get rows => _rows;

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final response = await http.get(Uri.parse(detailedUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to download scrip master: ${response.statusCode}');
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

      debugPrint('Scrip master loaded: ${_rows.length} instruments');
    } catch (e) {
      error = e.toString();
      debugPrint('ScripMaster error: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Filter for Index Options (NIFTY, BANKNIFTY, etc.)
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
        if (sym.isNotEmpty) {
          set.add(sym.split(' ').first);
        }
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
