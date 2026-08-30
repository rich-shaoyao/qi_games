# QiGames（Word Charades）App Store 发布手册

> 工程：`/Users/lishaoyao/data0/iaa/QiGames`（Objective-C，Bundle ID `com.qishare.ios.hxs`）
> 生成日期：2026-08-28
> 当前状态：代码合规项已补齐（隐私清单 / ATT / UMP），待账号 + 构建环境就绪后走发布流程。

---

## 0. 现状盘点

| 项 | 状态 |
|---|---|
| 部署目标 | iOS 15.0，arm64（iPhone/iPad） |
| AdMob | SPM 依赖 **11.7.0**（交付版本；Xcode 15.2 无法链接它，构建/打包需 Xcode 16+） |
| 广告网络 | AdMob + InMobi + Vungle（本地 xcframework） |
| Info.plist | 含 ATT 文案、SKAdNetworkItems（50+）、麦克风/语音/定位描述、`GADApplicationIdentifier`（⚠️ 当前是**测试 ID**，需换正式） |
| App 隐私清单 | ✅ `QiGames/PrivacyInfo.xcprivacy`（已加入工程 Resources） |
| ATT 请求 | ✅ AppDelegate `qi_initializeAdMobAfterTrackingAuthorization` |
| UMP 同意流程 | ✅ AppDelegate `qi_requestConsentFromViewController:` |
| 第三方 SDK 隐私清单 | ✅ 自带（GoogleMobileAds / UMP / InMobi / Vungle） |
| 开发者账号/证书 | ❌ 无（需注册） |
| 构建环境 | ❌ 本机 macOS 13.7 + Xcode 15.2（**无法上架**，必须 Xcode 16+） |

---

## 1. 硬性前提（缺一不可）

1. **Apple Developer Program 账号**（$99/年，developer.apple.com 注册），并在 App Store Connect 创建 App 记录。
2. **Xcode 16 及以上**构建环境（Apple 自 2025-04 起强制所有提交用 Xcode 16+；2026 年需用最新/次新 Xcode，即 Xcode 26.x 或 25.x）。本机 macOS 13.7 装不了 Xcode 16（最低 macOS 14.5），三条出路见「方案总览」。
3. **正式 AdMob App ID**：AdMob 后台创建应用后得到 `ca-app-pub-xxxx~yyyy`，替换 Info.plist 的 `GADApplicationIdentifier`（当前为测试 ID）。
4. **正式 InMobi / Vungle 账号 ID**：替换 `AppDelegate.m` 顶部 `kQiInMobiAccountID` / `kQiVungleAppID` 占位符。
5. **审核元数据**：隐私政策 URL（广告 App 必须）、App 名称、描述、截图（6.9"/6.7"/6.5" iPhone 各 1-2 张 + iPad）、支持 URL、审核备注（说明测试账号/登录方式，本 App 无账号）。

---

## 2. 方案总览

| 方案 | 适合 | 关键动作 | 成本 |
|---|---|---|---|
| **A. 升级本机环境** | 想在本机打正式包 | 升 macOS 14+（Intel 机最高到 Xcode 16.x；若 Xcode 26 要求 Apple Silicon 则需换机）→ 装 Xcode → 登录账号 → archive/上传 | 时间 + 账号 |
| **B. CI 云打包（推荐，无新 Mac 也能走）** | 本机无法升级/不想动环境 | 工程推 GitHub → GitHub Actions（macOS runner 自带 Xcode 26）archive + 签名 + 上传 App Store Connect | 账号 + GitHub |
| **C. 第三方/合作方账号** | 想最快上线、不自己持有账号 | 代码合规已就绪，出 archive 包交给对方签名上传（Bundle ID 需注册在对方账号下） | 分成/服务费 |

> 无论哪种方案，**代码合规项已全部改好**，不需要再动代码（除非换正式 AdMob ID）。

---

## 3. 方案 B 详细准备清单（CI 云打包）

### 3.1 开发者账号侧准备
1. 注册 Apple Developer Program 账号（$99/年）。
2. **注册 App ID**：developer.apple.com → Certificates, IDs & Profiles → Identifiers → 新建 App ID，Bundle ID 填 **`com.qishare.ios.hxs`**（显式 ID），勾选 App Services（本 App 无需特殊 capability）。
3. **创建 App Store 分发证书**：Certificates → 新建 `Apple Distribution` 证书（.cer），用本机钥匙串导出成 `.p12`（含私钥）+ 记下导出密码。
   - 替代：App Store Connect API Key（.p8，用于 altool 上传，无需证书管理）。
