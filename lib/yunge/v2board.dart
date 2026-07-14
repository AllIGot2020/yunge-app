// 云歌 · V2board 接口对接
// 面板与订阅是两个域名（服务端确认）：
//   登录/用户信息 -> israelpost-co.org
//   订阅内容      -> aomozm.com
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

class YunGeApi {
  // API 域名（登录/用户信息/订阅都走这里）。
  // 注意：israelpost-co.org 挂在 Cloudflare 上会 302 跳到前端站，调不了 API，
  // 真正的 V2board 后端 API 在 aomozm.com（已实测确认）。
  static const String apiBase = 'https://www.aomozm.com';
  static const String subBase = 'https://www.aomozm.com';
  // 面板站（仅用于注册/续费等网页跳转链接）
  static const String panelBase = 'https://www.israelpost-co.org';
  static String get _api => '$apiBase/api/v1';

  static final Dio _dio = _buildDio();

  static Dio _buildDio() {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        // V2board 习惯表单提交
        contentType: Headers.formUrlEncodedContentType,
        // 跟随重定向；接受所有状态码自己读后端 message（v2board 业务错误用 HTTP 500）
        followRedirects: true,
        maxRedirects: 5,
        validateStatus: (status) => status != null && status < 600,
        headers: {'Accept': 'application/json'},
      ),
    );
    // 关键：对自己面板的 API 请求强制直连，绕过系统代理/TUN，
    // 否则开启系统代理后请求被 mihomo 劫持，TLS 握手失败（HandshakeException）。
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.findProxy = (uri) => 'DIRECT';
        return client;
      },
    );
    return dio;
  }

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
      // 后端返回了错误 message（如"邮箱或密码错误"）
      if (data is Map && data['message'] != null) {
        throw '${data['message']}';
      }
      throw '登录失败（HTTP ${resp.statusCode}）';
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

  // ============ 下单 / 支付 ============

  /// 套餐列表
  static Future<List<PlanItem>> fetchPlans(String authData) async {
    final resp = await _dio.get(
      '$_api/user/plan/fetch',
      options: Options(headers: {'Authorization': authData}),
    );
    final data = resp.data;
    if (data is Map && data['data'] is List) {
      return (data['data'] as List)
          .map((e) => PlanItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    throw _dataErr(data, '获取套餐失败');
  }

  /// 支付方式列表
  static Future<List<PaymentMethod>> fetchPaymentMethods(
      String authData) async {
    final resp = await _dio.get(
      '$_api/user/order/getPaymentMethod',
      options: Options(headers: {'Authorization': authData}),
    );
    final data = resp.data;
    if (data is Map && data['data'] is List) {
      return (data['data'] as List)
          .map((e) => PaymentMethod.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    throw _dataErr(data, '获取支付方式失败');
  }

  /// 下单，返回 trade_no（订单号）。下单前自动清理待支付订单，避免"有未支付订单"卡住。
  static Future<String> saveOrder(
      String authData, int planId, String period) async {
    await _cancelPendingOrders(authData);
    final resp = await _dio.post(
      '$_api/user/order/save',
      data: {'plan_id': '$planId', 'period': period},
      options: Options(headers: {'Authorization': authData}),
    );
    final data = resp.data;
    // save 成功时 data 是 trade_no 字符串（且无 message）
    if (data is Map && data['data'] != null && data['message'] == null) {
      return '${data['data']}';
    }
    throw _dataErr(data, '下单失败');
  }

  /// 取消该用户所有待支付订单（status==0）
  static Future<void> _cancelPendingOrders(String authData) async {
    try {
      final resp = await _dio.get(
        '$_api/user/order/fetch',
        options: Options(headers: {'Authorization': authData}),
      );
      final data = resp.data;
      if (data is Map && data['data'] is List) {
        for (final o in (data['data'] as List)) {
          if (o is Map && o['status'] == 0 && o['trade_no'] != null) {
            await _dio.post(
              '$_api/user/order/cancel',
              data: {'trade_no': '${o['trade_no']}'},
              options: Options(headers: {'Authorization': authData}),
            );
          }
        }
      }
    } catch (_) {
      // 清理失败不阻断下单（下单会给出后端提示）
    }
  }

  /// 结账，返回 {type, data}（EPay: type=1，data 为收银台 URL）
  static Future<CheckoutResult> checkout(
      String authData, String tradeNo, int method) async {
    final resp = await _dio.post(
      '$_api/user/order/checkout',
      data: {'trade_no': tradeNo, 'method': '$method'},
      options: Options(headers: {'Authorization': authData}),
    );
    final data = resp.data;
    if (data is Map && data.containsKey('type')) {
      return CheckoutResult(
        type: data['type'] is int
            ? data['type']
            : int.tryParse('${data['type']}') ?? 1,
        data: '${data['data']}',
      );
    }
    throw _dataErr(data, '结账失败');
  }

  /// 查询订单状态（0=待支付 3=已支付其它=处理中）
  static Future<int> checkOrder(String authData, String tradeNo) async {
    final resp = await _dio.get(
      '$_api/user/order/check',
      queryParameters: {'trade_no': tradeNo},
      options: Options(headers: {'Authorization': authData}),
    );
    final data = resp.data;
    if (data is Map && data['data'] != null) {
      final v = data['data'];
      return v is int ? v : int.tryParse('$v') ?? 0;
    }
    return 0;
  }

  static String _dataErr(dynamic data, String fallback) {
    if (data is Map && data['message'] != null) return '${data['message']}';
    return fallback;
  }


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

// ============ 下单/支付 模型 ============

/// 支付周期（对应 v2board plan 表价格字段）
class PlanPeriod {
  final String key; // month_price / quarter_price / half_year_price / year_price
  final String label;
  final int price; // 分
  const PlanPeriod(this.key, this.label, this.price);
}

class PlanItem {
  final int id;
  final String name;
  final int transferEnable; // GB
  final String? content;
  final int? monthPrice;
  final int? quarterPrice;
  final int? halfYearPrice;
  final int? yearPrice;

  const PlanItem({
    required this.id,
    required this.name,
    required this.transferEnable,
    this.content,
    this.monthPrice,
    this.quarterPrice,
    this.halfYearPrice,
    this.yearPrice,
  });

  factory PlanItem.fromJson(Map<String, dynamic> j) {
    int? _i(v) => v == null ? null : (v is int ? v : int.tryParse('$v'));
    return PlanItem(
      id: _i(j['id']) ?? 0,
      name: '${j['name'] ?? ''}',
      transferEnable: _i(j['transfer_enable']) ?? 0,
      content: j['content']?.toString(),
      monthPrice: _i(j['month_price']),
      quarterPrice: _i(j['quarter_price']),
      halfYearPrice: _i(j['half_year_price']),
      yearPrice: _i(j['year_price']),
    );
  }

  /// 可购买的周期列表（价格非空的）
  List<PlanPeriod> get periods {
    final list = <PlanPeriod>[];
    if (monthPrice != null) list.add(PlanPeriod('month_price', '月付', monthPrice!));
    if (quarterPrice != null) {
      list.add(PlanPeriod('quarter_price', '季付', quarterPrice!));
    }
    if (halfYearPrice != null) {
      list.add(PlanPeriod('half_year_price', '半年付', halfYearPrice!));
    }
    if (yearPrice != null) list.add(PlanPeriod('year_price', '年付', yearPrice!));
    return list;
  }
}

class PaymentMethod {
  final int id;
  final String name;
  final String payment; // EPay 等
  final String? icon;
  const PaymentMethod({
    required this.id,
    required this.name,
    required this.payment,
    this.icon,
  });
  factory PaymentMethod.fromJson(Map<String, dynamic> j) => PaymentMethod(
        id: j['id'] is int ? j['id'] : int.tryParse('${j['id']}') ?? 0,
        name: '${j['name'] ?? ''}',
        payment: '${j['payment'] ?? ''}',
        icon: j['icon']?.toString(),
      );
}

class CheckoutResult {
  final int type; // 0:二维码内容 1:跳转URL -1:免费直接成功
  final String data;
  const CheckoutResult({required this.type, required this.data});
}

