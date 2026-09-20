import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/note.dart';
import '../../providers/category_provider.dart';
import '../../providers/note_provider.dart';
import '../../utils/app_feedback.dart';
import '../../widgets/category_picker_sheet.dart';

/// 笔记编辑页（新建与编辑复用，实现文档 §8.2）。
///
/// [noteId] 为 null 时表示新建，否则加载对应笔记回显。
/// 保存规则（实现文档 §15-5）：正文可为空；标题为空时以"未命名 + 时间"兜底。
class NoteEditPage extends StatefulWidget {
  final int? noteId;

  /// 从分类页进入时传入，新建笔记直接归属此分类
  final int? initialCategoryId;

  const NoteEditPage({super.key, this.noteId, this.initialCategoryId});

  @override
  State<NoteEditPage> createState() => _NoteEditPageState();
}

class _NoteEditPageState extends State<NoteEditPage> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;

  /// 当前选中分类；null = 未分类
  int? _categoryId;

  /// 编辑模式下的原笔记（保存时保留 created_at）
  Note? _original;

  @override
  void initState() {
    super.initState();
    _original = context.read<NoteProvider>().byId(widget.noteId);
    _titleCtrl = TextEditingController(text: _original?.title ?? '');
    _contentCtrl = TextEditingController(text: _original?.content ?? '');
    // 编辑已有笔记沿用原分类；新建时优先用传入的 initialCategoryId，
    // 否则回退到首个预置分类
    _categoryId = _original?.categoryId ??
        widget.initialCategoryId ??
        context.read<CategoryProvider>().defaultCategoryId('note');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoryName =
        context.watch<CategoryProvider>().nameOf(_categoryId);
    final isNew = widget.noteId == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? '新建笔记' : '编辑笔记'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: '保存',
            onPressed: _save,
          ),
        ],
      ),
      body: Column(
        children: [
          // 标题输入
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _titleCtrl,
              maxLength: 100,
              decoration: const InputDecoration(
                labelText: '标题',
                border: OutlineInputBorder(),
                counterText: '', // 隐藏字数计数，保持简洁
              ),
            ),
          ),
          // 分类选择
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: const Text('分类'),
            trailing: Text(categoryName,
                style: TextStyle(color: Colors.teal.shade700)),
            onTap: _pickCategory,
          ),
          const Divider(height: 1),
          // 正文输入
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _contentCtrl,
                maxLines: null, // 多行输入
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: '输入笔记正文…',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 弹出分类选择底部弹层
  Future<void> _pickCategory() async {
    final result = await showCategoryPickerSheet(
      context,
      assetType: 'note',
      currentId: _categoryId,
    );
    if (result == null) return; // 取消，保持原选择
    setState(() {
      _categoryId = result == -1 ? null : result;
    });
  }

  /// 保存笔记：空标题兜底为"未命名 + 时间"，写库失败给出提示
  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text;
    final now = DateTime.now().millisecondsSinceEpoch;

    final note = Note(
      id: _original?.id,
      title: title.isEmpty
          ? '未命名 ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}'
          : title,
      content: content,
      categoryId: _categoryId,
      createdAt: _original?.createdAt ?? now,
      updatedAt: now,
    );

    try {
      await context.read<NoteProvider>().save(note);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (_) {
      // 存储异常（如磁盘已满）：提示重试，编辑内容不丢失
      if (mounted) showError(context, '保存失败，请重试');
    }
  }
}
