import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/asset_item.dart';
import '../../providers/asset_provider.dart';
import '../../providers/audio_playback_provider.dart';
import '../../providers/category_provider.dart';
import '../../utils/app_feedback.dart';
import '../../utils/formatters.dart';
import '../../widgets/asset_edit_dialog.dart';
import '../../widgets/category_filter_menu.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/empty_state.dart';
import '../category/category_manage_page.dart';
import 'record_audio_page.dart';

/// 语音列表页（实现文档 §8.4，对应验收标准 4）。
///
/// - 每条语音内置迷你播放条：播放/暂停按钮 + 进度；
/// - 全局单播放器：切换条目即停止上一条；
/// - FAB 进入录音页。
class AudioListPage extends StatefulWidget {
  const AudioListPage({super.key});

  @override
  State<AudioListPage> createState() => _AudioListPageState();
}

class _AudioListPageState extends State<AudioListPage> {
  /// 当前分类筛选：null = 全部；-1 = 未分类；其他 = 分类 id
  int? _filterCategoryId;
  bool _unclassified = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AssetProvider>();
    final categories = context.watch<CategoryProvider>();
    // 播放状态变化（含每秒进度）会触发整表重建，列表规模小，可接受
    final playback = context.watch<AudioPlaybackProvider>();

    final audios = provider.itemsOf(AssetType.audio).where((a) {
      if (_unclassified) return a.categoryId == null;
      if (_filterCategoryId != null) return a.categoryId == _filterCategoryId;
      return true;
    }).toList();

    final filterLabel = _unclassified
        ? '未分类'
        : _filterCategoryId == null
            ? '全部'
            : categories.nameOf(_filterCategoryId);

    return Scaffold(
      appBar: AppBar(
        title: Text('语音 · $filterLabel'),
        actions: [
          CategoryFilterMenu(
            assetType: 'audio',
            selected:
                _unclassified ? 'none' : _filterCategoryId?.toString() ?? 'all',
            onSelected: _onFilterSelected,
          ),
          IconButton(
            icon: const Icon(Icons.category_outlined),
            tooltip: '管理分类',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const CategoryManagePage(
                  assetType: 'audio',
                  typeLabel: '语音',
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.mic),
        label: const Text('录音'),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const RecordAudioPage()),
        ),
      ),
      body: audios.isEmpty
          ? const EmptyState(
              icon: Icons.mic_none,
              message: '暂无语音',
              hint: '点击右下角「录音」开始录制',
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: audios.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) => _AudioTile(
                asset: audios[i],
                categoryName: categories.nameOf(audios[i].categoryId),
                isActive: playback.playingId == audios[i].id,
                isPlaying: playback.isPlaying,
                position: playback.position,
                duration: playback.duration,
                onToggle: () => _toggle(audios[i]),
                onEdit: () => _edit(audios[i]),
                onDelete: () => _delete(audios[i]),
              ),
            ),
    );
  }

  void _onFilterSelected(String value) {
    setState(() {
      if (value == 'all') {
        _filterCategoryId = null;
        _unclassified = false;
      } else if (value == 'none') {
        _filterCategoryId = null;
        _unclassified = true;
      } else {
        _filterCategoryId = int.tryParse(value);
        _unclassified = false;
      }
    });
  }

  /// 播放/暂停切换；文件丢失时给出提示（验收标准 4 的异常分支）
  Future<void> _toggle(AssetItem asset) async {
    final ok = await context.read<AudioPlaybackProvider>().toggle(asset);
    if (!ok && mounted) {
      showError(context, '文件不存在或已被删除');
    }
  }

  /// 删除语音：先停止播放（若正在播这条），再删索引与文件
  Future<void> _delete(AssetItem asset) async {
    final ok = await confirmDelete(
      context,
      message: '确定删除语音「${asset.name}」吗？录音文件将一并删除，无法恢复。',
    );
    if (!ok || !mounted) return;
    final playback = context.read<AudioPlaybackProvider>();
    if (playback.playingId == asset.id) {
      await playback.stop();
    }
    if (!mounted) return;
    await context.read<AssetProvider>().deleteAsset(asset);
  }

  Future<void> _edit(AssetItem asset) async {
    final result = await showAssetEditDialog(
      context,
      asset: asset,
      allowRename: true,
    );
    if (result == null || !mounted) return;
    await context.read<AssetProvider>().updateAsset(
          asset,
          name: result.name,
          categoryId: result.categoryId,
        );
    if (mounted) showInfo(context, '语音信息已更新');
  }
}

/// 单条语音条目：信息行 + 迷你播放条（仅当前条显示）
class _AudioTile extends StatelessWidget {
  final AssetItem asset;
  final String categoryName;
  final bool isActive; // 是否为当前播放条目
  final bool isPlaying; // 当前是否处于播放中
  final Duration position;
  final Duration? duration;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AudioTile({
    required this.asset,
    required this.categoryName,
    required this.isActive,
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // 时长显示：语音自带记录时长；播放中的条目用实际加载时长兜底
    final displayMs = duration?.inMilliseconds ?? asset.durationMs ?? 0;
    // 进度比例（播放中条目）
    final progress = isActive && displayMs > 0
        ? (position.inMilliseconds / displayMs).clamp(0.0, 1.0)
        : 0.0;

    return Column(
      children: [
        ListTile(
          leading: IconButton(
            icon: Icon(
                isActive && isPlaying ? Icons.pause_circle : Icons.play_circle),
            iconSize: 34,
            color: Colors.teal,
            onPressed: onToggle,
            tooltip: isActive && isPlaying ? '暂停' : '播放',
          ),
          title: Text(asset.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            '${formatDuration(asset.durationMs ?? 0)} · $categoryName · ${formatDateTime(asset.createdAt)}',
            style: const TextStyle(fontSize: 12),
          ),
          trailing: PopupMenuButton<String>(
            tooltip: '更多操作',
            onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('重命名 / 设置分类')),
              PopupMenuItem(value: 'delete', child: Text('删除')),
            ],
          ),
          onTap: onToggle, // 点击整行也可切换播放
        ),
        // 迷你进度条（仅当前播放条目显示）
        if (isActive)
          Padding(
            padding: const EdgeInsets.fromLTRB(72, 0, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 3,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${formatDuration(position.inMilliseconds)} / ${formatDuration(displayMs)}',
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
