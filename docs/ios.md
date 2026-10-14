# 拾光账本 3.0.1 · iPhone 13 适配

本分支从发布提交 `1dc90e5695c6661ed4ffdd548bd2ef1472f29bf2` 创建。
目标是 iPhone 13 机型，最低系统 iOS 15，不是兼容 iOS 13 系统。
保留原版 Flutter 页面、报表、记账规则、语音草稿核对及 Paraformer-zh INT8 模型。

## 本地运行

需要 macOS、Xcode 26 或更新版本、Flutter 3.47.2，以及 CocoaPods。
与 Android 一样，平台工程通过脚本生成，不将模型、生成工程或证书提交到 Git。
已有 `ios/` 时脚本保留 Xcode 签名设置；原生桥接、资源配置及测试由源码重新应用。

```bash
flutter config --no-enable-swift-package-manager
bash tool/bootstrap_ios.sh
python3 tool/prepare_voice_model.py --platform ios
flutter pub get
flutter analyze --no-fatal-infos
flutter test --timeout 90s
open ios/Runner.xcworkspace
```

在 Xcode 的 Runner → Signing & Capabilities 中选择自己的开发团队，
连接 iPhone 13，选择设备后运行。默认 Bundle ID 由 Flutter 生成为
`com.shiguang.smartBudget`；若账号需要其他标识，在 Xcode 中修改。
准备模型需要访问固定版本的 Hugging Face 文件，模型通过固定 SHA256 校验。

## 已接入的系统能力

- `smart_budget/storage`：账目和日期缓存分别保存到 Application Support 的 JSON 文件，串行后台读写和原子替换。
- CSV：使用系统“文件”选择器导入、导出，支持取消及重复操作保护；继续使用原版 CSV 解析规则。
- `smart_budget/voice`：返回应用包中的模型和词表路径，以及私有临时录音目录。模型不重复解压，临时 WAV 在处理后删除。
- 原生注册使用 Flutter 的 UIScene/隐式引擎回调，麦克风权限说明已配置。
- 图标沿用原有矢量设计，由 CoreGraphics 生成苹果要求的尺寸。

Android 可以先导出 CSV，再在 iPhone 中导入。CSV 仅迁移账单字段，
不包含预算、偏好、内部记录 ID 或日期缓存；重复追加导入会产生重复账单。
本分支未新增账号或跨设备自动同步。

## 验证与交付

GitHub Actions 的 `Validate iPhone 13 iOS port` 执行：
项目配置检查、完整 Flutter 回归、iPhone 13 模拟器原生通道与真实离线模型推理、
Swift 存储测试、模拟器应用构建和 ARM64 无签名 Release 构建。
生成截图、原生测试结果及无签名 `.app` 压缩包，保留 14 天。

模拟器集成测试需先准备测试音频：

```bash
python3 tool/prepare_voice_model.py --platform ios --include-smoke-audio
flutter test integration_test/ios_host_test.dart -d <模拟器ID> --timeout 300s
```

发布前重新执行不带 `--include-smoke-audio` 的模型准备命令。
测试音频不进入正式构建，正式模型与 Android 3.0.1 相同。
无签名 `.app` 不能直接安装到普通 iPhone；真机安装、归档或 TestFlight 需开发者账号签名。
本流程不会自动提交 App Store 或发布新版本。

## 真机验收

在 iPhone 13 上核对：暖橙界面和深色模式、安全区与键盘；
新增/编辑/删除后强制退出并重新打开；CSV 在“我的 iPhone”和 iCloud Drive 中导入导出与取消；
首次麦克风授权、拒绝授权、提前松手、来电/后台中断、30 秒上限、重新录音和确认保存；
飞行模式下识别中文语音，并记录首次模型加载、识别耗时和内存峰值。
模拟器的麦克风和 CPU 行为不能代替真机验收。

原版“每日记账提醒”目前只有开关及时间状态，本分支保留原有行为，未新增系统通知调度。
