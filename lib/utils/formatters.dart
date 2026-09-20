// 通用格式化工具：日期时间、语音时长、文件大小
import 'package:intl/intl.dart';

/// 毫秒时间戳 -> "yyyy-MM-dd HH:mm"
String formatDateTime(int millisecondsSinceEpoch) {
  return DateFormat('yyyy-MM-dd HH:mm')
      .format(DateTime.fromMillisecondsSinceEpoch(millisecondsSinceEpoch));
}

/// 毫秒时长 -> "mm:ss"（语音列表/录音页显示用）
String formatDuration(int milliseconds) {
  final totalSeconds = milliseconds ~/ 1000;
  final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
  final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

/// 字节数 -> 人类可读大小（B / KB / MB / GB）
String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
  return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
}
