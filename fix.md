# QiGames 科技发行对接整改清单（fix.md）

> 依据《iOS 移动应用科技发行对接方案 v1.0.0》（`docs/iOS移动应用科技发行对接方案(1).txt`）逐项核对，以下为当前工程**未满足项**及对应整改要求。整改完成后逐项勾选并更新状态。

## 一、未满足项与整改要求

### 1. 最低系统版本不达标（方案第三节「包体兼容性」）— ✅ 已整改
- **要求**：最低支持 iOS 15.0，向上完美适配 iOS 15.0 以上所有版本，无崩溃或显示异常。
- **现状（整改前）**：`IPHONEOS_DEPLOYMENT_TARGET` 为 11.0 / 12.0（工程配置 4 处）；`Info.plist` 的 `UIRequiredDeviceCapabilities` 仍要求 `armv7`（32 位，iOS 15 起已无 32 位设备）。
- **整改（已完成）**：
  - [x] 将 `IPHONEOS_DEPLOYMENT_TARGET` 提升至 15.0（Project 级 Debug/Release、Target 级 Debug/Release 共 4 处，见 `QiGames.xcodeproj/project.pbxproj`）
  - [x] 移除 `Info.plist` `UIRequiredDeviceCapabilities` 中的 `armv7`，仅保留 `arm64`；同时在 Target 级 Debug/Release 显式设置 `VALID_ARCHS = "arm64 x86_64"`，确保只构建 64 位（2026-08-25 调整：原 `arm64` 会过滤掉 x86_64，导致 Intel Mac 模拟器无法安装运行，现加入 `x86_64`；真机构建仍仅产出 arm64）
  - [x] 验证：`xcodebuild -showBuildSettings` 确认 `IPHONEOS_DEPLOYMENT_TARGET = 15.0`、`ARCHS = arm64`、`VALID_ARCHS = arm64`；模拟器 Debug 构建 `** BUILD SUCCEEDED **`（编译目标 `arm64-apple-ios15.0-simulator`，storyboard 按 `--minimum-deployment-target 15.0` 链接）
  - [x] iOS 17.2 模拟器（iPhone 15）安装启动冒烟通过：App 正常启动渲染，8 秒后进程存活无崩溃（截图 `/tmp/qigames_smoke.png`）
  - [ ] **真机全系回归验证**（iOS 15.0+ 多机型真机安装运行三个游戏，确认无崩溃、无显示异常）— 待交付前执行

