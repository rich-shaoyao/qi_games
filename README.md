# QiGames

本仓库用来存储 iOS 团建小游戏。当前包含 1 个游戏：默契猜词（QiDraw）。

## 工程信息

| 项目 | 说明 |
| --- | --- |
| 工程文件 | `QiGames.xcodeproj` |
| Target | `QiGames` |
| 开发语言 | Objective-C |
| 最低系统版本 | iOS 15.0（工程配置 `IPHONEOS_DEPLOYMENT_TARGET`，Debug / Release 均为 15.0） |
| 支持架构 | arm64（真机）；x86_64（Intel Mac 模拟器，`VALID_ARCHS = "arm64 x86_64"`） |
| 界面方式 | Storyboard（`Main` + 游戏 Storyboard） |
| 依赖管理 | Swift Package Manager（SPM）：AdMob `GoogleMobileAds` v11.7.0（交付目标版本，已锁定；本机 Xcode 15.2 可编译，完整链接需 Xcode 16 / iOS 18 SDK）+ 依赖 `GoogleUserMessagingPlatform` v2.7.0，版本锁定于 `Package.resolved` |
| Bundle ID | `com.qishare.ios.hxs` |
| 版本号 | `CFBundleShortVersionString` = 1.0，`CFBundleVersion` = 1 |
| 广告模块 | `QiAdManager` 抽象层 + 平台管理器（AdMob v11.7.0 真实 SDK、Vungle 7.0.0、InMobi 11.4.0、Chartboost 9.14.0，激励视频 / 插屏；当前使用各平台测试 ID，正式 ID 替换位置见各 Manager 实现文件顶部常量与 `AppDelegate.m`） |
| 隐藏功能 | `QiHiddenAdPanel` 隐藏广告面板（宏开关 `HIDDEN_AD_PANEL_ENABLED` 控制，见「开发说明」） |

## 目录结构

```
QiGames/
├── QiGames.xcodeproj/            # Xcode 工程（内含 SPM 依赖声明与 Package.resolved 版本锁文件）
├── QiGames/
│   ├── AppDelegate.h/m           # 应用入口（启动时 sleep 2 秒模拟启动图；代码加载 QiDraw 游戏页为根控制器）
│   ├── main.m
│   ├── Info.plist                # 权限声明（麦克风/语音识别/ATT/位置/SKAdNetwork）
│   ├── Tools.h/m                 # 公共工具（中文数字转阿拉伯数字等）
│   ├── QiSpeechManager.h/m       # 语音识别管理（当前未被启用）
│   ├── QiAdManager.h/m           # 广告管理抽象层（激励视频/插屏，已接入 AdMob v11.7.0 真实 SDK）
│   ├── QiHiddenAdPanel.h/m       # 隐藏广告面板（触发/加载/播放/倒计时刷新）
│   ├── QiDraw/
│   │   ├── QiDrawViewController.h/m    # 游戏：默契猜词
│   │   └── QiGuessWords.h/m            # 随机词库（小学/初中/高中/复杂/自定义）
│   ├── Base.lproj/
│   │   ├── QiDraw.storyboard           # 游戏界面（打开 App 直接进入）
│   │   └── LaunchScreen.storyboard     # 启动页
│   └── Assets.xcassets/                # App 图标、成功/失败图片资源
├── docs/
│   └── iOS移动应用科技发行对接方案(1).txt  # 变现/广告发行对接方案 v1.0.0
├── README.md                      # 使用说明 + 开发说明（本文档）
├── fix.md                         # 科技发行对接整改追踪清单（FIX-01~FIX-05）
├── LICENSE                        # 开源许可证
├── reasonix.toml                  # Reasonix 工具在本仓库的配置
└── .reasonix/                     # Reasonix 会话运行数据（工具自动生成，与 App 无关）
```

### 目录与文件详解

#### 根目录

| 文件/目录 | 作用 |
| --- | --- |
| `QiGames.xcodeproj/` | Xcode 工程本体。核心是 `project.pbxproj`（工程与编译配置、文件引用、Build Phases、SPM 依赖声明），另外 `project.xcworkspace/xcshareddata/swiftpm/Package.resolved` 锁定 SPM 依赖版本（GoogleMobileAds 11.7.0 / GoogleUserMessagingPlatform 2.7.0）。日常开发打开此工程即可 |
| `QiGames/` | App 全部源代码与资源，详见下节 |
| `README.md` | 使用说明与开发说明（即本文档） |
| `fix.md` | 科技发行对接整改追踪清单（FIX-01~FIX-05），逐项记录「未满足项 → 整改要求 → 整改结果」 |
| `docs/` | 对接方案文档目录，内含《iOS 移动应用科技发行对接方案 v1.0.0》（`fix.md` 的整改依据） |
| `LICENSE` | 开源许可证文件 |
| `reasonix.toml` | Reasonix 工具在本仓库的配置 |
| `.reasonix/` | Reasonix 工具运行时的会话 / 任务状态数据，与 App 本身无关，可忽略 |

