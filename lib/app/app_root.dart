import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../controllers/app_controller.dart';
import '../localization/app_translations.dart';
import '../theme/app_theme.dart';
import 'routes/app_pages.dart';
import 'routes/app_routes.dart';

class HayahApp extends StatelessWidget {
  const HayahApp({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppController>();

    return ScreenUtilInit(
      designSize: AppTheme.designSize,
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (_, _) => Obx(
        () => GetMaterialApp(
          title: 'title'.tr,
          debugShowCheckedModeBanner: false,
          translations: AppTranslations(),
          locale: Locale(controller.currentLanguage.value),
          fallbackLocale: AppTheme.fallbackLocale,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.nightTheme,
          themeMode: controller.isNightMode.value
              ? ThemeMode.dark
              : ThemeMode.light,
          initialRoute: AppRoutes.splash,
          getPages: AppPages.pages,
        ),
      ),
    );
  }
}
