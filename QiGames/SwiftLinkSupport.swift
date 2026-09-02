//
//  SwiftLinkSupport.swift
//  QiGames
//
//  此文件仅用于让 Xcode 以 Swift 兼容模式链接主 target，勿删除：
//  AdMob 11.x / ChartboostSDK / UnityAds 等 CocoaPods 静态库内含 Swift 代码，
//  纯 ObjC target（无任何 Swift 源文件）链接时会缺失
//  __swift_FORCE_LOAD_$_swiftCompatibility* / swift_getFunctionTypeMetadataGlobalActorBackDeploy
//  等符号导致 ld 失败。保留一个 Swift 源文件即可让链接器自动带上兼容库。
//

import Foundation