4. **创建 Provisioning Profile**：Profiles → `App Store` 类型 → 关联上面 App ID + 分发证书，下载 `.mobileprovision`。
5. **App Store Connect**：新建 App（平台 iOS，Bundle ID 选 `com.qishare.ios.hxs`，名称、语言、价格计划）。**上传 ipa 前 App 记录必须已存在。**

### 3.2 仓库侧准备
1. 工程 `git init` + 推 GitHub **私有仓库**（本机到 github.com 间歇超时，推送失败时改用 Gitee/自建或换网络；CI 侧访问 github 无此问题）。
2. 确认 `QiGames.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` 已固定 **11.7.0**（✅ 已是），CI 全新环境会正常拉取 SPM 依赖。
3. 建议加 `.gitignore`：`build/`、`dist/`、`DerivedData/`、`*.ipa`、`*.xcarchive`（本工程当前非 git 仓库，首次提交时补上）。
4. 若担心仓库含广告账号 ID 等敏感信息：`AppDelegate.m` 的 InMobi/Vungle ID 先填正式值（或留占位，通过 CI secret/环境变量注入——本项目简单起见直接填正式值，仓库设私有）。

### 3.3 GitHub Actions Secrets（仓库 Settings → Secrets → Actions）
| Secret | 内容 | 用途 |
|---|---|---|
| `DEVELOPER_TEAM_ID` | 开发者 Team ID（developer.apple.com 账号页可见） | 签名 |
| `DIST_CERT_P12` | 分发证书 .p12 的 **base64** | 装证书 |
| `DIST_CERT_PASSWORD` | .p12 导出密码 | 装证书 |
| `PROVISIONING_PROFILE` | App Store 描述文件 .mobileprovision 的 **base64** | 签名 |
| `ASC_API_KEY` | App Store Connect API Key .p8 的 **base64** | 上传（altool） |
| `ASC_API_KEY_ID` / `ASC_ISSUER_ID` | API Key ID / Issuer ID | 上传 |

> 用 `base64 -i 文件 -o -` 生成 base64 字符串。

### 3.4 参考 Workflow（`.github/workflows/release.yml`）
```yaml
name: Archive & Upload
on:
  workflow_dispatch:   # 手动触发；也可加 push tag 触发

jobs:
  build:
    runs-on: macos-15    # 自带 Xcode 26.x；也可 macos-14
    steps:
      - uses: actions/checkout@v4

      - name: Import distribution certificate
        uses: apple-actions/import-codesign-certs@v3
        with:
          p12-file-base64: ${{ secrets.DIST_CERT_P12 }}
          p12-password: ${{ secrets.DIST_CERT_PASSWORD }}

      - name: Install provisioning profile
        run: |
          mkdir -p "$HOME/Library/MobileDevice/Provisioning Profiles"
          echo "${{ secrets.PROVISIONING_PROFILE }}" | base64 -d > "$HOME/Library/MobileDevice/Provisioning Profiles/QiGames.mobileprovision"

      - name: Archive
        run: |
          xcodebuild archive \
            -project QiGames.xcodeproj -scheme QiGames \
            -configuration Release \
            -destination 'generic/platform=iOS' \
            -archivePath "$RUNNER_TEMP/QiGames.xcarchive" \
            DEVELOPMENT_TEAM=${{ secrets.DEVELOPER_TEAM_ID }} \
            CODE_SIGN_STYLE=Manual \
            PROVISIONING_PROFILE_SPECIFIER=QiGames \
            -allowProvisioningUpdates

      - name: Export ipa
        run: |
          cat > "$RUNNER_TEMP/exportOptions.plist" <<'EOF'
          <?xml version="1.0" encoding="UTF-8"?>
          <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
          <plist version="1.0">
          <dict>
            <key>method</key><string>app-store</string>
            <key>teamID</key><string>${{ secrets.DEVELOPER_TEAM_ID }}</string>
            <key>uploadSymbols</key><true/>
            <key>compileBitcode</key><false/>
          </dict>
          </plist>
          EOF
          xcodebuild -exportArchive \
            -archivePath "$RUNNER_TEMP/QiGames.xcarchive" \
            -exportOptionsPlist "$RUNNER_TEMP/exportOptions.plist" \
            -exportPath "$RUNNER_TEMP/export"

      - name: Upload to App Store Connect
        env:
          ASC_API_KEY: ${{ secrets.ASC_API_KEY }}
          ASC_API_KEY_ID: ${{ secrets.ASC_API_KEY_ID }}
          ASC_ISSUER_ID: ${{ secrets.ASC_ISSUER_ID }}
        run: |
          echo "$ASC_API_KEY" | base64 -d > "$RUNNER_TEMP/AuthKey.p8"
          xcrun altool --upload-app \
            -f "$RUNNER_TEMP/export/QiGames.ipa" \
            -t ios \
            --apiKey "$ASC_API_KEY_ID" --apiIssuer "$ASC_ISSUER_ID" \
            --apiKeyFile "$RUNNER_TEMP/AuthKey.p8" \
            --verbose
```

