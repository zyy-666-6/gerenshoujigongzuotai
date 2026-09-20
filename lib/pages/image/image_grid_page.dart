import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../constants.dart';
import '../../models/asset_item.dart';
import '../../providers/asset_provider.dart';
import '../../providers/category_provider.dart';
import '../../services/file_storage.dart';
import '../../services/import_service.dart';
import '../../utils/app_feedback.dart';
import '../../widgets/asset_edit_dialog.dart';
import '../../widgets/category_filter_menu.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/empty_state.dart';
import '../category/category_manage_page.dart';
import 'image_viewer_page.dart';

/// 图片管理页（实现文档 §8.3，对应验收标准 3）。
///
/// - 3 列缩略图网格，按分类筛选；
/// - 点击查看大图，长按删除；
/// - 底部双入口导入：相册多选（image_picker）/ 文件选择（file_picker）。
class ImageGridPage extends StatefulWidget {
  const ImageGridPage({super.key});

  @override
  State<ImageGridPage> createState() => _ImageGridPageState();
}

class _ImageGridPageState extends State<ImageGridPage> {
  /// 当前分类筛选：null = 全部；-1 = 未分类；其他 = 分类 id
  int? _filterCategoryId;
  bool _unclassified = false;

  /// 导入进行中标志（防止重复点击）
  bool _importing = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AssetProvider>();
    final categories = context.watch<CategoryProvider>();

    final images = provider.itemsOf(AssetType.image).where((a) {
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
        title: Text('图片 · $filterLabel'),
        actions: [
          CategoryFilterMenu(
            assetType: 'image',
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
                  assetType: 'image',
                  typeLabel: '图片',
                ),
              ),
            ),
          ),
        ],
      ),
      body: images.isEmpty
          ? const EmptyState(
              icon: Icons.image_outlined,
              message: '暂无图片',
              hint: '点击底部按钮从相册或文件导入',
            )
          : GridView.builder(
              padding: const EdgeInsets.all(4),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemCount: images.length,
              itemBuilder: (ctx, i) => _Thumb(
                asset: images[i],
                onTap: () => _openViewer(images[i]),
                onEdit: () => _edit(images[i]),
                onDelete: () => _delete(images[i]),
              ),
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('相册导入'),
                  onPressed: _importing ? null : _pickFromGallery,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonalIcon(
                  icon: const Icon(Icons.folder_open),
                  label: const Text('文件导入'),
                  onPressed: _importing ? null : _pickFromFiles,
                ),
              ),
            ],
          ),
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

  /// 当前筛选是具体分类时，导入的图片归入该分类；
  /// 未筛选（全部/未分类）时归入首个预置分类，避免散落未分类。
  int? get _importCategoryId {
    if (_filterCategoryId != null && !_unclassified) return _filterCategoryId;
    return context.read<CategoryProvider>().defaultCategoryId('image');
  }

  /// 相册导入：系统相册多选（无需存储权限）
  Future<void> _pickFromGallery() async {
    setState(() => _importing = true);
    try {
      final picked = await ImagePicker().pickMultiImage();
      if (picked.isEmpty) return; // 用户取消
      final result = await ImportService.importPickedImages(
        picked,
        categoryId: _importCategoryId,
      );
      if (!mounted) return;
      await context.read<AssetProvider>().reload();
      if (!mounted) return;
      result.hasFailure
          ? showError(context, result.describe())
          : showInfo(context, result.describe());
    } catch (_) {
      if (mounted) showError(context, '导入失败，请重试');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  /// 文件导入：系统文件选择器（支持多选，扩展名按白名单过滤）
  Future<void> _pickFromFiles() async {
    setState(() => _importing = true);
    try {
      // file_picker 13：pickFiles 直接返回列表，空列表表示用户取消
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: AppConstants.imageExtensions,
      );
      if (files.isEmpty) return; // 用户取消
      final importResult = await ImportService.importPickedFiles(
        files,
        AssetType.image,
        categoryId: _importCategoryId,
      );
      if (!mounted) return;
      await context.read<AssetProvider>().reload();
      if (!mounted) return;
      importResult.hasFailure
          ? showError(context, importResult.describe())
          : showInfo(context, importResult.describe());
    } catch (_) {
      if (mounted) showError(context, '导入失败，请重试');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  /// 查看大图
  Future<void> _openViewer(AssetItem asset) async {
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
  }

  /// 删除图片（二次确认，索引与文件一并删除）
  Future<void> _delete(AssetItem asset) async {
    final ok = await confirmDelete(
      context,
      message: '确定删除图片「${asset.name}」吗？文件将一并删除，无法恢复。',
    );
    if (!ok || !mounted) return;
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
    if (mounted) showInfo(context, '图片信息已更新');
  }
}

/// 单个缩略图格子：解码宽度限制在 300px，控制内存占用
class _Thumb extends StatelessWidget {
  final AssetItem asset;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _Thumb({
    required this.asset,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final file = FileStorage.instance.fileOfAsset(asset);
    return Stack(
      fit: StackFit.expand,
      children: [
        InkWell(
          onTap: onTap,
          onLongPress: onEdit,
          child: Image.file(
            file,
            cacheWidth: 300, // 按需解码，避免大图撑爆内存
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const ColoredBox(
              color: Colors.black12,
              child: Center(child: Icon(Icons.broken_image_outlined)),
            ),
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          child: PopupMenuButton<String>(
            color: Theme.of(context).colorScheme.surface,
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('重命名 / 设置分类')),
              PopupMenuItem(value: 'delete', child: Text('删除')),
            ],
          ),
        ),
      ],
    );
  }
}
