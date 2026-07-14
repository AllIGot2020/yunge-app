// 云歌 · 会员信息状态（新版 Riverpod Notifier，不走 codegen）
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'v2board.dart';
import 'auth_store.dart';

class UserInfoState {
  final UserInfo? info;
  final bool loading;
  final String? error;
  const UserInfoState({this.info, this.loading = false, this.error});

  UserInfoState copyWith({UserInfo? info, bool? loading, String? error}) =>
      UserInfoState(
        info: info ?? this.info,
        loading: loading ?? this.loading,
        error: error,
      );
}

class UserInfoNotifier extends Notifier<UserInfoState> {
  @override
  UserInfoState build() => const UserInfoState();

  Future<void> refresh() async {
    final session = await YunGeAuthStore.load();
    if (session == null || session.authData.isEmpty) {
      state = const UserInfoState(error: '未登录');
      return;
    }
    state = state.copyWith(loading: true, error: null);
    try {
      final info = await YunGeApi.getUserInfo(session.authData);
      state = UserInfoState(info: info, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: '$e');
    }
  }
}

final userInfoProvider =
    NotifierProvider<UserInfoNotifier, UserInfoState>(UserInfoNotifier.new);
