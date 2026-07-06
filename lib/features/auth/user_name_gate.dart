import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../controllers/app_controller.dart';
import '../navigation/main_router.dart';
import 'user_name_page.dart';

class UserNameGate extends StatelessWidget {
  const UserNameGate({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppController>();

    return Obx(
      () => controller.hasUserName ? const MainRouter() : const UserNamePage(),
    );
  }
}
