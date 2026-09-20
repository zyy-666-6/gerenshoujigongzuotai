import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../constants.dart';
import '../../models/asset_item.dart';
import '../../models/note.dart';
import '../../providers/asset_provider.dart';
import '../../providers/audio_playback_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/note_provider.dart';
import '../../services/file_storage.dart';
import '../../services/import_service.dart';
import '../../services/open_service.dart';
import '../../utils/app_feedback.dart';
import '../../utils/formatters.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/type_icon.dart';
import '../audio/record_audio_page.dart';
import '../image/image_viewer_page.dart';
import '../note/note_edit_page.dart';

/// 分类汇总页：按分类名称汇总四种资料各自独立的分类记录。
///
/// 每个分区（笔记/图片/语音/文档）标题右侧有添加按钮，
/// 点击后直接创建属于当前分类的新资料。
class CategoryContentPage extends StatelessWidget {
  final String categoryName;

  const CategoryContentPage({super.key, required this.categoryName});

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<CategoryProvider>();
    final notes = context.watch<NoteProvider>().notes;
    final assets = context.watch<AssetProvider>();

    final noteCategoryId = _categoryId(categories, 'note');
    final imageCategoryId = _categoryId(categories, 'image');
    final audioCategoryId = _categoryId(categories, 'audio');
    final docCategoryId = _categoryId(categories, 'doc');

    final matchedNotes = noteCategoryId == null
        ? <Note>[]
        : notes.where((item) => item.categoryId == noteCategoryId).toList();
    final images = _assetsIn(assets, AssetType.image, imageCategoryId);
    final audios = _assetsIn(assets, AssetType.audio, audioCategoryId);
    final docs = _assetsIn(assets, AssetType.doc, docCategoryId);
    final total =
        matchedNotes.length + images.length + audios.length + docs.length;

