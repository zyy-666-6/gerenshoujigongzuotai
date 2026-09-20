import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../providers/asset_provider.dart';
import '../../providers/category_provider.dart';
import '../../services/audio_recorder_service.dart';
import '../../services/import_service.dart';
import '../../utils/app_feedback.dart';
import '../../utils/formatters.dart';
import '../../widgets/category_picker_sheet.dart';

/// 录音页（实现文档 §8.4）。
///
/// 状态机：idle(未开始) -> recording(录制中) <-> paused(已暂停) -> 停止。
/// 停止后弹出保存对话框：确认名称与分类 -> 落盘并写索引 -> 返回语音列表。
/// 权限被拒时引导用户去系统设置开启麦克风。
class RecordAudioPage extends StatefulWidget {
  /// 从分类页进入时传入，录音保存时直接归属此分类
  final int? initialCategoryId;

  const RecordAudioPage({super.key, this.initialCategoryId});

  @override
  State<RecordAudioPage> createState() => _RecordAudioPageState();
}

/// 录音状态
enum _RecState { idle, recording, paused }

class _RecordAudioPageState extends State<RecordAudioPage> {
  final AudioRecorderService _recorder = AudioRecorderService();

  _RecState _state = _RecState.idle;

  /// 已录制时长（毫秒）；暂停期间不累计
  int _elapsedMs = 0;

  /// 每秒计时器（驱动界面刷新时长显示）
  Timer? _ticker;

  /// 录音临时文件路径
  String? _tempPath;