#### 入口与基础（QiGames/ 根目录）

| 文件 | 作用 |
| --- | --- |
| `main.m` | 程序入口 `main()`，创建 `UIApplication` 并加载 `AppDelegate` |
| `AppDelegate.h/m` | 应用生命周期代理。`didFinishLaunching` 中 `sleep 2 秒` 延长启动图展示（旧写法，建议后续优化移除）；从 `QiDraw.storyboard` 实例化 `QiDrawViewController` 包入 `UINavigationController` 并设为 `window.rootViewController`（打开 App 直接进入游戏页，无首页） |
| `Info.plist` | App 配置：Bundle ID、版本号、`GADApplicationIdentifier`、权限声明（麦克风 / 语音识别 / ATT / 位置）、`SKAdNetworkItems` 等 |
| `Tools.h/m` | 公共工具方法（如中文数字转阿拉伯数字等） |
| `QiSpeechManager.h/m` | 语音识别管理（`SFSpeechRecognizer` + `AVAudioEngine`），已实现但当前未启用 |

#### 广告模块

| 文件 | 作用 |
| --- | --- |
| `QiAdManager.h/m` | 广告管理抽象层：统一封装激励视频（`QiAdTypeRewarded`）与插屏（`QiAdTypeInterstitial`）的 `loadAdOfType:completion:` / `showAdOfType:completion:`。当前为 AdMob 真实实现（`GADRewardedAd` / `GADInterstitialAd`）；广告位 ID 集中定义在 `QiAdManager.m` 顶部常量，正式 ID 到手后仅需替换此处 |
| `QiHiddenAdPanel.h/m` | 隐藏广告面板：以 `UIView` overlay 覆盖 `keyWindow`，含 Rewarded Video / Interstitial 两个广告位按钮与关闭按钮。初次打开自动加载全部广告，加载成功高亮、失败置灰；点击按钮后置灰 → 播放 → 自动拉取 → 随机 5–10 秒倒计时刷新按钮状态；弹出后不弹 Toast / 弹窗 |

#### 游戏

| 文件 | 作用 |
| --- | --- |
| `QiDraw/QiDrawViewController.h/m` | 游戏「默契猜词」：随机词条展示、默认 360 秒倒计时（最后 30 秒变红）、成功 / 失败计数并自动换词 |
| `QiDraw/QiGuessWords.h/m` | 游戏词库：随机词条（小学 / 初中 / 高中 / 复杂 / 自定义分类） |

#### 界面与资源

| 文件/目录 | 作用 |
| --- | --- |
| `Base.lproj/QiDraw.storyboard` | 游戏界面（打开 App 直接进入） |
| `Base.lproj/LaunchScreen.storyboard` | 启动页 |
| `Assets.xcassets/` | 图片资源目录：`AppIcon.appiconset`（各尺寸 App 图标 + App Store 1024 图标）、`success.imageset`（成功图标）、`false.imageset`（失败图标） |

## 使用说明

### 环境准备

- macOS 上安装 Xcode（工程构建验证于 Xcode 15.2 完成；本机当前 AdMob 锁定 **v11.7.0**，Xcode 15.2 可编译但**完整链接需 Xcode 16（iOS 18 SDK）及以上**，见「开发环境」）。
- 首次打开工程时 Xcode 会自动解析 SPM 依赖（需能访问 `github.com` 与 `dl.google.com`），解析结果写入 `QiGames.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`（已随仓库提交，本机锁定 11.7.0 / 2.7.0）。
- 真机运行需登录 Apple ID 并在 `Signing & Capabilities` 中配置开发团队与签名。

### 安装与运行

1. 使用 Xcode 打开 `QiGames.xcodeproj`。
2. 选择 Scheme `QiGames` 与目标设备（模拟器或真机）。
3. 真机运行：在 Target `QiGames` → `Signing & Capabilities` 中配置开发团队与签名。
4. `⌘R` 运行。

工程结构说明：无首页，应用启动后由 `AppDelegate` 从 `QiDraw.storyboard` 实例化 `QiDrawViewController`，包入 `UINavigationController` 直接展示「默契猜词」游戏页面。

### 各游戏玩法

