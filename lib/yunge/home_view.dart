// 云歌 · 商业化首页（照参考图：大电源键 + IP检测 + 上下行卡 + 会员套餐卡）
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'user_provider.dart';
import 'pay_page.dart';
import 'auth_store.dart';

// 主题强调色（跟随 FlClash 原生淡调，取稍深的莫兰迪色保证对比度）
const _green = Color(0xFFB08B8F);
const _greenDark = Color(0xFF8F6B70);
const _blue = Color(0xFF3A8CFF);

class YunGeHomeView extends ConsumerStatefulWidget {
  const YunGeHomeView({super.key});

  @override
  ConsumerState<YunGeHomeView> createState() => _YunGeHomeViewState();
}

class _YunGeHomeViewState extends ConsumerState<YunGeHomeView> {
  @override
  void initState() {
    super.initState();
    // 首帧后拉会员信息 + 触发 IP 检测
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(userInfoProvider.notifier).refresh();
      ref.read(checkIpNumProvider.notifier).add();
    });
  }

  void _toggleConnect() {
    final isStart = ref.read(isStartProvider);
    // 开启加速前，强制确保系统代理已打开——否则核心起来了但流量没被接管，
    // 会出现「界面显示已连接但没网、要手动去托盘勾系统代理」的问题。
    if (!isStart) {
      final systemProxyOn = ref.read(
        networkSettingProvider.select((s) => s.systemProxy),
      );
      if (!systemProxyOn) {
        ref
            .read(networkSettingProvider.notifier)
            .update((s) => s.copyWith(systemProxy: true));
      }
    }
    ref
        .read(setupActionProvider.notifier)
        .updateStatus(!isStart, isInit: !ref.read(initProvider));
  }

  Future<void> _openRenew() async {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const YunGePayPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isStart = ref.watch(isStartProvider);
    final coreStatus = ref.watch(coreStatusProvider);

    return Container(
      color: const Color(0xFFF4F6F8),
      child: SafeArea(
        child: Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _topBar(coreStatus),
                const SizedBox(height: 12),
                _statusText(isStart),
                const SizedBox(height: 10),
                _powerButton(isStart),
                const SizedBox(height: 14),
                _ipDetection(),
                const SizedBox(height: 14),
                _trafficRow(),
                const SizedBox(height: 12),
                _memberCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 顶部：云歌 + 核心运行状态胶囊
  Widget _topBar(CoreStatus status) {
    final running = status == CoreStatus.connected;
    final connecting = status == CoreStatus.connecting;
    final label = connecting
        ? '核心启动中'
        : running
            ? '核心运行中'
            : '核心未运行';
    final color = running ? _green : (connecting ? Colors.orange : Colors.grey);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          '云歌',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, size: 14, color: color),
                  const SizedBox(width: 4),
                  Text(label, style: TextStyle(fontSize: 12, color: color)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _confirmLogout,
              icon: const Icon(Icons.logout, size: 20, color: Colors.grey),
              tooltip: '退出登录',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出当前账号吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('退出', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    // 断开连接 + 清订阅 + 清登录态
    try {
      if (ref.read(isStartProvider)) {
        await ref
            .read(setupActionProvider.notifier)
            .updateStatus(false, isInit: false);
      }
    } catch (_) {}
    try {
      // 删除所有 profile，避免下个账号看到上个账号的订阅
      final profiles = ref.read(profilesProvider);
      for (final p in profiles) {
        ref.read(profilesProvider.notifier).del(p.id);
      }
    } catch (_) {}
    await YunGeAuthStore.clear();
    ref.read(logoutSignalProvider.notifier).trigger();
  }

  Widget _statusText(bool isStart) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isStart ? '已开启加速' : '未连接',
            style: TextStyle(
              fontSize: 15,
              color: isStart ? _greenDark : Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isStart ? _green : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  // 大圆电源键（带光环）
  Widget _powerButton(bool isStart) {
    return Center(
      child: GestureDetector(
        onTap: _toggleConnect,
        child: Container(
          width: 150,
          height: 150,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: isStart
                  ? [const Color(0xFFF0E4E5), const Color(0xFFF4F6F8)]
                  : [const Color(0xFFECEFF2), const Color(0xFFF4F6F8)],
              stops: const [0.6, 1.0],
            ),
          ),
          child: Center(
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isStart
                      ? [_green, _greenDark]
                      : [const Color(0xFFB8C0CC), const Color(0xFF9AA5B4)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isStart ? _green : Colors.grey)
                        .withValues(alpha: 0.4),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.power_settings_new,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 当前出口 IP
  Widget _ipDetection() {
    final detection = ref.watch(networkDetectionProvider);
    final ipInfo = detection.ipInfo;
    final loading = detection.isLoading;
    final text = loading
        ? '检测IP中…'
        : (ipInfo != null ? ipInfo.ip : '未检测到出口IP');
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '当前地址',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => ref.read(checkIpNumProvider.notifier).add(),
              child: const Icon(Icons.refresh, size: 15, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
      ],
    );
  }

  // 上传/下载卡
  Widget _trafficRow() {
    final traffics = ref.watch(trafficsProvider).list;
    final last = traffics.isEmpty ? const Traffic() : traffics.last;
    return Row(
      children: [
        Expanded(
          child: _speedCard(
            icon: Icons.arrow_upward,
            color: _green,
            label: '上传',
            speed: '${last.up.traffic.show}/s',
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _speedCard(
            icon: Icons.arrow_downward,
            color: _blue,
            label: '下载',
            speed: '${last.down.traffic.show}/s',
          ),
        ),
      ],
    );
  }

  Widget _speedCard({
    required IconData icon,
    required Color color,
    required String label,
    required String speed,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color(0x0F000000), blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 2),
              Text(
                speed,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 会员套餐卡
  Widget _memberCard() {
    final us = ref.watch(userInfoProvider);
    final info = us.info;
    final planName = info?.planName ?? (info?.planId != null ? '已订阅套餐' : '暂无套餐');

    // 流量优先用 FlClash 从订阅头解析的真实数据（user/info 不返回 u/d）
    final sub = ref.watch(currentProfileProvider)?.subscriptionInfo;
    final total = sub != null && sub.total > 0
        ? sub.total
        : (info?.transferEnable ?? 0);
    final used = sub != null
        ? (sub.upload + sub.download)
        : (info?.used ?? 0);
    // 到期：订阅头 expire（秒）优先，回退 user/info
    final expireTs = (sub != null && sub.expire > 0)
        ? sub.expire
        : info?.expiredAt;

    final totalText = total > 0 ? _gb(total) : '—';
    final usedText = _gb(used);
    final expire = _expireText(expireTs);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _memberCell('会员套餐', planName),
              _divider(),
              _memberCell('流量情况', totalText, sub: '已用 $usedText'),
              _divider(),
              _memberCell('到期时间', expire),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _openRenew,
            child: RichText(
              text: const TextSpan(
                text: '续费或升级套餐，享受更多优惠 ',
                style: TextStyle(fontSize: 13, color: _greenDark),
                children: [
                  TextSpan(
                    text: '→',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _memberCell(String label, String value, {String? sub}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
        if (sub != null) ...[
          const SizedBox(height: 2),
          Text(sub, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ],
    );
  }

  Widget _divider() =>
      Container(width: 1, height: 34, color: const Color(0xFFEEEEEE));

  String _gb(int bytes) {
    final gb = bytes / 1024 / 1024 / 1024;
    if (gb < 0.01 && bytes > 0) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)}MB';
    }
    return '${gb.toStringAsFixed(2)}GB';
  }

  String _expireText(int? ts) {
    if (ts == null) return '长期';
    final d = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}
