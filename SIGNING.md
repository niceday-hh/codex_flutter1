# Android 长期签名

从 v2.1.0 开始，拾光账本使用固定的长期签名证书。私钥绝不能提交到 Git 仓库。

在仓库 `Settings → Secrets and variables → Actions` 中创建：
- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

固定证书 SHA-256：
`7F:34:3B:B4:19:D2:23:78:ED:5B:DE:6E:75:4F:51:24:3A:D9:84:C1:E8:80:04:FA:13:3B:8A:FE:9B:E3:CD:95`

请离线备份 keystore 和密码。私钥一旦丢失，就无法再为包名 `com.shiguang.smart_budget` 生成可覆盖安装的新版 APK。