#### 默契猜词（QiDrawViewController）
- 点「开始」显示随机词条，默认 360 秒倒计时（最后 30 秒数字变红）。
- 主持人看词条比划/描述，参与者猜词；猜对点「成功」、猜错或跳过点「失败」，自动切换下一词并累计计数。
- 倒计时归零后自动停止，禁用「成功 / 失败」按钮。

## 开发说明

### 开发环境

| 项目 | 要求 |
| --- | --- |
| Xcode | 本机 Intel Mac + Xcode 15.2：AdMob 锁定 **11.3.0**（本机可链接）/ 交付 **11.7.0**（可编译 + 模拟器运行，完整链接需 16.0 及以上）；**Chartboost 9.14.0 完整链接需 Xcode 26（iOS 26 SDK）**——其二进制由 Xcode 26 / Swift 6.2 构建，链接依赖 `swiftSynchronization` / `swiftXPC` 等 Swift 6.2 back-deployment 库，Xcode 16 及以下无法链接（工程源码本身 Xcode 15.2 可编译，链接阶段报 Undefined symbols 属工具链限制非代码问题）；交付打包建议 GitHub Actions 云打包选用 Xcode 26 runner |
| macOS | 支持 Xcode 16 的 macOS 版本（Apple Silicon）；Intel Mac 最高可用 Xcode 15.x，仅能完成编译无法完成 AdMob 链接 |
| 最低部署目标 | iOS 15.0（`IPHONEOS_DEPLOYMENT_TARGET`） |
| 架构 | arm64（真机）；Intel Mac 模拟器自动构建 x86_64（工程 `VALID_ARCHS = "arm64 x86_64"`） |

### 常用构建命令

查看 scheme 与构建配置：

```bash
xcodebuild -project QiGames.xcodeproj -list
xcodebuild -project QiGames.xcodeproj -scheme QiGames -showBuildSettings | grep -E "IPHONEOS_DEPLOYMENT_TARGET|ARCHS|VALID_ARCHS"
```

解析 / 更新 SPM 依赖（首次构建会自动执行；网络需可访问 `github.com`）：

```bash
xcodebuild -project QiGames.xcodeproj -scheme QiGames -resolvePackageDependencies
```

模拟器 Debug 构建（工程 `VALID_ARCHS = "arm64 x86_64"`，Intel Mac 模拟器自动产出 x86_64，无需覆盖架构；DerivedData 放到可写目录）：

```bash
xcodebuild -project QiGames.xcodeproj \
  -scheme QiGames -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -derivedDataPath /tmp/QiGamesDerivedDataX86 \
  build CODE_SIGNING_ALLOWED=NO
```

Info.plist 校验：

```bash
plutil -lint QiGames/Info.plist
```

### 模拟器安装与隐藏广告面板验证

隐藏广告面板触发文本为 `show**show**show`（插件通过根页面 `QiDrawViewController` 上的 1px×1px `UITextField.text` 赋值触发）。DEBUG 构建支持启动参数 `-qiSimulateAdPanelTrigger` 模拟插件赋值，便于自动化验证：

```bash
xcrun simctl boot <设备UDID>
xcrun simctl install <设备UDID> /tmp/QiGamesDerivedDataX86/Build/Products/Debug-iphonesimulator/QiGames.app
xcrun simctl launch <设备UDID> com.qishare.ios.hxs -qiSimulateAdPanelTrigger
```

预期链路日志（DEBUG 构建）：`[QiHiddenAdPanel] trigger matched, showing panel` → `show` → `type=0 loaded=1` → `type=1 loaded=1`。

### 架构说明

- **第三方依赖**：通过 Swift Package Manager 接入 AdMob `GoogleMobileAds` v11.7.0（交付目标版本，`exactVersion` 已锁定；本机 Xcode 15.2 可编译，完整链接需 Xcode 16 / iOS 18 SDK，含 `GoogleUserMessagingPlatform` v2.7.0 依赖）；版本以 `exactVersion` 锁定在 `project.pbxproj`，并随 `Package.resolved` 提交。
- **广告抽象层 `QiAdManager`**：统一封装激励视频（`QiAdTypeRewarded`）与插屏（`QiAdTypeInterstitial`）的 `loadAdOfType:completion:` / `showAdOfType:completion:`。已接入 AdMob 真实实现（`GADRewardedAd` / `GADInterstitialAd`，播放关闭后自动重新拉取）；广告位 ID 集中定义于 `QiAdManager.m` 顶部常量与 `Info.plist` 的 `GADApplicationIdentifier`，正式 ID 到手后仅需替换两处。
- **隐藏广告面板 `QiHiddenAdPanel`**：以 `UIView` overlay 覆盖当前 `keyWindow`，弹出后不弹 Toast / 弹窗；按钮状态与倒计时反馈全部收敛在按钮文案中。点击广告位按钮后置灰 → 播放 → 自动拉取 → 随机 5-10 秒倒计时 → 按结果恢复高亮 / 置灰。
- **隐藏面板开关**：`QiDrawViewController.m` 中 `HIDDEN_AD_PANEL_ENABLED` 宏（`#ifndef` 定义，默认 =1）。交付科技发行的 IPA 保留 =1（含面板功能与唤起逻辑）；线上公开版本置 0 去除面板功能，确保审核合规。
- **语音识别 `QiSpeechManager`**：基于 `SFSpeechRecognizer` + `AVAudioEngine` 的中文语音识别，已实现但当前未被任何游戏启用。

