import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../services/qibla_service.dart';
import '../../theme/app_theme.dart';
import '../auth/user_name_gate.dart';

class StartupSplash extends StatefulWidget {
  const StartupSplash({super.key});

  @override
  State<StartupSplash> createState() => _StartupSplashState();
}

class _StartupSplashState extends State<StartupSplash> {
  Timer? _timer;
  bool _showApp = false;
  bool _checkedCompassSupport = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _timer = Timer(AppTheme.splashDuration, () {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        if (!mounted) return;
        setState(() => _showApp = true);
        _showCompassSupportNotice();
      });
    });
  }

  Future<void> _showCompassSupportNotice() async {
    if (_checkedCompassSupport) return;
    _checkedCompassSupport = true;

    final supported = await Get.find<QiblaService>().supportsCompass();
    if (!mounted || supported) return;

    Get.snackbar(
      'qibla'.tr,
      'qibla_startup_no_sensor'.tr,
      snackPosition: SnackPosition.BOTTOM,
      duration: AppTheme.longSnackDuration,
      margin: EdgeInsets.all(AppTheme.space4),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showApp) {
      return const UserNameGate();
    }

    return ColoredBox(
      color: AppTheme.splashBackground,
      child: Center(
        child: Image.asset(
          AppTheme.splashAsset,
          width: MediaQuery.sizeOf(context).width,
          height: MediaQuery.sizeOf(context).height,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
