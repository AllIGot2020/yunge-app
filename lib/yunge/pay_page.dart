// 云歌 · 套餐选择 + 收银台支付页
// 流程：选套餐 → 选周期 → 下单 → checkout 拿收银台URL
//   移动端：内嵌 webview 打开收银台扫码付；桌面：跳浏览器 + 显示二维码
// 同时轮询 order/check，支付成功自动关闭并刷新会员信息
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'v2board.dart';
import 'auth_store.dart';
import 'user_provider.dart';

const _green = Color(0xFF07C160);
const _greenDark = Color(0xFF06AD56);

class YunGePayPage extends ConsumerStatefulWidget {
  const YunGePayPage({super.key});

  @override
  ConsumerState<YunGePayPage> createState() => _YunGePayPageState();
}

class _YunGePayPageState extends ConsumerState<YunGePayPage> {
  String? _authData;
  List<PlanItem> _plans = [];
  List<PaymentMethod> _methods = [];
  bool _loading = true;
  String? _err;

  // 选择态
  PlanItem? _plan;
  PlanPeriod? _period;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final s = await YunGeAuthStore.load();
      if (s == null) throw '未登录';
      _authData = s.authData;
      final plans = await YunGeApi.fetchPlans(s.authData);
      final methods = await YunGeApi.fetchPaymentMethods(s.authData);
      setState(() {
        _plans = plans;
        _methods = methods;
        if (plans.isNotEmpty) {
          _plan = plans.first;
          if (_plan!.periods.isNotEmpty) _period = _plan!.periods.first;
        }
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _err = '$e';
        _loading = false;
      });
    }
  }

  String _yuan(int fen) => (fen / 100).toStringAsFixed(2);

  Future<void> _pay() async {
    if (_authData == null || _plan == null || _period == null) return;
    if (_methods.isEmpty) {
      _toast('暂无可用支付方式');
      return;
    }
    final method = _methods.first; // 你的面板只有 EPay 一个
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: _green)),
    );
    try {
      final tradeNo =
          await YunGeApi.saveOrder(_authData!, _plan!.id, _period!.key);
      final result = await YunGeApi.checkout(_authData!, tradeNo, method.id);
      if (mounted) Navigator.of(context).pop(); // 关 loading

      if (result.type == -1) {
        // 免费/余额直接成功
        _onPaid();
        return;
      }
      // type 1: url 收银台；type 0: 二维码内容
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => _CashierPage(
          authData: _authData!,
          tradeNo: tradeNo,
          checkout: result,
          onPaid: _onPaid,
        ),
      ));
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      _toast('$e');
    }
  }

  void _onPaid() {
    ref.read(userInfoProvider.notifier).refresh();
    if (mounted) {
      _toast('支付成功，套餐已开通');
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: const Text('购买 / 续费套餐'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A1A),
        elevation: 0.5,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _green))
          : _err != null
              ? _errView()
              : _content(),
      bottomNavigationBar: (_loading || _err != null) ? null : _payBar(),
    );
  }

  Widget _errView() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_err!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            TextButton(onPressed: _load, child: const Text('重试')),
          ],
        ),
      );

  Widget _content() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('选择套餐',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ..._plans.map(_planCard),
          const SizedBox(height: 20),
          if (_plan != null && _plan!.periods.isNotEmpty) ...[
            const Text('选择时长',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _plan!.periods.map(_periodChip).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _planCard(PlanItem p) {
    final selected = _plan?.id == p.id;
    return GestureDetector(
      onTap: () => setState(() {
        _plan = p;
        _period = p.periods.isNotEmpty ? p.periods.first : null;
      }),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _green : const Color(0xFFE5E8EB),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('流量 ${p.transferEnable} GB',
                      style: const TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: _green, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _periodChip(PlanPeriod period) {
    final selected = _period?.key == period.key;
    return GestureDetector(
      onTap: () => setState(() => _period = period),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? _green.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? _green : const Color(0xFFE5E8EB),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(period.label,
                style: TextStyle(
                    fontSize: 14,
                    color: selected ? _greenDark : Colors.black87,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text('¥${_yuan(period.price)}',
                style: TextStyle(
                    fontSize: 13,
                    color: selected ? _greenDark : Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _payBar() {
    final price = _period?.price;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        color: Colors.white,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('应付金额',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Text(
                    price != null ? '¥${_yuan(price)}' : '—',
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _greenDark),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: _period == null ? null : _pay,
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('立即支付',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

/// 收银台页：移动端 webview / 桌面二维码+浏览器，轮询支付结果
class _CashierPage extends StatefulWidget {
  final String authData;
  final String tradeNo;
  final CheckoutResult checkout;
  final VoidCallback onPaid;
  const _CashierPage({
    required this.authData,
    required this.tradeNo,
    required this.checkout,
    required this.onPaid,
  });

  @override
  State<_CashierPage> createState() => _CashierPageState();
}

class _CashierPageState extends State<_CashierPage> {
  Timer? _poll;
  WebViewController? _webCtrl;
  bool _isMobile = false;
  bool _paid = false;

  @override
  void initState() {
    super.initState();
    _isMobile = Platform.isAndroid || Platform.isIOS;
    if (_isMobile && widget.checkout.type == 1) {
      _webCtrl = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..loadRequest(Uri.parse(widget.checkout.data));
    } else if (widget.checkout.type == 1) {
      // 桌面：直接用系统浏览器打开收银台
      _openExternal();
    }
    _startPoll();
  }

  Future<void> _openExternal() async {
    final uri = Uri.parse(widget.checkout.data);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _startPoll() {
    _poll = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        final status = await YunGeApi.checkOrder(widget.authData, widget.tradeNo);
        // 0=待支付；非0 视为已处理（3=已完成）
        if (status != 0 && !_paid) {
          _paid = true;
          _poll?.cancel();
          widget.onPaid();
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('支付'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A1A),
        elevation: 0.5,
        actions: [
          TextButton(
            onPressed: () async {
              final status =
                  await YunGeApi.checkOrder(widget.authData, widget.tradeNo);
              if (status != 0) {
                widget.onPaid();
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('尚未检测到支付，请完成付款')));
              }
            },
            child: const Text('我已支付', style: TextStyle(color: _greenDark)),
          ),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    // 移动端 + url 收银台：内嵌 webview
    if (_isMobile && widget.checkout.type == 1 && _webCtrl != null) {
      return WebViewWidget(controller: _webCtrl!);
    }
    // 二维码内容（type 0）：直接生成二维码
    if (widget.checkout.type == 0) {
      return _qrView(widget.checkout.data, '请使用微信/支付宝扫码支付');
    }
    // 桌面 + url：显示二维码（把收银台URL编成码）+ 已在浏览器打开
    return _qrView(widget.checkout.data, '已在浏览器打开收银台\n或扫码在手机上支付');
  }

  Widget _qrView(String data, String tip) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Color(0x14000000), blurRadius: 16),
              ],
            ),
            child: QrImageView(
              data: data,
              size: 220,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Text(tip,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 8),
          const Text('支付完成后将自动到账',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}
