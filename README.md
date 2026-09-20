# 个人工作台 Android APP

个人本地资料管理工具：集中管理**笔记、图片、语音、文档**四类资料，支持分类浏览与关键词搜索。纯本地存储、不联网、无服务器、无账号。

> 依据《个人工作台Android_APP需求对接文档》基础版（500 元 / 4 周 / 售后 1 周）与《实现文档 V1.0》开发。

---

## 一、功能清单

| 模块 | 功能 |
|---|---|
| 工作台首页 | 四大入口卡片（含数量摘要）、最近添加、搜索入口 |
| 笔记 | 新建 / 编辑 / 保存 / 查看 / 删除；标题 + 正文 + 分类 + 更新时间 |
| 图片 | 相册导入 / 文件导入；3 列缩略图；点击查看大图（双指缩放）；长按删除 |
| 语音 | App 内录音（暂停/继续）；保存命名与归类；列表内播放/暂停/进度；删除 |
| 文档 | 文件导入（pdf/doc/docx/xls/xlsx/ppt/pptx/txt）；PDF App 内预览；Office 调用系统兼容应用打开 |
| 分类 | 四种资料各自独立分类；新建/重命名/删除（删除分类不删资料，资料归入"未分类"） |
| 搜索 | 按笔记标题、笔记正文、文件名关键词搜索，结果分组直达 |
| 存储 | SQLite（索引与笔记）+ 本地文件（App 私有目录），重启不丢失 |

## 二、目录结构

```
personal_workbench/
├── android/                        # Android 定制文件（权限/页面配置；Gradle 由 flutter create 生成）
├── lib/
│   ├── main.dart                   # 入口：初始化 DB/文件目录、注入 Provider
│   ├── constants.dart              # 全局常量（分类类型、格式白名单）
│   ├── models/                     # 数据模型：Note / AssetItem / CategoryItem
│   ├── services/
│   │   ├── db_service.dart         # SQLite 建库建表（单例）
│   │   ├── file_storage.dart       # 文件落盘目录管理（单例）
│   │   ├── dao/                    # note_dao / asset_dao / category_dao
│   │   ├── import_service.dart     # 统一导入（拷贝+索引，批量容错）
│   │   ├── open_service.dart       # 打开分发（PDF 内预览/外部应用）
│   │   ├── audio_recorder_service.dart  # 录音封装（record 插件）
│   ├── providers/                  # 状态管理（Provider）
│   │   ├── note_provider.dart      # 笔记
│   │   ├── asset_provider.dart     # 图片/语音/文档
│   │   ├── category_provider.dart  # 分类
│   │   ├── audio_playback_provider.dart  # 全局语音播放器
│   ├── pages/                      # 页面
│   │   ├── home/                   # 工作台首页
│   │   ├── note/                   # 笔记列表 + 编辑
│   │   ├── image/                  # 图片网格 + 大图查看
│   │   ├── audio/                  # 语音列表 + 录音
│   │   ├── doc/                    # 文档列表 + PDF 预览
│   │   ├── category/               # 分类管理
│   │   └── search/                 # 搜索
│   ├── widgets/                    # 公共组件（空状态/确认框/分类选择/筛选菜单）
│   └── utils/                      # 工具（格式化/提示/LIKE 转义）
└── test/widget_test.dart           # 冒烟测试
```

## 三、开发环境安装（Windows）

| 项 | 要求 |
|---|---|
| Flutter | 最新稳定版（≥ 3.47，pdfrx 2.x 插件要求） |
| Android Studio | 用于安装 Android SDK 与 JDK（也可只装命令行工具） |
| 测试机 | Android 6.0+（以双方约定测试手机为准） |

1. **下载 Flutter SDK**：到官网 https://docs.flutter.dev/get-started/install/windows 下载 zip，解压到**不含中文和空格**的路径（如 `D:\flutter`）。
2. **（国内网络建议）配置镜像**——用 PowerShell 执行一次（永久生效）：
   ```powershell
   [System.Environment]::SetEnvironmentVariable('PUB_HOSTED_URL','https://pub.flutter-io.cn','User')
   [System.Environment]::SetEnvironmentVariable('FLUTTER_STORAGE_BASE_URL','https://storage.flutter-io.cn','User')
   ```
   执行后重新打开终端。
3. **加入 PATH**：系统设置 → 高级系统设置 → 环境变量 → 编辑用户 `Path` → 新增 `D:\flutter\bin`。重开终端后执行 `flutter --version` 能看到版本即成功。
4. **安装 Android Studio**：https://developer.android.com/studio 下载安装，首次启动完成向导（会自动装好 Android SDK 与 JDK）。
5. **检查环境并接受协议**：
   ```bash
   flutter doctor
   flutter doctor --android-licenses   # 逐项输入 y
   ```
   反复执行 `flutter doctor`，直到没有红色错误项即环境就绪（个别黄色提示不影响构建）。
6. **连接测试手机**：手机开启「开发者选项 → USB 调试」，用数据线连接电脑，`flutter devices` 中能看到设备即可（也可在 Android Studio 里创建虚拟设备）。

## 四、构建与运行（安装说明）

