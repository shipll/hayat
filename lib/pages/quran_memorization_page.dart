import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:quran/quran.dart' as quran_text;

import '../services/memorization_speech_service.dart';
import '../services/quran_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class QuranMemorizationPage extends StatefulWidget {
  const QuranMemorizationPage({super.key, required this.initialPage, required int initialEndVerse, required int initialStartVerse, required int initialSurah});

  final int initialPage;

  @override
  State<QuranMemorizationPage> createState() => _QuranMemorizationPageState();
}

class _QuranMemorizationPageState extends State<QuranMemorizationPage> {
  static const _goldColor = AppTheme.goldNight;
  static const _trainingStorageKey = 'memorization_training_v1';

  late final QuranService _quranService;
  late final MemorizationSpeechService _speechService;
  late final StorageService _storageService;

  late int _page;
  late List<QuranVerse> _pageVerses;
  late List<_MemorizationWord> _words;
  late _MemorizationMatcher _matcher;

  int _currentWordIndex = 0;
  int _furthestWordIndex = 0;
  int? _lastAcceptedWordIndex;
  final Map<String, _WordPerformance> _wordPerformance = {};
  bool _isListening = false;
  bool _hasPossibleError = false;
  bool _showFullText = false;
  bool _showHint = false;
  double _soundLevel = 0;
  Timer? _restartListenTimer;
  Timer? _errorTimer;
  String _lastHeardText = '';
  String? _trainingInsight;
  String _message = 'اضغط على الميكروفون وابدأ التلاوة.';

  @override
  void initState() {
    super.initState();
    _quranService = Get.find<QuranService>();
    _speechService = Get.find<MemorizationSpeechService>();
    _storageService = Get.find<StorageService>();
    _page = widget.initialPage.clamp(1, quran_text.totalPagesCount).toInt();
    _rebuildWords(resetProgress: true);
  }

  @override
  void dispose() {
    _restartListenTimer?.cancel();
    _errorTimer?.cancel();
    _speechService.cancel();
    super.dispose();
  }

  void _rebuildWords({required bool resetProgress}) {
    _pageVerses = _quranService.getPageVerses(_page);

    _words = <_MemorizationWord>[];
    for (final verse in _pageVerses) {
      final tokens = _splitQuranWords(verse.text);
      for (var wordNumber = 0; wordNumber < tokens.length; wordNumber++) {
        final token = tokens[wordNumber];
        _words.add(
          _MemorizationWord(
            text: token,
            normalized: _normalizeArabic(token),
            page: verse.page,
            surah: verse.surah,
            verse: verse.verse,
            wordNumber: wordNumber + 1,
          ),
        );
      }
    }
    _words.removeWhere((word) => word.normalized.isEmpty);
    _matcher = _MemorizationMatcher(_words);
    _loadPageTraining();

    if (resetProgress) {
      _currentWordIndex = 0;
      _furthestWordIndex = 0;
      _lastAcceptedWordIndex = null;
      _hasPossibleError = false;
      _soundLevel = 0;
      _lastHeardText = '';
      _showFullText = false;
      _showHint = false;
      _trainingInsight = null;
      _message = 'اضغط على الميكروفون وابدأ التلاوة.';
    }
  }

  void _loadPageTraining() {
    _wordPerformance.clear();
    final stored = _readTrainingStore();
    final pagePrefix = '$_page:';
    for (final entry in stored.entries) {
      if (!entry.key.startsWith(pagePrefix) || entry.value is! Map) continue;
      _wordPerformance[entry.key] = _WordPerformance.fromMap(entry.value);
    }
  }

  Map<String, dynamic> _readTrainingStore() {
    final stored = _storageService.read<dynamic>(
      _trainingStorageKey,
      <String, dynamic>{},
    );
    if (stored is! Map) return <String, dynamic>{};
    return stored.map((key, value) => MapEntry(key.toString(), value));
  }

  Future<void> _saveTrainingStore() async {
    final stored = _readTrainingStore();
    for (final entry in _wordPerformance.entries) {
      stored[entry.key] = entry.value.toMap();
    }
    await _storageService.write<Map<String, dynamic>>(
      _trainingStorageKey,
      stored,
    );
  }

  void _recordMatchedWords(_MemorizationMatchResult result) {
    final isBackward = result.matchType == _MemorizationMatchType.backward;
    final start = result.fromIndex.clamp(0, _words.length).toInt();
    final end = result.nextIndex.clamp(0, _words.length).toInt();

    for (var index = start; index < end; index++) {
      final word = _words[index];
      final key = _trainingKeyForWord(word);
      final stat = _wordPerformance.putIfAbsent(key, _WordPerformance.new);
      stat.readCount++;
      stat
        ..confidenceSum += result.confidence
        ..lastReviewed = DateTime.now();
      if (isBackward) stat.backtrackCount++;
      if (result.matchType == _MemorizationMatchType.fuzzy) {
        stat.errorCount++;
      }
    }

    if (result.mistakeType == _MemorizationMistakeType.skippedWord) {
      final skippedIndex = (start - 1).clamp(0, _words.length - 1).toInt();
      final key = _trainingKeyForWord(_words[skippedIndex]);
      final stat = _wordPerformance.putIfAbsent(key, _WordPerformance.new);
      stat.errorCount++;
      stat.lastReviewed = DateTime.now();
    }

    unawaited(_saveTrainingStore());
  }

  void _recordErrorAtCurrentWord(_MemorizationMistakeType mistakeType) {
    if (_currentWordIndex < 0 || _currentWordIndex >= _words.length) return;
    final key = _trainingKeyForWord(_words[_currentWordIndex]);
    final stat = _wordPerformance.putIfAbsent(key, _WordPerformance.new);
    stat.lastReviewed = DateTime.now();
    if (mistakeType == _MemorizationMistakeType.stall) {
      stat.stallCount++;
    } else if (mistakeType == _MemorizationMistakeType.repeated) {
      stat.repeatCount++;
    } else {
      stat.errorCount++;
    }
    unawaited(_saveTrainingStore());
  }

