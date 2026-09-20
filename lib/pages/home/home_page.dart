import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants.dart';
import '../../models/asset_item.dart';
import '../../models/note.dart';
import '../../providers/asset_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/note_provider.dart';
import '../../services/file_storage.dart';
import '../../services/open_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/type_icon.dart';
import '../audio/audio_list_page.dart';
import '../category/category_content_page.dart';
import '../image/image_viewer_page.dart';
import '../note/note_edit_page.dart';
import '../search/search_page.dart';

/// 工作台首页（实现文档 §8.1，对应验收标准 1/9）。
///
/// 结构：
/// - 顶部搜索框（点击进入搜索页）；
/// - 四大入口卡片：笔记 / 图片 / 语音 / 文档，显示数量摘要；
/// - 最近添加：四种类型混合取最新若干条，点击直达对应查看页。
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final noteProvider = context.watch<NoteProvider>();
    final assetProvider = context.watch<AssetProvider>();
    final categoryProvider = context.watch<CategoryProvider>();

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 16,
              backgroundImage: AssetImage('assets/images/avatar.jpg'),
            ),
            const SizedBox(width: 10),
            const Text(
              'བརྩོན་རྟོགས་དཔེ་མཛོད།',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SearchBar(),
          const SizedBox(height: 16),
          _CategoryNav(
            categories: categoryProvider,
            notes: noteProvider.notes,
            assets: assetProvider,
          ),
          const SizedBox(height: 8),
          _RecentSection(
            notes: noteProvider.notes,
            assets: assetProvider,
          ),
        ],
      ),
    );
  }
}

/// 六个跨资料类型的预置分类入口：横向滚动导航栏样式。
/// 点击某分类后进入汇总页，展示笔记/图片/语音/文档中属于该分类的全部资料。
class _CategoryNav extends StatelessWidget {
  final CategoryProvider categories;
  final List<Note> notes;
  final AssetProvider assets;

  const _CategoryNav({
    required this.categories,
    required this.notes,
    required this.assets,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: AppConstants.presetCategoryNames.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final name = AppConstants.presetCategoryNames[i];
          final count = _countFor(name);
          return _CategoryChip(
            name: name,
            count: count,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CategoryContentPage(categoryName: name),
              ),
            ),
          );
        },
      ),
    );
  }

  int _countFor(String name) {
    int? idOf(String type) {
      for (final category in categories.of(type)) {
        if (category.name == name) return category.id;
      }
      return null;
    }

    final noteId = idOf('note');
    var count =
        noteId == null ? 0 : notes.where((n) => n.categoryId == noteId).length;
    for (final type in AssetType.values) {
      final categoryId = idOf(type.dbValue);
      if (categoryId != null) {
        count += assets
            .itemsOf(type)
            .where((asset) => asset.categoryId == categoryId)
            .length;
      }
    }
    return count;
  }
}

/// 单个分类胶囊：分类名 + 条数角标
class _CategoryChip extends StatelessWidget {
  final String name;
  final int count;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.name,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.teal.shade50,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.teal,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.teal,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 顶部搜索框：点击跳转搜索页（不在首页直接输入，保持布局简单）
class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SearchPage()),
      ),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.search, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Text('搜索笔记、图片、语音、文档',
                style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }
}

/// 最近添加的资料条目（首页摘要用）
class _RecentItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final int createdAt;
  final Future<void> Function(BuildContext) onOpen;

  _RecentItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.createdAt,
    required this.onOpen,
  });
}

/// "最近添加"区块：四类资料各取最新 3 条，混合按时间倒序，最多展示 8 条
class _RecentSection extends StatelessWidget {
  final List<Note> notes;
  final AssetProvider assets;

  const _RecentSection({required this.notes, required this.assets});

  @override
  Widget build(BuildContext context) {
    final items = <_RecentItem>[
      for (final Note n in notes.take(3))
        _RecentItem(
          title: n.title,
          subtitle: '笔记 · ${formatDateTime(n.updatedAt)}',
          icon: Icons.edit_note,
          createdAt: n.updatedAt,
          onOpen: (ctx) => _pushPage(ctx, NoteEditPage(noteId: n.id)),
        ),
      for (final a in assets.itemsOf(AssetType.image).take(3))
        _RecentItem(
          title: a.name,
          subtitle: '图片 · ${formatDateTime(a.createdAt)}',
          icon: Icons.image_outlined,
          createdAt: a.createdAt,
          onOpen: (ctx) async {
            final file = FileStorage.instance.fileOfAsset(a);
            await _pushPage(
                ctx, ImageViewerPage(asset: a, filePath: file.path));
          },
        ),
      for (final a in assets.itemsOf(AssetType.audio).take(3))
        _RecentItem(
          title: a.name,
          subtitle: '语音 · ${formatDateTime(a.createdAt)}',
          icon: Icons.mic_none,
          createdAt: a.createdAt,
          onOpen: (ctx) => _pushPage(ctx, const AudioListPage()),
        ),
      for (final a in assets.itemsOf(AssetType.doc).take(3))
        _RecentItem(
          title: a.name,
          subtitle: '文档 · ${formatDateTime(a.createdAt)}',
          icon: iconForAsset(a),
          createdAt: a.createdAt,
          onOpen: (ctx) => OpenService.openAsset(ctx, a),
        ),
    ]..sort((x, y) => y.createdAt.compareTo(x.createdAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text('最近添加',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ),
        if (items.isEmpty)
          // 空状态引导（验收标准：数据为空时展示空状态）
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text('暂无资料，点击上方入口开始添加',
                  style: TextStyle(color: Colors.grey.shade500)),
            ),
          )
        else
          ...items.take(8).map(
                (it) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(it.icon, color: Colors.teal),
                  title: Text(it.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(it.subtitle, style: const TextStyle(fontSize: 12)),
                  onTap: () => it.onOpen(context),
                ),
              ),
      ],
    );
  }

  Future<void> _pushPage(BuildContext context, Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }
}
