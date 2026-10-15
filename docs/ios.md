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
纯文件存储用 SwiftPM 直接运行生产代码与同一组 XCTest，避免依赖应用测试运行器；
iOS 原生通道和真实模型推理另外在 iPhone 模拟器中验证。
还会从最终 `.app` 重新校验模型 SHA256、麦克风说明和许可文件，并检查未混入测试音频。
无签名真机 Release 构建后，将应用放入 `Payload/Runner.app` 并打包为 IPA。
检查最终 IPA 的目录结构、真机平台、可执行权限、Flutter 框架、完整模型 SHA256 及 ZIP CRC，
不包含测试音频或任何设备的签名描述文件；另附 `SHA256SUMS`。
全部检查通过后上传 `shiguang-3.0.1-unsigned-ipa` 产物，保留 90 天。
截图和依赖锁文件位于 `shiguang-v3.0.1-ios-validation` 产物中，保留 14 天。
测试结果记录在 Actions 日志中。

模拟器集成测试需先准备测试音频：

```bash
python3 tool/prepare_voice_model.py --platform ios --include-smoke-audio
flutter test integration_test/ios_host_test.dart -d <模拟器ID> --timeout 300s
```

发布前重新执行不带 `--include-smoke-audio` 的模型准备命令。
测试音频不进入正式构建，正式模型与 Android 3.0.1 相同。
未签名 IPA 不能直接安装到普通 iPhone，需要通过 SideStore 等工具签名后安装。
本流程不会自动提交 App Store 或发布新版本。

## 免费账号通过 SideStore 安装

1. 打开本分支最新一次成功的 iOS Actions 构建，在 Artifacts 中下载
   `shiguang-3.0.1-unsigned-ipa`，解压得到 `shiguang-3.0.1-unsigned.ipa` 和 `SHA256SUMS`。
   导入 SideStore 的是 `.ipa`，不是 GitHub 下载的外层 `.zip`。
2. 按 [SideStore 官方安装说明](https://docs.sidestore.io/docs/installation/install)，
   首次用电脑和 USB 连接手机完成 SideStore、配对和开发者模式设置。
3. 把 IPA 保存到 iPhone 的“文件”中；连接 Wi-Fi 和 LocalDevVPN，在 SideStore 的
   `My Apps` 页面点击 `+`，选择 IPA，使用自己的免费 Apple 账号签名安装。
4. 在到期前通过 SideStore 刷新自身和拾光账本；免费描述文件有效期约 7 天。
   后续通常可以直接在手机上操作；系统升级、配对失效或签名工具故障可能需要电脑恢复。

构建阶段无需提供 UDID、Apple 账号、签名证书或 GitHub Secrets，也无需付费开发者会员。
续签或更新保持同一 Apple 账号和应用标识，采用覆盖安装以保留本地账本，避免先卸载应用。
IPA 是 ARM64 真机 Release 构建，最低 iOS 15；iOS 26.x 的签名工具兼容性和实际运行需真机确认。
本产物优先用于 SideStore 独立安装；LiveContainer 内运行尚未验收。

## 真机验收

在 iPhone 13 上核对：暖橙界面和深色模式、安全区与键盘；
新增/编辑/删除后强制退出并重新打开；CSV 在“我的 iPhone”和 iCloud Drive 中导入导出与取消；
首次麦克风授权、拒绝授权、提前松手、来电/后台中断、30 秒上限、重新录音和确认保存；
飞行模式下识别中文语音，并记录首次模型加载、识别耗时和内存峰值。
模拟器的麦克风和 CPU 行为不能代替真机验收。

原版“每日记账提醒”目前只有开关及时间状态，本分支保留原有行为，未新增系统通知调度。
