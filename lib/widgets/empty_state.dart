import 'package:flutter/material.dart';

/// 通用空状态占位视图（首页/列表/搜索共用）。
///
/// 对应实现文档 §8.1/§10：数据为空时给出引导文案，不展示空白页面。
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? hint;

  const EmptyState({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.message,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(message, style: TextStyle(color: Colors.grey.shade600)),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(hint!, style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}