  @override
  void dispose() {
    // 页面销毁兜底：停掉计时器与录音资源
    _ticker?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  // ---------------- 按钮动作 ----------------

  /// 主按钮：
  /// idle -> 申请权限并开始；recording -> 暂停；paused -> 继续
  Future<void> _onMainButton() async {
    switch (_state) {
      case _RecState.idle:
        final granted = await _ensurePermission();
        if (!granted) return;
        try {
          // 临时文件放系统临时目录，保存确认后再拷入 App 目录
          _tempPath =
              '${Directory.systemTemp.path}/rec_${DateTime.now().millisecondsSinceEpoch}.m4a';
          await _recorder.start(_tempPath!);
          _startTicker();
          setState(() => _state = _RecState.recording);
        } catch (_) {
          // 录音启动失败（被占用/空间不足等）
          _tempPath = null;
          if (mounted) showError(context, '录音失败，请重试');
        }
        break;
      case _RecState.recording:
        await _recorder.pause();
        _ticker?.cancel();
        setState(() => _state = _RecState.paused);
        break;
      case _RecState.paused:
        await _recorder.resume();
        _startTicker();
        setState(() => _state = _RecState.recording);
        break;
    }
  }

  /// 停止录音 -> 弹出保存对话框
  Future<void> _onStop() async {
    _ticker?.cancel();
    final path = await _recorder.stop();
    setState(() => _state = _RecState.idle);

    final file = path ?? _tempPath;
    // 时长太短视为无效录音（避免保存空文件）
    if (file == null || _elapsedMs < 1000) {
      _cleanupTemp(file);
      if (mounted) showError(context, '录音时长太短，未保存');
      return;
    }
    await _showSaveDialog(file);
  }

  // ---------------- 权限处理 ----------------

  /// 确认麦克风权限；被拒时弹窗说明并引导去系统设置
  Future<bool> _ensurePermission() async {
    if (await _recorder.ensurePermission()) return true;
    if (!mounted) return false;
    final goSettings = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('需要麦克风权限'),
        content: const Text('录音功能需要使用麦克风。\n请在系统设置中允许「个人工作台」使用麦克风后重试。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('暂不'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('去设置'),
          ),
        ],
      ),
    );
    if (goSettings == true) {
      await openAppSettings(); // 跳转系统应用设置页
    }
    return false;
  }

  // ---------------- 保存对话框 ----------------

  /// 保存对话框：语音名称 + 分类（复用分类选择弹层）；
  /// 确认后落盘，放弃则删除临时文件并退出。
  Future<void> _showSaveDialog(String tempPath) async {
    final now = DateTime.now();
    final defaultName = '录音 ${DateFormat('yyyy-MM-dd HH:mm').format(now)}';
    final nameCtrl = TextEditingController(text: defaultName);

    // 优先使用从分类页传入的分类，否则取语音类型的首个预置分类
    final categories = context.read<CategoryProvider>().of('audio');
    int? selectedCategoryId = widget.initialCategoryId ??
        (categories.isNotEmpty ? categories.first.id : null);

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // 防止误触丢失录音
      builder: (ctx) {
        return StatefulBuilder(
          // StatefulBuilder：分类变化时重建对话框内容
          builder: (ctx, setDialogState) {
            final categoryName =
                context.read<CategoryProvider>().nameOf(selectedCategoryId);
            return AlertDialog(
              title: const Text('保存语音'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: '语音名称',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 分类选择行：点击弹出分类选择底部弹层
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.folder_outlined),
                    title: const Text('分类'),
                    trailing: Text(categoryName,
                        style: TextStyle(color: Colors.teal.shade700)),
                    onTap: () async {
                      final result = await showCategoryPickerSheet(
                        ctx,
                        assetType: 'audio',
                        currentId: selectedCategoryId,
                      );
                      if (result == null) return; // 取消，保持原选择
                      setDialogState(() {
                        // -1 表示"未分类"
                        selectedCategoryId = result == -1 ? null : result;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('放弃'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );

    // 对话框关闭后立即取值并释放控制器（顺序不能颠倒）
    final inputName = nameCtrl.text.trim();
    nameCtrl.dispose();

    if (confirmed != true) {
      // 放弃：删除临时文件并退出录音页
      _cleanupTemp(tempPath);
      if (mounted) Navigator.pop(context);
      return;
    }

    // 保存：拷入 App 语音目录 + 写索引
    final name = inputName.isEmpty ? defaultName : inputName;
    final saved = await ImportService.saveAudio(
      tempPath: tempPath,
      name: name,
      categoryId: selectedCategoryId,
      durationMs: _elapsedMs,
    );

    if (!mounted) return;
    if (saved == null) {
      showError(context, '保存失败，请重试');
      return;
    }
    await context.read<AssetProvider>().reload();
    if (!mounted) return;
    showInfo(context, '语音已保存');
    Navigator.pop(context); // 返回语音列表
  }

  // ---------------- 工具方法 ----------------

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedMs += 1000);
    });
  }

  /// 清理录音临时文件（失败/放弃场景）
  void _cleanupTemp(String? path) {
    if (path == null) return;
    final f = File(path);
    if (f.existsSync()) {
      try {
        f.deleteSync();
      } catch (_) {}
    }
  }

  // ---------------- 界面 ----------------

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isRunning = _state != _RecState.idle;

    return Scaffold(
      appBar: AppBar(title: const Text('录制语音')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 状态提示
            Text(
              switch (_state) {
                _RecState.idle => '点击下方按钮开始录音',
                _RecState.recording => '正在录音…',
                _RecState.paused => '已暂停',
              },
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            // 已录制时长（大字显示）
            Text(
              formatDuration(_elapsedMs),
              style: const TextStyle(fontSize: 44, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            // 主按钮：开始 / 暂停 / 继续
            GestureDetector(
              onTap: _onMainButton,
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _state == _RecState.recording
                      ? colorScheme.error
                      : colorScheme.primary,
                ),
                child: Icon(
                  _state == _RecState.idle
                      ? Icons.mic
                      : (_state == _RecState.recording
                          ? Icons.pause
                          : Icons.play_arrow),
                  color: Colors.white,
                  size: 44,
                ),
              ),
            ),
            const SizedBox(height: 40),
            // 停止按钮（录音中/暂停时可见）
            if (isRunning)
              TextButton.icon(
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('停止并保存'),
                onPressed: _onStop,
              ),
          ],
        ),
      ),
    );
  }
}
