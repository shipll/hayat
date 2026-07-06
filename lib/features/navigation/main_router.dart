import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../controllers/app_controller.dart';
import '../../pages/home_page.dart';
import '../../pages/profile_page.dart';
import '../../pages/quran_page.dart';
import '../../pages/salat_page.dart';
import '../../pages/sunnah_page.dart';

class MainRouter extends StatelessWidget {
  const MainRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppController>();

    return Obx(() {
      final pageIndex = controller.activePageIndex.value;
      final page = switch (pageIndex) {
        1 => const SalatPage(),
        2 => const QuranPage(),
        3 => const SunnahPage(),
        5 => const ProfilePage(),
        _ => const HomePage(),
      };

      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        reverseDuration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          if (controller.pageNavigationMode.value == PageNavigationMode.fold) {
            return FadeTransition(
              opacity: animation,
              child: SizeTransition(
                sizeFactor: animation,
                axis: Axis.horizontal,
                axisAlignment: 0,
                child: child,
              ),
            );
          }

          final offsetAnimation = Tween<Offset>(
            begin: const Offset(0.08, 0),
            end: Offset.zero,
          ).animate(animation);

          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: offsetAnimation, child: child),
          );
        },
        child: KeyedSubtree(key: ValueKey<int>(pageIndex), child: page),
      );
    });
  }
}