  _PageTrainingSummary _buildTrainingSummary() {
    if (_words.isEmpty) return const _PageTrainingSummary.empty();

    var readWords = 0;
    var errorCount = 0;
    var stallCount = 0;
    var backtrackCount = 0;
    var confidenceTotal = 0.0;
    var confidenceWords = 0;
    final weakVerses = <int, int>{};

    for (final word in _words) {
      final stat = _wordPerformance[_trainingKeyForWord(word)];
      if (stat == null) continue;
      if (stat.readCount > 0) {
        readWords++;
        confidenceTotal += stat.averageConfidence;
        confidenceWords++;
      }
      final weaknessScore =
          stat.errorCount + stat.stallCount + stat.backtrackCount;
      if (weaknessScore > 0) {
        weakVerses[word.verse] = (weakVerses[word.verse] ?? 0) + weaknessScore;
      }
      errorCount += stat.errorCount;
      stallCount += stat.stallCount;
      backtrackCount += stat.backtrackCount;
    }

    final mastery =
        ((readWords / _words.length) * 0.65) +
        ((confidenceWords == 0 ? 0 : confidenceTotal / confidenceWords) * 0.35);
    final weakestVerse = weakVerses.entries
        .fold<MapEntry<int, int>?>(
          null,
          (best, entry) =>
              best == null || entry.value > best.value ? entry : best,
        )
        ?.key;

    return _PageTrainingSummary(
      masteryPercent: (mastery * 100).clamp(0, 100).round(),
      weakPlaces: errorCount + stallCount + backtrackCount,
      weakestVerse: weakestVerse,
      reviewAdvice: _reviewAdviceFor(
        masteryPercent: (mastery * 100).clamp(0, 100).round(),
        weakestVerse: weakestVerse,
      ),
    );
  }

  String _reviewAdviceFor({
    required int masteryPercent,
    required int? weakestVerse,
  }) {
    if (weakestVerse != null && masteryPercent < 90) {
      return 'راجع من الآية $weakestVerse ثم أعد الصفحة مرة قصيرة.';
    }
    if (masteryPercent >= 90) return 'إتقان جيد. اجعلها في مراجعة لاحقة.';
    return 'أعد الصفحة مرة أخرى بتركيز هادئ.';
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      _restartListenTimer?.cancel();
      _errorTimer?.cancel();
      setState(() {
        _isListening = false;
        _soundLevel = 0;
        _message = 'تم إيقاف الاستماع.';
      });
      await _speechService.stop();
      return;
    }

    setState(() {
      _isListening = true;
      _hasPossibleError = false;
      _showHint = false;
      _message = 'أستمع الآن...';
    });

