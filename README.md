# QiGames

本仓库用来存储 iOS 团建小游戏。当前包含 1 个游戏：默契猜词（QiDraw），并已按科技发行对接需求接入广告 SDK（激励视频 / 插屏，通过隐藏广告面板展示与验证）。

## 工程信息

| 项目 | 说明 |
| --- | --- |
| 工程文件 | `QiGames.xcodeproj`；日常开发请打开 `QiGames.xcworkspace`（CocoaPods 生成，含 `QiGames.xcodeproj` + `Pods/Pods.xcodeproj`） |
| Target | `QiGames` |
| 开发语言 | Objective-C |
| 最低系统版本 | iOS 15.0（`IPHONEOS_DEPLOYMENT_TARGET`，Debug / Release 均为 15.0） |
| 支持架构 | arm64（真机）；x86_64（Intel Mac 模拟器，`VALID_ARCHS = "arm64 x86_64"`） |
| 界面方式 | Storyboard（`QiDraw.storyboard` + `LaunchScreen.storyboard`） |
| 依赖管理 | CocoaPods：`Google-Mobile-Ads-SDK`（= 11.7.0 精确锁定）、`FBAudienceNetwork`、`VungleSDK-iOS`、`ChartboostSDK`、`InMobiSDK`、`UnityAds`；各依赖（含传递依赖）版本以 `Podfile.lock` 锁定，`Pods/` 不入库 |
| Bundle ID | `com.qishare.ios.hxs` |
| 版本号 | `CFBundleShortVersionString` = 1.0，`CFBundleVersion` = 1 |
| 广告模块 | `QiAdManager`（AdMob 真实实现：激励视频 / 插屏加载 / 播放 / 播完自动重拉）+ `QiHiddenAdPanel` 隐藏广告面板（Rewarded / Interstitial 两栏，每栏 AdMob / Meta / Vungle / Chartboost / InMobi / Unity Ads 六平台行；当前仅 AdMob 真接入，其余五平台为占位「未接入」） |
| 广告位 ID | 当前使用 AdMob 官方测试 ID（App ID + 激励 + 插屏），正式 ID 到手后替换 `QiAdManager.m` 顶部常量与 `Info.plist` 的 `GADApplicationIdentifier` |

## 目录结构

```
QiGames/
├── QiGames.xcodeproj/            # Xcode 工程（CocoaPods 已集成）
├── QiGames.xcworkspace/          # CocoaPods 工作区（日常打开此项）
├── Podfile / Podfile.lock        # CocoaPods 依赖声明与版本锁定（入库）
├── QiGames/
│   ├── AppDelegate.h/m           # 应用入口：游戏页为根控制器 + AdMob/ATT/UMP 初始化
│   ├── main.m
│   ├── Info.plist                # GADApplicationIdentifier、SKAdNetworkItems、ATT、麦克风/语音权限
│   ├── QiAdManager.h/m           # 广告抽象层（AdMob 真实实现：激励视频 / 插屏）
│   ├── QiHiddenAdPanel.h/m       # 隐藏广告面板（六平台展示：AdMob 真接入 + 五平台占位）
│   ├── QiSpeechManager.h/m       # 语音识别管理（当前未被启用）
│   ├── QiDraw/
│   │   ├── QiDrawViewController.h/m    # 游戏：默契猜词（含隐藏面板触发逻辑）
│   │   └── QiGuessWords.h/m            # 随机词库（小学/初中/高中/复杂/自定义）
│   ├── Base.lproj/
│   │   ├── QiDraw.storyboard           # 游戏界面（打开 App 直接进入）
│   │   └── LaunchScreen.storyboard     # 启动页
│   └── Assets.xcassets/                # App 图标、成功/失败图片资源
├── README.md                      # 使用说明 + 开发说明（本文档）
├── LICENSE                        # 开源许可证
├── reasonix.toml                  # Reasonix 工具在本仓库的配置（git 忽略）
└── .reasonix/                     # Reasonix 会话运行数据（工具自动生成，与 App 无关）
```

### 目录与文件详解

| 文件/目录 | 作用 |
| --- | --- |
| `QiGames.xcodeproj/` | Xcode 工程本体。`project.pbxproj` 已由 CocoaPods 集成（Pods xcconfig 引用、Pods 脚本 phase），并注册广告模块源文件 |
| `QiGames.xcworkspace/` | CocoaPods 生成的顶层工作区，引用 `QiGames.xcodeproj` 与 `Pods/Pods.xcodeproj`；构建 / 打开工程均使用它 |
| `Podfile` | 六家广告平台依赖声明（`Google-Mobile-Ads-SDK` 以 `= 11.7.0` 精确锁定，其余取最新稳定版） |
| `Podfile.lock` | 锁定全部依赖（含传递依赖）精确版本，CI / 新环境据此复现 |
| `Pods/` | CocoaPods 依赖本体（git 忽略，不入库；约数百 MB） |
| `QiGames/` | App 全部源代码与资源 |

