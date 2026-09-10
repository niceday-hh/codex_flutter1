# Smart Budget · Flutter Android

基于会话中的 Smart Budget UI 设计稿实现的 iOS 风记账 App 原型，面向荣耀 100 等 Android 高刷全面屏手机。当前仓库包含用于 GitHub Actions 云端构建的 Flutter 源码压缩包与工作流。

## 云端 APK 构建

进入 GitHub Actions 的 **Build Android APK** 工作流即可手动运行；推送到 `main` 也会自动触发。构建产物 Artifact 名称为 `smart-budget-arm64-release`，其中包含 `app-release.apk`。

当前构建链：Flutter stable + Java 17 + Android ARM64 Release。
