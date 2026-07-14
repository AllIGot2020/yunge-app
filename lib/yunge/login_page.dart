// 云歌 · 登录页
import 'package:flutter/material.dart';
import 'v2board.dart';
import 'auth_store.dart';

class YunGeLoginPage extends StatefulWidget {
  /// 登录成功回调，把会话交回上层去注入订阅
  final Future<void> Function(YunGeSession session) onLoggedIn;
  const YunGeLoginPage({super.key, required this.onLoggedIn});

  @override
  State<YunGeLoginPage> createState() => _YunGeLoginPageState();
}

class _YunGeLoginPageState extends State<YunGeLoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _err;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final pwd = _password.text;
    if (email.isEmpty || pwd.isEmpty) {
      setState(() => _err = '请输入邮箱和密码');
      return;
    }
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final auth = await YunGeApi.login(email, pwd);
      final session = YunGeSession(
        email: email,
        token: auth.token,
        authData: auth.authData,
      );
      await YunGeAuthStore.save(session);
      await widget.onLoggedIn(session);
    } catch (e) {
      setState(() => _err = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1420),
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _YunGeBadge(size: 84),
                  const SizedBox(height: 18),
                  const Text(
                    '云歌看世界',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '连接世界，畅快体验',
                    style: TextStyle(color: Color(0xFF8EA0C0), fontSize: 13),
                  ),
                  const SizedBox(height: 28),
                  _field(_email, '邮箱', TextInputType.emailAddress, false),
                  const SizedBox(height: 12),
                  _field(_password, '密码', TextInputType.text, true),
                  if (_err != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _err!,
                      style: const TextStyle(
                        color: Color(0xFFFF5C5C),
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: FilledButton(
                      onPressed: _loading ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF3AA6FF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              '登 录',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String hint,
    TextInputType kt,
    bool obscure,
  ) {
    return TextField(
      controller: c,
      keyboardType: kt,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      cursorColor: const Color(0xFF3AA6FF),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF5A6B85)),
        filled: true,
        fillColor: const Color(0xFF141F30),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF2A3A58)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF3AA6FF)),
        ),
      ),
    );
  }
}

/// 金属徽章 YG（与 Mac 版一致的视觉）
class _YunGeBadge extends StatelessWidget {
  final double size;
  const _YunGeBadge({this.size = 72});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: Alignment(-0.2, -0.3),
          colors: [Color(0xFFEAF2FF), Color(0xFF5F728F), Color(0xFF33425C)],
          stops: [0.0, 0.55, 1.0],
        ),
        boxShadow: [
          BoxShadow(color: Color(0x66000000), blurRadius: 20, offset: Offset(0, 8)),
        ],
      ),
      child: Center(
        child: Text(
          'YG',
          style: TextStyle(
            fontSize: size * 0.36,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF3AA6FF),
            shadows: const [
              Shadow(color: Color(0xFF2FE6FF), blurRadius: 8),
            ],
          ),
        ),
      ),
    );
  }
}
