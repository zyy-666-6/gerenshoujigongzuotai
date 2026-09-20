/// SQLite LIKE 模糊查询的通配符转义。
///
/// 必须配合 SQL 中的 `ESCAPE '\'` 子句使用：
/// 把用户输入中的 `\`、`%`、`_` 转义为字面量，避免关键词被当作通配符。
String likePattern(String keyword) {
  final escaped = keyword
      .replaceAll('\\', '\\\\')
      .replaceAll('%', '\\%')
      .replaceAll('_', '\\_');
  return '%$escaped%';
}
