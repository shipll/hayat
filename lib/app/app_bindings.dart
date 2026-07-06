import 'package:get/get.dart';

import '../controllers/app_controller.dart';
import '../controllers/prayer_controller.dart';
import '../controllers/quran_controller.dart';
import '../services/audio_service.dart';
import '../services/memorization_speech_service.dart';
import '../services/notification_service.dart';
import '../services/prayer_service.dart';
import '../services/qibla_service.dart';
import '../services/quran_service.dart';
import '../services/storage_service.dart';

class AppBindings extends Bindings {
  @override
  void dependencies() {
    final storage = Get.find<StorageService>();

    Get.put(NotificationService(storage), permanent: true);
    Get.put(PrayerService(storage), permanent: true);
    Get.put(QuranService(storage), permanent: true);
    Get.put(QuranAudioService(), permanent: true);
    Get.put(MemorizationSpeechService(), permanent: true);
    Get.put(QiblaService(), permanent: true);
    Get.put(AppController(storage), permanent: true);
    Get.put(
      PrayerController(
        Get.find<PrayerService>(),
        Get.find<NotificationService>(),
      ),
      permanent: true,
    );
    Get.lazyPut(
      () => QuranController(
        Get.find<QuranService>(),
        Get.find<QuranAudioService>(),
      ),
      fenix: true,
    );
  }
}
