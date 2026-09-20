import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../models/asset_item.dart';
import '../services/file_storage.dart';

/// 语音播放状态管理（实现文档 §8.4）。
///
/// 全局单播放器：
/// - 同一条语音：点击在 播放/暂停 间切换；
/// - 不同语音：切换音源并从头播放；
/// - 播放进度/时长通过流同步给列表页的迷你播放条。
class AudioPlaybackProvider extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();

  /// 当前正在播放（或已暂停待续播）的语音 id
  int? _playingId;

  /// 是否正在播放
  bool _isPlaying = false;

  /// 当前播放位置
  Duration _position = Duration.zero;

  /// 当前音源总时长（加载完成前为 null）
  Duration? _duration;

  int? get playingId => _playingId;
  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Duration? get duration => _duration;

  // 订阅 just_audio 的状态流，任何变化都通知列表刷新
  final List<StreamSubscription<void>> _subscriptions = [];

  AudioPlaybackProvider() {
    _subscriptions.add(
      _player.playerStateStream.listen((state) {
        _isPlaying = state.playing;
        // 播放自然结束：回到开头并保持暂停，再次点击可重播
        if (!state.playing &&
            _player.processingState == ProcessingState.completed) {
          _player.seek(Duration.zero);
        }
        notifyListeners();
      }),
    );
    _subscriptions.add(
      _player.positionStream.listen((pos) {
        _position = pos;
        notifyListeners();
      }),
    );
    _subscriptions.add(
      _player.durationStream.listen((dur) {
        _duration = dur;
        notifyListeners();
      }),
    );
  }

  /// 列表播放按钮的统一入口。
  ///
  /// 返回 false 表示文件丢失（调用方据此提示"文件不存在或已被删除"）。
  Future<bool> toggle(AssetItem asset) async {
    try {
      // 同一条：播放/暂停切换
      if (_playingId == asset.id) {
        if (_player.playing) {
          await _player.pause();
        } else {
          await _player.play();
        }
        return true;
      }
      // 不同条：校验文件后切换音源
      final file = FileStorage.instance.fileOfAsset(asset);
      if (!await file.exists()) return false;
      await _player.stop();
      await _player.setFilePath(file.path);
      _playingId = asset.id;
      _position = Duration.zero;
      _duration = null;
      notifyListeners();
      await _player.play();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 停止播放并清空当前条目（删除语音前调用，避免播放已删除文件）
  Future<void> stop() async {
    await _player.stop();
    _playingId = null;
    _isPlaying = false;
    _position = Duration.zero;
    _duration = null;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _player.dispose();
    super.dispose();
  }
}
