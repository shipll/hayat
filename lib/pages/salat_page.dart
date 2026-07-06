import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_qiblah/flutter_qiblah.dart';
import 'package:get/get.dart';

import '../controllers/prayer_controller.dart';
import '../services/qibla_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/arabesque_painter.dart';

class SalatPage extends StatelessWidget {
  const SalatPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PrayerController>();
    final theme = Theme.of(context);
    final goldColor = theme.hayahGold;

    return Scaffold(
      body: ArabesqueBackground(
        child: SafeArea(
          child: Obx(() {
            final day = controller.prayerDay.value;
            return RefreshIndicator(
              onRefresh: controller.refreshPrayerTimes,
              child: ListView(
                padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 100.h),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Row(
                    children: [
                      Icon(Icons.schedule, color: goldColor, size: 28.r),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(
                          'prayer_times'.tr,
                          style: theme.textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: controller.refreshPrayerTimes,
                        icon: controller.isLoading.value
                            ? SizedBox(
                                width: 18.r,
                                height: 18.r,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: goldColor,
                                ),
                              )
                            : Icon(Icons.my_location, color: goldColor),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  if (controller.errorMessage.value.isNotEmpty)
                    _InfoBanner(
                      text: controller.errorMessage.value,
                      goldColor: goldColor,
                    ),
                  SizedBox(height: 16.h),
                  if (day == null)
                    Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 80.h),
                        child: CircularProgressIndicator(color: goldColor),
                      ),
                    )
                  else ...[
                    _NextPrayerCard(
                      goldColor: goldColor,
                      title: day.nextPrayerKey.tr,
                      time: controller.formatTime(day.nextPrayerTime),
                      countdown: controller.countdownText(),
                      location: day.locationLabel,
                      qibla: day.qiblaDegrees,
                    ),
                    SizedBox(height: 20.h),
                    _QiblaCompassCard(
                      qiblaDegrees: day.qiblaDegrees,
                      goldColor: goldColor,
                    ),
                    SizedBox(height: 20.h),
                    Text(
                      'egyptian_general_authority'.tr,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: goldColor,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    for (final prayer in day.prayers) ...[
                      _PrayerRow(
                        name: prayer.labelKey.tr,
                        time: controller.formatTime(prayer.time),
                        active: prayer.key == day.nextPrayerKey,
                        enabled: controller.notificationEnabled(prayer.key),
                        goldColor: goldColor,
                        onChanged: (value) => controller.setNotificationEnabled(
                          prayer.key,
                          value,
                        ),
                      ),
                      SizedBox(height: 10.h),
                    ],
                  ],
                ],
              ),
            );
          }),
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
    );
  }
}

class _NextPrayerCard extends StatelessWidget {
  const _NextPrayerCard({
    required this.goldColor,
    required this.title,
    required this.time,
    required this.countdown,
    required this.location,
    required this.qibla,
  });

