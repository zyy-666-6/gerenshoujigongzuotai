import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants.dart';
import '../../models/asset_item.dart';
import '../../providers/asset_provider.dart';
import '../../providers/category_provider.dart';
import '../../services/import_service.dart';
import '../../services/open_service.dart';
import '../../utils/app_feedback.dart';
import '../../utils/formatters.dart';
import '../../widgets/asset_edit_dialog.dart';
import '../../widgets/category_filter_menu.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/type_icon.dart';
import '../category/category_manage_page.dart';

/// 文档管理页（实现文档 §8.5，对应验收标准 5）。
///
/// - 按分类展示文档：名称、类型、大小、分类、时间；
/// - 点击打开：PDF 走 App 内预览，Office/txt 调用系统兼容应用；
/// - 导入：系统文件选择器，扩展名按白名单过滤（单选）。
class DocListPage extends StatefulWidget {
  const DocListPage({super.key});

  @override
  State<DocListPage> createState() => _DocListPageState();
}

class _DocListPageState extends State<DocListPage> {
  /// 当前分类筛选：null = 全部；-1 = 未分类；其他 = 分类 id
  int? _filterCategoryId;
  bool _unclassified = false;

  /// 导入进行中标志（防止重复点击）
  bool _importing = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AssetProvider>();
    final categories = context.watch<CategoryProvider>();

    final docs = provider.itemsOf(AssetType.doc).where((a) {
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
        title: Text('文档 · $filterLabel'),
        actions: [
          CategoryFilterMenu(
            assetType: 'doc',
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
                  assetType: 'doc',
                  typeLabel: '文档',
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.upload_file),
        label: const Text('导入文档'),
        onPressed: _importing ? null : _pickAndImport,
      ),
      body: docs.isEmpty
          ? const EmptyState(
              icon: Icons.folder_outlined,
              message: '暂无文档',
              hint: '点击右下角「导入文档」从手机文件选择',
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final doc = docs[i];
                return ListTile(
                  leading:
                      Icon(iconForAsset(doc), color: Colors.purple.shade400),
                  title: Text(doc.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    '${doc.extension.toUpperCase()} · ${formatFileSize(doc.size)} · ${categories.nameOf(doc.categoryId)} · ${formatDateTime(doc.createdAt)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: PopupMenuButton<String>(
                    tooltip: '更多操作',
                    onSelected: (value) =>
                        value == 'edit' ? _editCategory(doc) : _delete(doc),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('设置分类')),
                      PopupMenuItem(value: 'delete', child: Text('删除')),
                    ],
                  ),
                  onTap: () => OpenService.openAsset(context, doc),
                );
              },
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

  /// 当前筛选是具体分类时，导入的文档归入该分类；
  /// 未筛选（全部/未分类）时归入首个预置分类，避免散落未分类。
  int? get _importCategoryId {
    if (_filterCategoryId != null && !_unclassified) return _filterCategoryId;
    return context.read<CategoryProvider>().defaultCategoryId('doc');
  }

  /// 导入文档：白名单过滤 + 单选（实现文档 §15-4，批量待确认默认单选）
  Future<void> _pickAndImport() async {
    setState(() => _importing = true);
    try {
      // file_picker 13：单选走 pickFile，返回 null 表示用户取消
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: AppConstants.docExtensions,
      );
      if (file == null) return; // 用户取消
      final importResult = await ImportService.importPickedFiles(
        [file],
        AssetType.doc,
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

  Future<void> _delete(AssetItem doc) async {
    final ok = await confirmDelete(
      context,
      message: '确定删除文档「${doc.name}」吗？文件将一并删除，无法恢复。',
    );
    if (!ok || !mounted) return;
    await context.read<AssetProvider>().deleteAsset(doc);
  }

  Future<void> _editCategory(AssetItem doc) async {
    final result = await showAssetEditDialog(
      context,
      asset: doc,
      allowRename: false,
    );
    if (result == null || !mounted) return;
    await context.read<AssetProvider>().updateAsset(
          doc,
          name: result.name,
          categoryId: result.categoryId,
        );
    if (mounted) showInfo(context, '文档分类已更新');
  }
}