### 2. 未集成任何广告 SDK（方案第五、六节「广告对接」）— ✅ 已整改
- **要求**：接入 AdMob / Meta / Liftoff 等平台（优先 admob、meta、Liftoff），激励视频（Rewarded Video）与插屏（Interstitial）各对接一个广告位 ID；AdMob SDK 版本 v11.7.0，其余平台可对接官网最新 SDK。
- **现状（整改前）**：工程无 Podfile / SPM / 任何第三方库，全工程无广告相关代码。
- **整改（已完成）**：
  - [x] 通过 Swift Package Manager 集成 AdMob（GoogleMobileAds）及依赖 GoogleUserMessagingPlatform v2.7.0（`QiGames.xcodeproj/project.pbxproj` 锁定 `exactVersion`，`Package.resolved` 已生成）
  - [x] **2026-08-25 版本调整（本机 Intel Mac + Xcode 15.2）**：交付目标 AdMob v11.7.0（需 Xcode 16 / iOS 18 SDK 链接），本机 Xcode 15.2 / iOS 17.2 SDK 无法链接（11.7.0 二进制引用 `MarketplaceKit` / `CoreAudioTypes` / `swiftXPC`，均为 iOS 18 SDK 符号）；已将 SPM 锁定版本**降级为 v11.3.0**（`project.pbxproj` `exactVersion 11.3.0`，`Package.resolved` 同步，对应 commit `9ab66e38f5f0c2d02f2b024b1babd880130f19bf`）。**交付前须在 Xcode 16 环境将版本升回 v11.7.0 并完整回归**（SDK 版本与交付 IPA / 线上版本保持一致）
  - [x] `QiAdManager` stub 替换为真实 AdMob 加载 / 播放实现（`GADRewardedAd` / `GADInterstitialAd`，播放完成自动重新拉取），上层面板接口保持不变
  - [x] `Info.plist` 配置 `GADApplicationIdentifier`（当前为 Google 官方测试 App ID）+ 补全 AdMob 全量 `SKAdNetworkItems`（42 个 ID）
  - [x] `AppDelegate` 启动时初始化 `GADMobileAds`
  - [x] **2026-08-26 新增开屏广告（App Open Ad）**：`QiAdManager` 增加 `loadAppOpenAdWithCompletion:` / `showAppOpenAdIfAvailable`（无广告时自动重新加载，加载完成时前台则立即展示，`_appOpenAdLoading` / `_appOpenAdPresenting` 防重入防重复）；`AppDelegate` 在 `applicationDidBecomeActive:` 统一触发（冷启动 + 热启动均展示），SDK 初始化完成后兜底触发；测试 ID `ca-app-pub-3940256099942544/9257395921`；验证：模拟器冷启动仅一次 `app open ad loaded` + `presenting app open ad`，全屏广告（IMA Test mode + 广告素材 + close 按钮）持续展示至用户关闭
  - [x] **移除开屏广告（App Open Ad）**：按需求删除 `QiAdManager` 的 `loadAppOpenAdWithCompletion:` / `showAppOpenAdIfAvailable` / `presentAppOpenAd` 及 `kQiAppOpenAdUnitID` / `appOpenAd*` 属性，清理 `GADFullScreenContentDelegate` 回调中的开屏分支；`AppDelegate` 删除 `applicationDidBecomeActive:` 触发及 SDK 初始化回调中的兜底调用。开屏测试 ID `ca-app-pub-3940256099942544/9257395921` 不再使用。激励视频 / 插屏逻辑不受影响
  - [ ] 正式广告位 ID 替换：当前使用 Google 官方测试 ID（激励 `ca-app-pub-3940256099942544/1712485313`、插屏 `ca-app-pub-3940256099942544/4411468910`、App ID `ca-app-pub-3940256099942544~1458002511`），待与我方确认正式 ID 后替换 `QiAdManager.m` 顶部常量与 `Info.plist`
  - [x] 验证（2026-08-25，本机降级后）：SPM 解析成功（`GoogleMobileAds @ 11.3.0`、`GoogleUserMessagingPlatform @ 2.7.0`）；`otool`/`nm` 确认 11.3.0 模拟器二进制**无** `MarketplaceKit` / `swiftXPC` / `CoreAudioTypes` 未定义引用；全部 13 个源文件用 Xcode 15.2 工具链（iOS 17.2 模拟器 SDK）编译并链接 11.3.0 成功（无 Undefined symbols，仅既有 nullability 警告）
  - [x] 复核（2026-08-25，本会话）：再次 `resolvePackageDependencies` 成功（11.3.0 / 2.7.0）；`QiAdManager.m` / `AppDelegate.m` 对 11.3.0 真实头文件编译检查 0 错误 0 警告；**模拟器 Debug（x86_64）与真机 Release（arm64）双构建均 `BUILD SUCCEEDED`**，app 二进制内静态链接 GAD 符号，产物 SDK 版本经 `plutil` 确认 `GoogleMobileAds 11.3.0` + `UserMessagingPlatform 2.7.0`
  - [x] **2026-08-28 升级回 v11.7.0（交付目标版本）**：`project.pbxproj` `exactVersion 11.3.0 → 11.7.0`，重新 `resolvePackageDependencies` 成功（`GoogleMobileAds @ 11.7.0`、`GoogleUserMessagingPlatform @ 2.7.0`），`Package.resolved` 同步（GAM commit `6457f9651bea0d62a548ac63fa9d34aae7d0488e`）；`QiAdManager.m` / `AppDelegate.m` 对 11.7.0 头文件语法检查 0 错误；模拟器 Debug 构建编译全部通过，**链接阶段报 `MarketplaceKit` / `CoreAudioTypes` / `swiftXPC`（iOS 18 SDK 框架）undefined**（本机 Xcode 15.2 / iOS 17.2 SDK 限制，与 skill 第 4 节记录一致，非代码问题）——完整链接构建 + 真机回归待 Xcode 16 环境
  - [ ] 交付前回归（Xcode 16 环境）：**SPM 已锁定 v11.7.0**，完整链接构建 + 真机全系回归 + 模拟器验证，确认交付 IPA 与线上版本 SDK 一致

