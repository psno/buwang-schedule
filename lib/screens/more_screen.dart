import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/course.dart';
import '../models/app_mode.dart';
import '../models/saturday_mode.dart';
import '../services/html_parser.dart';
import '../utils/constants.dart';
import '../utils/extensions.dart';
import '../services/database_service.dart';
import '../services/log_service.dart';
import '../theme/app_theme.dart';
import '../app.dart';

/// 不忘课表 - More Screen (更多)
/// Settings, import/export, theme, and about.
class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  final DatabaseService _db = DatabaseService.instance;
  SaturdayMode _saturdayMode = SaturdayMode.off;
  int _courseCount = 0;
  bool _isDarkMode = false;
  UserRole _userRole = UserRole.student;
  SchoolType _schoolType = SchoolType.highSchool;
  AppThemeColor _themeColor = AppThemeColor.blue;
  bool _developerMode = false;

  // Logo连点相关
  int _logoTapCount = 0;
  Timer? _logoTapTimer;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final satMode = await _db.getSetting('saturday_mode');
      final count = await _db.courseCount;
      final roleStr = await _db.getSetting(AppConstants.keyUserRole);
      final schoolStr = await _db.getSetting(AppConstants.keySchoolType);
      final themeStr = await _db.getSetting(AppConstants.keyThemeColor);
      final devMode = await _db.getSetting('developer_mode');
      if (mounted) {
        setState(() {
          _saturdayMode = SaturdayMode.values[int.tryParse(satMode ?? '0') ?? 0];
          _courseCount = count;
          _isDarkMode = context.isDarkMode;
          _userRole = UserRole.values[int.tryParse(roleStr ?? '0') ?? 0];
          _schoolType = SchoolType.values[int.tryParse(schoolStr ?? '0') ?? 0];
          _themeColor = AppThemeColor.fromIndex(int.tryParse(themeStr ?? '0') ?? 0);
          _developerMode = devMode == '1';
        });
      }
    } catch (_) {}
  }

  Future<void> _setSaturdayMode(SaturdayMode mode) async {
    await _db.setSetting('saturday_mode', mode.index.toString());
    setState(() => _saturdayMode = mode);
    if (mounted) context.showSnackBar('周六模式已更新');
  }

  Future<void> _setUserRole(UserRole role) async {
    await _db.setSetting(AppConstants.keyUserRole, role.index.toString());
    setState(() => _userRole = role);
    if (mounted) context.showSnackBar('用户角色已更新');
  }

  Future<void> _setSchoolType(SchoolType type) async {
    await _db.setSetting(AppConstants.keySchoolType, type.index.toString());
    setState(() => _schoolType = type);
    if (mounted) context.showSnackBar('学校类型已更新');
  }

  void _setThemeColor(AppThemeColor color) {
    setState(() => _themeColor = color);
    _db.setSetting(AppConstants.keyThemeColor, color.id.toString());
    BuwangApp.appKey.currentState?.setThemeColor(color);
  }

  /// Logo连点开启开发者模式
  void _onLogoTap() {
    _logoTapTimer?.cancel();
    _logoTapCount++;

    if (_developerMode) {
      _logoTapCount = 0;
      return;
    }

    final remain = 5 - _logoTapCount;

    if (_logoTapCount >= 5) {
      _developerMode = true;
      _logoTapCount = 0;
      LogService.instance.setEnabled(true);
      _db.setSetting('developer_mode', '1');
      setState(() {});
      if (mounted) context.showSuccessSnackBar('🔧 开发者模式已开启');
      return;
    }

    if (remain > 0 && remain <= 4 && mounted) {
      context.showSnackBar('再点击 $remain 次开启开发者模式');
    }

    _logoTapTimer = Timer(const Duration(seconds: 2), () {
      _logoTapCount = 0;
    });
  }

  /// 保存赞赏码到本地
  Future<void> _saveQrToLocal() async {
    try {
      final byteData = await rootBundle.load('assets/images/wechat_qr.jpg');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/buwang_qr.jpg');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      await Share.shareXFiles([XFile(file.path)], text: '不忘课表 - 开发者赞赏码');
      if (mounted) context.showSuccessSnackBar('已保存，可从分享中保存到相册');
    } catch (e) {
      if (mounted) context.showErrorSnackBar('保存失败: $e');
    }
  }

  Future<void> _importFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['html', 'json'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;

      if (file.bytes == null || file.bytes!.isEmpty) {
        if (mounted) context.showErrorSnackBar('无法读取文件');
        return;
      }
      final content = utf8.decode(file.bytes!, allowMalformed: true);
      if (content.trim().isEmpty) {
        if (mounted) context.showErrorSnackBar('文件内容为空');
        return;
      }

      List<Course> courses;
      if (file.name.endsWith('.json')) {
        courses = _parseJsonCourses(content);
      } else {
        courses = _parseHtmlCourses(content);
      }

      if (courses.isEmpty) {
        if (mounted) context.showErrorSnackBar('未找到课程数据');
        return;
      }

      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('导入课表'),
          content: Text('将导入 ${courses.length} 个课程，现有数据会被替换。确定继续？'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确定导入')),
          ],
        ),
      );

      if (confirm == true) {
        await _db.importCourses(courses);
        await _loadSettings();
        if (mounted) context.showSuccessSnackBar('成功导入 ${courses.length} 个课程');
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('导入失败'),
            content: SingleChildScrollView(child: Text('$e')),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('确定'))],
          ),
        );
      }
    }
  }

  List<Course> _parseJsonCourses(String jsonStr) {
    try {
      final list = jsonDecode(jsonStr) as List;
      return list.map((m) => Course.fromMap(m as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception('JSON解析失败: $e');
    }
  }

  List<Course> _parseHtmlCourses(String htmlStr) {
    try {
      final result = HtmlScheduleParser.parseHtmlString(htmlStr);
      if (result.courses.isEmpty && htmlStr.isNotEmpty) {
        final hasMf = htmlStr.contains('SCHEDULE_MF');
        final hasSat = htmlStr.contains('SCHEDULE_SAT_CONFIG');
        String detail = '文件长度:${htmlStr.length} | MF:$hasMf | SAT:$hasSat';
        if (hasMf) {
          final mfResult = HtmlScheduleParser.extractJsonDebug(htmlStr, 'SCHEDULE_MF');
          detail += ' | MF解析:$mfResult';
        }
        throw Exception(detail);
      }
      return result.courses;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _exportToFile() async {
    try {
      final courses = await _db.exportCourses();
      if (courses.isEmpty) {
        if (mounted) context.showErrorSnackBar('没有课程数据可导出');
        return;
      }
      final jsonStr = jsonEncode(courses.map((c) => c.toMap()).toList());
      await Share.share(jsonStr, subject: '不忘课表 - 课表数据');
    } catch (e) {
      if (mounted) context.showErrorSnackBar('导出失败: $e');
    }
  }

  void _showImportHelp() {
    final theme = context.textTheme;
    final cs = context.colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('📋 如何导入课表'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('方式一：直接导入HTML', style: theme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('如果你有教务系统生成的课表HTML网页文件，直接用「导入课表」选择该文件即可。'),
              const SizedBox(height: 16),
              Text('方式二：用AI生成JSON', style: theme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('1. 打开你的课表（网页/APP/纸质拍照都行）\n2. 截图发给任意AI（豆包/Kimi/ChatGPT等）\n3. 发送以下提示词：'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
                child: SelectableText(
                  '请把这张课表截图转成JSON数组，格式如下：\n[{"name":"班级名","subject":"科目","dayOfWeek":1,"period":2,"teacher":"老师名","color":0}]\n\n字段说明：\nname: 班级名（如高一1班）\nsubject: 科目名\ndayOfWeek: 1=周一..6=周六\nperiod: 节次（0=早自习,1=第1节..12=第12节）\nteacher: 老师姓名\ncolor: 0-9随便填\nlocation: 教室地点（可选）\n\n如果课表上有作息时间（每节课的上下课时间），请额外输出一个timeSlots数组：\n[{"period":0,"label":"早自习","start":"07:05","end":"07:45"},{"period":1,"label":"第1节","start":"08:25","end":"09:05"}]\n\n只输出JSON，不要其他内容。',
                  style: theme.bodySmall?.copyWith(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
              const SizedBox(height: 12),
              const Text('4. 复制AI返回的JSON\n5. 保存为.json文件发到手机\n6. 回到本App用「导入课表」选择该文件'),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('知道了'))],
      ),
    );
  }

  void _showAbout() {
    final theme = context.textTheme;
    final cs = context.colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.school, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppConstants.appName, style: theme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                Text('v${AppConstants.appVersion}', style: theme.bodySmall),
              ],
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('不忘课表是一款简洁高效的课程管理工具，帮助你轻松管理每日课程安排、设置上课提醒，再也不用担心忘课。'),
              const SizedBox(height: 16),
              Text('功能特色', style: theme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('• 课表导入与管理（HTML/JSON）'),
              const Text('• 上课提醒（闹钟/日历/通知）'),
              const Text('• 一键同步整学期到系统日历'),
              const Text('• 教师/学生版自动切换'),
              const Text('• 高中/大学模式支持'),
              const Text('• 深色模式 + 三套主题色'),
              const SizedBox(height: 8),
              Text('联系方式', style: theme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('SNO · dxzaaa@yeah.net'),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('确定'))],
      ),
    );
  }

  /// 赞赏弹窗（含长按保存 + 接定制化软件）
  void _showSupportDialog() {
    final theme = context.textTheme;
    final cs = context.colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('💖 支持开发者', style: theme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('如果不忘课表对你有帮助，欢迎请开发者喝杯咖啡'),
            const SizedBox(height: 16),
            GestureDetector(
              onLongPress: () {
                Navigator.pop(ctx);
                _saveQrToLocal();
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset('assets/images/wechat_qr.jpg', width: 200, height: 200, fit: BoxFit.cover),
                  ),
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
                      ),
                      child: const Text('长按保存到本地', textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text('微信扫码赞赏', style: theme.bodySmall),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.code, size: 18, color: cs.primary),
                      const SizedBox(width: 8),
                      Expanded(child: Text('承接小程序、App、Web系统、数据看板等软件定制开发', style: theme.bodySmall)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.email_outlined, size: 16, color: cs.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Text('dxzaaa@yeah.net', style: theme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final ts = context.textTheme;
    _isDarkMode = context.isDarkMode;

    return Scaffold(
      appBar: AppBar(title: Text('更多', style: ts.titleLarge?.copyWith(fontSize: 18))),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ─── 数据管理 ───
          _buildSectionHeader(context, '数据管理', Icons.storage),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                _buildTile(context, Icons.upload_file, cs.primary, '导入课表', '从 HTML 或 JSON 文件导入', _importFromFile),
                const Divider(height: 1, indent: 72),
                _buildTile(context, Icons.download, cs.secondary, '导出课表', '当前已有 $_courseCount 个课程', _exportToFile),
                const Divider(height: 1, indent: 72),
                _buildTile(context, Icons.help_outline, cs.tertiary, '导入帮助', '不会导入？用AI截图生成JSON', _showImportHelp),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ─── 课表设置 ───
          _buildSectionHeader(context, '课表设置', Icons.tune),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                ListTile(
                  leading: _iconBox(cs.tertiary, Icons.weekend),
                  title: const Text('周六模式'),
                  subtitle: Text(_saturdayModeLabel, style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                  trailing: PopupMenuButton<SaturdayMode>(
                    icon: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                    onSelected: _setSaturdayMode,
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: SaturdayMode.off, child: Text('关闭 (隐藏周六)')),
                      PopupMenuItem(value: SaturdayMode.round1, child: Text('轮次 1')),
                      PopupMenuItem(value: SaturdayMode.round2, child: Text('轮次 2')),
                      PopupMenuItem(value: SaturdayMode.round3, child: Text('轮次 3')),
                    ],
                  ),
                ),
                const Divider(height: 1, indent: 72),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      _iconBox(cs.primary, _userRole == UserRole.student ? Icons.person : Icons.school),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('用户角色'),
                            const SizedBox(height: 4),
                            SegmentedButton<UserRole>(
                              segments: const [
                                ButtonSegment(value: UserRole.student, label: Text('学生'), icon: Icon(Icons.person, size: 16)),
                                ButtonSegment(value: UserRole.teacher, label: Text('教师'), icon: Icon(Icons.school, size: 16)),
                              ],
                              selected: {_userRole},
                              onSelectionChanged: (s) => _setUserRole(s.first),
                              style: ButtonStyle(visualDensity: VisualDensity.compact, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, indent: 72),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      _iconBox(cs.tertiary, _schoolType == SchoolType.highSchool ? Icons.class_ : Icons.account_balance),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('学校类型'),
                            const SizedBox(height: 4),
                            SegmentedButton<SchoolType>(
                              segments: const [
                                ButtonSegment(value: SchoolType.highSchool, label: Text('高中'), icon: Icon(Icons.class_, size: 16)),
                                ButtonSegment(value: SchoolType.university, label: Text('大学'), icon: Icon(Icons.account_balance, size: 16)),
                              ],
                              selected: {_schoolType},
                              onSelectionChanged: (s) => _setSchoolType(s.first),
                              style: ButtonStyle(visualDensity: VisualDensity.compact, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, indent: 72),
                ListTile(
                  leading: _iconBox(cs.primary, _isDarkMode ? Icons.dark_mode : Icons.light_mode),
                  title: const Text('深色模式'),
                  subtitle: Text(_isDarkMode ? '跟随系统 (深色)' : '跟随系统 (浅色)', style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                ),
                const Divider(height: 1, indent: 72),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      _iconBox(cs.primary, Icons.palette_outlined),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('主题颜色', style: ts.bodyLarge),
                            const SizedBox(height: 8),
                            Row(
                              children: AppThemeColor.values.map((color) {
                                final selected = _themeColor == color;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: GestureDetector(
                                    onTap: () => _setThemeColor(color),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      width: 36, height: 36,
                                      decoration: BoxDecoration(
                                        color: color.seedColor,
                                        shape: BoxShape.circle,
                                        border: selected ? Border.all(color: cs.onSurface, width: 3) : null,
                                        boxShadow: selected ? [BoxShadow(color: color.seedColor.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 2))] : null,
                                      ),
                                      child: selected ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ─── 开发者工具（仅开发者模式可见）───
          if (_developerMode) ...[
            const SizedBox(height: 16),
            _buildSectionHeader(context, '开发者工具', Icons.bug_report),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                children: [
                  _buildTile(context, Icons.bug_report, cs.error, '导出调试日志', '将日志分享到微信/QQ', () => LogService.instance.exportLog()),
                  const Divider(height: 1, indent: 72),
                  _buildTile(context, Icons.delete_sweep, cs.error, '清空调试日志', null, () async {
                    await LogService.instance.clear();
                    if (mounted) context.showSnackBar('日志已清空');
                  }),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // ─── 关于 ───
          _buildSectionHeader(context, '关于', Icons.info_outline),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                _buildTile(context, Icons.info_outline, cs.primary, '关于不忘课表',
                    '版本 ${AppConstants.appVersion}${_developerMode ? ' 🔧' : ''}', _showAbout),
                const Divider(height: 1, indent: 72),
                _buildTile(context, Icons.favorite, cs.secondary, '支持开发者',
                    '请开发者喝杯咖啡 ☕', _showSupportDialog),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // ─── Logo（连点5次开启开发者模式）───
          GestureDetector(
            onTap: _onLogoTap,
            child: Center(
              child: Column(
                children: [
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [cs.primary, cs.tertiary], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: cs.primary.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 4))],
                    ),
                    child: const Icon(Icons.school, color: Colors.white, size: 40),
                  ),
                  const SizedBox(height: 12),
                  Text(AppConstants.appName, style: ts.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  Text('v${AppConstants.appVersion}', style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _iconBox(Color color, IconData icon) {
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: color, size: 22),
    );
  }

  Widget _buildTile(BuildContext context, IconData icon, Color iconColor, String title, String? subtitle, VoidCallback onTap) {
    final cs = context.colorScheme;
    final ts = context.textTheme;
    return ListTile(
      leading: _iconBox(iconColor, icon),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle, style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant)) : null,
      trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
      onTap: onTap,
    );
  }

  String get _saturdayModeLabel {
    switch (_saturdayMode) {
      case SaturdayMode.off: return '关闭 (隐藏周六列)';
      case SaturdayMode.round1: return '轮次 1';
      case SaturdayMode.round2: return '轮次 2';
      case SaturdayMode.round3: return '轮次 3';
    }
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    final cs = context.colorScheme;
    final ts = context.textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: cs.primary),
          const SizedBox(width: 8),
          Text(title, style: ts.titleSmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
