import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/app_controller.dart';
import '../../theme/app_theme.dart';

class UserNamePage extends StatefulWidget {
  const UserNamePage({super.key});

  @override
  State<UserNamePage> createState() => _UserNamePageState();
}

class _UserNamePageState extends State<UserNamePage> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    await Get.find<AppController>().setUserName(name);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goldColor = theme.hayahGold;

    return Scaffold(
      backgroundColor: AppTheme.splashBackground,
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: AppTheme.space6,
                vertical: AppTheme.space8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.mosque, color: goldColor, size: AppTheme.iconXl),
                  SizedBox(height: AppTheme.space5),
                  Text(
                    'user_name_title'.tr,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: AppTheme.onSplash,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: AppTheme.space2),
                  Text(
                    'user_name_subtitle'.tr,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.onSplashMuted,
                      height: AppTheme.textHeightRelaxed,
                    ),
                  ),
                  SizedBox(height: AppTheme.space7),
                  TextField(
                    controller: _nameController,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _saveName(),
                    style: TextStyle(color: AppTheme.onSplash),
                    decoration: InputDecoration(
                      labelText: 'your_name'.tr,
                      labelStyle: TextStyle(color: AppTheme.onSplashMuted),
                      filled: true,
                      fillColor: AppTheme.onSplash.withValues(
                        alpha: AppTheme.alphaLow,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        borderSide: BorderSide(
                          color: AppTheme.onSplash.withValues(
                            alpha: AppTheme.alphaBorder,
                          ),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        borderSide: BorderSide(color: goldColor),
                      ),
                    ),
                  ),
                  SizedBox(height: AppTheme.space5),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: goldColor,
                      foregroundColor: AppTheme.splashBackground,
                      padding: EdgeInsets.symmetric(vertical: AppTheme.space4),
                    ),
                    onPressed: _saveName,
                    icon: const Icon(Icons.check_rounded),
                    label: Text(
                      'continue'.tr,
                      style: const TextStyle(fontWeight: FontWeight.bold),
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
}
