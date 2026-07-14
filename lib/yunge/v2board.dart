// 云歌 · V2board 接口对接
// 面板与订阅是两个域名（服务端确认）：
//   登录/用户信息 -> israelpost-co.org
//   订阅内容      -> aomozm.com
import 'package:dio/dio.dart';

class YunGeApi {
  static const String panelBase = 'https://www.israelpost-co.org';
  static const String subBase = 'https://www.aomozm.com';
  static String get _api => '$panelBase/api/v1';

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      // V2board 习惯表单提交
      contentType: Headers.formUrlEncodedContentType,
    ),
  );

  /// 登录，返回 {token, is_admin, auth_data}
  static Future<AuthData> login(String email, String password) async {
    try {
      final resp = await _dio.post(
        '$_api/passport/auth/login',
        data: {'email': email, 'password': password},
      );
      final data = resp.data;
      if (data is Map && data['data'] is Map) {
        final d = data['data'] as Map;
        return AuthData(
          token: '${d['token']}',
          authData: '${d['auth_data']}',
          isAdmin: (d['is_admin'] ?? 0) is int
              ? d['is_admin'] ?? 0
              : int.tryParse('${d['is_admin']}') ?? 0,
        );
      }
      throw '登录响应异常';
    } on DioException catch (e) {
      throw _errMsg(e);
    }
  }

  /// 用户信息（套餐/流量/到期）
  static Future<UserInfo> getUserInfo(String authData) async {
    try {
      final resp = await _dio.get(
        '$_api/user/info',
        options: Options(headers: {'Authorization': authData}),
      );
      final data = resp.data;
      if (data is Map && data['data'] is Map) {
        return UserInfo.fromJson(Map<String, dynamic>.from(data['data']));
      }
      throw '获取用户信息失败';
    } on DioException catch (e) {
      throw _errMsg(e);
    }
  }

  /// 用 token 拼订阅地址（clash 格式）
  static String subscribeUrl(String token) =>
      '$subBase/api/v1/client/subscribe?token=${Uri.encodeComponent(token)}&flag=clash';

  static String _errMsg(DioException e) {
    // 优先返回后端 message
    final resp = e.response?.data;
    if (resp is Map && resp['message'] != null) {
      return '${resp['message']}';
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return '网络超时，请检查网络';
      case DioExceptionType.connectionError:
        return '无法连接服务器';
      default:
        return '请求失败：${e.message ?? e.type.name}';
    }
  }
}

class AuthData {
  final String token; // 订阅 token
  final String authData; // JWT，后续鉴权
  final int isAdmin;
  const AuthData({
    required this.token,
    required this.authData,
    required this.isAdmin,
  });
}

class UserInfo {
  final String? email;
  final int? planId;
  final int? expiredAt; // 秒级时间戳，null=不过期
  final int u; // 已上传
  final int d; // 已下载
  final int transferEnable; // 套餐总流量
  final String? planName;

  const UserInfo({
    this.email,
    this.planId,
    this.expiredAt,
    this.u = 0,
    this.d = 0,
    this.transferEnable = 0,
    this.planName,
  });

  factory UserInfo.fromJson(Map<String, dynamic> j) {
    int _i(v) => v is int ? v : int.tryParse('${v ?? 0}') ?? 0;
    String? planName;
    final plan = j['plan'];
    if (plan is Map && plan['name'] != null) planName = '${plan['name']}';
    return UserInfo(
      email: j['email']?.toString(),
      planId: j['plan_id'] == null ? null : _i(j['plan_id']),
      expiredAt: j['expired_at'] == null ? null : _i(j['expired_at']),
      u: _i(j['u']),
      d: _i(j['d']),
      transferEnable: _i(j['transfer_enable']),
      planName: planName,
    );
  }

  int get used => u + d;
}
