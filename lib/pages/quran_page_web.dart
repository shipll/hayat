import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/app_controller.dart';
import '../theme/app_theme.dart';

class QuranPage extends StatelessWidget {
  const QuranPage({super.key});

  @override
  Widget build(BuildContext context) {
    final appController = Get.find<AppController>();

    return Obx(() {
      final isNightMode = appController.isNightMode.value;
      final backgroundColor = isNightMode
          ? Colors.black
          : AppTheme.backgroundLight;
      final textColor = isNightMode ? Colors.white : Colors.black;
      final mutedTextColor = textColor.withValues(alpha: 0.7);
      final goldColor = isNightMode ? AppTheme.goldNight : AppTheme.goldLight;
      final theme = isNightMode
          ? ThemeData.dark(useMaterial3: true)
          : ThemeData.light(useMaterial3: true);

      return Theme(
        data: theme.copyWith(
          scaffoldBackgroundColor: backgroundColor,
          colorScheme: theme.colorScheme.copyWith(
            primary: goldColor,
            secondary: goldColor,
            surface: backgroundColor,
            onSurface: textColor,
          ),
        ),
        child: Scaffold(
          backgroundColor: backgroundColor,
          body: SafeArea(
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: goldColor,
                          foregroundColor: isNightMode
                              ? Colors.black
                              : Colors.white,
                        ),
                        onPressed: () => appController.navigateToPage(0),
                        icon: const Icon(Icons.home_rounded),
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.menu_book_rounded,
                      color: goldColor,
                      size: 64,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'صفحة المصحف الكاملة تعمل على Android و iOS.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'أنت تشغل التطبيق الآن على Web/Chrome، ومكتبة المصحف والتفسير تستخدم SQLite/FFI وهي غير مدعومة على الويب. شغل التطبيق على الهاتف أو المحاكي لرؤية المصحف الكامل.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: mutedTextColor,
                        fontSize: 16,
                        height: 1.7,
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}
