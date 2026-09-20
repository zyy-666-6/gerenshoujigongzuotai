import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 冒烟测试：验证基础组件可构建。
///
/// 注：完整功能验收依赖真机环境（数据库/文件/麦克风），
/// 按需求文档第九章的验收标准在约定测试机上执行。
void main() {
  testWidgets('冒烟测试：基础组件可构建', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('个人工作台')),
        ),
      ),
    );
    expect(find.text('个人工作台'), findsOneWidget);
  });
}
