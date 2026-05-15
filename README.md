<p align="center">
  <img src="assets/images/wechat_qr.jpg" width="180" />
</p>

<h1 align="center">不忘课表</h1>

<p align="center">
  <strong>一款简洁好用的课表管理 App</strong>
</p>

<p align="center">
  <a href="https://github.com/psno/buwang-schedule/stargazers"><img alt="GitHub stars" src="https://img.shields.io/github/stars/psno/buwang-schedule.svg" /></a>
  <a href="https://github.com/psno/buwang-schedule/network/members"><img alt="GitHub forks" src="https://img.shields.io/github/forks/psno/buwang-schedule.svg" /></a>
  <img alt="Platform" src="https://img.shields.io/badge/platform-Android%20%7C%20iOS-lightgrey.svg" />
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.29-blue.svg" />
  <a href="LICENSE"><img alt="License" src="https://img.shields.io/badge/license-MIT--NC-green.svg" /></a>
</p>

<p align="center">
  <a href="#功能特性">功能特性</a> •
  <a href="#截图">截图</a> •
  <a href="#下载安装">下载安装</a> •
  <a href="#开发构建">开发构建</a> •
  <a href="#赞赏支持">赞赏支持</a> •
  <a href="#许可证">许可证</a>
</p>

---

## 功能特性

- 📋 **课表管理** — 支持手动录入和 AI 拍照识别导入课表
- 🔄 **日历同步** — 一键将整学期课程同步到系统日历，支持深度清理
- ⏰ **上课提醒** — 课前通知提醒，支持自定义提醒时间
- 👨‍🏫 **教师/学生模式** — 自动切换显示风格（教师看班级，学生看科目）
- 🏫 **高中/大学模式** — 支持单双周、多节连排、自定义时间段
- 🎨 **个性化主题** — 三套主题色 + 深色模式
- 📱 **跨平台** — Android & iOS 双端支持
- 🔒 **隐私安全** — 所有数据本地存储，无需联网登录

## 截图

> 欢迎提交 PR 补充截图

## 下载安装

### Android

**最新版本：[v1.4.4](https://github.com/psno/buwang-schedule/releases/tag/v1.4.4)**

前往 [Releases](https://github.com/psno/buwang-schedule/releases) 页面下载 APK。

### iOS

暂无签名版本，可通过源码自行构建（需要 macOS + Xcode）。

## 开发构建

### 环境要求

- Flutter >= 3.0.0
- Dart >= 3.0.0
- Android SDK (Android 构建)
- Xcode (iOS 构建)

### 快速开始

```bash
# 克隆仓库
git clone https://github.com/psno/buwang-schedule.git
cd buwang-schedule

# 安装依赖
flutter pub get

# 运行调试版
flutter run

# 构建 Android APK
flutter build apk --release

# 构建 iOS（需要 macOS）
flutter build ios --release --no-codesign
```

### 项目结构

```
lib/
├── main.dart                 # 应用入口
├── app.dart                  # App 配置
├── models/                   # 数据模型
│   ├── course.dart           # 课程模型
│   └── time_slot.dart        # 时间段模型
├── screens/                  # 页面
│   ├── home_screen.dart      # 首页
│   ├── timetable_screen.dart # 课表页
│   ├── more_screen.dart      # 更多/设置页
│   └── reminder_screen.dart  # 提醒管理页
├── services/                 # 业务服务
│   ├── database_service.dart # SQLite 数据库
│   ├── calendar_sync_service.dart  # 日历同步
│   ├── notification_service.dart   # 通知提醒
│   ├── alarm_service.dart          # 闹钟
│   └── html_parser.dart            # AI 导入解析
└── widgets/                  # 公共组件
```

## 更新日志

### v1.4.4 (2026-05-15)
- ✨ 新增 iOS 跨平台适配
- 🐛 修复日历同步重复创建账户问题
- 🐛 修复深度清理功能
- 🐛 修复课表纵向滚动问题

### v1.4.0 (2026-05-13)
- ✨ 新增可编辑时间段（点击修改上下课时间）
- ✨ 新增日历深度清理功能
- ✨ 新增教师/学生版自动切换
- 🎨 优化课表首列固定显示

## 赞赏支持

如果不忘课表对你有帮助，欢迎请开发者喝杯咖啡 ☕

<p align="center">
  <img src="assets/images/wechat_qr.jpg" width="200" />
</p>

<p align="center">
  <em>微信扫码赞赏</em>
</p>

## 联系方式

- GitHub: [psno](https://github.com/psno)
- 邮箱: dxzaaa@yeah.net
- 接小程序、App、Web 系统、数据看板等软件定制开发

## 许可证

本项目基于 [MIT License with Non-Commercial Clause](LICENSE) 开源。

**仅限非商业用途**，如需商业使用请联系作者获取授权。

---

<p align="center">
  <em>如果觉得不错，请点个 ⭐ Star 支持一下！</em>
</p>
