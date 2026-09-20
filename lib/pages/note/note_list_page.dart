import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/note.dart';
import '../../providers/category_provider.dart';
import '../../providers/note_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/category_filter_menu.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/empty_state.dart';
import '../category/category_manage_page.dart';
import 'note_edit_page.dart';

/// 笔记列表页（实现文档 §8.2，对应验收标准 2/6）。
///
/// - 按更新时间倒序展示，支持按分类筛选（全部/未分类/各分类）；
/// - 点击进入编辑页，尾部按钮删除（二次确认）；
/// - FAB 新建笔记。
class NoteListPage extends StatefulWidget {
  const NoteListPage({super.key});

  @override
  State<NoteListPage> createState() => _NoteListPageState();
}

class _NoteListPageState extends State<NoteListPage> {
  /// 当前分类筛选：null = 全部；-1 = 未分类；其他 = 分类 id
  int? _filterCategoryId;
  bool _unclassified = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NoteProvider>();
    final categories = context.watch<CategoryProvider>();

    // 本地按分类过滤（个人数据量级，无需数据库层过滤）
    final notes = provider.notes.where((n) {
      if (_unclassified) return n.categoryId == null;
      if (_filterCategoryId != null) return n.categoryId == _filterCategoryId;
      return true;
    }).toList();

    // 标题栏显示当前筛选项
    final filterLabel = _unclassified
        ? '未分类'
        : _filterCategoryId == null
            ? '全部'
            : categories.nameOf(_filterCategoryId);

    return Scaffold(
      appBar: AppBar(
        title: Text('笔记 · $filterLabel'),
        actions: [
          CategoryFilterMenu(
            assetType: 'note',
            selected: _unclassified
                ? 'none'
                : _filterCategoryId?.toString() ?? 'all',
            onSelected: _onFilterSelected,
          ),
          // 分类管理入口
          IconButton(
            icon: const Icon(Icons.category_outlined),
            tooltip: '管理分类',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const CategoryManagePage(
                  assetType: 'note',
                  typeLabel: '笔记',
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('新建笔记'),
        onPressed: () => _pushEdit(null),
      ),
      body: notes.isEmpty
          ? const EmptyState(
              icon: Icons.edit_note,
              message: '暂无笔记',
              hint: '点击右下角「新建笔记」开始记录',
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: notes.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final note = notes[i];
                return ListTile(
                  title: Text(
                    note.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${categories.nameOf(note.categoryId)} · ${formatDateTime(note.updatedAt)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: '删除',
                    onPressed: () => _delete(note),
                  ),
                  onTap: () => _pushEdit(note.id),
                );
              },
            ),
    );
  }

  /// 处理筛选菜单选择：字符串编码还原为筛选状态
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

  Future<void> _pushEdit(int? noteId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => NoteEditPage(noteId: noteId)),
    );
  }

  Future<void> _delete(Note note) async {
    final ok = await confirmDelete(
      context,
      message: '确定删除笔记「${note.title}」吗？删除后无法恢复。',
    );
    if (!ok || !mounted) return;
    await context.read<NoteProvider>().delete(note.id!);
  }
}