  final Color goldColor;
  final String title;
  final String time;
  final String countdown;
  final String location;
  final double qibla;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: goldColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, color: goldColor, size: 18.r),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
          SizedBox(height: 18.h),
          Text('next_prayer'.tr, style: theme.textTheme.labelMedium),
          SizedBox(height: 6.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.displayLarge?.copyWith(
                    fontSize: 36.sp,
                    color: Colors.white,
                  ),
                ),
              ),
              Text(
                time,
                style: TextStyle(
                  fontSize: 34.sp,
                  fontWeight: FontWeight.bold,
                  color: goldColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            'in_time'.trParams({'time': countdown}),
            style: theme.textTheme.bodyMedium,
          ),
          SizedBox(height: 16.h),
          InkWell(
            onTap: null,
            child: Row(
              children: [
                Icon(Icons.explore, color: goldColor),
                SizedBox(width: 8.w),
                Text(
                  '${'qibla_direction'.tr}: ${qibla.toStringAsFixed(1)}°',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: goldColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QiblaCompassCard extends StatefulWidget {
  const _QiblaCompassCard({
    required this.qiblaDegrees,
    required this.goldColor,
  });

  final double qiblaDegrees;
  final Color goldColor;

  @override
  State<_QiblaCompassCard> createState() => _QiblaCompassCardState();
}

class _QiblaCompassCardState extends State<_QiblaCompassCard> {
  late final QiblaService _qiblaService;
  Future<QiblaReadiness>? _readinessFuture;
  bool _isActive = false;

  @override
  void initState() {
    super.initState();
    _qiblaService = Get.find<QiblaService>();
  }

  void _startCompass() {
    setState(() {
      _isActive = true;
      _readinessFuture = _qiblaService.prepareCompass();
    });
  }

  void _stopCompass() {
    _qiblaService.disposeCompass();
    setState(() {
      _isActive = false;
      _readinessFuture = null;
    });
  }

  @override
  void dispose() {
    _qiblaService.disposeCompass();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(18.r),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: widget.goldColor.withValues(alpha: 0.18)),
      ),
      child: !_isActive
          ? _CompassIdleContent(
              goldColor: widget.goldColor,
              qiblaDegrees: widget.qiblaDegrees,
              onStart: _startCompass,
            )
          : FutureBuilder<QiblaReadiness>(
              future: _readinessFuture,
              builder: (context, supportSnapshot) {
                if (supportSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.r),
                      child: CircularProgressIndicator(color: widget.goldColor),
                    ),
                  );
                }

                final readiness =
                    supportSnapshot.data ??
                    const QiblaReadiness.unavailable('qibla_stream_error');
                if (!readiness.ready) {
                  return _QiblaFallbackContent(
                    goldColor: widget.goldColor,
                    qiblaDegrees: widget.qiblaDegrees,
                    message: (readiness.messageKey ?? 'qibla_stream_error').tr,
                    onStop: _stopCompass,
                  );
                }

                return StreamBuilder<QiblahDirection>(
                  stream: _qiblaService.directionStream,
                  builder: (context, snapshot) {
                    return _QiblaCameraContent(
                      goldColor: widget.goldColor,
                      qiblaDegrees: widget.qiblaDegrees,
                      headingDegrees: snapshot.data?.direction,
                      message: snapshot.hasError
                          ? 'qibla_stream_error'.tr
                          : 'qibla_align_hint'.tr,
                      onStop: _stopCompass,
                    );
                  },
                );
              },
            ),
    );
  }
}

class _QiblaCameraContent extends StatefulWidget {
  const _QiblaCameraContent({
    required this.goldColor,
    required this.qiblaDegrees,
    required this.headingDegrees,
    required this.message,
    required this.onStop,
  });

  final Color goldColor;
  final double qiblaDegrees;
  final double? headingDegrees;
  final String message;
  final VoidCallback onStop;

  @override
  State<_QiblaCameraContent> createState() => _QiblaCameraContentState();
}

class _QiblaCameraContentState extends State<_QiblaCameraContent> {
  CameraController? _cameraController;
  Future<String?>? _cameraFuture;

  @override
  void initState() {
    super.initState();
    _cameraFuture = _initCamera();
  }

  Future<String?> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return 'qibla_camera_unavailable';

      final camera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return null;
      }

      _cameraController = controller;
      return null;
    } on CameraException catch (error) {
      if (error.code == 'CameraAccessDenied' ||
          error.code == 'CameraAccessDeniedWithoutPrompt' ||
          error.code == 'CameraAccessRestricted') {
        return 'qibla_camera_permission_denied';
      }
      return 'qibla_camera_unavailable';
    } catch (_) {
      return 'qibla_camera_unavailable';
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _cameraFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(24.r),
              child: CircularProgressIndicator(color: widget.goldColor),
            ),
          );
        }

        final errorKey = snapshot.data;
        final controller = _cameraController;
        if (errorKey != null ||
            controller == null ||
            !controller.value.isInitialized) {
          return _QiblaFallbackContent(
            goldColor: widget.goldColor,
            qiblaDegrees: widget.qiblaDegrees,
            message: (errorKey ?? 'qibla_camera_unavailable').tr,
            onStop: widget.onStop,
          );
        }

        return _QiblaCameraOverlay(
          controller: controller,
          goldColor: widget.goldColor,
          qiblaDegrees: widget.qiblaDegrees,
          headingDegrees: widget.headingDegrees,
          message: widget.message,
          onStop: widget.onStop,
        );
      },
    );
  }
}

