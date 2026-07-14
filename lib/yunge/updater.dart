// 云歌 · 应用内自动更新（下载对应平台安装包 + 安装）
//   安卓：下载 apk → open_filex 拉起系统安装器（需"安装未知应用"权限）
//   Windows：下载 setup.exe → 打开运行安装
//   macOS：下载 dmg → 打开挂载
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

class YunGeUpdater {
  /// 从 release 的 assets 里挑当前平台的安装包 URL
  static String? pickAssetUrl(List assets) {
    bool isArm64 = false;
    // 简单判断架构（安卓优先 arm64）
    for (final a in assets) {
      final name = '${a['name'] ?? ''}'.toLowerCase();
      final url = '${a['browser_download_url'] ?? ''}';
      if (Platform.isAndroid) {
        if (name.endsWith('arm64-v8a.apk')) return url;
      } else if (Platform.isWindows) {
        if (name.contains('windows') && name.endsWith('setup.exe')) return url;
      } else if (Platform.isMacOS) {
        if (name.endsWith('.dmg')) return url;
      }
    }
    // 安卓回退：任意 apk
    if (Platform.isAndroid) {
      for (final a in assets) {
        final name = '${a['name'] ?? ''}'.toLowerCase();
        if (name.endsWith('.apk')) return '${a['browser_download_url']}';
      }
    }
    // Windows 回退：zip
    if (Platform.isWindows) {
      for (final a in assets) {
        final name = '${a['name'] ?? ''}'.toLowerCase();
        if (name.contains('windows') && name.endsWith('.zip')) {
          return '${a['browser_download_url']}';
        }
      }
    }
    // ignore: unused_local_variable
    isArm64;
    return null;
  }

  /// 下载安装包并安装，onProgress: 0~1
  static Future<void> downloadAndInstall(
    String url, {
    void Function(double progress)? onProgress,
  }) async {
    final dir = await getTemporaryDirectory();
    final fileName = url.split('/').last;
    final savePath = '${dir.path}/$fileName';
    final dio = Dio();
    await dio.download(
      url,
      savePath,
      onReceiveProgress: (received, total) {
        if (total > 0 && onProgress != null) {
          onProgress(received / total);
        }
      },
    );
    // 打开安装包（安卓拉起安装器，桌面运行安装程序）
    await OpenFilex.open(savePath);
  }
}

/// 更新进度对话框：显示下载进度，下完自动打开安装
class YunGeUpdateProgressDialog extends StatefulWidget {
  final String url;
  const YunGeUpdateProgressDialog({super.key, required this.url});

  @override
  State<YunGeUpdateProgressDialog> createState() =>
      _YunGeUpdateProgressDialogState();
}

class _YunGeUpdateProgressDialogState
    extends State<YunGeUpdateProgressDialog> {
  double _progress = 0;
  String? _err;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      await YunGeUpdater.downloadAndInstall(
        widget.url,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (mounted) setState(() => _done = true);
    } catch (e) {
      if (mounted) setState(() => _err = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('正在更新'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_err != null)
            Text('更新失败：$_err',
                style: const TextStyle(color: Colors.red))
          else ...[
            LinearProgressIndicator(
              value: _progress,
              color: const Color(0xFF07C160),
              backgroundColor: const Color(0xFFE5E8EB),
            ),
            const SizedBox(height: 12),
            Text(
              _done
                  ? '下载完成，请按提示完成安装'
                  : '下载中 ${(_progress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ],
      ),
      actions: [
        if (_err != null || _done)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
      ],
    );
  }
}