#### 入口与基础（QiGames/ 根目录）

| 文件 | 作用 |
| --- | --- |
| `main.m` | 程序入口 `main()`，创建 `UIApplication` 并加载 `AppDelegate` |
| `AppDelegate.h/m` | 应用生命周期代理。`didFinishLaunching` 中从 `QiDraw.storyboard` 实例化 `QiDrawViewController` 包入 `UINavigationController` 设为根控制器；随后请求 ATT（iOS 14+）并初始化 AdMob（`GADMobileAds`），再走 UMP 同意流（GDPR / EEA + UK + Brazil） |
| `Info.plist` | App 配置：Bundle ID、版本号、`GADApplicationIdentifier`（当前为 Google 测试 App ID）、`SKAdNetworkItems`（AdMob 全量 ID）、ATT 文案、麦克风 / 语音识别权限 |
| `QiSpeechManager.h/m` | 语音识别管理（`SFSpeechRecognizer` + `AVAudioEngine`），已实现但当前未启用 |

#### 广告模块

| 文件 | 作用 |
| --- | --- |
| `QiAdManager.h/m` | 广告抽象层：`QiAdType`（激励视频 / 插屏）+ `QiAdPlatform`（六平台枚举）。当前为 **AdMob 真实实现**（pod `Google-Mobile-Ads-SDK 11.7.0`）：`loadAdOfType:completion:` / `showAdOfType:completion:` / `isAdReadyOfType:`，播放/展示失败后自动重拉；广告位 ID 集中定义在 `QiAdManager.m` 顶部常量 |
| `QiHiddenAdPanel.h/m` | 隐藏广告面板：`UIView` overlay 覆盖 `keyWindow`，左右两栏（蓝 Rewarded Video / 红 Interstitial）× 六平台行。AdMob 行自动加载 → 高亮可点 → 播放 → 播完重拉 → 随机 5–10 秒倒计时刷新；Meta / Vungle / Chartboost / InMobi / Unity Ads 行为占位「未接入」灰态（待平台 ID 与适配） |

#### 游戏

| 文件 | 作用 |
| --- | --- |
| `QiDraw/QiDrawViewController.h/m` | 游戏「默契猜词」：随机词条展示、计时、成功 / 失败计数并自动换词；另含隐藏面板触发逻辑（宏 `HIDDEN_AD_PANEL_ENABLED` 控制，1px 文本框赋值 `show**show**show` 触发、DEBUG 五连点 / `-qiSimulateAdPanelTrigger` 模拟） |
| `QiDraw/QiGuessWords.h/m` | 游戏词库：随机词条（小学 / 初中 / 高中 / 复杂 / 自定义分类） |

#### 界面与资源

| 文件/目录 | 作用 |
| --- | --- |
| `Base.lproj/QiDraw.storyboard` | 游戏界面（打开 App 直接进入） |
| `Base.lproj/LaunchScreen.storyboard` | 启动页 |
| `Assets.xcassets/` | App 图标、成功 / 失败图片资源 |

## 使用说明

### 环境准备

- macOS 上安装 Xcode；本机 Xcode 15.2 可完成**编译**，**完整链接需新版 Xcode**（Google-Mobile-Ads-SDK 11.7.0 需 iOS 18 SDK；ChartboostSDK / UnityAds 由新版工具链构建，见「开发说明」）。
- CocoaPods：`pod --version`（≥ 1.9）。依赖下载需能访问 `cdn.cocoapods.org` 与各 SDK 二进制源；国内网络经代理（如 Clash 端口 7897）：
  ```bash
  export LANG=en_US.UTF-8
  export http_proxy=http://127.0.0.1:7897 https_proxy=http://127.0.0.1:7897 all_proxy=http://127.0.0.1:7897
  cd <工程根目录> && pod install
  ```
- 真机运行需登录 Apple ID 并在 `Signing & Capabilities` 中配置开发团队与签名。

### 安装与运行

1. `pod install`（首次或依赖变更后；`Podfile.lock` 已入库，CI / 新环境直接复现）。
2. 使用 Xcode 打开 **`QiGames.xcworkspace`**（不要单独打开 `.xcodeproj`）。
3. 选择 Scheme `QiGames` 与目标设备（模拟器或真机）。
4. `⌘R` 运行。

工程结构说明：无首页，应用启动后由 `AppDelegate` 从 `QiDraw.storyboard` 实例化 `QiDrawViewController`，包入 `UINavigationController` 直接展示「默契猜词」游戏页面。

### 各游戏玩法

