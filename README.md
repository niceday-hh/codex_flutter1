# Smart Budget · Flutter Android

基于会话中的 Smart Budget UI 设计稿实现的 iOS 风记账 App 原型，面向荣耀 100 等 Android 高刷全面屏手机。项目采用 Flutter，界面以轻量玻璃质感、圆角卡片、弹性滚动、隐式动画、图表过渡和触感反馈为核心。

## 已实现

- 首页：本月收入 / 支出 / 结余、预算进度、快捷入口、近期消费、分类消费。
- 记账：支出 / 收入切换、大金额输入、分类选择、日期与备注、保存反馈。
- 账单：搜索、支出 / 收入筛选、按日期分组、左滑删除。
- 图表：环形分类图、14 天柱状趋势、收入概览、预算健康度。
- 动效：Tab 页平滑切换、按钮按压缩放、图表绘制动画、AnimatedSwitcher、BouncingScrollPhysics、毛玻璃底栏。
- Android：Edge-to-edge、120Hz 刷新率偏好提示、ARM64 release 构建路径。
- 本地数据：Android host 通过原生 SharedPreferences + Flutter MethodChannel 保存 JSON，不依赖第三方数据库插件。

## 目标设备

荣耀 100 官方规格为 6.7 英寸、2664×1200。UI 全部使用 Flutter 逻辑像素和响应式布局，不按物理像素硬编码，因此也可适配大多数 1080p / 1.5K Android 全面屏设备。

推荐目标：

- Android ARM64
- minSdk 由当前 Flutter 模板管理（建议不低于 23）
- 当前 Flutter stable
- Java 17

## 本地生成 Android Host

本仓库故意不固定一份可能很快过时的 Flutter Android Gradle模板。运行下面脚本会使用你当前安装的 Flutter 生成官方 Android host，然后自动写入 Smart Budget 的 SharedPreferences 持久化通道和高刷偏好：

```bash
bash ./tool/bootstrap_android.sh
flutter pub get
flutter run
```

构建荣耀 100 / ARM64 APK：

```bash
flutter build apk --release --target-platform android-arm64
```

APK 默认位于：

```text
build/app/outputs/flutter-apk/app-release.apk
```

> `flutter create` 默认 release 配置通常使用调试签名便于直接安装测试。正式上架或对外分发时，请配置自己的 release keystore，并妥善保存密钥。

## 云端构建

已内置两套配置：

- `.github/workflows/build-apk.yml`：GitHub Actions，一键构建 ARM64 APK 并上传 Artifact。
- `codemagic.yaml`：Codemagic 构建配置。

GitHub Actions 的流程会自动：安装当前 Flutter stable → 生成 Android host → `flutter analyze` → `flutter test` → 构建 release APK。

## 项目结构

```text
lib/
  main.dart                 App 入口、Edge-to-edge
  app_theme.dart            主题、颜色与分类视觉
  app_store.dart            数据状态、汇总、持久化
  models.dart               账单数据模型
  shell.dart                四 Tab 壳与毛玻璃底栏
  pages/
    home_page.dart
    add_page.dart
    ledger_page.dart
    stats_page.dart
  widgets/
    common.dart             卡片、进度条、交易行等
    charts.dart             环形图与柱状图 CustomPainter
tool/
  bootstrap_android.sh      生成 Android host + 原生持久化
.github/workflows/
  build-apk.yml             GitHub 云构建 APK
```

## 下一步适合加入

当前版本是可交互的 UI / 数据原型。产品化时建议继续加入：SQLite / Drift 数据库、预算编辑页、分类管理、周期账单、CSV/Excel 导入导出、拍照 OCR、云同步、指纹/人脸 App Lock、深色模式、小组件、通知提醒，以及正式签名和隐私政策。
