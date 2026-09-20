// 统一的轻量提示（实现文档 §10：所有异常场景用 SnackBar 反馈）
import 'package:flutter/material.dart';

/// 错误提示（红色）：导入失败 / 文件丢失 / 权限拒绝 / 打开失败等
void showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
}

/// 普通提示（主题色）：导入成功 / 保存成功等操作反馈
void showInfo(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
}
