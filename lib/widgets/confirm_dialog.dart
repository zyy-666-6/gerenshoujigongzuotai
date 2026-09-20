import 'package:flutter/material.dart';

/// 删除二次确认对话框。
///
/// 基础版不提供回收站（实现文档 §15-7）：删除即永久，
/// 因此所有删除操作必须经过此确认。
Future<bool> confirmDelete(
  BuildContext context, {
  String title = '确认删除',
  String? message,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message ?? '删除后无法恢复，确定删除吗？'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('取消'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red.shade700,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('删除'),
        ),
      ],
    ),
  );
  return result == true;
}
