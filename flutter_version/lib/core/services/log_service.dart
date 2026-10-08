import 'package:flutter/foundation.dart';
import '../models/log_entry.dart';

class LogService extends ChangeNotifier {
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

  final List<LogEntry> _logs = [];
  final int maxLogs = 500;

  List<LogEntry> get logs => List.unmodifiable(_logs);

  void log(LogLevel level, String tag, String message) {
    final entry = LogEntry(level: level, tag: tag, message: message);
    _logs.add(entry);
    if (_logs.length > maxLogs) {
      _logs.removeAt(0);
    }
    notifyListeners();
    if (kDebugMode) {
      debugPrint(entry.toString());
    }
  }

  void info(String tag, String message) => log(LogLevel.info, tag, message);
  void warn(String tag, String message) => log(LogLevel.warning, tag, message);
  void error(String tag, String message) => log(LogLevel.error, tag, message);
  void success(String tag, String message) => log(LogLevel.success, tag, message);

  void clear() {
    _logs.clear();
    notifyListeners();
  }

  String exportToString() {
    return _logs.map((e) => e.toString()).join('\n');
  }
}
