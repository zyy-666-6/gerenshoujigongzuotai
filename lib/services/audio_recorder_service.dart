import 'package:record/record.dart';

/// 录音服务：对 record 插件（AudioRecorder）的薄封装（实现文档 §8.4）。
///
/// 生命周期：由录音页面创建并持有，页面销毁时调用 [dispose]。
/// - 输出 m4a（AAC）格式：压缩率高、Android 兼容性好；
/// - [ensurePermission] 在未授权时会主动弹出系统授权框；
/// - 录音先写临时文件，用户确认保存后再由 ImportService 落盘。
class AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();

  /// 确认麦克风权限；未授权时触发系统授权弹窗。
  /// 返回 false 表示用户拒绝授权，由页面引导去系统设置。
  Future<bool> ensurePermission() => _recorder.hasPermission();

  /// 开始录音，写入 [tempPath] 指定的临时文件
  Future<void> start(String tempPath) {
    return _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc, // AAC-LC 编码
        bitRate: 128000, // 128 kbps，兼顾音质与体积
        sampleRate: 44100, // 44.1 kHz 采样率
      ),
      path: tempPath,
    );
  }

  /// 暂停录音（可 resume 继续）
  Future<void> pause() => _recorder.pause();

  /// 继续录音
  Future<void> resume() => _recorder.resume();

  /// 停止录音，返回录音文件路径（未开始时返回 null）
  Future<String?> stop() => _recorder.stop();

  /// 释放底层资源（页面销毁时调用）
  void dispose() => _recorder.dispose();
}
