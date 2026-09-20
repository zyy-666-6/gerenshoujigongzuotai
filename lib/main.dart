import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/asset_provider.dart';
import 'providers/audio_playback_provider.dart';
import 'providers/category_provider.dart';
import 'providers/note_provider.dart';
import 'services/db_service.dart';
import 'services/file_storage.dart';
import 'pages/home/home_page.dart';

/// 应用入口。
///
/// 启动顺序（实现文档 §4）：
/// 1. 初始化数据库（建库/建表/预置默认分类）；
/// 2. 初始化文件存储目录（files/images、files/audio、files/docs）；
/// 3. 注入全局 Provider 后进入工作台首页。
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DbService.instance.init();
  await FileStorage.instance.init();
  runApp(const WorkbenchApp());
}

/// 应用根组件
class WorkbenchApp extends StatelessWidget {
  const WorkbenchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // 各 Provider 创建时立即异步加载首屏数据，加载完成后自动通知刷新
        ChangeNotifierProvider(create: (_) => CategoryProvider()..load()),
        ChangeNotifierProvider(create: (_) => NoteProvider()..load()),
        ChangeNotifierProvider(create: (_) => AssetProvider()..reload()),
        ChangeNotifierProvider(create: (_) => AudioPlaybackProvider()),
      ],
      child: MaterialApp(
        title: '个人工作台',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00695C)),
          appBarTheme: const AppBarTheme(centerTitle: true),
        ),
        home: const HomePage(),
      ),
    );
  }
}
