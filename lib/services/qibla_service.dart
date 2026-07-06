import 'package:flutter_qiblah/flutter_qiblah.dart';
import 'package:geolocator/geolocator.dart' show LocationPermission;

class QiblaReadiness {
  const QiblaReadiness._({
    required this.ready,
    required this.supported,
    this.messageKey,
  });

  const QiblaReadiness.ready() : this._(ready: true, supported: true);

  const QiblaReadiness.unavailable(String messageKey, {bool supported = true})
    : this._(ready: false, supported: supported, messageKey: messageKey);

  final bool ready;
  final bool supported;
  final String? messageKey;
}

class QiblaService {
  Future<bool> supportsCompass() async {
    try {
      final supported = await FlutterQiblah.androidDeviceSensorSupport();
      return supported ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<LocationStatus> checkLocationStatus() =>
      FlutterQiblah.checkLocationStatus();

  Future<LocationPermission> requestPermissions() =>
      FlutterQiblah.requestPermissions();

  Future<QiblaReadiness> prepareCompass() async {
    final supported = await supportsCompass();
    if (!supported) {
      return const QiblaReadiness.unavailable(
        'qibla_no_sensor',
        supported: false,
      );
    }

    try {
      var locationStatus = await checkLocationStatus();
      if (!locationStatus.enabled) {
        return const QiblaReadiness.unavailable('qibla_location_disabled');
      }

      var permission = locationStatus.status;
      if (permission == LocationPermission.denied) {
        permission = await requestPermissions();
      }

      if (permission == LocationPermission.deniedForever) {
        return const QiblaReadiness.unavailable('qibla_permission_denied');
      }

      if (permission == LocationPermission.denied) {
        return const QiblaReadiness.unavailable('qibla_permission_denied');
      }

      return const QiblaReadiness.ready();
    } catch (_) {
      return const QiblaReadiness.unavailable('qibla_stream_error');
    }
  }

  Stream<QiblahDirection> get directionStream => FlutterQiblah.qiblahStream;

  void disposeCompass() {
    FlutterQiblah().dispose();
  }
}
