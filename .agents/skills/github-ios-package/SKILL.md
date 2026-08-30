---
name: github-ios-package
description: 通过 GitHub Actions 云打包 iOS 工程为 ipa 的完整流程（本机 Xcode 过旧、无法链接新版广告 SDK 时的免升级打包方案）。覆盖 git 入库准备、workflow 编写（签名/未签名自适应分支，含 if 不能引用 secrets 的坑）、push 触发、API 轮询监控、artifact 断点续传下载、ipa 本地验证与常见故障修复。适用于「上架前验证构建」和「真机安装测试」两个场景。
---

# GitHub Actions 云打包 iOS 工程为 ipa

## 适用场景

- 本机 Xcode 版本过低（如 15.2 / iOS 17.2 SDK），无法链接新版广告 SDK
  （例：AdMob 11.7.0 引用 iOS 18 SDK 符号 MarketplaceKit/swiftXPC，需 Xcode 16+）。
- 需要在不升级本机系统的前提下：真机安装测试、上架前验证构建链路。
- GitHub 云 runner（macos-latest）自带最新 Xcode，可正常链接。

## 前置条件

- GitHub 私有仓库 + 推送凭证：SSH key 已加入 GitHub 账号
  （验证：`ssh -T git@github.com` 返回 `Hi <账号>!`），或 HTTPS + PAT。
- 工程已是 git 仓库；`Package.resolved` 固定交付版本（如 11.7.0）。

## 一、工程入库准备

1. `.gitignore`（排除构建产物与本地工具状态）：
   ```gitignore
   # Build artifacts
   build/
   dist/
   DerivedData/
   # macOS
   .DS_Store
   xcuserdata/
   *.xcuserstate
   # Packages
   *.ipa
   *.xcarchive
   *.dSYM.zip
   ```
2. **Vendor 广告 SDK（xcframework）必须入库**：pbxproj 引用的是本地相对路径
   （如 `QiGames/Vendor/InMobi/InMobiSDK.xcframework`），CI checkout 后没有它无法编译。
3. 初始提交：
   ```bash
   git init -b main
   git config user.name "..." && git config user.email "..."
   git add -A && git commit -m "chore: 初始化"
   ```
4. 配置 remote 并推送：
   ```bash
   git remote add origin git@github.com:<账号>/<仓库>.git
   GIT_SSH_COMMAND="ssh -o ConnectTimeout=15 -o BatchMode=yes" git push -u origin main
   ```

## 二、workflow 编写（.github/workflows/package.yml）

要点：
- **`if:` 条件不能直接引用 `secrets` 上下文**（报 `Unrecognized named-value: 'secrets'`，
  导致 workflow 无效、job 不启动）→ 用 job 级 `env` 标志或 step `env` + shell 分支。
- 签名/未签名自适应：配置了证书 secrets 走 App Store 签名分支，否则 `CODE_SIGNING_ALLOWED=NO` 未签名。
- 触发：`push` 到 main 自动跑 + `workflow_dispatch` 手动跑。

```yaml
name: CI Package (pre-release verification)

on:
  workflow_dispatch:
  push:
    branches: [ main ]

jobs:
  package:
    runs-on: macos-latest
    env:
      HAS_CERT: ${{ secrets.DIST_CERT_P12 != '' }}
    steps:
      - uses: actions/checkout@v4

      - name: Import distribution certificate
        if: env.HAS_CERT == 'true'
        uses: apple-actions/import-codesign-certs@v3
        with:
          p12-file-base64: ${{ secrets.DIST_CERT_P12 }}
          p12-password: ${{ secrets.DIST_CERT_PASSWORD }}

      - name: Install provisioning profile
        if: env.HAS_CERT == 'true'
        run: |
          mkdir -p "$HOME/Library/MobileDevice/Provisioning Profiles"
          echo "${{ secrets.PROVISIONING_PROFILE }}" | base64 -d > "$HOME/Library/MobileDevice/Provisioning Profiles/QiGames.mobileprovision"

      - name: Archive (unsigned by default; signed when cert secrets configured)
        env:
          CERT_P12: ${{ secrets.DIST_CERT_P12 }}
          TEAM_ID: ${{ secrets.DEVELOPER_TEAM_ID }}
          PROFILE_SPECIFIER: ${{ secrets.PROVISIONING_PROFILE_SPECIFIER }}
        run: |
          if [ -n "$CERT_P12" ]; then
            xcodebuild archive \
              -project QiGames.xcodeproj -scheme QiGames \
              -configuration Release \
              -destination 'generic/platform=iOS' \
              -archivePath build/QiGames.xcarchive \
              DEVELOPMENT_TEAM="$TEAM_ID" \
              CODE_SIGN_STYLE=Manual \
              PROVISIONING_PROFILE_SPECIFIER="$PROFILE_SPECIFIER" \
              -allowProvisioningUpdates
          else
            xcodebuild archive \
              -project QiGames.xcodeproj -scheme QiGames \
              -configuration Release \
              -destination 'generic/platform=iOS' \
              -archivePath build/QiGames.xcarchive \
              CODE_SIGNING_ALLOWED=NO
          fi

      - name: Package ipa
        run: |
          mkdir -p Payload
          cp -R build/QiGames.xcarchive/Products/Applications/QiGames.app Payload/
          zip -q -r -y QiGames.ipa Payload/

      - name: Verify bundle
        run: |
          unzip -t QiGames.ipa > /dev/null && echo "ipa zip OK"
          file Payload/QiGames.app/QiGames
          /usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" Payload/QiGames.app/Info.plist

      - uses: actions/upload-artifact@v4
        with:
          name: QiGames-ipa
          path: QiGames.ipa
```

