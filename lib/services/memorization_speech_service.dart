import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as speech;
import 'package:vosk_flutter_service/vosk_flutter_service.dart';

enum _SpeechBackend { system, vosk }

class MemorizationSpeechService {
  static const _arabicModelUrl =
      'https://alphacephei.com/vosk/models/vosk-model-ar-mgb2-0.4.zip';
  static const _voskSampleRate = 16000;

  final speech.SpeechToText _speech = speech.SpeechToText();
  final VoskFlutterPlugin _vosk = VoskFlutterPlugin.instance();
  final ModelLoader _modelLoader = ModelLoader();

  _SpeechBackend? _backend;
  bool _systemInitialized = false;
  bool _voskInitialized = false;
  bool _voskListening = false;
  bool _fallingBackToVosk = false;

  Model? _voskModel;
  Recognizer? _voskRecognizer;
  SpeechService? _voskSpeechService;
  StreamSubscription<String>? _voskPartialSubscription;
  StreamSubscription<String>? _voskResultSubscription;

  void Function(String text, bool isFinal)? _resultHandler;
  ValueChanged<String>? _statusHandler;
  ValueChanged<String>? _errorHandler;
  String? _lastErrorCode;

  bool get isListening {
    if (_backend == _SpeechBackend.vosk) return _voskListening;
    return _speech.isListening;
  }

  Future<bool> initialize() async {
    if (_backend != null) return true;

    if (await _initSystemSpeech()) {
      _backend = _SpeechBackend.system;
      return true;
    }

    if (await _initVosk()) {
      _backend = _SpeechBackend.vosk;
      return true;
    }

    return false;
  }

  Future<bool> isModelDownloaded() async {
    if (_backend == _SpeechBackend.system || _systemInitialized) return true;
    return _voskInitialized;
  }

  Future<bool> ensureModelDownloaded({
    ValueChanged<String>? onStatus,
    ValueChanged<String>? onError,
  }) async {
    if (_backend == _SpeechBackend.system || _systemInitialized) {
      onStatus?.call('model_ready');
      return true;
    }

    final previousStatusHandler = _statusHandler;
    final previousErrorHandler = _errorHandler;
    _statusHandler = onStatus ?? _statusHandler;
    _errorHandler = onError ?? _errorHandler;

    final ready = await _initVosk();

    _statusHandler = previousStatusHandler;
    _errorHandler = previousErrorHandler;
    return ready;
  }

  Future<void> listen({
    required void Function(String text, bool isFinal) onResult,
    required ValueChanged<String> onStatus,
    required ValueChanged<String> onError,
    ValueChanged<double>? onSoundLevel,
  }) async {
    _resultHandler = onResult;
    _statusHandler = onStatus;
    _errorHandler = onError;
    _lastErrorCode = null;

    final ready = await initialize();
    if (!ready) {
      if (_lastErrorCode == null) onError('speech_unavailable');
      return;
    }

    if (_backend == _SpeechBackend.vosk) {
      await _listenVosk();
      return;
    }

    await _listenSystem(onSoundLevel: onSoundLevel);
  }

  Future<void> stop() async {
    if (_backend == _SpeechBackend.vosk) {
      _voskListening = false;
      await _voskSpeechService?.stop();
      return;
    }

    await _speech.stop();
  }

  Future<void> cancel() async {
    if (_backend == _SpeechBackend.vosk) {
      _voskListening = false;
      await _cancelVoskSubscriptions();
      await _voskSpeechService?.cancel();
      return;
    }

    await _speech.cancel();
  }

  Future<bool> _initSystemSpeech() async {
    if (_systemInitialized) return true;

    try {
      _systemInitialized = await _speech.initialize(
        onStatus: (status) => _statusHandler?.call(status),
        onError: (error) => _handleSystemError(error.errorMsg),
        options: [
          speech.SpeechToText.androidNoBluetooth,
          speech.SpeechToText.iosNoBluetooth,
        ],
      );
    } catch (_) {
      _systemInitialized = false;
    }

    return _systemInitialized;
  }

