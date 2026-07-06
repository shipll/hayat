import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../controllers/app_controller.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/arabesque_painter.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppController>();
    final theme = Theme.of(context);
    final goldColor = theme.hayahGold;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: ArabesqueBackground(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 100.h),
            children: [
              // --- Header ---
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.r),
                    decoration: BoxDecoration(
                      color: goldColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.person_outline, color: goldColor, size: 24.r),
                  ),
                  SizedBox(width: 12.w),
                  Text(
                    'profile'.tr,
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24.h),

              // --- Premium Profile Card ---
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(24.r),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [
                            theme.cardTheme.color ?? const Color(0x26064E3B),
                            (theme.cardTheme.color ?? const Color(0x26064E3B)).withValues(alpha: 0.4),
                          ]
                        : [
                            Colors.white,
                            theme.colorScheme.primary.withValues(alpha: 0.03),
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24.r),
                  border: Border.all(
                    color: goldColor.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: goldColor.withValues(alpha: isDark ? 0.04 : 0.06),
                      blurRadius: 20.r,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: Column(
                  children: [
                    // Avatar stack with edit action overlay
                    GestureDetector(
                      onTap: () => _showEditNameSheet(context, controller),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Outer glowing ring
                            Container(
                              width: 116.r,
                              height: 116.r,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: goldColor.withValues(alpha: 0.15),
                                  width: 2,
                                ),
                              ),
                            ),
                            // Middle decorative ring
                            Container(
                              width: 104.r,
                              height: 104.r,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: goldColor.withValues(alpha: 0.35),
                                  width: 1.5,
                                ),
                              ),
                            ),
                            // Main Avatar Container
                            Container(
                              width: 92.r,
                              height: 92.r,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    goldColor.withValues(alpha: 0.25),
                                    goldColor.withValues(alpha: 0.05),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Icon(
                                Icons.person_rounded,
                                color: goldColor,
                                size: 48.r,
                              ),
                            ),
                            // Edit Icon Overlay
                            Positioned(
                              bottom: 2.r,
                              right: 2.r,
                              child: Container(
                                padding: EdgeInsets.all(6.r),
                                decoration: BoxDecoration(
                                  color: goldColor,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.2),
                                      blurRadius: 4.r,
                                      offset: const Offset(0, 2),
                                    )
                                  ],
                                ),
                                child: Icon(
                                  Icons.edit,
                                  color: isDark ? Colors.black : Colors.white,
                                  size: 14.r,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Obx(
                      () => Text(
                        controller.userName.value.isNotEmpty
                            ? controller.userName.value
                            : 'Omar',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      'sojourners'.tr.toUpperCase(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: goldColor,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 36.h),

              // --- General Settings Section ---
              _buildSectionHeader(theme, 'settings'.tr, goldColor),
              SizedBox(height: 16.h),

              Obx(
                () => _SettingsCard(
                  icon: Icons.badge_outlined,
                  title: 'name'.tr,
                  subtitle: controller.userName.value,
                  goldColor: goldColor,
                  onTap: () => _showEditNameSheet(context, controller),
                  trailing: Container(
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: goldColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Text(
                      'edit'.tr,
                      style: TextStyle(
                        color: goldColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12.sp,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 14.h),

              _SettingsCard(
                icon: Icons.language,
                title: 'language'.tr,
                subtitle: controller.currentLanguage.value == 'en' ? 'lang_en'.tr : 'lang_ar'.tr,
                goldColor: goldColor,
                onTap: controller.toggleLanguage,
                trailing: Obx(
                  () => OutlinedButton(
                    onPressed: controller.toggleLanguage,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: goldColor,
                      side: BorderSide(color: goldColor.withValues(alpha: 0.6)),
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 8.h,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: Text(
                      controller.currentLanguage.value == 'en' ? 'AR' : 'EN',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 14.h),

              Obx(
                () => _SettingsCard(
                  icon: controller.isNightMode.value
                      ? Icons.dark_mode_outlined
                      : Icons.light_mode_outlined,
                  title: 'appearance'.tr,
                  subtitle: controller.isNightMode.value
                      ? 'theme_night'.tr
                      : 'theme_light'.tr,
                  goldColor: goldColor,
                  trailing: Switch.adaptive(
                    value: controller.isNightMode.value,
                    activeColor: goldColor,
                    onChanged: (_) => controller.toggleTheme(),
                  ),
                ),
              ),
              SizedBox(height: 14.h),

              Obx(
                () => _SettingsCard(
                  icon: Icons.view_carousel_outlined,
                  title: 'page_navigation'.tr,
                  subtitle:
                      controller.pageNavigationMode.value ==
                          PageNavigationMode.slide
                      ? 'page_navigation_slide'.tr
                      : 'page_navigation_fold'.tr,
                  goldColor: goldColor,
                  trailing: _NavigationModeToggle(
                    goldColor: goldColor,
                    value: controller.pageNavigationMode.value,
                    onChanged: controller.setPageNavigationMode,
                  ),
                ),
              ),
              SizedBox(height: 36.h),

              // --- Spiritual Reminders Section ---
              _buildSectionHeader(theme, 'dhikr_reminders'.tr, goldColor),
              SizedBox(height: 16.h),

              Obx(
                () => _DhikrSettingsCard(
                  goldColor: goldColor,
                  controller: controller,
                  isEnabled: controller.dhikrReminderEnabled.value,
                  reminderMode: controller.dhikrReminderMode.value,
                  dailyTarget: controller.dhikrDailyTarget.value,
                  reminderModeLabel: controller.dhikrReminderModeLabel,
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 5),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title, Color goldColor) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Row(
        children: [
          Container(
            width: 4.w,
            height: 16.h,
            decoration: BoxDecoration(
              color: goldColor,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(width: 8.w),
          Text(
            title.toUpperCase(),
            style: theme.textTheme.labelMedium?.copyWith(
              color: goldColor,
              fontSize: 12.sp,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

void _showEditNameSheet(BuildContext context, AppController controller) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _EditNameSheet(controller: controller),
  );
}

class _EditNameSheet extends StatefulWidget {
  const _EditNameSheet({required this.controller});

  final AppController controller;

  @override
  State<_EditNameSheet> createState() => _EditNameSheetState();
}

class _EditNameSheetState extends State<_EditNameSheet> {
  late final TextEditingController _nameController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.controller.userName.value,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);
    final navigator = Navigator.of(context);
    await widget.controller.setUserName(_nameController.text);
    if (!mounted) return;
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goldColor = theme.hayahGold;
    final isDark = theme.brightness == Brightness.dark;
    final textDirection = widget.controller.currentLanguage.value == 'ar'
        ? TextDirection.rtl
        : TextDirection.ltr;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(28.r),
            topRight: Radius.circular(28.r),
          ),
          border: Border(
            top: BorderSide(
              color: goldColor.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20.r,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Directionality(
            textDirection: textDirection,
            child: Padding(
              padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 24.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Grabber Handle
                  Center(
                    child: Container(
                      width: 48.w,
                      height: 5.h,
                      margin: EdgeInsets.only(bottom: 22.h),
                      decoration: BoxDecoration(
                        color: goldColor.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2.5.r),
                      ),
                    ),
                  ),
                  Text(
                    'edit_name'.tr,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 18.h),
                  TextField(
                    controller: _nameController,
                    autofocus: true,
                    enabled: !_isSaving,
                    textInputAction: TextInputAction.done,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    onSubmitted: (_) => _saveName(),
                    decoration: InputDecoration(
                      labelText: 'your_name'.tr,
                      labelStyle: TextStyle(
                        color: goldColor.withValues(alpha: 0.8),
                      ),
                      floatingLabelStyle: TextStyle(
                        color: goldColor,
                        fontWeight: FontWeight.bold,
                      ),
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withValues(alpha: 0.03)
                          : Colors.black.withValues(alpha: 0.02),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16.r),
                        borderSide: BorderSide(
                          color: goldColor.withValues(alpha: 0.3),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16.r),
                        borderSide: BorderSide(
                          color: goldColor.withValues(alpha: 0.3),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16.r),
                        borderSide: BorderSide(
                          color: goldColor,
                          width: 2,
                        ),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 18.w,
                        vertical: 16.h,
                      ),
                    ),
                  ),
                  SizedBox(height: 20.h),
                  FilledButton(
                    onPressed: _isSaving ? null : _saveName,
                    style: FilledButton.styleFrom(
                      backgroundColor: goldColor,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      elevation: 2,
                    ),
                    child: _isSaving
                        ? SizedBox(
                            width: 20.r,
                            height: 20.r,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: isDark ? Colors.black : Colors.white,
                            ),
                          )
                        : Text(
                            'save'.tr,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
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

class _SettingsCard extends StatefulWidget {
  const _SettingsCard({
    required this.icon,
    required this.title,
    required this.goldColor,
    required this.trailing,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color goldColor;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  State<_SettingsCard> createState() => _SettingsCardState();
}

class _SettingsCardState extends State<_SettingsCard> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTapDown: (_) => widget.onTap != null ? _animController.forward() : null,
        onTapUp: (_) {
          if (widget.onTap != null) {
            _animController.reverse();
            widget.onTap!();
          }
        },
        onTapCancel: () => widget.onTap != null ? _animController.reverse() : null,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) => Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          ),
          child: Container(
            padding: EdgeInsets.all(16.r),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: widget.goldColor.withValues(alpha: 0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10.r,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10.r),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        widget.goldColor.withValues(alpha: 0.15),
                        widget.goldColor.withValues(alpha: 0.02),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(
                      color: widget.goldColor.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Icon(widget.icon, color: widget.goldColor, size: 22.r),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                        ),
                      ),
                      if (widget.subtitle != null) ...[
                        SizedBox(height: 2.h),
                        Text(
                          widget.subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.brightness == Brightness.dark
                                ? theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7)
                                : theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                Flexible(child: widget.trailing),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavigationModeToggle extends StatelessWidget {
  const _NavigationModeToggle({
    required this.goldColor,
    required this.value,
    required this.onChanged,
  });

  final Color goldColor;
  final PageNavigationMode value;
  final ValueChanged<PageNavigationMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6.w,
      runSpacing: 6.h,
      alignment: WrapAlignment.end,
      children: [
        _ChoiceChipButton(
          label: 'page_navigation_slide'.tr,
          selected: value == PageNavigationMode.slide,
          enabled: true,
          goldColor: goldColor,
          onSelected: () => onChanged(PageNavigationMode.slide),
        ),
        _ChoiceChipButton(
          label: 'page_navigation_fold'.tr,
          selected: value == PageNavigationMode.fold,
          enabled: true,
          goldColor: goldColor,
          onSelected: () => onChanged(PageNavigationMode.fold),
        ),
      ],
    );
  }
}

class _DhikrSettingsCard extends StatefulWidget {
  const _DhikrSettingsCard({
    required this.goldColor,
    required this.controller,
    required this.isEnabled,
    required this.reminderMode,
    required this.dailyTarget,
    required this.reminderModeLabel,
  });

  final Color goldColor;
  final AppController controller;
  final bool isEnabled;
  final DhikrReminderMode reminderMode;
  final int dailyTarget;
  final String reminderModeLabel;

  @override
  State<_DhikrSettingsCard> createState() => _DhikrSettingsCardState();
}

class _DhikrSettingsCardState extends State<_DhikrSettingsCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: _isExpanded
              ? widget.goldColor.withValues(alpha: 0.4)
              : widget.goldColor.withValues(alpha: 0.2),
          width: _isExpanded ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: _isExpanded
                ? widget.goldColor.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.02),
            blurRadius: _isExpanded ? 16.r : 8.r,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
          childrenPadding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
          iconColor: widget.goldColor,
          collapsedIconColor: widget.goldColor,
          onExpansionChanged: (expanded) {
            setState(() {
              _isExpanded = expanded;
            });
          },
          leading: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.all(10.r),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: widget.isEnabled
                    ? [
                        widget.goldColor.withValues(alpha: 0.2),
                        widget.goldColor.withValues(alpha: 0.05),
                      ]
                    : [
                        theme.disabledColor.withValues(alpha: 0.1),
                        theme.disabledColor.withValues(alpha: 0.02),
                      ],
              ),
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(
                color: widget.isEnabled
                    ? widget.goldColor.withValues(alpha: 0.3)
                    : theme.disabledColor.withValues(alpha: 0.2),
              ),
            ),
            child: Icon(
              widget.isEnabled ? Icons.notifications_active : Icons.self_improvement,
              color: widget.isEnabled ? widget.goldColor : theme.disabledColor,
              size: 22.r,
            ),
          ),
          title: Text(
            'dhikr_reminders'.tr,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            widget.isEnabled
                ? 'dhikr_reminders_desc'.trParams({
                    'mode': widget.reminderModeLabel,
                  })
                : 'dhikr_reminder_disabled_desc'.tr,
            style: theme.textTheme.bodySmall?.copyWith(
              color: widget.isEnabled
                  ? theme.textTheme.bodySmall?.color
                  : theme.disabledColor,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch.adaptive(
                value: widget.isEnabled,
                activeColor: widget.goldColor,
                onChanged: widget.controller.setDhikrReminderEnabled,
              ),
              SizedBox(width: 4.w),
              AnimatedRotation(
                turns: _isExpanded ? 0.5 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.expand_more, color: widget.goldColor, size: 24.r),
              ),
            ],
          ),
          children: [
            Divider(color: widget.goldColor.withValues(alpha: 0.16), height: 22.h),
            _DhikrOptionSection(
              icon: Icons.tune,
              title: 'dhikr_reminder_mode'.tr,
              subtitle: widget.isEnabled
                  ? 'dhikr_reminder_mode_desc'.tr
                  : 'dhikr_reminder_disabled_desc'.tr,
              goldColor: widget.goldColor,
              child: Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: [
                  _ChoiceChipButton(
                    label: 'dhikr_mode_once_daily'.tr,
                    selected: widget.reminderMode == DhikrReminderMode.onceDaily,
                    enabled: widget.isEnabled,
                    goldColor: widget.goldColor,
                    onSelected: () => widget.controller.setDhikrReminderMode(
                      DhikrReminderMode.onceDaily,
                    ),
                  ),
                  _ChoiceChipButton(
                    label: 'dhikr_mode_morning_evening'.tr,
                    selected: widget.reminderMode == DhikrReminderMode.morningEvening,
                    enabled: widget.isEnabled,
                    goldColor: widget.goldColor,
                    onSelected: () => widget.controller.setDhikrReminderMode(
                      DhikrReminderMode.morningEvening,
                    ),
                  ),
                  _ChoiceChipButton(
                    label: 'dhikr_mode_after_prayers'.tr,
                    selected: widget.reminderMode == DhikrReminderMode.afterPrayers,
                    enabled: widget.isEnabled,
                    goldColor: widget.goldColor,
                    onSelected: () => widget.controller.setDhikrReminderMode(
                      DhikrReminderMode.afterPrayers,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20.h),
            _DhikrOptionSection(
              icon: Icons.flag_outlined,
              title: 'dhikr_daily_target'.tr,
              subtitle: 'dhikr_daily_target_desc'.tr,
              goldColor: widget.goldColor,
              child: Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: [
                  for (final target in const [1, 3, 5])
                    _ChoiceChipButton(
                      label: '$target',
                      selected: widget.dailyTarget == target,
                      enabled: widget.isEnabled,
                      goldColor: widget.goldColor,
                      onSelected: () => widget.controller.setDhikrDailyTarget(target),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DhikrOptionSection extends StatelessWidget {
  const _DhikrOptionSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.goldColor,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color goldColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(6.r),
              decoration: BoxDecoration(
                color: goldColor.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: goldColor, size: 16.r),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        Padding(
          padding: EdgeInsetsDirectional.only(start: 32.w),
          child: child,
        ),
      ],
    );
  }
}

class _ChoiceChipButton extends StatelessWidget {
  const _ChoiceChipButton({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.goldColor,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final Color goldColor;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color bg;
    BorderSide border;
    TextStyle style;

    if (!enabled) {
      bg = isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03);
      border = BorderSide(color: Colors.transparent);
      style = theme.textTheme.bodySmall!.copyWith(
        color: theme.disabledColor,
        fontWeight: FontWeight.w500,
      );
    } else if (selected) {
      bg = goldColor.withValues(alpha: 0.18);
      border = BorderSide(color: goldColor, width: 1.5);
      style = theme.textTheme.bodySmall!.copyWith(
        color: goldColor,
        fontWeight: FontWeight.bold,
      );
    } else {
      bg = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03);
      border = BorderSide(color: goldColor.withValues(alpha: 0.2), width: 1);
      style = theme.textTheme.bodySmall!.copyWith(
        color: theme.colorScheme.onSurface,
        fontWeight: FontWeight.w500,
      );
    }

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: enabled ? onSelected : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.fromBorderSide(border),
            boxShadow: selected && enabled
                ? [
                    BoxShadow(
                      color: goldColor.withValues(alpha: 0.1),
                      blurRadius: 8.r,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
          ),
          child: Text(
            label,
            style: style,
          ),
        ),
      ),
    );
  }
}