    await _startListeningSession();
  }

  Future<void> _startListeningSession() async {
    await _speechService.listen(
      onResult: _handleRecognizedText,
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'done' || status == 'notListening') {
          _restartListeningIfNeeded();
          return;
        }
        setState(() {
          _message = switch (status) {
            'model_downloading' =>
              'يتم تحميل نموذج التعرف الصوتي أول مرة. سيعمل لاحقًا بدون إنترنت.',
            'model_ready' => 'نموذج التعرف الصوتي جاهز.',
            'processing' => 'أحلل التلاوة الآن...',
            'listening' => 'أستمع الآن...',
            _ => _message,
          };
        });
      },
      onError: (error) {
        if (!mounted) return;
        if (error == 'model_download_failed') {
          setState(() {
            _isListening = false;
            _soundLevel = 0;
            _message =
                'تعذر تحميل نموذج التعرف الصوتي. افتح الإنترنت أول مرة فقط ثم حاول مجددًا.';
          });
          return;
        }
        if (error == 'vosk_unavailable') {
          setState(() {
            _isListening = false;
            _soundLevel = 0;
            _message =
                'تعذر تشغيل محرك التعرف الصوتي المحلي على هذا الجهاز. حاول إعادة فتح التطبيق.';
          });
          return;
        }
        if (error == 'speech_unavailable') {
          setState(() {
            _isListening = false;
            _soundLevel = 0;
            _message =
                'تعذر تشغيل التعرف الصوتي الآن. سيستخدم التطبيق المحرك المحلي عندما يتوفر النموذج.';
          });
          return;
        }
        setState(() {
          _isListening = false;
          _soundLevel = 0;
          _message = error == 'permission_denied'
              ? 'اسمح للتطبيق باستخدام الميكروفون لتشغيل مساعد الحفظ.'
              : 'تعذر الاستماع الآن. تحقق من الاتصال أو حاول مرة أخرى.';
        });
      },
      onSoundLevel: (level) {
        if (!mounted || !_isListening) return;
        setState(() => _soundLevel = level);
      },
    );
  }

  void _restartListeningIfNeeded() {
    if (!_isListening || _furthestWordIndex >= _words.length) return;
    _restartListenTimer?.cancel();
    _restartListenTimer = Timer(const Duration(milliseconds: 350), () {
      if (mounted && _isListening) {
        _startListeningSession();
      }
    });
  }

  void _handleRecognizedText(String recognizedText, bool _) {
    if (!mounted ||
        !_isListening ||
        _furthestWordIndex >= _words.length ||
        recognizedText.trim().isEmpty ||
        _words.isEmpty) {
      return;
    }

    final result = _matcher.match(
      currentIndex: _currentWordIndex,
      recognizedText: recognizedText,
    );
    if (result.isEmpty) {
      setState(() => _lastHeardText = recognizedText);
      return;
    }

    final nextWordIndex = result.nextIndex.clamp(0, _words.length).toInt();
    final changedPosition = nextWordIndex != _currentWordIndex;
    final acceptedWordIndex = result.matched
        ? (nextWordIndex > 0 ? nextWordIndex - 1 : null)
        : _lastAcceptedWordIndex;
    final nextFurthestWordIndex = nextWordIndex > _furthestWordIndex
        ? nextWordIndex
        : _furthestWordIndex;
    final advancedFurthest = nextFurthestWordIndex > _furthestWordIndex;
    final completedPage = nextFurthestWordIndex >= _words.length;

    setState(() {
      _lastHeardText = recognizedText;
      if (changedPosition || advancedFurthest) {
        _errorTimer?.cancel();
        _currentWordIndex = nextWordIndex;
        _furthestWordIndex = nextFurthestWordIndex;
        _lastAcceptedWordIndex = acceptedWordIndex;
        _hasPossibleError = false;
        _showHint = false;
        _trainingInsight = null;
        _message = completedPage
            ? 'أحسنت، اكتملت الصفحة المحددة.'
            : _messageForMatch(result);
      }
    });

    if (result.matched) {
      _recordMatchedWords(result);
    } else if (result.hasPossibleError ||
        result.mistakeType == _MemorizationMistakeType.repeated) {
      _recordErrorAtCurrentWord(result.mistakeType);
    }

    if (completedPage) {
      HapticFeedback.mediumImpact();
      unawaited(_advanceAfterPageCompletion());
      return;
    }

    if (!changedPosition && !advancedFurthest && result.hasPossibleError) {
      _scheduleErrorAlert();
    }
  }

  String _messageForMatch(_MemorizationMatchResult result) {
    return switch (result.matchType) {
      _MemorizationMatchType.backward =>
        'رجعت معك للموضع السابق، والنص المكشوف سيبقى ظاهرًا.',
      _MemorizationMatchType.fuzzy => 'قبلت الكلمة بتطابق قريب. تابع بهدوء.',
      _MemorizationMatchType.sequence =>
        'تم تحديد موضعك داخل الصفحة. تابع التلاوة.',
      _ => 'تابع التلاوة من موضعك الحالي.',
    };
  }

  Future<void> _advanceAfterPageCompletion() async {
    _restartListenTimer?.cancel();
    _errorTimer?.cancel();
    final completedPage = _page;
    final summary = _buildTrainingSummary();
    final summaryText = summary.displayText;
    _trainingInsight = summaryText;
    unawaited(_saveTrainingStore());

    if (_page >= quran_text.totalPagesCount) {
      setState(() {
        _isListening = false;
        _soundLevel = 0;
        _trainingInsight = summaryText;
        _message = 'أحسنت، اكتمل حفظ آخر صفحة.';
      });
      await _speechService.stop();
      return;
    }

    await _speechService.stop();
    if (!mounted) return;

    setState(() {
      _page = (_page + 1).clamp(1, quran_text.totalPagesCount).toInt();
      _rebuildWords(resetProgress: true);
      _isListening = true;
      _soundLevel = 0;
      _trainingInsight = 'ملخص صفحة $completedPage: $summaryText';
      _message = 'انتقلت للصفحة التالية. تابع التلاوة.';
    });

    _restartListenTimer = Timer(const Duration(milliseconds: 450), () {
      if (mounted && _isListening) {
        _startListeningSession();
      }
    });
  }

  Future<void> _goToPage(int page) async {
    final nextPage = page.clamp(1, quran_text.totalPagesCount).toInt();
    if (nextPage == _page) return;

    _restartListenTimer?.cancel();
    _errorTimer?.cancel();
    final shouldResumeListening = _isListening;

    if (shouldResumeListening) {
      await _speechService.stop();
      if (!mounted) return;
    } else {
      _speechService.cancel();
    }

    setState(() {
      _page = nextPage;
      _rebuildWords(resetProgress: true);
      _isListening = shouldResumeListening;
      _soundLevel = 0;
      _message = shouldResumeListening
          ? 'انتقلت للصفحة $_page. تابع التلاوة.'
          : 'انتقلت للصفحة $_page. ابدأ حين تكون جاهزًا.';
    });

    if (shouldResumeListening) {
      _restartListenTimer = Timer(const Duration(milliseconds: 350), () {
        if (mounted && _isListening) {
          _startListeningSession();
        }
      });
    }
  }

  void _scheduleErrorAlert() {
    _errorTimer?.cancel();
    final wordIndexAtSchedule = _currentWordIndex;
    _errorTimer = Timer(const Duration(milliseconds: 1800), () {
      if (!mounted ||
          !_isListening ||
          _currentWordIndex != wordIndexAtSchedule ||
          _currentWordIndex >= _words.length) {
        return;
      }

      HapticFeedback.lightImpact();
      _recordErrorAtCurrentWord(_MemorizationMistakeType.stall);
      setState(() {
        _hasPossibleError = true;
        _showHint = true;
        _trainingInsight =
            'تلميح: ركز على الكلمة الحالية، فقد تم تسجيلها كنقطة تحتاج مراجعة.';
        _message = 'راجع الموضع الحالي ثم تابع.';
      });
    });
  }

  void _resetAttempt() {
    _restartListenTimer?.cancel();
    _errorTimer?.cancel();
    _speechService.cancel();
    setState(() {
      _currentWordIndex = 0;
      _furthestWordIndex = 0;
      _lastAcceptedWordIndex = null;
      _hasPossibleError = false;
      _showHint = false;
      _showFullText = false;
      _lastHeardText = '';
      _isListening = false;
      _soundLevel = 0;
      _trainingInsight = null;
      _message = 'تمت إعادة المحاولة. ابدأ حين تكون جاهزًا.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: _goldColor,
          secondary: _goldColor,
          surface: Colors.black,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text('مساعد الحفظ - صفحة $_page'),
        ),
        body: SafeArea(
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _MemorizationPageFrame(
                      words: _words,
                      currentIndex: _currentWordIndex,
                      revealedIndex: _furthestWordIndex,
                      hasError: _hasPossibleError,
                      showHint: _showHint,
                      pageVerses: _pageVerses,
                      lastAcceptedIndex: _lastAcceptedWordIndex,
                      showFullText: _showFullText,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_isListening || _lastHeardText.trim().isNotEmpty) ...[
                    _LastHeardBar(
                      text: _lastHeardText,
                      isListening: _isListening,
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    _message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                  if (_trainingInsight != null) ...[
                    const SizedBox(height: 8),
                    _TrainingInsightBar(text: _trainingInsight!),
                  ],
                  const SizedBox(height: 14),
                  _Controls(
                    isListening: _isListening,
                    soundLevel: _soundLevel,
                    onMicPressed: _toggleListening,
                    onRetryPressed: _resetAttempt,
                    onPreviousPagePressed: _page > 1
                        ? () => _goToPage(_page - 1)
                        : null,
                    onNextPagePressed: _page < quran_text.totalPagesCount
                        ? () => _goToPage(_page + 1)
                        : null,
                    onRevealPressed: () =>
                        setState(() => _showFullText = !_showFullText),
                    showFullText: _showFullText,
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

class _MemorizationPageFrame extends StatelessWidget {
  const _MemorizationPageFrame({
    required this.words,
    required this.currentIndex,
    required this.revealedIndex,
    required this.hasError,
    required this.showHint,
    required this.pageVerses,
    required this.lastAcceptedIndex,
    required this.showFullText,
  });

  final List<_MemorizationWord> words;
  final int currentIndex;
  final int revealedIndex;
  final bool hasError;
  final bool showHint;
  final List<QuranVerse> pageVerses;
  final int? lastAcceptedIndex;
  final bool showFullText;

  @override
  Widget build(BuildContext context) {
    final activeColor = hasError
        ? Colors.redAccent
        : _QuranMemorizationPageState._goldColor;

    return Center(
      child: AspectRatio(
        aspectRatio: 0.74,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
            child: _MushafPageLayoutView(
              pageVerses: pageVerses,
              memorizationWords: words,
              currentIndex: currentIndex,
              revealedIndex: revealedIndex,
              lastAcceptedIndex: lastAcceptedIndex,
              activeColor: activeColor,
              showHint: showHint,
              hasError: hasError,
              showText: showFullText,
            ),
          ),
        ),
      ),
    );
  }
}

class _MushafPageLayoutView extends StatelessWidget {
  const _MushafPageLayoutView({
    required this.pageVerses,
    required this.memorizationWords,
    required this.currentIndex,
    required this.revealedIndex,
    required this.lastAcceptedIndex,
    required this.activeColor,
    required this.showHint,
    required this.hasError,
    required this.showText,
  });

  static const _lineCount = 15;

  final List<QuranVerse> pageVerses;
  final List<_MemorizationWord> memorizationWords;
  final int currentIndex;
  final int revealedIndex;
  final int? lastAcceptedIndex;
  final Color activeColor;
  final bool showHint;
  final bool hasError;
  final bool showText;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final horizontalPadding = width * 0.055;
        final topPadding = height * 0.025;
        final bottomPadding = height * 0.025;
        final lineSpan =
            (height - topPadding - bottomPadding) /
            (_lineCount - 1).clamp(1, _lineCount);
        final lines = _buildLines(pageVerses, memorizationWords);

        return ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: DecoratedBox(
            decoration: const BoxDecoration(color: Color(0xFF11120F)),
            child: Stack(
              children: [
                ...List.generate(_lineCount, (index) {
                  final top = topPadding + (index * lineSpan);
                  return Positioned(
                    left: horizontalPadding,
                    right: horizontalPadding,
                    top: top,
                    child: Container(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.22),
                    ),
                  );
                }),
                ...List.generate(lines.length, (index) {
                  final top = topPadding + (index * lineSpan) - 10;
                  return Positioned(
                    left: horizontalPadding * 0.9,
                    right: horizontalPadding * 0.9,
                    top: top.clamp(0, height - 26),
                    child: _MushafTextLine(
                      tokens: lines[index],
                      activeColor: activeColor,
                      currentIndex: currentIndex,
                      revealedIndex: revealedIndex,
                      lastAcceptedIndex: lastAcceptedIndex,
                      showText: showText,
                      showHint: showHint,
                      hasError: hasError,
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  List<List<_MushafLineToken>> _buildLines(
    List<QuranVerse> verses,
    List<_MemorizationWord> memorizationWords,
  ) {
    final allWords = verses
        .expand((verse) => _splitQuranWords(verse.text))
        .length
        .clamp(1, 9999);
    final wordsPerLine = (allWords / _lineCount).clamp(3, 9999).toDouble();
    final lines = List.generate(_lineCount, (_) => <_MushafLineToken>[]);
    var lineIndex = 0;
    var wordsInLine = 0;
    var memorizationCursor = 0;

    for (final verse in verses) {
      final words = _splitQuranWords(verse.text);
      for (final word in words) {
        if (wordsInLine >= wordsPerLine && lineIndex < _lineCount - 1) {
          lineIndex++;
          wordsInLine = 0;
        }
        final memorizationIndex = _findMemorizationWordIndex(
          memorizationWords: memorizationWords,
          startIndex: memorizationCursor,
          surah: verse.surah,
          verse: verse.verse,
          word: word,
        );
        if (memorizationIndex != null) {
          memorizationCursor = memorizationIndex + 1;
        }

        lines[lineIndex].add(
          _MushafLineToken.word(word, memorizationIndex: memorizationIndex),
        );
        wordsInLine++;
      }
      lines[lineIndex].add(_MushafLineToken.verse(verse.verse));
    }

    return lines;
  }

  int? _findMemorizationWordIndex({
    required List<_MemorizationWord> memorizationWords,
    required int startIndex,
    required int surah,
    required int verse,
    required String word,
  }) {
    final normalized = _normalizeArabic(word);

    for (var index = startIndex; index < memorizationWords.length; index++) {
      final candidate = memorizationWords[index];
      if (candidate.surah > surah ||
          (candidate.surah == surah && candidate.verse > verse)) {
        return null;
      }
      if (candidate.surah == surah &&
          candidate.verse == verse &&
          candidate.normalized == normalized) {
        return index;
      }
    }

    return null;
  }
}

class _MushafLineToken {
  const _MushafLineToken._({
    required this.text,
    required this.verse,
    required this.isVerse,
    required this.memorizationIndex,
  });

  factory _MushafLineToken.word(
    String text, {
    required int? memorizationIndex,
  }) => _MushafLineToken._(
    text: text,
    verse: 0,
    isVerse: false,
    memorizationIndex: memorizationIndex,
  );

  factory _MushafLineToken.verse(int verse) => _MushafLineToken._(
    text: '',
    verse: verse,
    isVerse: true,
    memorizationIndex: null,
  );

  final String text;
  final int verse;
  final bool isVerse;
  final int? memorizationIndex;
}

class _MushafTextLine extends StatelessWidget {
  const _MushafTextLine({
    required this.tokens,
    required this.activeColor,
    required this.currentIndex,
    required this.revealedIndex,
    required this.lastAcceptedIndex,
    required this.showText,
    required this.showHint,
    required this.hasError,
  });

  final List<_MushafLineToken> tokens;
  final Color activeColor;
  final int currentIndex;
  final int revealedIndex;
  final int? lastAcceptedIndex;
  final bool showText;
  final bool showHint;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          textDirection: TextDirection.rtl,
          children: tokens.map((token) {
            if (token.isVerse) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _VerseCircleBadge(
                  verse: token.verse,
                  color: activeColor,
                  compact: true,
                ),
              );
            }
            final wordIndex = token.memorizationIndex;
            final belongsToRange = wordIndex != null;
            final revealed =
                showText || (wordIndex != null && wordIndex < revealedIndex);
            final isCurrent =
                wordIndex != null && wordIndex == currentIndex && !showText;
            final isLastAccepted =
                wordIndex != null && wordIndex == lastAcceptedIndex;
            final hinted = isCurrent && showHint;
            final displayText = revealed
                ? token.text
                : hinted
                ? token.text
                : '....';
            final textColor = isLastAccepted
                ? const Color(0xFF7DD3FC)
                : revealed || hinted || isCurrent
                ? Colors.white
                : Colors.white.withValues(alpha: belongsToRange ? 0.22 : 0.08);

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: EdgeInsets.symmetric(
                horizontal: isCurrent ? 4 : 1,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: isLastAccepted
                    ? const Color(0xFF0EA5E9).withValues(alpha: 0.26)
                    : isCurrent
                    ? (hasError ? Colors.redAccent : activeColor).withValues(
                        alpha: 0.22,
                      )
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: isCurrent || isLastAccepted
                    ? Border.all(
                        color: isLastAccepted
                            ? const Color(0xFF38BDF8)
                            : hasError
                            ? Colors.redAccent
                            : activeColor,
                        width: 1,
                      )
                    : null,
              ),
              child: Text(
                displayText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColor,
                  fontFamily: 'Amiri',
                  fontSize: 16,
                  fontWeight: revealed || isCurrent
                      ? FontWeight.w700
                      : FontWeight.w500,
                  height: 1,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _VerseCircleBadge extends StatelessWidget {
  const _VerseCircleBadge({
    required this.verse,
    required this.color,
    this.compact = false,
  });

  final int verse;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 20.0 : 34.0;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.86),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.24),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Text(
        _toArabicDigits(verse),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: compact ? 8.5 : 13,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}

String _toArabicDigits(int value) {
  const digits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  return value
      .toString()
      .split('')
      .map((char) => digits[int.parse(char)])
      .join();
}

class _LastHeardBar extends StatelessWidget {
  const _LastHeardBar({required this.text, required this.isListening});

  final String text;
  final bool isListening;

  @override
  Widget build(BuildContext context) {
    final heardText = text.trim();
    final displayText = heardText.isEmpty
        ? isListening
              ? 'بانتظار الكلام...'
              : 'لم يتم التقاط كلام بعد.'
        : heardText;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _QuranMemorizationPageState._goldColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _QuranMemorizationPageState._goldColor.withValues(alpha: 0.28),
        ),
      ),
      child: Text(
        displayText,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: heardText.isEmpty
              ? Colors.white.withValues(alpha: 0.52)
              : Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w700,
          height: 1.35,
        ),
      ),
    );
  }
}

class _TrainingInsightBar extends StatelessWidget {
  const _TrainingInsightBar({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _QuranMemorizationPageState._goldColor.withValues(alpha: 0.24),
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 13.5,
          height: 1.35,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.isListening,
    required this.soundLevel,
    required this.onMicPressed,
    required this.onRetryPressed,
    required this.onPreviousPagePressed,
    required this.onNextPagePressed,
    required this.onRevealPressed,
    required this.showFullText,
  });

  final bool isListening;
  final double soundLevel;
  final VoidCallback onMicPressed;
  final VoidCallback onRetryPressed;
  final VoidCallback? onPreviousPagePressed;
  final VoidCallback? onNextPagePressed;
  final VoidCallback onRevealPressed;
  final bool showFullText;

  @override
  Widget build(BuildContext context) {
    final normalizedLevel = ((soundLevel + 2) / 12).clamp(0.0, 1.0).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isListening) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: normalizedLevel,
              minHeight: 5,
              backgroundColor: Colors.white12,
              color: _QuranMemorizationPageState._goldColor,
            ),
          ),
          const SizedBox(height: 10),
        ],
        Align(
          alignment: Alignment.center,
          child: Material(
            color: Colors.black.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(28),
            clipBehavior: Clip.antiAlias,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: _QuranMemorizationPageState._goldColor.withValues(
                    alpha: 0.34,
                  ),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MemorizationToolbarButton(
                    tooltip: 'الصفحة السابقة',
                    icon: Icons.chevron_right_rounded,
                    onPressed: onPreviousPagePressed,
                  ),
                  _MemorizationToolbarButton(
                    tooltip: isListening ? 'إيقاف الاستماع' : 'ابدأ التلاوة',
                    icon: isListening ? Icons.stop_rounded : Icons.mic_rounded,
                    highlighted: true,
                    onPressed: onMicPressed,
                  ),
                  _MemorizationToolbarButton(
                    tooltip: 'إعادة المحاولة',
                    icon: Icons.replay_rounded,
                    onPressed: onRetryPressed,
                  ),
                  _MemorizationToolbarButton(
                    tooltip: showFullText ? 'إخفاء النص' : 'إظهار النص',
                    icon: showFullText
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    onPressed: onRevealPressed,
                  ),
                  _MemorizationToolbarButton(
                    tooltip: 'الصفحة التالية',
                    icon: Icons.chevron_left_rounded,
                    onPressed: onNextPagePressed,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MemorizationToolbarButton extends StatelessWidget {
  const _MemorizationToolbarButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.highlighted = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final color = !enabled
        ? Colors.white.withValues(alpha: 0.28)
        : highlighted
        ? Colors.black
        : _QuranMemorizationPageState._goldColor;
    final background = enabled && highlighted
        ? _QuranMemorizationPageState._goldColor
        : Colors.transparent;

    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, color: color),
      style: IconButton.styleFrom(
        backgroundColor: background,
        fixedSize: const Size(44, 44),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _MemorizationWord {
  const _MemorizationWord({
    required this.text,
    required this.normalized,
    required this.page,
    required this.surah,
    required this.verse,
    required this.wordNumber,
  });

  final String text;
  final String normalized;
  final int page;
  final int surah;
  final int verse;
  final int wordNumber;
}

String _trainingKeyForWord(_MemorizationWord word) {
  return '${word.page}:${word.surah}:${word.verse}:${word.wordNumber}';
}

class _WordPerformance {
  _WordPerformance({
    this.readCount = 0,
    this.errorCount = 0,
    this.stallCount = 0,
    this.backtrackCount = 0,
    this.repeatCount = 0,
    this.confidenceSum = 0,
    this.lastReviewed,
  });

  factory _WordPerformance.fromMap(Map<dynamic, dynamic> map) {
    return _WordPerformance(
      readCount: _readInt(map['readCount']),
      errorCount: _readInt(map['errorCount']),
      stallCount: _readInt(map['stallCount']),
      backtrackCount: _readInt(map['backtrackCount']),
      repeatCount: _readInt(map['repeatCount']),
      confidenceSum: _readDouble(map['confidenceSum']),
      lastReviewed: DateTime.tryParse(map['lastReviewed']?.toString() ?? ''),
    );
  }

  int readCount;
  int errorCount;
  int stallCount;
  int backtrackCount;
  int repeatCount;
  double confidenceSum;
  DateTime? lastReviewed;

  double get averageConfidence =>
      readCount == 0 ? 0 : confidenceSum / readCount;

  Map<String, dynamic> toMap() {
    return {
      'readCount': readCount,
      'errorCount': errorCount,
      'stallCount': stallCount,
      'backtrackCount': backtrackCount,
      'repeatCount': repeatCount,
      'confidenceSum': confidenceSum,
      'lastReviewed': lastReviewed?.toIso8601String(),
    };
  }
}

class _PageTrainingSummary {
  const _PageTrainingSummary({
    required this.masteryPercent,
    required this.weakPlaces,
    required this.weakestVerse,
    required this.reviewAdvice,
  });

  const _PageTrainingSummary.empty()
    : masteryPercent = 0,
      weakPlaces = 0,
      weakestVerse = null,
      reviewAdvice = 'لم تسجل الصفحة بيانات كافية بعد.';

  final int masteryPercent;
  final int weakPlaces;
  final int? weakestVerse;
  final String reviewAdvice;

  String get displayText {
    final weakVerseText = weakestVerse == null
        ? 'لا توجد آية ضعيفة واضحة.'
        : 'أكثر موضع يحتاج مراجعة: الآية $weakestVerse.';
    return 'الإتقان $masteryPercent%، مواضع المساعدة $weakPlaces. $weakVerseText $reviewAdvice';
  }
}

int _readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _readDouble(Object? value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

class _MemorizationMatchResult {
  const _MemorizationMatchResult({
    required this.matched,
    required this.confidence,
    required this.matchType,
    required this.mistakeType,
    required this.fromIndex,
    required this.nextIndex,
    required this.matchedCount,
    required this.hasPossibleError,
    this.unexpectedWord,
  });

  final bool matched;
  final double confidence;
  final _MemorizationMatchType matchType;
  final _MemorizationMistakeType mistakeType;
  final int fromIndex;
  final int nextIndex;
  final int matchedCount;
  final bool hasPossibleError;
  final String? unexpectedWord;

  bool get isEmpty =>
      !matched && !hasPossibleError && matchType == _MemorizationMatchType.none;
}

enum _MemorizationMatchType {
  none,
  direct,
  fuzzy,
  sequence,
  backward,
  repeated,
}

enum _MemorizationMistakeType {
  none,
  possibleSpeechError,
  skippedWord,
  backward,
  repeated,
  stall,
}

class _MemorizationMatcher {
  const _MemorizationMatcher(this.words);

  static const double _minimumWordSimilarity = 0.70;

  final List<_MemorizationWord> words;

  _MemorizationMatchResult match({
    required int currentIndex,
    required String recognizedText,
  }) {
    final heardCompact = _compactArabic(recognizedText);
    final heardWords = _splitHeardWords(recognizedText);
    final compactHeardWords = heardWords
        .map(_compactArabic)
        .where((word) => word.isNotEmpty)
        .toList();
    if (heardCompact.isEmpty || heardWords.isEmpty) {
      return const _MemorizationMatchResult(
        matched: false,
        confidence: 0,
        matchType: _MemorizationMatchType.none,
        mistakeType: _MemorizationMistakeType.none,
        fromIndex: 0,
        nextIndex: 0,
        matchedCount: 0,
        hasPossibleError: false,
      );
    }

    final currentMatch = _SequenceMatch(
      startIndex: currentIndex,
      score: _matchHeardWordsAt(
        startWordIndex: currentIndex,
        heardWords: compactHeardWords,
      ),
    );
    final anchorMatch = _bestAnchorMatch(
      heardWords: compactHeardWords,
      currentIndex: currentIndex,
    );
    final selectedMatch = _selectMatch(currentMatch, anchorMatch);
    final nextIndex = selectedMatch.startIndex + selectedMatch.matchedCount;

    if (selectedMatch.matchedCount > 0) {
      final isBackward = selectedMatch.startIndex < currentIndex;
      final isSequence = selectedMatch.matchedCount > 1;
      final isFuzzy = selectedMatch.hasFuzzyWord;
      return _MemorizationMatchResult(
        matched: true,
        confidence: selectedMatch.confidence,
        matchType: isBackward
            ? _MemorizationMatchType.backward
            : isSequence
            ? _MemorizationMatchType.sequence
            : isFuzzy
            ? _MemorizationMatchType.fuzzy
            : _MemorizationMatchType.direct,
        mistakeType: isBackward
            ? _MemorizationMistakeType.backward
            : isFuzzy
            ? _MemorizationMistakeType.possibleSpeechError
            : _MemorizationMistakeType.none,
        fromIndex: selectedMatch.startIndex,
        nextIndex: nextIndex,
        matchedCount: selectedMatch.matchedCount,
        hasPossibleError: false,
      );
    }

    final revealedCompact = _compactArabic(
      words.take(currentIndex).map((word) => word.normalized).join(' '),
    );
    final repeatedOldSpeech =
        revealedCompact.isNotEmpty &&
        (revealedCompact.contains(heardCompact) ||
            heardCompact.contains(revealedCompact));

    return _MemorizationMatchResult(
      matched: false,
      confidence: 0,
      matchType: repeatedOldSpeech
          ? _MemorizationMatchType.repeated
          : _MemorizationMatchType.none,
      mistakeType: repeatedOldSpeech
          ? _MemorizationMistakeType.repeated
          : _MemorizationMistakeType.possibleSpeechError,
      fromIndex: currentIndex,
      nextIndex: currentIndex,
      matchedCount: 0,
      hasPossibleError: !repeatedOldSpeech,
      unexpectedWord: heardWords.isEmpty ? null : heardWords.last,
    );
  }

  _SequenceMatch _selectMatch(
    _SequenceMatch currentMatch,
    _SequenceMatch anchorMatch,
  ) {
    final isBackwardAnchor = anchorMatch.startIndex < currentMatch.startIndex;
    if (isBackwardAnchor &&
        currentMatch.startIndex > 0 &&
        anchorMatch.matchedCount < 2) {
      return currentMatch;
    }
    if (anchorMatch.matchedCount > currentMatch.matchedCount) {
      return anchorMatch;
    }
    if (anchorMatch.matchedCount == 0) return currentMatch;
    if (currentMatch.matchedCount == 0) return anchorMatch;
    if (anchorMatch.matchedCount == currentMatch.matchedCount &&
        anchorMatch.confidence > currentMatch.confidence + 0.12 &&
        anchorMatch.matchedCount >= 2) {
      return anchorMatch;
    }
    if (isBackwardAnchor && anchorMatch.matchedCount >= 2) {
      return anchorMatch;
    }
    return currentMatch;
  }

  _SequenceMatch _bestAnchorMatch({
    required List<String> heardWords,
    required int currentIndex,
  }) {
    var best = const _SequenceMatch(startIndex: 0, score: _MatchScore.empty());

    for (var index = 0; index < words.length; index++) {
      final score = _matchHeardWordsAt(
        startWordIndex: index,
        heardWords: heardWords,
      );
      if (score.matchedCount < 2 && index != currentIndex) continue;

      final candidate = _SequenceMatch(startIndex: index, score: score);
      if (_isBetterAnchor(candidate, best, currentIndex)) {
        best = candidate;
      }
    }

    return best;
  }

  bool _isBetterAnchor(
    _SequenceMatch candidate,
    _SequenceMatch best,
    int currentIndex,
  ) {
    if (candidate.matchedCount != best.matchedCount) {
      return candidate.matchedCount > best.matchedCount;
    }

    if ((candidate.confidence - best.confidence).abs() > 0.08) {
      return candidate.confidence > best.confidence;
    }

    final candidateDistance = (candidate.startIndex - currentIndex).abs();
    final bestDistance = (best.startIndex - currentIndex).abs();
    if (candidateDistance != bestDistance) {
      return candidateDistance < bestDistance;
    }

    return candidate.startIndex < best.startIndex;
  }

  _MatchScore _matchHeardWordsAt({
    required int startWordIndex,
    required List<String> heardWords,
  }) {
    if (startWordIndex < 0 || startWordIndex >= words.length) {
      return const _MatchScore.empty();
    }

    var matchedCount = 0;
    var confidenceSum = 0.0;
    var hasFuzzyWord = false;
    for (final heardWord in heardWords) {
      final wordIndex = startWordIndex + matchedCount;
      if (wordIndex >= words.length) break;

      final expected = _compactArabic(words[wordIndex].normalized);
      final confidence = _wordMatchConfidence(heardWord, expected);
      if (confidence <= 0) break;
      confidenceSum += confidence;
      if (confidence < 1) hasFuzzyWord = true;
      matchedCount++;
    }

    if (matchedCount == 0) return const _MatchScore.empty();
    return _MatchScore(
      matchedCount: matchedCount,
      confidence: confidenceSum / matchedCount,
      hasFuzzyWord: hasFuzzyWord,
    );
  }

  double _wordMatchConfidence(String heardCompact, String expectedCompact) {
    for (final variant in _wordVariants(expectedCompact)) {
      if (heardCompact == variant) {
        return 1;
      }
      final shortestLength = heardCompact.length < variant.length
          ? heardCompact.length
          : variant.length;
      if (shortestLength <= 2) continue;

      if (heardCompact.length >= 4 &&
          variant.length >= 4 &&
          (heardCompact.contains(variant) || variant.contains(heardCompact))) {
        return 0.82;
      }
      final similarity = _wordSimilarity(heardCompact, variant);
      if (_hasSmallWordError(heardCompact, variant) &&
          similarity >= _minimumWordSimilarity) {
        return similarity;
      }
    }

    return 0;
  }

  bool _hasSmallWordError(String heard, String expected) {
    final maxLength = heard.length > expected.length
        ? heard.length
        : expected.length;
    final allowedDistance = maxLength >= 7 ? 2 : 1;
    return _levenshteinDistance(heard, expected) <= allowedDistance;
  }

  double _wordSimilarity(String heard, String expected) {
    if (heard == expected) return 1;
    if (heard.isEmpty || expected.isEmpty) return 0;

    final maxLength = heard.length > expected.length
        ? heard.length
        : expected.length;
    final distance = _levenshteinDistance(heard, expected);
    return 1 - (distance / maxLength);
  }

  int _levenshteinDistance(String first, String second) {
    if (first == second) return 0;
    if (first.isEmpty) return second.length;
    if (second.isEmpty) return first.length;

    var previous = List<int>.generate(second.length + 1, (index) => index);
    var current = List<int>.filled(second.length + 1, 0);

    for (var i = 0; i < first.length; i++) {
      current[0] = i + 1;

      for (var j = 0; j < second.length; j++) {
        final substitutionCost = first.codeUnitAt(i) == second.codeUnitAt(j)
            ? 0
            : 1;
        final deletion = previous[j + 1] + 1;
        final insertion = current[j] + 1;
        final substitution = previous[j] + substitutionCost;

        current[j + 1] = [
          deletion,
          insertion,
          substitution,
        ].reduce((a, b) => a < b ? a : b);
      }

      final swap = previous;
      previous = current;
      current = swap;
    }

    return previous[second.length];
  }

  Set<String> _wordVariants(String expectedCompact) {
    final variants = <String>{expectedCompact};

    variants.addAll(_disconnectedLetterVariants(expectedCompact));
    if (expectedCompact.startsWith('ال') && expectedCompact.length > 4) {
      variants.add(expectedCompact.substring(2));
    }
    if (expectedCompact == 'بسم') variants.add('باسم');
    if (expectedCompact == 'الرحمن') variants.add('الرحمان');
    if (expectedCompact == 'ملك') variants.add('مالك');
    if (expectedCompact == 'مالك') variants.add('ملك');

    variants.removeWhere((variant) => variant.length < 2);
    return variants;
  }

  Set<String> _disconnectedLetterVariants(String expectedCompact) {
    const letters = {
      'ا': 'الف',
      'ل': 'لام',
      'م': 'ميم',
      'ص': 'صاد',
      'ر': 'را',
      'ك': 'كاف',
      'ه': 'ها',
      'ي': 'يا',
      'ع': 'عين',
      'ط': 'طا',
      'س': 'سين',
      'ح': 'حا',
      'ق': 'قاف',
      'ن': 'نون',
    };

    if (expectedCompact.length < 2 || expectedCompact.length > 5) {
      return const <String>{};
    }

    final names = <String>[];
    for (final char in expectedCompact.characters) {
      final name = letters[char];
      if (name == null) return const <String>{};
      names.add(name);
    }

    return {names.join(), names.join(' ')}.map(_compactArabic).toSet();
  }
}

class _SequenceMatch {
  const _SequenceMatch({required this.startIndex, required this.score});

  final int startIndex;
  final _MatchScore score;

  int get matchedCount => score.matchedCount;
  double get confidence => score.confidence;
  bool get hasFuzzyWord => score.hasFuzzyWord;
}

class _MatchScore {
  const _MatchScore({
    required this.matchedCount,
    required this.confidence,
    required this.hasFuzzyWord,
  });

  const _MatchScore.empty()
    : matchedCount = 0,
      confidence = 0,
      hasFuzzyWord = false;

  final int matchedCount;
  final double confidence;
  final bool hasFuzzyWord;
}

List<String> _splitQuranWords(String value) {
  return value
      .replaceAll(RegExp(r'[\u06DD????0-90-9]+'), ' ')
      .split(RegExp(r'\s+'))
      .map((word) => word.trim())
      .where((word) => word.isNotEmpty)
      .toList();
}

List<String> _splitHeardWords(String value) {
  final normalized = _normalizeArabic(value);
  if (normalized.isEmpty) return const <String>[];
  return normalized
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
}

String _compactArabic(String value) {
  return _normalizeArabic(value)
      .replaceAll('باسم', 'بسم')
      .replaceAll('الرحمان', 'الرحمن')
      .replaceAll('رحمان', 'رحمن')
      .replaceAll('مالكيوم', 'ملكيوم')
      .replaceAll('ذالك', 'ذلك')
      .replaceAll('هاذا', 'هذا')
      .replaceAll('لاكن', 'لكن')
      .replaceAll(' ', '');
}

String _normalizeArabic(String value) {
  return value
      .trim()
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u06D6-\u06ED]'), '')
      .replaceAll('\u0640', '')
      .replaceAll(RegExp(r'[إأآٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ؤ', 'و')
      .replaceAll('ئ', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll(RegExp(r'[^\u0621-\u064A\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
