// 云歌 · 登录门控
// 包住 HomePage：启动检查登录态 → 未登录显示登录页 → 登录成功注入订阅 → 进主界面。
import 'package:fl_clash/pages/pages.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_store.dart';
import 'login_page.dart';
import 'user_provider.dart';

class YunGeAuthGate extends ConsumerStatefulWidget {
  const YunGeAuthGate({super.key});

  @override
  ConsumerState<YunGeAuthGate> createState() => _YunGeAuthGateState();
}

class _YunGeAuthGateState extends ConsumerState<YunGeAuthGate> {
  bool _checking = true;
  YunGeSession? _session;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final s = await YunGeAuthStore.load();
    if (!mounted) return;
    setState(() {
      _session = s;
      _checking = false;
    });
    // 已登录：静默确保订阅 profile 存在（首启或订阅被删时补上）
    if (s != null) {
      await _ensureSubscription(s);
    }
  }

  /// 把订阅地址注入 FlClash 的 profile 系统（若尚无任何 profile）
  Future<void> _ensureSubscription(YunGeSession s) async {
    try {
      final profiles = ref.read(profilesProvider);
      if (profiles.isEmpty) {
        await ref
            .read(profilesActionProvider.notifier)
            .addProfileFormURL(s.subscribeUrl);
      }
    } catch (_) {
      // 注入失败不阻塞进入主界面，用户可在页面内重试
    }
  }

  Future<void> _onLoggedIn(YunGeSession s) async {
    setState(() => _session = s);
    // 登录后强制拉一次订阅
    try {
      await ref
          .read(profilesActionProvider.notifier)
          .addProfileFormURL(s.subscribeUrl);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    // 监听退出信号：退出时会自增，触发本 gate 清 session 回登录页
    ref.listen(logoutSignalProvider, (prev, next) {
      if (mounted) {
        setState(() {
          _session = null;
        });
      }
    });

    if (_checking) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D1420),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF3AA6FF)),
        ),
      );
    }
    if (_session == null) {
      return YunGeLoginPage(onLoggedIn: _onLoggedIn);
    }
    return const HomePage();
  }
}
