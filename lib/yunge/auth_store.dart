// 云歌 · 登录态持久化
// 独立使用 SharedPreferences，不侵入 FlClash 的 Preferences 类，方便同步上游。
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'v2board.dart';

class YunGeAuthStore {
  static const _key = 'yunge_auth';

  /// 读取已保存的登录态（未登录返回 null）
  static Future<YunGeSession?> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key);
    if (raw == null) return null;
    try {
      final m = json.decode(raw) as Map<String, dynamic>;
      return YunGeSession(
        email: '${m['email'] ?? ''}',
        token: '${m['token'] ?? ''}',
        authData: '${m['auth_data'] ?? ''}',
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(YunGeSession s) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(
      _key,
      json.encode({
        'email': s.email,
        'token': s.token,
        'auth_data': s.authData,
      }),
    );
  }

  static Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_key);
  }
}

class YunGeSession {
  final String email;
  final String token;
  final String authData;
  const YunGeSession({
    required this.email,
    required this.token,
    required this.authData,
  });

  String get subscribeUrl => YunGeApi.subscribeUrl(token);
}