class _QiblaCameraOverlay extends StatelessWidget {
  const _QiblaCameraOverlay({
    required this.controller,
    required this.goldColor,
    required this.qiblaDegrees,
    required this.headingDegrees,
    required this.message,
    required this.onStop,
  });

  final CameraController controller;
  final Color goldColor;
  final double qiblaDegrees;
  final double? headingDegrees;
  final String message;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasLiveDirection = headingDegrees != null;
    final rotation = ((qiblaDegrees - (headingDegrees ?? 0)) + 360) % 360;

    return Column(
      children: [
        _QiblaHeader(goldColor: goldColor, qiblaDegrees: qiblaDegrees),
        SizedBox(height: 16.h),
        ClipRRect(
          borderRadius: BorderRadius.circular(18.r),
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: Stack(
              fit: StackFit.expand,
              alignment: Alignment.center,
              children: [
                CameraPreview(controller),
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: goldColor.withValues(alpha: 0.42),
                      width: 1.5,
                    ),
                  ),
                ),
                Container(color: Colors.black.withValues(alpha: 0.10)),
                Center(
                  child: hasLiveDirection
                      ? Transform.rotate(
                          angle: rotation * math.pi / 180,
                          child: Icon(
                            Icons.navigation,
                            color: goldColor,
                            size: 82.r,
                            shadows: const [
                              Shadow(color: Colors.black87, blurRadius: 12),
                            ],
                          ),
                        )
                      : _NoCompassCameraMarker(
                          goldColor: goldColor,
                          qiblaDegrees: qiblaDegrees,
                        ),
                ),
                Positioned(
                  top: 12.h,
                  child: _CameraDirectionPill(
                    text: hasLiveDirection
                        ? 'qibla_live'.tr
                        : 'qibla_camera_preview'.tr,
                    goldColor: goldColor,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 12.h),
        Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
        if (headingDegrees != null) ...[
          SizedBox(height: 6.h),
          Text(
            '${'device_heading'.tr}: ${headingDegrees!.toStringAsFixed(1)}°',
            style: theme.textTheme.bodySmall?.copyWith(
              color: goldColor.withValues(alpha: 0.75),
            ),
          ),
        ],
        SizedBox(height: 10.h),
        TextButton.icon(
          onPressed: onStop,
          icon: const Icon(Icons.stop_circle_outlined),
          label: Text('stop_qibla'.tr),
        ),
      ],
    );
  }
}

class _NoCompassCameraMarker extends StatelessWidget {
  const _NoCompassCameraMarker({
    required this.goldColor,
    required this.qiblaDegrees,
  });