### 3. 隐藏广告面板未实现（方案第六节「广告面板」）— ✅ 已整改
- **要求**：
  - 首页包含 `UITextField`（为适配插件，首页尽可能只放一个；游戏类首页无法放置时可在不影响主体功能的位置增加 1px×1px 控件），插件自动赋值 `show**show**show`
  - 首页视图渲染完成，延时 5-10 秒后判断文本框内容，若等于 `show**show**show` 则显示隐藏广告面板
  - 面板初次打开自动加载全部平台广告，加载完成对应按钮高亮，失败或暂无广告置灰
  - 点击 Rewarded Video 重新加载所有激励视频广告，点击后置灰、随机 5-10 秒倒计时后恢复高亮；高亮可点击、置灰不可点击
  - 点击 Interstitial 按激励视频刷新逻辑处理插屏广告
  - 点击广告位按钮后播放对应广告，播放完成自动重新拉取并更新按钮高亮 / 置灰
  - 面板弹出后 APP 不能弹出 Toast 和弹窗
  - 面板样式必须按方案示例图规则实现，不得使用其他样式
- **现状（整改前）**：`Main.storyboard` 无任何 `UITextField`，首页 `ViewController` 为空实现，无面板 UI、无触发逻辑、无加载 / 刷新逻辑，整块功能不存在。
- **整改（已完成）**：
  - [x] 首页 `QiDrawViewController` 代码创建 1px×1px `UITextField`（首页仅此一个），不干扰主体功能
  - [x] 首页 `viewDidAppear` 渲染完成后延时随机 5-10 秒，判断 `UITextField.text == "show**show**show"`，命中则弹出隐藏广告面板
  - [x] 新建 `QiGames/QiHiddenAdPanel.h/.m`：实现面板 UI（Rewarded Video / Interstitial 按钮 + 关闭按钮），初次打开自动加载全部平台广告，加载完成对应按钮高亮、失败 / 暂无广告置灰
  - [x] 新建 `QiGames/QiAdManager.h/.m`：广告加载 / 播放管理抽象层（已接入真实 AdMob，见 FIX-02）；实现「点击按钮 → 置灰 → 播放广告 → 播放完成自动拉取 → 随机 5-10 秒倒计时刷新按钮状态（高亮 / 置灰）」逻辑
  - [x] 面板弹出后不弹 Toast / 弹窗（倒计时反馈收敛在按钮文案中，无任何 UIAlert / 弹窗调用）
  - [x] 线上 / 交付版本策略：`QiDraw/QiDrawViewController.m` 中 `HIDDEN_AD_PANEL_ENABLED` 宏开关（默认 =1，交付 IPA 含面板功能与唤起逻辑；线上公开版本置 0 即可去除，确保审核合规）
  - [x] 面板样式按方案「示例图」校准（2026-08-26 获取示例图后按图实现）：左右两栏布局——左栏（蓝）标题 Rewarded Video + 平台行 AdMob，右栏（红）标题 Interstitial + 平台行 AdMob；右上角 ✕ 关闭；底部灰色分隔线下保留一行小字位（内容待定）；仅接入 AdMob 故每栏只列 AdMob 一项，未接入平台不展示
  - [x] 验证：模拟器 Debug 构建 `** BUILD SUCCEEDED **`；iOS 17.2 模拟器（iPhone 15 Pro）启动参数模拟插件赋值后，日志确认完整链路 `trigger matched → show → type=0 loaded=1 → type=1 loaded=1`，截图确认面板为新两栏样式（左蓝 Rewarded/AdMob、右红 Interstitial/AdMob，均高亮「点击播放」），无 Toast / 弹窗

