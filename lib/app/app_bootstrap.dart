import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../services/quran_library_bootstrap.dart';
import '../services/storage_service.dart';
import 'app_bindings.dart';

class AppBootstrap {
  const AppBootstrap._();

  static Future<void> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();

    final storage = StorageService();
    await storage.init();
    await initQuranLibrary();

    Get.put(storage, permanent: true);
    AppBindings().dependencies();
  }
}