  Future<void> _listenSystem({ValueChanged<double>? onSoundLevel}) async {
    _statusHandler?.call('listening');
    try {
      await _speech.listen(
        onResult: (result) =>
            _resultHandler?.call(result.recognizedWords, result.finalResult),
        onSoundLevelChange: onSoundLevel,
        listenOptions: speech.SpeechListenOptions(
          localeId: 'ar',
          partialResults: true,
          cancelOnError: false,
          onDevice: false,
          listenMode: speech.ListenMode.dictation,
          pauseFor: const Duration(seconds: 8),
          listenFor: const Duration(minutes: 10),
        ),
      );
    } catch (error) {
      await _fallbackToVosk();
    }
  }

  Future<bool> _initVosk() async {
    if (_voskInitialized) return true;

    try {
      _statusHandler?.call('model_downloading');
      final modelPath = await _modelLoader.loadFromNetwork(_arabicModelUrl);
      _statusHandler?.call('model_ready');

      _voskModel = await _vosk.createModel(modelPath);
      _voskRecognizer = await _vosk.createRecognizer(
        model: _voskModel!,
        sampleRate: _voskSampleRate,
      );
      _voskSpeechService = await _vosk.initSpeechService(_voskRecognizer!);
      _voskInitialized = true;
      return true;
    } catch (error, stackTrace) {
      debugPrint('Vosk initialization failed: $error\n$stackTrace');
      _emitError(_normalizeVoskError(error));
      return false;
    }
  }

  Future<void> _listenVosk() async {
    final speechService = _voskSpeechService;
    if (speechService == null && !await _initVosk()) {
      _emitError('vosk_unavailable');
      return;
    }

    await _cancelVoskSubscriptions();
    _voskPartialSubscription = _voskSpeechService!.onPartial().listen((event) {
      final text = _extractVoskText(event);
      if (text.isNotEmpty) _resultHandler?.call(text, false);
    });
    _voskResultSubscription = _voskSpeechService!.onResult().listen((event) {
      final text = _extractVoskText(event);
      if (text.isNotEmpty) _resultHandler?.call(text, true);
    });

    try {
      _statusHandler?.call('listening');
      await _voskSpeechService!.start(
        onRecognitionError: _handleVoskRecognitionError,
      );
      _voskListening = true;
    } catch (error, stackTrace) {
      debugPrint('Vosk listen failed: $error\n$stackTrace');
      _voskListening = false;
      _emitError(_normalizeVoskError(error));
    }
  }

  Future<void> _cancelVoskSubscriptions() async {
    await _voskPartialSubscription?.cancel();
    await _voskResultSubscription?.cancel();
    _voskPartialSubscription = null;
    _voskResultSubscription = null;
  }

  void _handleSystemError(String error) {
    final normalized = _normalizeSpeechError(error);
    if (normalized == 'speech_unavailable') {
      unawaited(_fallbackToVosk());
      return;
    }
    _emitError(normalized);
  }

  void _handleVoskRecognitionError(Object error) {
    _voskListening = false;
    _emitError(_normalizeVoskError(error));
  }

  Future<void> _fallbackToVosk() async {
    if (_fallingBackToVosk) return;
    _fallingBackToVosk = true;

    try {
      await _speech.cancel();
      if (await _initVosk()) {
        _backend = _SpeechBackend.vosk;
        await _listenVosk();
        return;
      }
    } finally {
      _fallingBackToVosk = false;
    }
  }

  void _emitError(String code) {
    _lastErrorCode = code;
    _errorHandler?.call(code);
  }

  String _extractVoskText(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map<String, dynamic>) {
        final text = decoded['text'] ?? decoded['partial'];
        return text?.toString().trim() ?? '';
      }
    } catch (_) {
      // Some platform implementations may return plain text.
    }
    return value.trim();
  }

  String _normalizeSpeechError(String error) {
    final value = error.toLowerCase();
    if (value.contains('permission') || value.contains('denied')) {
      return 'permission_denied';
    }
    return 'speech_unavailable';
  }

  String _normalizeVoskError(Object error) {
    final value = error.toString().toLowerCase();
    if (value.contains('permission') ||
        value.contains('denied') ||
        value.contains('microphone')) {
      return 'permission_denied';
    }
    if (value.contains('socket') ||
        value.contains('network') ||
        value.contains('host') ||
        value.contains('connection') ||
        value.contains('http')) {
      return 'model_download_failed';
    }
    return 'vosk_unavailable';
  }
}
