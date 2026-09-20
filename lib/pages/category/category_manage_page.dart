import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/category.dart';
import '../../providers/category_provider.dart';
import '../../utils/app_feedback.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/empty_state.dart';

/// 分类管理页（实现文档 §8.6，对应验收标准 6）。
///
/// 按资料类型隔离管理（从各列表页进入，只管理该类型的分类）：
/// - 新建 / 重命名：同类型下不允许重名，重复时提示；
/// - 删除：该分类下的资料自动归入"未分类"，资料本身不删除。
class CategoryManagePage extends StatelessWidget {
  /// 资料类型标识：note / image / audio / doc
  final String assetType;

  /// 类型中文名（页面标题与提示文案用）
  final String typeLabel;

  const CategoryManagePage({
    super.key,
    required this.assetType,
    required this.typeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<CategoryProvider>().of(assetType);

    return Scaffold(
      appBar: AppBar(title: Text('$typeLabel分类管理')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('新建分类'),
        onPressed: () => _showNameDialog(context, title: '新建$typeLabel分类'),
      ),
      body: categories.isEmpty
          ? const EmptyState(icon: Icons.category_outlined, message: '暂无分类')
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: categories.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final c = categories[i];
                return ListTile(
                  leading: const Icon(Icons.folder_outlined),
                  title: Text(c.name),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: '重命名',
                        onPressed: () => _showNameDialog(
                          context,
                          title: '重命名分类',
                          initialName: c.name,
                          onConfirm: (newName) => context
                              .read<CategoryProvider>()
                              .rename(c, newName),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: '删除',
                        onPressed: () => _delete(context, c),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  /// 新建/重命名共用的输入对话框。
  ///
  /// [onConfirm] 为空表示新建场景；返回错误文案时显示在输入框下方。
  Future<void> _showNameDialog(
    BuildContext context, {
    required String title,
    String? initialName,
    Future<String?> Function(String name)? onConfirm,
  }) async {
    final ctrl = TextEditingController(text: initialName ?? '');
    String? error; // 输入校验/重名错误提示

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: InputDecoration(
              labelText: '分类名称',
              border: const OutlineInputBorder(),
              errorText: error,
            ),
            onChanged: (_) {
              // 输入变化时清除错误提示
              if (error != null) setDialogState(() => error = null);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                // 先同步取 Provider，避免 await 之后继续使用 context
                final provider = context.read<CategoryProvider>();
                final name = ctrl.text.trim();
                if (name.isEmpty) {
                  setDialogState(() => error = '名称不能为空');
                  return;
                }
                if (name == initialName) {
                  Navigator.pop(ctx); // 未改动，直接关闭
                  return;
                }
                // 新建或重命名：Provider 返回 null 表示成功，否则为错误文案
                final err = onConfirm == null
                    ? await provider.add(name, assetType)
                    : await onConfirm(name);
                if (err != null) {
                  setDialogState(() => error = err);
                  return;
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
  }

  /// 删除分类：先说明影响（资料归入未分类，不会被删除）
  Future<void> _delete(BuildContext context, CategoryItem category) async {
    final ok = await confirmDelete(
      context,
      title: '删除分类',
      message: '删除分类「${category.name}」后，该分类下的$typeLabel'
          '资料将归入「未分类」，资料本身不会被删除。确定删除吗？',
    );
    if (!ok || !context.mounted) return;
    await context.read<CategoryProvider>().delete(category);
    if (context.mounted) showInfo(context, '分类已删除');
  }
}