#### 默契猜词（QiDrawViewController）
- 点「开始」显示随机词条，主持人看词条比划/描述，参与者猜词；猜对点「成功」、猜错或跳过点「失败」，自动切换下一词并累计计数。

## 开发说明

### 构建命令（注意使用 workspace）

```bash
xcodebuild -workspace QiGames.xcworkspace -scheme QiGames -list
xcodebuild -workspace QiGames.xcworkspace -scheme QiGames -showBuildSettings | grep -E "IPHONEOS_DEPLOYMENT_TARGET|ARCHS|VALID_ARCHS"
```

模拟器 Debug 构建：

```bash
xcodebuild -workspace QiGames.xcworkspace \
  -scheme QiGames -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/QiGamesDD \
  build CODE_SIGNING_ALLOWED=NO
```

配置校验：

```bash
plutil -lint QiGames/Info.plist
```

### 工具链限制与云打包

- 本机 Xcode 15.2（iOS 17.2 SDK）：工程与 pod **编译全部通过**，但完整链接会报未定义系统库 / 符号——`Google-Mobile-Ads-SDK 11.7.0`（引用 iOS 18 SDK 的 `MarketplaceKit` / `CoreAudioTypes` 等）、`ChartboostSDK 9.14.0`（`swiftSynchronization` / `swiftXPC`）、`UnityAds 4.20.0`（新版 Swift 6 符号）均需新版工具链。属工具链限制而非代码问题。
- 完整链接 / 打包请用新版 Xcode 环境：Apple Silicon 本机升级，或 GitHub Actions `macos-latest` 云打包（衔接全局 skill `github-ios-package`；`.github/workflows/package.yml` 已改为 `-workspace` + `pod install`）。

### 隐藏广告面板验证

面板触发文本 `show**show**show`（插件通过根页面 `QiDrawViewController` 上的 1px×1px `UITextField.text` 赋值触发）。DEBUG 构建支持启动参数 `-qiSimulateAdPanelTrigger` 与真机五连点触发。预期链路日志（DEBUG）：`[QiHiddenAdPanel] show` → AdMob 行 `type=0/1 loaded=1`；面板中 Meta / Vungle / Chartboost / InMobi / Unity Ads 行显示「未接入」灰态。

### 架构说明

- **依赖管理**：CocoaPods 引入六家广告平台（`Google-Mobile-Ads-SDK = 11.7.0` + 五家最新稳定版）；版本锁定于 `Podfile.lock`。`Pods/` 忽略入库，`Podfile / Podfile.lock / QiGames.xcworkspace` 入库。
- **广告抽象层 `QiAdManager`**：平台无关设计（`QiAdType` / 单例 / 加载回调），当前实现为 AdMob（`GADRewardedAd` / `GADInterstitialAd`）；`QiAdPlatform` 枚举承载六平台，为后续平台适配预留。广告位 ID 集中定义于 `QiAdManager.m` 顶部常量，`GADApplicationIdentifier` 在 `Info.plist`。
- **隐藏广告面板 `QiHiddenAdPanel`**：两栏（Rewarded Video / Interstitial）× 六平台行；AdMob 真接入（加载 → 高亮 → 播放 → 重拉 → 5-10 秒倒计时），五平台占位；弹出后不弹 Toast / 弹窗，反馈收敛在按钮文案。
- **面板触发开关**：`QiDrawViewController.m` 中 `HIDDEN_AD_PANEL_ENABLED` 宏（默认 1）。
- **语音识别 `QiSpeechManager`**：基于 `SFSpeechRecognizer` + `AVAudioEngine`，已实现但当前未启用。

### 代码规范

- 所有方法均有方法级注释，统一使用 Xcode / Doxygen 风格（作用 / 入参 / 出参）；属性行内注释用 `//!<`；枚举 / 宏就近注释。
- 调试日志使用 `#if DEBUG` 包裹的 `NSLog`，Release 构建不输出。
- 文件头只保留文件名说明。

## 已知事项与注意事项

- `Info.plist` 已声明麦克风与语音识别权限，语音功能当前未启用。
- 广告位当前为 **AdMob 官方测试 ID**（测试 App ID + 激励 / 插屏测试单元），演示广告带 "Test mode" 标签；正式交付前需替换为正式广告单元 ID（`QiAdManager.m` 顶部常量 + `Info.plist` `GADApplicationIdentifier`），并核对 ATT / SKAdNetwork 配置。
- Meta / Vungle / Chartboost / InMobi / Unity Ads 五个平台仅完成 pod SDK 引入，尚未配置平台 ID 与适配层，面板对应行显示「未接入」。
- 本机 Xcode 15.2 无法完整链接新版广告 SDK（见「工具链限制与云打包」），交付构建请在目标工具链环境执行。