> 仓库中的 `android/` Gradle 构建配置由第 2 步 `flutter create` 按所安装的 Flutter 版本自动生成，并在其上叠加了两处本项目专用调整（已随仓库保存；若重新生成，请按下方列表补回）：
> 1. `android/gradle.properties`：`kotlin.incremental=false` —— 本机 pub 缓存在 C: 盘、项目在 D: 盘，Kotlin 增量编译器跨盘符计算相对路径会崩溃（Windows 已知问题）；
> 2. `android/app/build.gradle.kts`：`compileSdk = 37` —— permission_handler 插件要求。
>
> 已定制的 Android 文件：`AndroidManifest.xml`（麦克风权限 / 应用名 / 包可见性声明）、`MainActivity.kt`（flutter create 生成于 `com.personal.personal_workbench` 包下）、`res/values/styles.xml`、`res/drawable/launch_background.xml`。
>
> **不执行第 2 步直接构建会失败（缺少 gradle wrapper）。**

```bash
# 1. 安装 Flutter SDK 后确认环境就绪
flutter doctor

# 2. 进入项目目录，补齐平台样板文件（已存在的文件不会被覆盖）
cd personal_workbench
flutter create --platforms android --org com.personal --project-name personal_workbench .

# 3. 拉取依赖
flutter pub get

# 4. 连接手机（开启 USB 调试）后运行
flutter devices
flutter run

# 5. 打包正式 APK（产物位于 build/app/outputs/flutter-apk/）
flutter build apk --release
```

**APK 安装到手机**：

1. 将 `app-release.apk` 传到手机（微信/数据线/网盘均可）。
2. 点击 APK，系统提示"未知来源/安装未知应用"时，按提示允许当前来源安装（不同品牌路径略有差异，一般在 系统设置 → 安全 → 安装未知应用）。
3. 安装完成即可离线使用，无需任何网络与账号。

**正式签名（可选）**：默认使用 debug 签名即可满足个人安装；如需自有签名，生成 keystore 后在 `android/app/build.gradle`（由 flutter create 生成后）的 `release` 块替换 `signingConfig`。

## 五、使用说明

### 笔记
- 首页点「笔记」→ 右下角「新建笔记」；输入标题（可留空，自动以"未命名+时间"命名）与正文，右上角 ✓ 保存。
- 点击列表条目进入编辑；条目右侧按钮删除（需二次确认）。

### 图片
- 首页点「图片」→ 底部「相册导入」（可多选）或「文件导入」。
- 点击缩略图查看大图（双指缩放）；长按缩略图删除。
- 顶部筛选按钮可按分类查看；正在筛选某分类时导入的图片自动归入该分类。

### 语音
- 首页点「语音」→ 右下角「录音」→ 首次使用需允许麦克风权限。
- 大按钮：开始 / 暂停 / 继续；「停止并保存」后确认名称与分类。
- 列表点击即播放/暂停，当前条目显示进度；右侧按钮删除。

### 文档
- 首页点「文档」→ 右下角「导入文档」选择文件。
- PDF：App 内直接预览翻页；Word/Excel/PPT/TXT：调用手机上已安装的对应应用打开。

### 分类
- 各列表页右上角文件夹图标进入分类管理：新建、重命名、删除。
- 删除分类时，该分类下的资料自动归入"未分类"，资料不会被删除。

### 搜索
- 首页顶部搜索框 → 输入关键词（300ms 防抖自动搜索）→ 结果按类型分组，点击直达。

## 六、权限说明

| 权限 | 用途 | 说明 |
|---|---|---|
| 麦克风 | 录音 | 仅在点击"开始录音"时申请；拒绝后可去系统设置开启 |
| 文件/相册 | 选择导入文件 | 走系统选择器，无需授权，不扫描手机其他文件 |
| 网络 | 无 | 本应用不申请网络权限，完全离线 |

## 七、数据存储与备份提醒

- 数据位置：App 私有目录内的 SQLite 数据库与 `files/` 文件夹（图片/语音/文档）。
- **卸载 App、清空应用数据、恢复出厂设置会删除全部本地资料**，请自行保留原始资料副本（基础版不含备份/恢复/云同步）。
- 存储空间不足会导致保存失败并提示，请清理手机空间后重试。

## 八、常见问题

| 现象 | 原因与处理 |
|---|---|
| Word/Excel/PPT 打不开 | 手机未安装可打开该格式的应用；安装 WPS/Office 后重试。要求 App 内完整渲染排版不在基础版范围 |
| 录音无声音 | 检查系统设置中是否允许本应用使用麦克风 |
| 提示"文件不存在或已被删除" | 底层文件被系统清理或手工删除；可在列表中删除该失效记录 |
| 保存/导入失败 | 多为存储空间不足，清理后重试 |
| 安装时提示"未知来源" | 见第四节安装说明，允许当前来源安装即可 |

## 九、边界说明（基础版不含）

云同步/备份恢复、账号与多人协作、iOS 或鸿蒙版本、应用市场上架、AI 能力（总结/OCR/语音转文字）、密码锁/指纹解锁、Office 文档 App 内完整排版渲染与编辑、历史资料批量整理迁移。如需以上能力，请按需求变更流程另行评估。
