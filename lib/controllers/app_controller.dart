import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../controllers/prayer_controller.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class AppController extends GetxController {
  AppController(this._storage);

  final StorageService _storage;
  StreamSubscription<String>? _notificationPayloadSub;
  Timer? _dayTicker;
  NotificationService get _notificationService =>
      Get.find<NotificationService>();

  static const _dhikrAssetPath = 'assets/data/daily_dhikr.json';
  static const _selectedDailyDhikrDateKey = 'selected_daily_dhikr_date';
  static const _selectedDailyDhikrIdKey = 'selected_daily_dhikr_id';
  static const _selectedDailyDhikrPoolSizeKey =
      'selected_daily_dhikr_pool_size';

  static const List<DailyDhikr> _fallbackDailyDhikrItems = [
    DailyDhikr(
      id: 0,
      text: 'سبحان الله وبحمده',
      reference: 'ذكر عظيم يملأ القلب تسبيحا وشكرا لله.',
    ),
    DailyDhikr(
      id: 1,
      text:
          'لا إله إلا الله وحده لا شريك له، له الملك وله الحمد وهو على كل شيء قدير',
      reference: 'ذكر يجدد معنى التوحيد والتوكل.',
    ),
    DailyDhikr(
      id: 2,
      text: 'أستغفر الله العظيم وأتوب إليه',
      reference: 'استغفار يفتح باب الرجوع إلى الله.',
    ),
    DailyDhikr(
      id: 3,
      text: 'اللهم صل وسلم على نبينا محمد',
      reference: 'صلاة وسلام على رسول الله صلى الله عليه وسلم.',
    ),
    DailyDhikr(
      id: 4,
      text: 'لا حول ولا قوة إلا بالله',
      reference: 'ذكر يرسخ الافتقار إلى عون الله.',
    ),
  ];

  final RxList<DailyDhikr> dailyDhikrItems =
      List<DailyDhikr>.of(_fallbackDailyDhikrItems).obs;

  // Navigation / Route state
  // 0: Home, 1: Salat, 2: Quran, 3: Sunnah, 5: Profile
  final RxInt activePageIndex = 0.obs;

  // Language state
  late final RxString currentLanguage;

  // Theme state
  late final RxBool isNightMode;

  // User profile state
  late final RxString userName;

  // Page transition preference
  late final Rx<PageNavigationMode> pageNavigationMode;

  // Dhikr reminders
  late final RxBool dhikrReminderEnabled;
  late final Rx<DhikrReminderMode> dhikrReminderMode;
  late final RxInt dhikrDailyTarget;
  late final RxInt dhikrCompletedCount;
  late final RxString dhikrCompletionDate;
  late final RxInt selectedDhikrId;

  // App simulation states
  final RxInt tasbihCount = 11.obs; // out of 33 (33%)
  final RxDouble prayerProgress = 0.75.obs; // 75% progress to Maghrib
  final RxString currentDayKey = ''.obs;

  @override
  void onInit() {
    super.onInit();
    currentLanguage = _storage.read<String>('language', 'en').obs;
    isNightMode = _storage.read<bool>('night_mode', true).obs;
    userName = _storage.read<String>('user_name', '').obs;
    pageNavigationMode = _readPageNavigationMode().obs;
    dhikrReminderEnabled = _storage
        .read<bool>('dhikr_reminder_enabled', false)
        .obs;
    dhikrReminderMode = _readDhikrReminderMode().obs;
    dhikrDailyTarget = _storage.read<int>('dhikr_daily_target', 3).obs;
    dhikrCompletedCount = _storage.read<int>('dhikr_completed_count', 0).obs;
    dhikrCompletionDate = _storage
        .read<String>('dhikr_completion_date', '')
        .obs;
    _resetDhikrProgressIfNeeded();
    selectedDhikrId = _storage
        .read<int>(_selectedDailyDhikrIdKey, _fallbackDailyDhikrItems.first.id)
        .obs;
    unawaited(_loadDhikrItems());
    if (Get.isRegistered<NotificationService>()) {
      _notificationPayloadSub = _notificationService.payloads.listen(
        handleNotificationPayload,
      );
    }
    if (dhikrReminderEnabled.value && Get.isRegistered<NotificationService>()) {
      unawaited(rescheduleDhikrReminders());
    }
    _startDayTicker();
  }

  @override
  void onClose() {
    _notificationPayloadSub?.cancel();
    _dayTicker?.cancel();
    super.onClose();
  }

  bool get hasUserName => userName.value.trim().isNotEmpty;

  DailyDhikr get currentDailyDhikr {
    final id = selectedDhikrId.value;
    return dailyDhikrItems.firstWhere(
      (dhikr) => dhikr.id == id,
      orElse: () => dailyDhikrItems.first,
    );
  }

  String get currentDailyDhikrPayload => 'dhikr:${currentDailyDhikr.id}';

  String get dhikrProgressLabel =>
      '${dhikrCompletedCount.value.clamp(0, dhikrDailyTarget.value)} / ${dhikrDailyTarget.value}';

  double get dhikrProgressValue {
    if (dhikrDailyTarget.value <= 0) return 0;
    return (dhikrCompletedCount.value / dhikrDailyTarget.value).clamp(0.0, 1.0);
  }

  String get dhikrReminderModeLabel {
    return switch (dhikrReminderMode.value) {
      DhikrReminderMode.onceDaily => 'dhikr_mode_once_daily'.tr,
      DhikrReminderMode.morningEvening => 'dhikr_mode_morning_evening'.tr,
      DhikrReminderMode.afterPrayers => 'dhikr_mode_after_prayers'.tr,
    };
  }

  Future<void> setUserName(String name) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return;
    userName.value = cleanName;
    await _storage.write('user_name', cleanName);
  }

  Future<void> changeLanguage(String langCode) async {
    currentLanguage.value = langCode;
    await _storage.write('language', langCode);
    Get.updateLocale(Locale(langCode));
  }

  void toggleLanguage() {
    if (currentLanguage.value == 'en') {
      changeLanguage('ar');
    } else {
      changeLanguage('en');
    }
  }

  void toggleTheme() {
    isNightMode.toggle();
    _storage.write('night_mode', isNightMode.value);
    Get.changeThemeMode(isNightMode.value ? ThemeMode.dark : ThemeMode.light);
  }

  Future<void> setDhikrReminderEnabled(bool enabled) async {
    dhikrReminderEnabled.value = enabled;
    await _storage.write('dhikr_reminder_enabled', enabled);
    if (enabled) {
      await rescheduleDhikrReminders();
    } else {
      await _notificationService.cancelDhikrReminders();
    }
  }

  Future<void> setDhikrReminderMode(DhikrReminderMode mode) async {
    dhikrReminderMode.value = mode;
    await _storage.write('dhikr_reminder_mode', mode.name);
    await rescheduleDhikrReminders();
  }

  Future<void> setDhikrDailyTarget(int target) async {
    dhikrDailyTarget.value = target;
    await _storage.write('dhikr_daily_target', target);
    if (dhikrCompletedCount.value > target) {
      dhikrCompletedCount.value = target;
      await _storage.write('dhikr_completed_count', target);
    }
  }

  Future<void> completeCurrentDhikr() async {
    _resetDhikrProgressIfNeeded();
    if (dhikrCompletedCount.value < dhikrDailyTarget.value) {
      dhikrCompletedCount.value++;
      await _storage.write('dhikr_completed_count', dhikrCompletedCount.value);
      await _storage.write('dhikr_completion_date', _todayKey());
    }
    incrementTasbih();
  }

  Future<void> rescheduleDhikrReminders() async {
    if (!Get.isRegistered<NotificationService>()) return;
    if (dhikrReminderEnabled.value) {
      await _notificationService.scheduleDhikrReminders(
        mode: dhikrReminderMode.value,
        dhikrText: currentDailyDhikr.text,
        payload: currentDailyDhikrPayload,
        prayerDay: Get.isRegistered<PrayerController>()
            ? Get.find<PrayerController>().prayerDay.value
            : null,
      );
    } else {
      await _notificationService.cancelDhikrReminders();
    }
  }

  void handleNotificationPayload(String payload) {
    if (payload.startsWith('dhikr:')) {
      final id = int.tryParse(payload.substring('dhikr:'.length));
      if (id != null) {
        selectedDhikrId.value = id;
      }
      navigateToPage(0);
      Future<void>.delayed(
        const Duration(milliseconds: 2100),
        showCurrentDhikr,
      );
      return;
    }

    if (payload.startsWith('prayer:')) {
      final prayerKey = payload.substring('prayer:'.length);
      navigateToPage(1);
      Future<void>.delayed(const Duration(milliseconds: 2100), () {
        Get.snackbar(
          'prayer_times'.tr,
          '${prayerKey.tr} - ${'notification_opened'.tr}',
          snackPosition: SnackPosition.BOTTOM,
        );
      });
    }
  }

  void showCurrentDhikr() {
    if (Get.isBottomSheetOpen == true) return;
    final dhikr = currentDailyDhikr;
    Get.bottomSheet<void>(
      _DhikrDetailSheet(dhikr: dhikr),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  void navigateToPage(int index) {
    activePageIndex.value = index;
  }

  Future<void> setPageNavigationMode(PageNavigationMode mode) async {
    pageNavigationMode.value = mode;
    await _storage.write('page_navigation_mode', mode.name);
  }

  void incrementTasbih() {
    if (tasbihCount.value < 33) {
      tasbihCount.value++;
    } else {
      tasbihCount.value = 0;
    }
  }

  DhikrReminderMode _readDhikrReminderMode() {
    final raw = _storage.read<String>(
      'dhikr_reminder_mode',
      DhikrReminderMode.onceDaily.name,
    );
    return DhikrReminderMode.values.firstWhere(
      (mode) => mode.name == raw,
      orElse: () => DhikrReminderMode.onceDaily,
    );
  }

  void _resetDhikrProgressIfNeeded() {
    final today = _todayKey();
    if (dhikrCompletionDate.value == today) return;
    dhikrCompletionDate.value = today;
    dhikrCompletedCount.value = 0;
    unawaited(_storage.write('dhikr_completion_date', today));
    unawaited(_storage.write('dhikr_completed_count', 0));
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadDhikrItems() async {
    try {
      final rawJson = await rootBundle.loadString(_dhikrAssetPath);
      final decoded = jsonDecode(rawJson);
      if (decoded is! List) return;

      final loadedItems = decoded
          .whereType<Map>()
          .map((json) => DailyDhikr.fromJson(Map<String, dynamic>.from(json)))
          .where((dhikr) => dhikr.text.trim().isNotEmpty)
          .toList(growable: false);

      if (loadedItems.isEmpty) return;

      dailyDhikrItems.assignAll(loadedItems);
      _selectDailyDhikrIfNeeded(forceWhenMissing: true);
      if (dhikrReminderEnabled.value) {
        unawaited(rescheduleDhikrReminders());
      }
    } catch (_) {
      dailyDhikrItems.assignAll(_fallbackDailyDhikrItems);
      _selectDailyDhikrIfNeeded(forceWhenMissing: true);
    }
  }

  PageNavigationMode _readPageNavigationMode() {
    final raw = _storage.read<String>(
      'page_navigation_mode',
      PageNavigationMode.slide.name,
    );
    return PageNavigationMode.values.firstWhere(
      (mode) => mode.name == raw,
      orElse: () => PageNavigationMode.slide,
    );
  }

  void _selectDailyDhikrIfNeeded({bool forceWhenMissing = false}) {
    final today = _todayKey();
    final savedDate = _storage.read<String>(_selectedDailyDhikrDateKey, '');
    final savedId = _storage.read<int>(
      _selectedDailyDhikrIdKey,
      _fallbackDailyDhikrItems.first.id,
    );
    final savedPoolSize = _storage.read<int>(
      _selectedDailyDhikrPoolSizeKey,
      0,
    );
    final currentPoolSize = dailyDhikrItems.length;
    final hasSavedDhikr = dailyDhikrItems.any((dhikr) => dhikr.id == savedId);
    final isSamePool = savedPoolSize == currentPoolSize;

    if (savedDate == today && hasSavedDhikr && isSamePool) {
      selectedDhikrId.value = savedId;
      return;
    }
    if (savedDate == today && !forceWhenMissing) return;

    final nextDhikr = _randomDailyDhikr();
    selectedDhikrId.value = nextDhikr.id;
    unawaited(_storage.write(_selectedDailyDhikrDateKey, today));
    unawaited(_storage.write(_selectedDailyDhikrIdKey, nextDhikr.id));
    unawaited(_storage.write(_selectedDailyDhikrPoolSizeKey, currentPoolSize));
  }

  DailyDhikr _randomDailyDhikr() {
    final items = dailyDhikrItems.isEmpty
        ? _fallbackDailyDhikrItems
        : dailyDhikrItems;
    final previousId = _storage.read<int>(_selectedDailyDhikrIdKey, -1);
    if (items.length == 1) return items.first;

    final random = Random();
    DailyDhikr candidate;
    do {
      candidate = items[random.nextInt(items.length)];
    } while (candidate.id == previousId);
    return candidate;
  }

  void _startDayTicker() {
    currentDayKey.value = _todayKey();
    if (_isWidgetTestBinding) return;
    _dayTicker?.cancel();
    _dayTicker = Timer.periodic(const Duration(minutes: 15), (_) {
      final today = _todayKey();
      if (currentDayKey.value == today) return;
      currentDayKey.value = today;
      _selectDailyDhikrIfNeeded();
      _resetDhikrProgressIfNeeded();
      unawaited(rescheduleDhikrReminders());
    });
  }

  bool get _isWidgetTestBinding => WidgetsBinding.instance.runtimeType
      .toString()
      .contains('TestWidgetsFlutterBinding');
}

enum PageNavigationMode { slide, fold }

class DailyDhikr {
  const DailyDhikr({
    required this.id,
    required this.text,
    required this.reference,
  });

  factory DailyDhikr.fromJson(Map<String, dynamic> json) {
    return DailyDhikr(
      id: (json['id'] as num?)?.toInt() ?? 0,
      text: json['text']?.toString() ?? '',
      reference: json['reference']?.toString() ?? '',
    );
  }

  final int id;
  final String text;
  final String reference;
}

class _DhikrDetailSheet extends StatelessWidget {
  const _DhikrDetailSheet({required this.dhikr});

  final DailyDhikr dhikr;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goldColor = theme.hayahGold;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Container(
          margin: EdgeInsets.all(AppTheme.space4),
          padding: EdgeInsets.fromLTRB(
            AppTheme.space5,
            AppTheme.space5,
            AppTheme.space5,
            AppTheme.space5,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: goldColor.withValues(alpha: 0.25)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.self_improvement, color: goldColor),
                  SizedBox(width: AppTheme.space2),
                  Expanded(
                    child: Text(
                      'daily_dhikr'.tr,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: goldColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: Get.back,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              SizedBox(height: AppTheme.space4),
              Text(
                dhikr.text,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  height: 1.7,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: AppTheme.space4),
              Text(
                dhikr.reference,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
              ),
              SizedBox(height: AppTheme.space5),
              FilledButton.icon(
                onPressed: () async {
                  await Get.find<AppController>().completeCurrentDhikr();
                  Get.back<void>();
                },
                icon: const Icon(Icons.touch_app),
                label: Text('dhikr_done'.tr),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
