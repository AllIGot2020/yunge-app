# 云歌定制说明（基于 FlClash）

本仓库 fork 自 [chen08209/FlClash](https://github.com/chen08209/FlClash)，改造为「云歌看世界」机场客户端。
所有云歌专属代码集中在 `lib/yunge/`，方便同步上游、最小侵入。

## 改动清单

### 新增（lib/yunge/）
- `v2board.dart` — V2board 接口对接（登录 / 用户信息 / 拼订阅 URL）
- `auth_store.dart` — 登录态持久化（SharedPreferences）
- `login_page.dart` — 账号密码登录页（金属徽章 UI）
- `auth_gate.dart` — 登录门控：未登录→登录页；登录成功→注入订阅→主界面

### 接入点
- `lib/application.dart` — `child: const HomePage()` 改为 `const YunGeAuthGate()`

### 品牌
- 安卓显示名：`android/app/src/main/AndroidManifest.xml` → 云歌看世界
- Windows 窗口标题：`windows/runner/main.cpp` → 云歌看世界
- 默认主色：`lib/common/constant.dart` `defaultPrimaryColor` → 0xFF3AA6FF（科技蓝）
- macOS 显示名保持 FlClash（Mac 主力是 Tauri 版，此为备用）

### 未改（重要）
- `appName` 常量、helper service 名、socket/pipe/isolate 名 **保持 FlClash** —— 内部标识，改了会破坏内核通信
- 应用图标暂用默认 —— 后续用 flutter_launcher_icons + 云歌 YG 徽章一键替换（增强项）

## V2board 接口

| 用途 | 地址 |
|------|------|
| 登录 | `POST https://www.israelpost-co.org/api/v1/passport/auth/login` |
| 用户信息 | `GET /api/v1/user/info`（header Authorization: auth_data） |
| 订阅 | `https://www.aomozm.com/api/v1/client/subscribe?token={token}&flag=clash` |

## 登录→连接闭环

登录成功 → `YunGeApi.login` 拿 token/auth_data → 存 SharedPreferences →
`profilesActionProvider.addProfileFormURL(订阅URL)` 注入 FlClash profile →
FlClash 自动下载订阅、解析节点 → 用户点连接即用。

## 构建

沿用 FlClash 的 `.github/workflows/build.yaml`，打 tag `v*` 触发三端构建。
