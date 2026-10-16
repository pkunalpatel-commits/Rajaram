import 'package:flutter/foundation.dart';

/// Simple in-app log buffer so users can see errors without adb.
class AppLog {
  static final List<String> _lines = [];
  static const int _max = 300;
  static final ValueNotifier<int> version = ValueNotifier(0);

  static List<String> get lines => List.unmodifiable(_lines);

  static void clear() {
    _lines.clear();
    version.value++;
  }

  static void i(String msg) => _add('I', msg);
  static void e(String msg) => _add('E', msg);
  static void w(String msg) => _add('W', msg);

  static void _add(String level, String msg) {
    final t = DateTime.now();
    final ts =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
    final line = '[$ts] $level  $msg';
    _lines.add(line);
    if (_lines.length > _max) {
      _lines.removeRange(0, _lines.length - _max);
    }
    version.value++;
    debugPrint(line);
  }
}
