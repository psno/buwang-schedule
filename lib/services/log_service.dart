import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:logger/logger.dart';

/// 日志服务 — 隐藏开发者模式
/// 记录所有关键操作到本地文件，可一键导出
class LogService {
  LogService._();
  static final LogService instance = LogService._();

  Logger? _logger;
  File? _logFile;
  bool _enabled = false;
  final List<String> _buffer = [];

  /// 是否已启用日志
  bool get isEnabled => _enabled;

  /// 初始化日志服务
  Future<void> initialize() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _logFile = File('${dir.path}/buwang_debug.log');

      _logger = Logger(
        printer: PrettyPrinter(methodCount: 0),
        output: _FileOutput(_logFile!),
      );

      _enabled = true;
      i('日志服务已初始化');
    } catch (e) {
      _enabled = false;
    }
  }

  /// 启用/禁用日志
  void setEnabled(bool value) {
    _enabled = value;
    if (_enabled && _logger == null) {
      initialize();
    }
  }

  /// Info 级别日志
  void i(String message, [dynamic error]) {
    _log('INFO', message);
    if (_enabled && _logger != null) {
      _logger!.i(message);
    }
  }

  /// Warning 级别日志
  void w(String message, [dynamic error]) {
    _log('WARN', message);
    if (_enabled && _logger != null) {
      _logger!.w(message);
    }
  }

  /// Error 级别日志
  void e(String message, [dynamic error, StackTrace? stackTrace]) {
    _log('ERROR', message);
    if (_enabled && _logger != null) {
      _logger!.e(message, error: error, stackTrace: stackTrace);
    }
  }

  void _log(String level, String message) {
    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
    final entry = '[$timeStr][$level] $message';
    _buffer.add(entry);

    // 保留最近 500 条
    if (_buffer.length > 500) {
      _buffer.removeRange(0, _buffer.length - 500);
    }
  }

  /// 获取最近的日志
  String getRecentLogs({int count = 100}) {
    final start = _buffer.length > count ? _buffer.length - count : 0;
    return _buffer.sublist(start).join('\n');
  }

  /// 获取全部日志内容
  Future<String> getFullLog() async {
    if (_logFile == null || !await _logFile!.exists()) {
      return getRecentLogs();
    }
    try {
      return await _logFile!.readAsString();
    } catch (_) {
      return getRecentLogs();
    }
  }

  /// 导出日志文件（分享到微信/QQ）
  Future<void> exportLog() async {
    final content = await getFullLog();
    if (content.isEmpty) return;

    // 写到临时文件
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/buwang_debug_log.txt');
    await file.writeAsString(content);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: '不忘课表 - 调试日志',
    );
  }

  /// 清空日志
  Future<void> clear() async {
    _buffer.clear();
    if (_logFile != null && await _logFile!.exists()) {
      await _logFile!.writeAsString('');
    }
  }
}

/// 写文件的 Logger Output
class _FileOutput extends LogOutput {
  final File file;
  _FileOutput(this.file);

  @override
  void output(OutputEvent event) {
    try {
      final line = event.lines.join('\n');
      file.writeAsStringSync('$line\n', mode: FileMode.append);
    } catch (_) {}
  }
}