### 3.5 本机等价命令（方案 A 或 CI 调试时用）
```bash
# archive（签名；DEVELOPMENT_TEAM 填真实 Team ID）
xcodebuild archive -project QiGames.xcodeproj -scheme QiGames \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath build/QiGames.xcarchive \
  DEVELOPMENT_TEAM=XXXXXXXXXX -allowProvisioningUpdates

# export ipa（exportOptions.plist 见上方，method = app-store）
xcodebuild -exportArchive -archivePath build/QiGames.xcarchive \
  -exportOptionsPlist exportOptions.plist -exportPath build/export

# 上传（需 App Store Connect API Key）
xcrun altool --upload-app -f build/export/QiGames.ipa -t ios \
  --apiKey <KEY_ID> --apiIssuer <ISSUER_ID> --apiKeyFile AuthKey.p8 --verbose
```

---

## 4. 方案 A 步骤（本机 / 另一台 Mac）
1. macOS 升到 14.5+（Intel 机）或 15+（Apple Silicon），App Store 装最新 Xcode。
2. Xcode → Settings → Accounts 登录开发者 Apple ID。
3. 打开工程 → Signing & Capabilities → 勾选 Automatically manage signing → 选 Team。
4. 用 Xcode 15.2 无法链接 AdMob 11.7.0，**务必用 Xcode 16+ 打开**（链接 11.7.0 正常）。
5. 按 3.5 的命令 archive → export → altool 上传；或直接在 Xcode Organizer 里 Distribute → App Store Connect。

## 5. 方案 C 步骤（第三方账号）
1. 本机或 CI 出 **archive**（`xcodebuild archive`，签名可留空 `CODE_SIGNING_ALLOWED=NO`）。
2. 把 `.xcarchive`（或未签名 ipa）交给对方，对方用其证书重新签名 + 上传：
   `xcodebuild -exportArchive ... DEVELOPMENT_TEAM=<对方Team> -allowProvisioningUpdates`
3. ⚠️ Bundle ID `com.qishare.ios.hxs` 必须注册在对方账号下；上架后 App 归对方账号管理（可转让所有权）。

---

## 6. 代码合规项（已完成 ✅）
- `QiGames/PrivacyInfo.xcprivacy`：声明广告数据（IDFA）收集 + 跟踪；`EnvironmentVariables`(1C8F.1) / `ProcessInfo`(4D34.1)（`-qiSimulateAdPanelTrigger` 调试参数）；已加入工程 Resources。
- `QiGames/AppDelegate.m`：`qi_initializeAdMobAfterTrackingAuthorization`（iOS 14+ 先请求 ATT 再初始化 AdMob）；`qi_requestConsentFromViewController:`（UMP 同意流程）。
- 第三方 SDK（GoogleMobileAds / UMP / InMobi / Vungle）自带隐私清单，随包携带。
- **待办**：换正式 `GADApplicationIdentifier`（Info.plist）、正式 InMobi/Vungle ID（AppDelegate.m）。

## 7. App Store Connect 提交清单
- [ ] App 记录已创建（Bundle ID、名称、价格、语言）
- [ ] 隐私政策 URL（广告 App 必填）
- [ ] 描述 / 关键词 / 支持 URL
- [ ] 截图（iPhone 6.9/6.7/6.5 + iPad）与预览视频（可选）
- [ ] 版本号/构建号（当前 1.0 (1)；每次上传需递增构建号）
- [ ] 审核信息 + 备注（说明测试方式；广告 App 建议注明有测试广告位）
- [ ] App Privacy（App Store Connect 问卷）：声明收集「广告数据/设备标识」，与隐私清单一致
- [ ] Export Compliance：使用标准加密选「是」（HTTPS 等）

## 8. 常见问题
- **为什么本机 Xcode 15.2 打不了 11.7.0 的包**：11.7.0 二进制引用 iOS 18 SDK 符号（MarketplaceKit/swiftXPC），Xcode 15.2 链接失败。Xcode 16+ 正常。
- **中国区上架**：猜词类游戏若被归为「游戏类」，中国区需游戏版号（无版号只能选非中国区/海外区发布）；同时需 ICP 备案相关资质。建议先发布海外区。
- **广告不展示**：检查正式 AdMob ID、InMobi/Vungle ID、以及 UMP 同意状态（欧盟区需同意才出个性化广告）。
- **ATT 与广告**：用户拒绝 ATT 时广告以非个性化形式展示（AdMob 自动降级），不影响 App 运行。
- **构建号冲突**：App Store Connect 拒绝已存在的构建号，每次提交递增 `CFBundleVersion`。
