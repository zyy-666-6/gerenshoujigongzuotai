import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/asset_item.dart';
import '../../models/note.dart';
import '../../providers/audio_playback_provider.dart';
import '../../providers/category_provider.dart';
import '../../services/dao/asset_dao.dart';
import '../../services/dao/note_dao.dart';
import '../../services/db_service.dart';
import '../../services/file_storage.dart';
import '../../services/open_service.dart';
import '../../utils/app_feedback.dart';
import '../../utils/formatters.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/type_icon.dart';
import '../audio/audio_list_page.dart';
import '../image/image_viewer_page.dart';
import '../note/note_edit_page.dart';

/// 搜索结果集合：笔记 + 文件资料（图片/语音/文档）
class _SearchResults {
  final List<Note> notes;
  final List<AssetItem> assets;

  const _SearchResults({required this.notes, required this.assets});

  bool get isEmpty => notes.isEmpty && assets.isEmpty;
}

/// 基础搜索页（实现文档 §8.7，对应验收标准 7）。
///
/// - 可检索字段：笔记标题、笔记正文、文件显示名（与数据库 LIKE 查询一致）；
/// - 输入防抖 300ms 后触发查询；
/// - 结果按资料类型分组展示，点击直达对应查看/播放页；
/// - 无结果展示空状态（不做全文索引与内容识别，属需求边界）。
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _keywordCtrl = TextEditingController();

  /// 防抖计时器：停止输入 300ms 后才发起查询
  Timer? _debounce;

  /// 搜索结果；null 表示尚未搜索（关键词为空）
  _SearchResults? _results;

  @override
  void dispose() {
    _debounce?.cancel();
    _keywordCtrl.dispose();
    super.dispose();
  }

  /// 执行搜索：笔记（标题/正文）+ 文件资料（显示名）
  Future<void> _search(String keyword) async {
    final kw = keyword.trim();
    if (kw.isEmpty) {
      setState(() => _results = null);
      return;
    }
    final db = await DbService.instance.database;
    final notes = await NoteDao(db).search(kw);
    final assets = await AssetDao(db).search(kw);
    if (!mounted) return;
    setState(() {
      _results = _SearchResults(notes: notes, assets: assets);
    });
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    final categories = context.watch<CategoryProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('搜索'),
      ),
      body: Column(
        children: [
          // 搜索输入框
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _keywordCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '输入关键词：标题 / 文件名 / 笔记正文',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _keywordCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _keywordCtrl.clear();
                          setState(() => _results = null);
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                setState(() {}); // 刷新清空按钮
                _debounce?.cancel();
                _debounce = Timer(
                  const Duration(milliseconds: 300),
                  () => _search(value),
                );
              },
            ),
          ),
          // 结果区
          Expanded(
            child: results == null
                ? const EmptyState(
                    icon: Icons.search,
                    message: '输入关键词开始搜索',
                    hint: '支持笔记标题、笔记正文、文件名',
                  )
                : results.isEmpty
                    ? EmptyState(
                        icon: Icons.search_off,
                        message: '未找到与「${_keywordCtrl.text.trim()}」相关的资料',
                      )
                    : _buildResultList(results, categories),
          ),
        ],
      ),
    );
  }

  /// 分组结果列表：笔记 -> 图片 -> 语音 -> 文档
  Widget _buildResultList(
      _SearchResults results, CategoryProvider categories) {
    final images =
        results.assets.where((a) => a.type == AssetType.image).toList();
    final audios =
        results.assets.where((a) => a.type == AssetType.audio).toList();
    final docs =
        results.assets.where((a) => a.type == AssetType.doc).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: [
        ..._section('笔记', results.notes.length,
            results.notes.map((n) => _noteTile(n, categories)).toList()),
        ..._section('图片', images.length,
            images.map((a) => _assetTile(a, categories)).toList()),
        ..._section('语音', audios.length,
            audios.map((a) => _assetTile(a, categories)).toList()),
        ..._section('文档', docs.length,
            docs.map((a) => _assetTile(a, categories)).toList()),
      ],
    );
  }

  /// 分组标题（结果为 0 的分组不显示）
  List<Widget> _section(String label, int count, List<Widget> tiles) {
    if (tiles.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Text('$label（$count）',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ),
      ...tiles,
    ];
  }

  /// 笔记结果条目：点击进入编辑页查看
  Widget _noteTile(Note note, CategoryProvider categories) {
    return ListTile(
      leading: const Icon(Icons.edit_note, color: Colors.teal),
      title: Text(note.title,
          maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        note.content.isEmpty
            ? '${categories.nameOf(note.categoryId)} · ${formatDateTime(note.updatedAt)}'
            : note.content.replaceAll('\n', ' '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12),
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => NoteEditPage(noteId: note.id)),
      ),
    );
  }

  /// 文件资料结果条目：图片->大图，语音->播放/列表，文档->预览或外部打开
  Widget _assetTile(AssetItem asset, CategoryProvider categories) {
    final subtitle =
        '${categories.nameOf(asset.categoryId)} · ${formatDateTime(asset.createdAt)}';
    return ListTile(
      leading: Icon(iconForAsset(asset), color: Colors.teal),
      title: Text(asset.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle,
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12)),
      // 语音：尾部提供快捷播放按钮
      trailing: asset.type == AssetType.audio
          ? IconButton(
              icon: const Icon(Icons.play_circle, color: Colors.teal),
              onPressed: () => _togglePlay(asset),
            )
          : null,
      onTap: () => _openAsset(asset),
    );
  }

  /// 语音快捷播放
  Future<void> _togglePlay(AssetItem asset) async {
    final ok =
        await context.read<AudioPlaybackProvider>().toggle(asset);
    if (!ok && mounted) {
      showError(context, '文件不存在或已被删除');
    }
  }

  /// 按类型打开资料
  Future<void> _openAsset(AssetItem asset) async {
    switch (asset.type) {
      case AssetType.image:
        final file = FileStorage.instance.fileOfAsset(asset);
        if (!await file.exists()) {
          if (mounted) showError(context, '文件不存在或已被删除');
          return;
        }
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ImageViewerPage(asset: asset, filePath: file.path),
          ),
        );
        break;
      case AssetType.audio:
        // 语音跳转列表页播放（保持与首页一致的交互）
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AudioListPage()),
        );
        break;
      case AssetType.doc:
        if (!mounted) return;
        await OpenService.openAsset(context, asset);
        break;
    }
  }
}