### 4. 数据权限声明缺失（方案第四节「白包准备」）— ✅ 已整改
- **要求**：上架提审时数据权限选择大概位置（Location）和标识（Identifiers），用途为广告和营销。
- **现状（整改前）**：`Info.plist` 仅声明麦克风（`NSMicrophoneUsageDescription`）与语音识别（`NSSpeechRecognitionUsageDescription`）权限。
- **整改（已完成）**：
  - [x] 新增 `NSUserTrackingUsageDescription`（ATT 广告跟踪弹窗）：「为了向您提供更相关的广告内容，我们需要使用您的设备标识符，用于广告投放与营销。」
  - [x] 新增 `NSLocationWhenInUseUsageDescription`（大概位置权限）：「App 需要获取您的大概位置信息，用于广告投放与营销。」
  - [x] 新增 `SKAdNetworkItems` 广告归因配置：已补齐 Google AdMob 全量 42 个 `skadnetwork_id`（含基线 `cstr6suwn9.skadnetwork`；列表与 AdMob 官方文档一致，来源见 AdMob「Update your Info.plist」）
  - [ ] 其他变现平台（Meta / Liftoff 等）SKAdNetwork ID 补全：当前仅接入 AdMob，若后续新增平台按平台列表补齐（待 FIX-02 平台确认）
  - [ ] 上架提审时数据权限部分勾选 Location 与 Identifiers，用途注明广告和营销（App Store Connect 提审操作，待上架时执行）
  - [x] 验证：`plutil -lint QiGames/Info.plist` 通过，三个键值均正确写入；模拟器 Debug 构建 `** BUILD SUCCEEDED **`

### 5. 白包 / 账号合规配置缺失（方案第二、四节）
- **要求**：
  - 营销网址、技术支持网址、隐私政策网址三网唯一，严禁跨产品复用；营销网址网站内容需与开发者名下其他产品不同
  - 独立的人名 / support / contact 三个邮箱（不得与其他包体共用；人名邮箱在注册变现平台时作为开发者邮箱）
  - 提供营销网址下 `app-ads.txt` 的编辑权限，或运营期间配合实时同步更新
  - 白包上架后提交对接数据：产品名、bundle ID、Apple ID、开发者名称、App Store 商品页 URL、ads 对接入口、三邮箱登录地址 / 用户名 / 密码
- **现状**：仓库内无任何对应产物（无隐私政策文件、无网址 / 邮箱 / app-ads.txt 配置），属运营 / 账号侧配置。
- **整改**：
  - [ ] 准备营销网址、技术支持网址、隐私政策网址（三网唯一、内容独立）
  - [ ] 准备独立的人名 / support / contact 三个企业邮箱
  - [ ] 营销网址下配置 `app-ads.txt` 并提供管理入口
  - [ ] 白包上架后整理并提交对接信息（产品名 / bundle ID / Apple ID / 开发者名称 / 商品页 URL / 三邮箱凭证）

## 二、整改状态跟踪

| 编号 | 事项 | 优先级 | 状态 | 备注 |
| --- | --- | --- | --- | --- |
| FIX-01 | 最低系统版本提升至 iOS 15.0，移除 armv7 | 高 | ✅ 已完成 | 编译 + iOS 17.2 模拟器冒烟通过；真机全系回归待交付前执行 |
| FIX-02 | 集成广告 SDK 与广告位（激励视频 / 插屏） | 高 | ✅ 已完成 | AdMob（SPM）已接入，`QiAdManager` 为真实实现；当前为 Google 测试 ID，正式 ID 待确认替换；**SPM 已锁定 11.7.0（交付目标版本）**，本机 Xcode 15.2 可编译，完整链接需 Xcode 16 环境构建（待交付前回归） |
| FIX-03 | 实现隐藏广告面板（触发 / UI / 加载 / 倒计时逻辑） | 高 | ✅ 已完成 | 广告加载/播放已接真实 AdMob；面板样式已按方案示例图校准（2026-08-26：左右两栏，左蓝 Rewarded / 右红 Interstitial，平台行 AdMob，底部小字位待定） |
| FIX-04 | 补齐数据权限声明（ATT / Location / SKAdNetwork） | 中 | ✅ 已完成 | SKAdNetwork 已补全 AdMob 全量 42 个 ID；其他平台 ID 待新增平台时补齐；上架勾选待提审执行 |
| FIX-05 | 白包 / 账号合规配置（三网 / 三邮箱 / app-ads.txt） | 中 | ☐ 待办 | 运营侧配置 |

> 注：对接的 SDK 与广告位代码等信息，线上版本与交付 IPA 版本必须保持一致。