  final Color goldColor;
  final double qiblaDegrees;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 248.r,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.66),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: goldColor.withValues(alpha: 0.48)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _ManualGuideArrow(
                icon: Icons.keyboard_double_arrow_left,
                label: 'qibla_turn_left'.tr,
                goldColor: goldColor,
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.navigation, color: goldColor, size: 42.r),
                  SizedBox(height: 4.h),
                  Text(
                    'qibla_forward'.tr,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              _ManualGuideArrow(
                icon: Icons.keyboard_double_arrow_right,
                label: 'qibla_turn_right'.tr,
                goldColor: goldColor,
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            '${qiblaDegrees.toStringAsFixed(1)}°',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: goldColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'qibla_no_live_direction'.tr,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(color: Colors.white),
          ),
          SizedBox(height: 6.h),
          Text(
            'qibla_manual_arrows_hint'.tr,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.82),
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _ManualGuideArrow extends StatelessWidget {
  const _ManualGuideArrow({
    required this.icon,
    required this.label,
    required this.goldColor,
  });

  final IconData icon;
  final String label;
  final Color goldColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: goldColor, size: 34.r),
        SizedBox(height: 4.h),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _CameraDirectionPill extends StatelessWidget {
  const _CameraDirectionPill({required this.text, required this.goldColor});

  final String text;
  final Color goldColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: goldColor.withValues(alpha: 0.48)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.videocam, color: goldColor, size: 16.r),
          SizedBox(width: 6.w),
          Text(
            text,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _QiblaFallbackContent extends StatelessWidget {
  const _QiblaFallbackContent({
    required this.goldColor,
    required this.qiblaDegrees,
    required this.message,
    required this.onStop,
  });

  final Color goldColor;
  final double qiblaDegrees;
  final String message;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        _QiblaHeader(goldColor: goldColor, qiblaDegrees: qiblaDegrees),
        SizedBox(height: 18.h),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 22.h),
          decoration: BoxDecoration(
            color: goldColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(color: goldColor.withValues(alpha: 0.20)),
          ),
          child: Column(
            children: [
              Icon(Icons.explore_off, color: goldColor, size: 52.r),
              SizedBox(height: 10.h),
              Text(
                '${qiblaDegrees.toStringAsFixed(1)}°',
                style: theme.textTheme.displaySmall?.copyWith(
                  color: goldColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        SizedBox(height: 10.h),
        TextButton.icon(
          onPressed: onStop,
          icon: const Icon(Icons.stop_circle_outlined),
          label: Text('stop_qibla'.tr),
        ),
      ],
    );
  }
}

class _QiblaHeader extends StatelessWidget {
  const _QiblaHeader({required this.goldColor, required this.qiblaDegrees});

  final Color goldColor;
  final double qiblaDegrees;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(Icons.explore, color: goldColor),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            'qibla'.tr,
            style: theme.textTheme.labelMedium?.copyWith(
              color: goldColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Text(
          '${qiblaDegrees.toStringAsFixed(1)}°',
          style: theme.textTheme.headlineMedium?.copyWith(color: goldColor),
        ),
      ],
    );
  }
}

class _CompassIdleContent extends StatelessWidget {
  const _CompassIdleContent({
    required this.goldColor,
    required this.qiblaDegrees,
    required this.onStart,
  });

  final Color goldColor;
  final double qiblaDegrees;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Row(
          children: [
            Icon(Icons.explore, color: goldColor),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                'qibla'.tr,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: goldColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              '${qiblaDegrees.toStringAsFixed(1)}°',
              style: theme.textTheme.headlineMedium?.copyWith(color: goldColor),
            ),
          ],
        ),
        SizedBox(height: 14.h),
        Text(
          'qibla_on_demand_hint'.tr,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
        SizedBox(height: 14.h),
        FilledButton.icon(
          onPressed: onStart,
          icon: const Icon(Icons.explore),
          label: Text('start_qibla'.tr),
        ),
      ],
    );
  }
}

class _PrayerRow extends StatelessWidget {
  const _PrayerRow({
    required this.name,
    required this.time,
    required this.active,
    required this.enabled,
    required this.goldColor,
    required this.onChanged,
  });

  final String name;
  final String time;
  final bool active;
  final bool enabled;
  final Color goldColor;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: active
            ? goldColor.withValues(alpha: 0.10)
            : theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: active ? goldColor : goldColor.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        children: [
          Icon(
            active ? Icons.notifications_active : Icons.schedule,
            color: goldColor,
            size: 22.r,
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Text(
              name,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: active ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
          Text(
            time,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontSize: 20.sp,
              color: active ? goldColor : theme.colorScheme.onSurface,
            ),
          ),
          SizedBox(width: 8.w),
          Switch.adaptive(
            value: enabled,
            activeColor: goldColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.text, required this.goldColor});

  final String text;
  final Color goldColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: goldColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: goldColor.withValues(alpha: 0.25)),
      ),
      child: Text(text, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