    return Scaffold(
      appBar: AppBar(title: Text(categoryName)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          ..._section(
            context,
            '笔记',
            matchedNotes.map((note) => _noteTile(context, note)).toList(),
            onAdd: noteCategoryId == null
                ? null
                : () => _addNote(context, noteCategoryId),
          ),
          ..._section(
            context,
            '图片',
            images.map((asset) => _assetTile(context, asset)).toList(),
            onAdd: imageCategoryId == null
                ? null
                : () => _addImage(context, imageCategoryId),
          ),
          ..._section(
            context,
            '语音',
            audios.map((asset) => _assetTile(context, asset)).toList(),
            onAdd: audioCategoryId == null
                ? null
                : () => _addAudio(context, audioCategoryId),
          ),
          ..._section(
            context,
            '文档',
            docs.map((asset) => _assetTile(context, asset)).toList(),
            onAdd: docCategoryId == null
                ? null
                : () => _addDoc(context, docCategoryId),
          ),
          if (total == 0)
            const EmptyState(
              icon: Icons.folder_open_outlined,
              message: '该分类暂无资料',
              hint: '点击各分区右侧的加号按钮添加资料',
            ),
        ],
      ),
    );
  }

  int? _categoryId(CategoryProvider categories, String type) {
    for (final category in categories.of(type)) {
      if (category.name == categoryName) return category.id;
    }
    return null;
  }

  List<AssetItem> _assetsIn(
    AssetProvider provider,
    AssetType type,
    int? categoryId,
  ) {
    if (categoryId == null) return const [];
    return provider
        .itemsOf(type)
        .where((item) => item.categoryId == categoryId)
        .toList();
  }

  /// 分区标题 + 添加按钮 + 列表项
  List<Widget> _section(
    BuildContext context,
    String label,
    List<Widget> tiles, {
    VoidCallback? onAdd,
  }) {
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 8, 4),
        child: Row(
          children: [
            Text(
              '$label（${tiles.length}）',
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const Spacer(),
            if (onAdd != null)
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 22),
                color: Colors.teal,
                tooltip: '添加$label',
                onPressed: onAdd,
              ),
          ],
        ),
      ),
      ...tiles,
    ];
  }

  // ---------------- 各类型添加操作 ----------------

  Future<void> _addNote(BuildContext context, int categoryId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NoteEditPage(initialCategoryId: categoryId),
      ),
    );
  }

  Future<void> _addImage(BuildContext context, int categoryId) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('相册导入'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: const Text('文件导入'),
              onTap: () => Navigator.pop(ctx, 'file'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;

    if (choice == 'gallery') {
      final picked = await ImagePicker().pickMultiImage();
      if (picked.isEmpty) return;
      final result = await ImportService.importPickedImages(
        picked,
        categoryId: categoryId,
      );
      if (!context.mounted) return;
      await context.read<AssetProvider>().reload();
      if (!context.mounted) return;
      result.hasFailure
          ? showError(context, result.describe())
          : showInfo(context, result.describe());
    } else {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: AppConstants.imageExtensions,
      );
      if (files.isEmpty) return;
      final result = await ImportService.importPickedFiles(
        files,
        AssetType.image,
        categoryId: categoryId,
      );
      if (!context.mounted) return;
      await context.read<AssetProvider>().reload();
      if (!context.mounted) return;
      result.hasFailure
          ? showError(context, result.describe())
          : showInfo(context, result.describe());
    }
  }

  Future<void> _addAudio(BuildContext context, int categoryId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecordAudioPage(initialCategoryId: categoryId),
      ),
    );
  }

  Future<void> _addDoc(BuildContext context, int categoryId) async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: AppConstants.docExtensions,
    );
    if (file == null) return;
    final result = await ImportService.importPickedFiles(
      [file],
      AssetType.doc,
      categoryId: categoryId,
    );
    if (!context.mounted) return;
    await context.read<AssetProvider>().reload();
    if (!context.mounted) return;
    result.hasFailure
        ? showError(context, result.describe())
        : showInfo(context, result.describe());
  }

  // ---------------- 列表项构建 ----------------

  Widget _noteTile(BuildContext context, Note note) {
    return ListTile(
      leading: const Icon(Icons.edit_note, color: Colors.teal),
      title: Text(
        note.title.isEmpty ? '未命名笔记' : note.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        note.content.isEmpty
            ? formatDateTime(note.updatedAt)
            : note.content.replaceAll('\n', ' '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
        tooltip: '删除',
        onPressed: () => _deleteNote(context, note),
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => NoteEditPage(noteId: note.id)),
      ),
    );
  }

  Widget _assetTile(BuildContext context, AssetItem asset) {
    return ListTile(
      leading: Icon(iconForAsset(asset), color: Colors.teal),
      title: Text(
        asset.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        formatDateTime(asset.createdAt),
        style: const TextStyle(fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (asset.type == AssetType.audio)
            IconButton(
              icon: const Icon(Icons.play_circle_outline),
              tooltip: '播放 / 暂停',
              onPressed: () => _toggleAudio(context, asset),
            )
          else
            const Icon(Icons.chevron_right, size: 20),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            tooltip: '删除',
            onPressed: () => _deleteAsset(context, asset),
          ),
        ],
      ),
      onTap: () => _openAsset(context, asset),
    );
  }

  Future<void> _toggleAudio(BuildContext context, AssetItem asset) async {
    final ok = await context.read<AudioPlaybackProvider>().toggle(asset);
    if (!ok && context.mounted) showError(context, '文件不存在或已被删除');
  }

  /// 删除笔记（二次确认，仅删数据库记录）
  Future<void> _deleteNote(BuildContext context, Note note) async {
    final ok = await confirmDelete(
      context,
      message: '确定删除笔记「${note.title.isEmpty ? '未命名笔记' : note.title}」吗？删除后无法恢复。',
    );
    if (!ok || !context.mounted) return;
    await context.read<NoteProvider>().delete(note.id!);
  }

  /// 删除文件资料（二次确认；语音先停止播放，索引与落盘文件一并删除）
  Future<void> _deleteAsset(BuildContext context, AssetItem asset) async {
    final typeLabel = asset.type.label;
    final ok = await confirmDelete(
      context,
      message: '确定删除$typeLabel「${asset.name}」吗？文件将一并删除，无法恢复。',
    );
    if (!ok || !context.mounted) return;
    // 删除语音前若正在播放这条，先停止
    if (asset.type == AssetType.audio) {
      final playback = context.read<AudioPlaybackProvider>();
      if (playback.playingId == asset.id) {
        await playback.stop();
      }
    }
    if (!context.mounted) return;
    await context.read<AssetProvider>().deleteAsset(asset);
  }

  Future<void> _openAsset(BuildContext context, AssetItem asset) async {
    if (asset.type == AssetType.audio) {
      await _toggleAudio(context, asset);
      return;
    }
    if (asset.type == AssetType.doc) {
      await OpenService.openAsset(context, asset);
      return;
    }

    final file = FileStorage.instance.fileOfAsset(asset);
    if (!await file.exists()) {
      if (context.mounted) showError(context, '文件不存在或已被删除');
      return;
    }
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ImageViewerPage(asset: asset, filePath: file.path),
      ),
    );
  }
}
