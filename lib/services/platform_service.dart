import 'dart:io';

/// 平台检测工具 — 集中管理所有平台判断逻辑
/// 避免在各处散落 Platform.isAndroid / Platform.isIOS
class PlatformService {
  PlatformService._();

  static bool get isAndroid => Platform.isAndroid;
  static bool get isIOS => Platform.isIOS;

  /// iOS 不支持系统闹钟，只能用本地通知替代
  static bool get supportsSystemAlarm => isAndroid;
}
