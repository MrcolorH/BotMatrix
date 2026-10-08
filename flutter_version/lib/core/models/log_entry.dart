import 'package:intl/intl.dart';

enum LogLevel { info, warning, error, success }

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String tag;
  final String message;

  LogEntry({
    required this.level,
    required this.tag,
    required this.message,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  String get formattedTime => DateFormat('HH:mm:ss').format(timestamp);

  String get prefix {
    switch (level) {
      case LogLevel.info:
        return 'INFO';
      case LogLevel.warning:
        return 'WARN';
      case LogLevel.error:
        return 'ERR ';
      case LogLevel.success:
        return 'OK  ';
    }
  }

  @override
  String toString() => '[$formattedTime] [$prefix] [$tag] $message';
}