## 三、监控构建（API 轮询）

需要 PAT（权限 `repo`）：
```bash
TOKEN=<PAT>
curl -s -H "Authorization: Bearer $TOKEN" \
  "https://api.github.com/repos/<账号>/<仓库>/actions/runs?per_page=1" \
  | grep -oE '"status": "[^"]*"|"conclusion": "[^"]*"'
```
循环轮询直到 `status=completed`（注意 JSON 是单行，勿用 `grep -B/-A` 按行匹配）。

## 四、下载 artifact（断点续传）

本机到 GitHub CDN 慢时，`curl` 单次会超时，用 `-C -` 续传：
```bash
# 1) 查 run id 和 artifact id
#    GET /repos/<账号>/<仓库>/actions/runs/<run_id>/artifacts
# 2) 断点续传下载（目标字节数 TARGET 取 size_in_bytes）
for i in $(seq 1 15); do
  curl -sL -C - -H "Authorization: Bearer $TOKEN" \
    "https://api.github.com/repos/<账号>/<仓库>/actions/artifacts/<artifact_id>/zip" \
    -o artifact.zip --max-time 40
  SZ=$(stat -f%z artifact.zip)
  [ "$SZ" -ge "$TARGET" ] && break
done
# 3) 解包
unzip -q artifact.zip   # 得到 QiGames.ipa
unzip -q QiGames.ipa -d app   # Payload/QiGames.app
```

## 五、本地验证

```bash
B=app/Payload/QiGames.app
file "$B/QiGames"                                    # arm64
/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$B/Info.plist"
unzip -t QiGames.ipa | tail -1                       # zip 完整性
ls "$B/Frameworks/"                                  # 广告 SDK 嵌入
ls "$B/Base.lproj/"                                  # storyboardc
test -f "$B/PrivacyInfo.xcprivacy" && echo 隐私清单有
```

## 关键差异：静态链接 vs 动态框架

- **Xcode 15.2（本地）**：SPM 的 GoogleMobileAds 被**静态链接进主二进制**
  （`nm` 可见 `_OBJC_CLASS_$_GADMobileAds` 为 S）。
- **新版 Xcode（CI macos-latest）**：作为**动态 framework 嵌入** `Frameworks/`
  （主二进制无 GAD 类符号，属正常）。验证时查 `Frameworks/` 目录而非主二进制符号。

## 六、上架（签名 + 上传）

1. 仓库 Secrets 配置：`DIST_CERT_P12`（.p12 base64）、`DIST_CERT_PASSWORD`、
   `PROVISIONING_PROFILE`（.mobileprovision base64）、`DEVELOPER_TEAM_ID`、
   `PROVISIONING_PROFILE_SPECIFIER`。
2. 重新 push 或手动 Run workflow → 自动走签名分支。
3. 上传 App Store Connect（需 App Store Connect API Key .p8）：
   ```bash
   xcrun altool --upload-app -f build/export/QiGames.ipa -t ios \
     --apiKey <KEY_ID> --apiIssuer <ISSUER_ID> --apiKeyFile AuthKey.p8 --verbose
   ```
   详细上架流程见工程内 `docs/AppStore发布手册.md`。

## 常见故障

| 症状 | 根因 | 修复 |
|---|---|---|
| Actions 页 job 不启动 / API `total_count: 0` | workflow YAML 无效（多为 `if:` 引用 secrets） | 用 `POST .../actions/workflows/package.yml/dispatches` 复现 422 错误信息；改用 env 标志 |
| run conclusion=failure 但无 job | 同上 | 同上 |
| push 卡死/超时 | github.com 间歇不通 | `GIT_SSH_COMMAND="ssh -o ConnectTimeout=15"`；重试 |
| artifact 下载慢/中断 | 本机到 CDN 慢 | `curl -C -` 断点续传（见四） |
| 主二进制查不到 GAD 符号 | 新版 Xcode 动态框架嵌入 | 查 `Frameworks/GoogleMobileAds.framework`（见五） |
| CI 构建失败在 SPM 解析 | runner 网络问题 | 重跑；SPM 拉取 GitHub 依赖通常正常 |

## 安全提醒

- PAT 用完即从临时文件删除（`rm -f /tmp/gh_token`），并提醒用户在 GitHub 吊销。
- secrets 只在 workflow `env` 中引用，不写进日志/命令字符串。
