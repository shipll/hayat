import 'package:get/get.dart';

import '../../features/auth/user_name_page.dart';
import '../../features/navigation/main_router.dart';
import '../../features/splash/startup_splash.dart';
import 'app_routes.dart';

class AppPages {
  const AppPages._();

  static final pages = <GetPage<dynamic>>[
    GetPage(name: AppRoutes.splash, page: () => const StartupSplash()),
    GetPage(name: AppRoutes.userName, page: () => const UserNamePage()),
    GetPage(name: AppRoutes.main, page: () => const MainRouter()),
  ];
}
