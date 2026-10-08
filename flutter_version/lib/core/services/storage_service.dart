import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String keyBotToken = 'tg_bot_token';
  static const String keyProxyUrl = 'tg_proxy_url';
  static const String keyAutoStart = 'tg_auto_start';

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  String get botToken => _prefs.getString(keyBotToken) ?? '';
  Future<bool> setBotToken(String value) => _prefs.setString(keyBotToken, value.trim());

  String get proxyUrl => _prefs.getString(keyProxyUrl) ?? '';
  Future<bool> setProxyUrl(String value) => _prefs.setString(keyProxyUrl, value.trim());

  bool get autoStart => _prefs.getBool(keyAutoStart) ?? false;
  Future<bool> setAutoStart(bool value) => _prefs.setBool(keyAutoStart, value);

  // 模块启用状态
  bool isModuleEnabled(String moduleId, {bool defaultValue = true}) {
    return _prefs.getBool('mod_${moduleId}_enabled') ?? defaultValue;
  }

  Future<bool> setModuleEnabled(String moduleId, bool enabled) {
    return _prefs.setBool('mod_${moduleId}_enabled', enabled);
  }

  // 模块自定义配置
  String getModuleSetting(String moduleId, String key, {String defaultValue = ''}) {
    return _prefs.getString('mod_${moduleId}_$key') ?? defaultValue;
  }

  Future<bool> setModuleSetting(String moduleId, String key, String value) {
    return _prefs.setString('mod_${moduleId}_$key', value.trim());
  }

  bool getModuleBoolSetting(String moduleId, String key, {bool defaultValue = false}) {
    return _prefs.getBool('mod_${moduleId}_$key') ?? defaultValue;
  }

  Future<bool> setModuleBoolSetting(String moduleId, String key, bool value) {
    return _prefs.setBool('mod_${moduleId}_$key', value);
  }
}