### 代码规范

- 所有方法均有方法级注释，统一使用 Xcode / Doxygen 风格，说明作用、入参、出参：

```objc
/**
 *  方法作用说明。
 *
 *  @param xxx 入参说明。
 *  @return 出参说明（无返回值时写「无」）。
 */
- (void)someMethod:(NSString *)param;
```

- 属性行内说明使用 `//!<` 注释；枚举值、宏开关等就近注释。
- 调试日志使用 `#if DEBUG` 包裹的 `NSLog`，Release 构建不输出。
- 文件头只保留文件名说明，不包含 Created / Copyright 注释。

### 整改追踪（fix.md）

科技发行对接方案（`docs/iOS移动应用科技发行对接方案(1).txt` v1.0.0）整改状态摘要：

| 编号 | 事项 | 状态 | 备注 |
| --- | --- | --- | --- |
| FIX-01 | 最低系统版本提升至 iOS 15.0，移除 armv7 | ✅ 已完成 | 真机全系回归待交付前执行 |
| FIX-02 | 集成广告 SDK 与广告位（激励视频 / 插屏） | ✅ 已完成 | AdMob（SPM）已接入，`QiAdManager` 为真实实现；当前为 Google 测试 ID，正式 ID 待确认替换；SPM 已锁定 **11.7.0**（交付目标），本机 Xcode 15.2 可编译，**完整链接需 Xcode 16 环境构建** |
| FIX-03 | 实现隐藏广告面板（触发 / UI / 加载 / 倒计时逻辑） | ✅ 已完成 | 广告加载/播放已接真实 AdMob；面板样式已按方案示例图校准（2026-08-26：左右两栏，左蓝 Rewarded / 右红 Interstitial，平台行 AdMob，底部小字位待定） |
| FIX-04 | 补齐数据权限声明（ATT / Location / SKAdNetwork） | ✅ 已完成 | SKAdNetwork 已补全 AdMob 全量 42 个 ID；其他平台 ID 待新增平台时补齐 |
| FIX-05 | 白包 / 账号合规配置（三网 / 三邮箱 / app-ads.txt） | ☐ 待办 | 运营侧配置 |

详细整改要求、已完成项与待办见 `fix.md`。

### 发布与合规注意事项

- 上架提审时在 App Store Connect 数据权限部分勾选 Location 与 Identifiers，用途注明「广告和营销」。
- `Info.plist` 的 `GADApplicationIdentifier` 与 `SKAdNetworkItems`（AdMob 全量 42 个 ID）已配置；**当前为 Google 官方测试 App ID**（`ca-app-pub-3940256099942544~1458002511`），正式 App ID 到手后必须替换（含 `QiAdManager.m` 内三个广告位 ID：激励 / 插屏 / 开屏）。
- 交付 IPA 与线上版本必须保持 SDK 版本（交付目标 AdMob 11.7.0，已锁定；完整链接需 Xcode 16 环境）与广告位 ID 一致。
- 白包上架需准备三网（营销 / 技术支持 / 隐私政策）唯一网址、独立三邮箱，并提供营销网址下 `app-ads.txt` 管理权限。

## 已知事项与注意事项

- `AppDelegate` 中 `[NSThread sleepForTimeInterval:2.0]` 会阻塞主线程 2 秒，属于延长启动图的旧写法，如需优化建议移除。
- `Info.plist` 已声明麦克风（`NSMicrophoneUsageDescription`）与语音识别（`NSSpeechRecognitionUsageDescription`）权限，语音相关功能当前未启用。
- 隐藏广告面板样式已按方案示例图校准（2026-08-26：左右两栏，左蓝 Rewarded Video / 右红 Interstitial，栏内平台行 AdMob，右上角 ✕ 关闭，底部灰分隔线 + 小字位内容待定；详见 `fix.md` FIX-03）。
- 全项目已添加方法级代码注释（作用 / 入参 / 出参），修改方法时请同步维护对应注释。
