// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:quran/quran.dart' as quran_text;
import 'package:quran_library/quran_library.dart';
import 'package:turn_page_transition/turn_page_transition.dart';

import '../controllers/app_controller.dart';
import '../services/audio_service.dart';
import '../services/quran_service.dart';
import '../theme/app_theme.dart';
import 'quran_memorization_page.dart';

final ValueNotifier<int> _mushafPageNotifier = ValueNotifier<int>(1);

class QuranPage extends StatefulWidget {
  const QuranPage({super.key});

  static const _goldColor = Color(0xFFD4AF37);

  @override
  State<QuranPage> createState() => _QuranPageState();
}

class _QuranPageState extends State<QuranPage> {
  late final QuranService _quranService;
  final _foldPageViewKey = GlobalKey<_QuranFoldPageViewState>();
  Timer? _toolbarTimer;
  bool _isToolbarVisible = false;

  @override
  void initState() {
    super.initState();
    _quranService = Get.find<QuranService>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final lastRead = _quranService.getLastRead();
      _mushafPageNotifier.value = lastRead.page;
      QuranLibrary().jumpToPage(lastRead.page);
    });
  }

  @override
  void dispose() {
    _toolbarTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appController = Get.find<AppController>();

    return Obx(() {
      final isNightMode = appController.isNightMode.value;
      final quranTheme = ThemeData(
        useMaterial3: false,
        brightness: isNightMode ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: isNightMode
            ? Colors.black
            : AppTheme.backgroundLight,
        colorScheme: isNightMode
            ? const ColorScheme.dark(
                primary: AppTheme.goldNight,
                secondary: AppTheme.goldNight,
                surface: Colors.black,
                onPrimary: Colors.black,
                onSecondary: Colors.black,
                onSurface: Colors.white,
              )
            : const ColorScheme.light(
                primary: AppTheme.goldLight,
                secondary: AppTheme.goldLight,
                surface: AppTheme.backgroundLight,
                onPrimary: Colors.white,
                onSecondary: Colors.white,
                onSurface: Colors.black,
              ),
      );

      return Theme(
        data: quranTheme,
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (_, _) => appController.navigateToPage(0),
          child: Stack(
            children: [
              Obx(
                () =>
                    appController.pageNavigationMode.value ==
                        PageNavigationMode.fold
                    ? ValueListenableBuilder<int>(
                        valueListenable: _mushafPageNotifier,
                        builder: (context, page, _) {
                          return _QuranFoldPageView(
                            key: _foldPageViewKey,
                            currentPage: page,
                            onPageChanged: saveMushafPage,
                            onPagePress: _toggleToolbar,
                            onAyahLongPress: (_, ayah) =>
                                _showAyahMoreOptions(
                                  context: context,
                                  ayah: ayah,
                                ),
                            anotherMenuChildOnTap: (ayah) =>
                                _showAyahMoreOptions(
                                  context: context,
                                  ayah: ayah,
                                ),
                          );
                        },
                      )
                    : _QuranLibraryView(
                        withPageView: true,
                        onPageChanged: (pageIndex) =>
                            saveMushafPage(pageIndex + 1),
                        onPagePress: _toggleToolbar,
                        onAyahLongPress: (_, ayah) =>
                            _showAyahMoreOptions(context: context, ayah: ayah),
                        anotherMenuChildOnTap: (ayah) =>
                            _showAyahMoreOptions(context: context, ayah: ayah),
                      ),
              ),
              PositionedDirectional(
                start: 12,
                end: 12,
                top: MediaQuery.paddingOf(context).top + 8,
                child: AnimatedOpacity(
                  opacity: _isToolbarVisible ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: IgnorePointer(
                    ignoring: !_isToolbarVisible,
                    child: ValueListenableBuilder<int>(
                      valueListenable: _mushafPageNotifier,
                      builder: (context, page, _) {
                        return _QuranQuickPanel(
                          currentPage: page,
                          onSearch: () => _showQuranSearchSheet(context),
                          onIndex: () => _showQuranIndexSheet(context),
                          onJump: () => _showQuranJumpSheet(context),
                          onPrevious: () => _goToMushafPageFromControl(
                            (page - 1).clamp(1, quran_text.totalPagesCount),
                          ),
                          onNext: () => _goToMushafPageFromControl(
                            (page + 1).clamp(1, quran_text.totalPagesCount),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              PositionedDirectional(
                start: 12,
                end: 12,
                bottom: MediaQuery.paddingOf(context).bottom + 8,
                child: AnimatedOpacity(
                  opacity: _isToolbarVisible ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: IgnorePointer(
                    ignoring: !_isToolbarVisible,
                    child: _QuranFloatingToolbar(
                      onHome: () => appController.navigateToPage(0),
                      onMemorize: () => _showQuranMemorizationSheet(context),
                      onAudio: () => _showQuranAudioSheet(context),
                      onSaveMark: () => _saveCurrentReadingMark(context),
                      onOpenMark: () => _openReadingMarkSheet(context),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  void _toggleToolbar() {
    if (_isToolbarVisible) {
      _hideToolbar();
    } else {
      _showToolbar();
    }
  }

  void _showToolbar() {
    _toolbarTimer?.cancel();
    if (mounted) {
      setState(() => _isToolbarVisible = true);
    }
    _toolbarTimer = Timer(const Duration(seconds: 5), _hideToolbar);
  }

  void _hideToolbar() {
    _toolbarTimer?.cancel();
    _toolbarTimer = null;
    if (mounted && _isToolbarVisible) {
      setState(() => _isToolbarVisible = false);
    }
  }

  Future<void> _saveCurrentReadingMark(BuildContext context) async {
    final page = _currentMushafPage();
    await _quranService.saveReadingMarkPage(page);
    await _quranService.saveLastReadPage(page);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حفظ العلامة في الموضع الحالي')),
    );
  }

  void _goToMushafPageFromControl(num page) {
    final appController = Get.find<AppController>();
    if (appController.pageNavigationMode.value == PageNavigationMode.fold) {
      if (_foldPageViewKey.currentState?.turnToPage(page) ?? false) return;
      return;
    }
    _jumpToMushafPage(page);
  }
}

class _QuranQuickPanel extends StatelessWidget {
  const _QuranQuickPanel({
    required this.currentPage,
    required this.onSearch,
    required this.onIndex,
    required this.onJump,
    required this.onPrevious,
    required this.onNext,
  });

  final int currentPage;
  final VoidCallback onSearch;
  final VoidCallback onIndex;
  final VoidCallback onJump;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goldColor = theme.hayahGold;
    final isDark = theme.brightness == Brightness.dark;

    return Align(
      alignment: AlignmentDirectional.topCenter,
      child: Material(
        color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(24),
        elevation: 8,
        clipBehavior: Clip.antiAlias,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width - 24,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: goldColor.withValues(alpha: 0.34),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _QuranToolbarButton(
                tooltip: 'بحث',
                icon: Icons.search_rounded,
                onPressed: onSearch,
              ),
              _QuranToolbarButton(
                tooltip: 'الفهرس',
                icon: Icons.format_list_bulleted_rounded,
                onPressed: onIndex,
              ),
              _QuranToolbarButton(
                tooltip: 'الصفحة السابقة',
                icon: Icons.chevron_right_rounded,
                onPressed: onPrevious,
              ),
              InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: onJump,
                child: SizedBox(
                  width: 46,
                  height: 36,
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'ص $currentPage',
                        maxLines: 1,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ).copyWith(color: goldColor),
                      ),
                    ),
                  ),
                ),
              ),
              _QuranToolbarButton(
                tooltip: 'الصفحة التالية',
                icon: Icons.chevron_left_rounded,
                onPressed: onNext,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuranFloatingToolbar extends StatelessWidget {
  const _QuranFloatingToolbar({
    required this.onHome,
    required this.onMemorize,
    required this.onAudio,
    required this.onSaveMark,
    required this.onOpenMark,
  });

  final VoidCallback onHome;
  final VoidCallback onMemorize;
  final VoidCallback onAudio;
  final VoidCallback onSaveMark;
  final VoidCallback onOpenMark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goldColor = theme.hayahGold;
    final isDark = theme.brightness == Brightness.dark;

    return Align(
      alignment: AlignmentDirectional.bottomCenter,
      child: Material(
        color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(24),
        elevation: 8,
        clipBehavior: Clip.antiAlias,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: goldColor.withValues(alpha: 0.34),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _QuranToolbarButton(
                tooltip: 'رجوع',
                icon: Icons.home_rounded,
                onPressed: onHome,
              ),
              _QuranToolbarButton(
                tooltip: 'حفظ موضع القراءة',
                icon: Icons.bookmark_add_rounded,
                onPressed: onSaveMark,
              ),
              _QuranToolbarButton(
                tooltip: 'الذهاب إلى العلامة',
                icon: Icons.flag_rounded,
                onPressed: onOpenMark,
              ),
              _QuranToolbarButton(
                tooltip: 'تشغيل التلاوة',
                icon: Icons.volume_up_rounded,
                onPressed: onAudio,
              ),
              _QuranToolbarButton(
                tooltip: 'مساعد الحفظ',
                icon: Icons.psychology_rounded,
                onPressed: onMemorize,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuranToolbarButton extends StatelessWidget {
  const _QuranToolbarButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final goldColor = Theme.of(context).hayahGold;

    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, color: goldColor),
      style: IconButton.styleFrom(
        fixedSize: const Size(38, 38),
        minimumSize: const Size(38, 38),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

void _openReadingMarkSheet(BuildContext context) {
  final quranService = Get.find<QuranService>();
  final currentPageVerses = quranService.getPageVerses(_currentMushafPage());
  final savedMark = quranService.getReadingMark();
  final initialVerse =
      savedMark ??
      (currentPageVerses.isEmpty
          ? quranService.getLastRead()
          : currentPageVerses.first);
  var selectedSurah = initialVerse.surah;
  var selectedVerse = initialVerse.verse;

  Future<void> saveSelectedAndGo(BuildContext sheetContext) async {
    await quranService.saveReadingMark(selectedSurah, selectedVerse);
    await quranService.saveLastRead(selectedSurah, selectedVerse);
    final page = quran_text.getPageNumber(selectedSurah, selectedVerse);
    QuranLibrary().jumpToPage(page);
    if (sheetContext.mounted) Navigator.pop(sheetContext);
  }

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.black,
    isScrollControlled: true,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          final verseCount = quran_text.getVerseCount(selectedSurah);
          selectedVerse = selectedVerse.clamp(1, verseCount).toInt();

          return SafeArea(
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  18,
                  14,
                  18,
                  MediaQuery.viewInsetsOf(context).bottom + 22,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.flag_rounded,
                          color: QuranPage._goldColor,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'علامة القراءة',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                    if (savedMark != null) ...[
                      const SizedBox(height: 8),
                      _ReadingMarkSummary(verse: savedMark),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: QuranPage._goldColor,
                          side: const BorderSide(color: QuranPage._goldColor),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          QuranLibrary().jumpToPage(savedMark.page);
                          quranService.saveLastRead(
                            savedMark.surah,
                            savedMark.verse,
                          );
                          Navigator.pop(sheetContext);
                        },
                        icon: const Icon(Icons.near_me_rounded),
                        label: const Text('الذهاب إلى العلامة المحفوظة'),
                      ),
                    ] else ...[
                      const SizedBox(height: 8),
                      Text(
                        'لم تحفظ علامة بعد. اختر موضعاً أو احفظ الصفحة الحالية من شريط الأدوات.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.68),
                          height: 1.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _QuranRangeDropdown<int>(
                      value: selectedSurah,
                      label: 'السورة',
                      items: List.generate(quran_text.totalSurahCount, (index) {
                        final surah = index + 1;
                        return DropdownMenuItem<int>(
                          value: surah,
                          child: Text(
                            '$surah. ${quran_text.getSurahNameArabic(surah)}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }),
                      onChanged: (value) {
                        if (value == null) return;
                        setSheetState(() {
                          selectedSurah = value;
                          selectedVerse = 1;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _QuranRangeDropdown<int>(
                      value: selectedVerse,
                      label: 'الآية',
                      items: List.generate(verseCount, (index) {
                        final verse = index + 1;
                        return DropdownMenuItem<int>(
                          value: verse,
                          child: Text('الآية $verse'),
                        );
                      }),
                      onChanged: (value) {
                        if (value == null) return;
                        setSheetState(() => selectedVerse = value);
                      },
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: QuranPage._goldColor,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      onPressed: () => saveSelectedAndGo(sheetContext),
                      icon: const Icon(Icons.bookmark_added_rounded),
                      label: const Text('حفظ هذا الموضع والذهاب إليه'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

class _ReadingMarkSummary extends StatelessWidget {
  const _ReadingMarkSummary({required this.verse});

  final QuranVerse verse;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        'المحفوظ الآن: ${quran_text.getSurahNameArabic(verse.surah)} - الآية ${verse.verse} - الصفحة ${verse.page}',
        textAlign: TextAlign.right,
        style: const TextStyle(color: Colors.white, height: 1.5),
      ),
    );
  }
}

void _showQuranMemorizationSheet(BuildContext context) {
  final quranService = Get.find<QuranService>();
  final initialPageVerses = quranService.getPageVerses(_currentMushafPage());
  final initialVerse = initialPageVerses.isEmpty
      ? quranService.getLastRead()
      : initialPageVerses.first;
  var selectedSurah = initialVerse.surah;
  var selectedVerse = initialVerse.verse;
  var selectedEndVerse = initialPageVerses
      .where((verse) => verse.surah == selectedSurah)
      .map((verse) => verse.verse)
      .fold<int>(
        initialVerse.verse,
        (previous, verse) => verse > previous ? verse : previous,
      );

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.black,
    isScrollControlled: true,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          final verseCount = quran_text.getVerseCount(selectedSurah);
          selectedVerse = selectedVerse.clamp(1, verseCount).toInt();
          selectedEndVerse = selectedEndVerse
              .clamp(selectedVerse, verseCount)
              .toInt();

          return SafeArea(
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  18,
                  14,
                  18,
                  MediaQuery.viewInsetsOf(context).bottom + 22,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.psychology_rounded,
                          color: QuranPage._goldColor,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'مساعد الحفظ',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _QuranRangeDropdown<int>(
                      value: selectedSurah,
                      label: 'السورة',
                      items: List.generate(quran_text.totalSurahCount, (index) {
                        final surah = index + 1;
                        return DropdownMenuItem<int>(
                          value: surah,
                          child: Text(
                            '$surah. ${quran_text.getSurahNameArabic(surah)}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }),
                      onChanged: (value) {
                        if (value == null) return;
                        setSheetState(() {
                          selectedSurah = value;
                          selectedVerse = 1;
                          selectedEndVerse = quran_text.getVerseCount(value);
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _QuranRangeDropdown<int>(
                      value: selectedVerse,
                      label: 'بداية الحفظ',
                      items: List.generate(verseCount, (index) {
                        final verse = index + 1;
                        return DropdownMenuItem<int>(
                          value: verse,
                          child: Text('الآية $verse'),
                        );
                      }),
                      onChanged: (value) {
                        if (value == null) return;
                        setSheetState(() {
                          selectedVerse = value;
                          if (selectedEndVerse < value) {
                            selectedEndVerse = value;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _QuranRangeDropdown<int>(
                      value: selectedEndVerse,
                      label: 'نهاية الحفظ',
                      items: List.generate(verseCount - selectedVerse + 1, (
                        index,
                      ) {
                        final verse = selectedVerse + index;
                        return DropdownMenuItem<int>(
                          value: verse,
                          child: Text('الآية $verse'),
                        );
                      }),
                      onChanged: (value) {
                        if (value == null) return;
                        setSheetState(() => selectedEndVerse = value);
                      },
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: QuranPage._goldColor,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        final page = quran_text.getPageNumber(
                          selectedSurah,
                          selectedVerse,
                        );
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => QuranMemorizationPage(
                              initialPage: page,
                              initialSurah: selectedSurah,
                              initialStartVerse: selectedVerse,
                              initialEndVerse: selectedEndVerse,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('بدء الحفظ'),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'سيتم إخفاء الكلمات ثم إظهارها تدريجياً أثناء التلاوة.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

void _showQuranAudioSheet(BuildContext context) {
  final quranService = Get.find<QuranService>();
  final audioService = Get.find<QuranAudioService>();
  final initialPageVerses = quranService.getPageVerses(_currentMushafPage());
  final initialVerse = initialPageVerses.isEmpty
      ? quranService.getLastRead()
      : initialPageVerses.first;
  var selectedReciterKey = quranService.getSelectedReciter().key;
  var selectedSurah = initialVerse.surah;
  var selectedVerse = initialVerse.verse;
  var selectedEndVerse = quran_text.getVerseCount(initialVerse.surah);
  var isLoading = false;

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.black,
    isScrollControlled: true,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          final currentPage = _currentMushafPage();
          final verseCount = quran_text.getVerseCount(selectedSurah);
          if (selectedVerse > verseCount) {
            selectedVerse = verseCount;
          }
          if (selectedEndVerse > verseCount) {
            selectedEndVerse = verseCount;
          }
          if (selectedEndVerse < selectedVerse) {
            selectedEndVerse = selectedVerse;
          }
          final versesToPlay = quranService.getSurahVersesRange(
            selectedSurah,
            selectedVerse,
            selectedEndVerse,
          );
          final firstVerse = versesToPlay.isEmpty ? null : versesToPlay.first;
          final lastVerse = versesToPlay.isEmpty ? null : versesToPlay.last;

          Future<void> playSelectedVerses() async {
            setSheetState(() => isLoading = true);
            try {
              final urls = versesToPlay
                  .map((verse) => verse.audioUrl)
                  .where((url) => url.trim().isNotEmpty)
                  .toList();
              await audioService.playPlaylist(urls);
            } catch (_) {
              Get.snackbar(
                'الصوت',
                'تعذر تشغيل التلاوة. تأكد من الاتصال بالإنترنت ثم حاول مرة أخرى.',
                backgroundColor: Colors.red.shade900,
                colorText: Colors.white,
              );
            } finally {
              if (sheetContext.mounted) {
                setSheetState(() => isLoading = false);
              }
            }
          }

          return SafeArea(
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  18,
                  14,
                  18,
                  MediaQuery.viewInsetsOf(context).bottom + 22,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.volume_up_rounded,
                          color: QuranPage._goldColor,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'تشغيل التلاوة',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: selectedReciterKey,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF151515),
                      decoration: InputDecoration(
                        labelText: 'القارئ',
                        labelStyle: const TextStyle(color: Colors.white70),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white24),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                            color: QuranPage._goldColor,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                      items: QuranService.reciters
                          .map(
                            (reciter) => DropdownMenuItem<String>(
                              value: reciter.key,
                              child: Text(reciter.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) async {
                        if (value == null) return;
                        setSheetState(() => selectedReciterKey = value);
                        await quranService.setSelectedReciter(value);
                        if (sheetContext.mounted) setSheetState(() {});
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: selectedSurah,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF151515),
                      decoration: InputDecoration(
                        labelText: 'السورة',
                        labelStyle: const TextStyle(color: Colors.white70),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white24),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                            color: QuranPage._goldColor,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                      items: List.generate(quran_text.totalSurahCount, (index) {
                        final surah = index + 1;
                        return DropdownMenuItem<int>(
                          value: surah,
                          child: Text(
                            '$surah. ${quran_text.getSurahNameArabic(surah)}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }),
                      onChanged: (value) {
                        if (value == null) return;
                        setSheetState(() {
                          selectedSurah = value;
                          selectedVerse = 1;
                          selectedEndVerse = quran_text.getVerseCount(value);
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: selectedVerse,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF151515),
                      decoration: InputDecoration(
                        labelText: 'بدء التشغيل من الآية',
                        labelStyle: const TextStyle(color: Colors.white70),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white24),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                            color: QuranPage._goldColor,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                      items: List.generate(verseCount, (index) {
                        final verse = index + 1;
                        return DropdownMenuItem<int>(
                          value: verse,
                          child: Text('الآية $verse'),
                        );
                      }),
                      onChanged: (value) {
                        if (value == null) return;
                        setSheetState(() {
                          selectedVerse = value;
                          if (selectedEndVerse < value) {
                            selectedEndVerse = value;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: selectedEndVerse,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF151515),
                      decoration: InputDecoration(
                        labelText: 'انتهاء التشغيل عند الآية',
                        labelStyle: const TextStyle(color: Colors.white70),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white24),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                            color: QuranPage._goldColor,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                      items: List.generate(verseCount - selectedVerse + 1, (
                        index,
                      ) {
                        final verse = selectedVerse + index;
                        return DropdownMenuItem<int>(
                          value: verse,
                          child: Text('الآية $verse'),
                        );
                      }),
                      onChanged: (value) {
                        if (value == null) return;
                        setSheetState(() => selectedEndVerse = value);
                      },
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'الصفحة الحالية: $currentPage',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (firstVerse != null && lastVerse != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              'سيتم التشغيل من ${quran_text.getSurahNameArabic(firstVerse.surah)} '
                              'آية ${firstVerse.verse} إلى آية ${lastVerse.verse}',
                              style: const TextStyle(
                                color: Colors.white70,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    StreamBuilder(
                      stream: audioService.playerStateStream,
                      builder: (context, snapshot) {
                        final isPlaying =
                            snapshot.data?.playing ?? audioService.isPlaying;

                        return Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: QuranPage._goldColor,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 13,
                                  ),
                                ),
                                onPressed: isLoading
                                    ? null
                                    : playSelectedVerses,
                                icon: isLoading
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.black,
                                        ),
                                      )
                                    : Icon(
                                        isPlaying
                                            ? Icons.replay_rounded
                                            : Icons.play_arrow_rounded,
                                      ),
                                label: Text(
                                  isPlaying
                                      ? 'إعادة التشغيل'
                                      : 'تشغيل النطاق المحدد',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            IconButton.filledTonal(
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white12,
                                foregroundColor: Colors.white,
                                fixedSize: const Size(48, 48),
                              ),
                              onPressed: () => audioService.stop(),
                              icon: const Icon(Icons.stop_rounded),
                              tooltip: 'إيقاف',
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'سيتم تشغيل الآيات المختارة بالتتابع حسب القارئ المحدد.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

int _currentMushafPage() {
  final signaledPage = _mushafPageNotifier.value;
  if (signaledPage >= 1 && signaledPage <= quran_text.totalPagesCount) {
    return signaledPage;
  }
  try {
    return QuranLibrary().currentPageNumber
        .clamp(1, quran_text.totalPagesCount)
        .toInt();
  } catch (_) {
    return 1;
  }
}

void _jumpToMushafPage(num page) {
  final safePage = page.clamp(1, quran_text.totalPagesCount).toInt();
  _mushafPageNotifier.value = safePage;
  QuranLibrary().jumpToPage(safePage);
  Get.find<QuranService>().saveLastReadPage(safePage);
}

Future<void> saveMushafPage(int page) async {
  final safePage = page.clamp(1, quran_text.totalPagesCount).toInt();
  _mushafPageNotifier.value = safePage;
  await Get.find<QuranService>().saveLastReadPage(safePage);
}

void _disposeTextControllerAfterRouteExit(
  Future<void>? route,
  TextEditingController controller,
) {
  route?.whenComplete(() async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    controller.dispose();
  });
}

void _showQuranJumpSheet(BuildContext context) {
  final controller = TextEditingController(text: '${_currentMushafPage()}');
  String? errorText;

  final route = showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.black,
    isScrollControlled: true,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          void submit() {
            final page = int.tryParse(controller.text.trim());
            if (page == null || page < 1 || page > quran_text.totalPagesCount) {
              setSheetState(() => errorText = 'أدخل رقم صفحة صحيح');
              return;
            }
            _jumpToMushafPage(page);
            Navigator.pop(sheetContext);
          }

          return SafeArea(
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  18,
                  16,
                  18,
                  MediaQuery.viewInsetsOf(context).bottom + 22,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'انتقال سريع',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: controller,
                      autofocus: false,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.go,
                      onSubmitted: (_) => submit(),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'رقم الصفحة',
                        helperText: 'من 1 إلى ${quran_text.totalPagesCount}',
                        errorText: errorText,
                        labelStyle: const TextStyle(color: Colors.white70),
                        helperStyle: const TextStyle(color: Colors.white54),
                        enabledBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white24),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: QuranPage._goldColor),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: QuranPage._goldColor,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      onPressed: submit,
                      icon: const Icon(Icons.near_me_rounded),
                      label: const Text('اذهب إلى الصفحة'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );

  _disposeTextControllerAfterRouteExit(route, controller);
}

void _showQuranIndexSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.black,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.78,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                child: Text(
                  'فهرس السور',
                  style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: quran_text.totalSurahCount,
                  separatorBuilder: (_, _) =>
                      Divider(color: Colors.white.withValues(alpha: 0.08)),
                  itemBuilder: (context, index) {
                    final surah = index + 1;
                    final page = quran_text.getPageNumber(surah, 1);
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: QuranPage._goldColor.withValues(
                          alpha: 0.14,
                        ),
                        foregroundColor: QuranPage._goldColor,
                        child: Text('$surah'),
                      ),
                      title: Text(
                        quran_text.getSurahNameArabic(surah),
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        'آياتها ${quran_text.getVerseCount(surah)} - صفحة $page',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.62),
                        ),
                      ),
                      onTap: () {
                        _jumpToMushafPage(page);
                        Navigator.pop(sheetContext);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void _showQuranSearchSheet(BuildContext context) {
  final controller = TextEditingController();
  var query = '';

  final route = showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.black,
    isScrollControlled: true,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          final results = _searchQuranLightly(query);

          return SafeArea(
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: SizedBox(
                height: MediaQuery.sizeOf(sheetContext).height * 0.78,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    18,
                    16,
                    18,
                    MediaQuery.viewInsetsOf(context).bottom + 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'بحث في القرآن',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: controller,
                        autofocus: false,
                        textInputAction: TextInputAction.search,
                        onChanged: (value) =>
                            setSheetState(() => query = value),
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'كلمة أو جزء من آية',
                          hintText: 'مثال: الحمد لله',
                          labelStyle: TextStyle(color: Colors.white70),
                          hintStyle: TextStyle(color: Colors.white38),
                          prefixIcon: Icon(
                            Icons.search,
                            color: QuranPage._goldColor,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.white24),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: QuranPage._goldColor),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: query.trim().isEmpty
                            ? const Center(
                                child: Text(
                                  'اكتب عبارة للبحث داخل المصحف',
                                  style: TextStyle(color: Colors.white54),
                                ),
                              )
                            : results.isEmpty
                            ? const Center(
                                child: Text(
                                  'لا توجد نتائج مطابقة',
                                  style: TextStyle(color: Colors.white54),
                                ),
                              )
                            : ListView.separated(
                                itemCount: results.length,
                                separatorBuilder: (_, _) => Divider(
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                                itemBuilder: (context, index) {
                                  final result = results[index];
                                  return ListTile(
                                    title: Text(
                                      result.text,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        height: 1.5,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${quran_text.getSurahNameArabic(result.surah)} - الآية ${result.verse} - الصفحة ${result.page}',
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.62,
                                        ),
                                      ),
                                    ),
                                    onTap: () {
                                      _jumpToMushafPage(result.page);
                                      Navigator.pop(sheetContext);
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );

  _disposeTextControllerAfterRouteExit(route, controller);
}

List<_QuranSearchResult> _searchQuranLightly(String query) {
  final normalizedQuery = _normalizeArabicSearch(query);
  if (normalizedQuery.length < 2) return const [];

  final matches = <_QuranSearchResult>[];
  for (var surah = 1; surah <= quran_text.totalSurahCount; surah++) {
    final verseCount = quran_text.getVerseCount(surah);
    for (var verse = 1; verse <= verseCount; verse++) {
      final text = quran_text.getVerse(surah, verse, verseEndSymbol: true);
      if (!_normalizeArabicSearch(text).contains(normalizedQuery)) continue;
      matches.add(
        _QuranSearchResult(
          surah: surah,
          verse: verse,
          page: quran_text.getPageNumber(surah, verse),
          text: text,
        ),
      );
      if (matches.length >= 80) return matches;
    }
  }
  return matches;
}

String _normalizeArabicSearch(String value) {
  return value
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('آ', 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .trim();
}

class _QuranSearchResult {
  const _QuranSearchResult({
    required this.surah,
    required this.verse,
    required this.page,
    required this.text,
  });

  final int surah;
  final int verse;
  final int page;
  final String text;
}

void _showAyahMoreOptions({
  required BuildContext context,
  required AyahModel ayah,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.black,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'خيارات الآية',
                style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _QuranOptionTile(
                icon: Icons.menu_book,
                title: 'عرض التفسير',
                subtitle: 'فتح التفسير المحدد للآية',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showAyahTafsir(context, ayah);
                },
              ),
              _QuranOptionTile(
                icon: Icons.download_for_offline_outlined,
                title: 'تحميل أو اختيار تفسير',
                subtitle: 'اختر من التفاسير والترجمات المتاحة',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showTafsirDownloads(context, ayah);
                },
              ),
              _QuranOptionTile(
                icon: Icons.translate,
                title: 'معنى الآية بالعربية',
                subtitle: 'عرض معنى مبسط للآية باللغة العربية',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showArabicMeaning(context, ayah);
                },
              ),
              _QuranOptionTile(
                icon: Icons.auto_awesome_motion_rounded,
                title: 'الآيات المتشابهة',
                subtitle: 'عرض آيات قريبة من هذه الآية في الألفاظ',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showSimilarAyahs(context, ayah);
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void _showSimilarAyahs(BuildContext context, AyahModel ayah) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.black,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.82,
          child: FutureBuilder<List<SimilarQuranVerse>>(
            future: _loadSimilarAyahs(ayah),
            builder: (context, snapshot) {
              final results = snapshot.data ?? const <SimilarQuranVerse>[];

              return Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                        const Expanded(
                          child: Text(
                            'الآيات المتشابهة',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      ayah.text,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        height: 1.8,
                      ),
                    ),
                    const Divider(color: Colors.white24, height: 28),
                    Expanded(
                      child: snapshot.connectionState != ConnectionState.done
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: QuranPage._goldColor,
                              ),
                            )
                          : results.isEmpty
                          ? const _SimilarAyahsEmptyState()
                          : ListView.separated(
                              itemCount: results.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(color: Colors.white12),
                              itemBuilder: (context, index) {
                                return _SimilarAyahTile(result: results[index]);
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}

Future<List<SimilarQuranVerse>> _loadSimilarAyahs(AyahModel ayah) async {
  try {
    final quranService = Get.find<QuranService>();
    final surah = ayah.surahNumber ?? _surahNumberFromGlobalAyah(ayah);
    if (surah <= 0) return <SimilarQuranVerse>[];

    return quranService.getSimilarVerses(surah, ayah.ayahNumber);
  } catch (error, stackTrace) {
    log(
      'Similar ayahs failed: $error',
      name: 'HayahQuran',
      stackTrace: stackTrace,
    );
    return <SimilarQuranVerse>[];
  }
}

void _showAyahTafsir(BuildContext context, AyahModel ayah) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.black,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.82,
          child: FutureBuilder<String>(
            future: _loadSelectedTafsirText(ayah),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(
                  child: CircularProgressIndicator(color: QuranPage._goldColor),
                );
              }

              final hasError = snapshot.hasError;
              final tafsirText = snapshot.data?.trim() ?? '';

              return Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                        const Expanded(
                          child: Text(
                            'تفسير الآية',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      ayah.text,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        height: 1.8,
                      ),
                    ),
                    const Divider(color: Colors.white24, height: 28),
                    Expanded(
                      child: hasError || tafsirText.isEmpty
                          ? _TafsirEmptyState(
                              ayah: ayah,
                              error: hasError ? '${snapshot.error}' : null,
                            )
                          : SingleChildScrollView(
                              child: Text(
                                tafsirText,
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  height: 1.75,
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}

Future<String> _loadSelectedTafsirText(AyahModel ayah) async {
  final appTafsirText = await _loadAppTafsirText(ayah);
  if (appTafsirText.trim().isNotEmpty) {
    return appTafsirText;
  }

  final quran = QuranLibrary();
  try {
    await quran.initTafsir();
  } catch (error, stackTrace) {
    log(
      'Quran library tafsir initialization failed: $error',
      name: 'HayahQuran',
      stackTrace: stackTrace,
    );
    return '';
  }

  var selectedIndex = quran.tafsirSelected;
  if (selectedIndex > 4) {
    selectedIndex = 3;
  }

  final selectedText = await _tryLoadTafsirByIndex(quran, ayah, selectedIndex);
  if (selectedText.trim().isNotEmpty) {
    return selectedText;
  }

  if (selectedIndex != 3) {
    final fallbackText = await _tryLoadTafsirByIndex(quran, ayah, 3);
    if (fallbackText.trim().isNotEmpty) return fallbackText;
  }

  return '';
}

Future<String> _loadAppTafsirText(AyahModel ayah) async {
  try {
    final quranService = Get.find<QuranService>();
    final surah = ayah.surahNumber ?? _surahNumberFromGlobalAyah(ayah);
    if (surah <= 0) return '';

    final tafsir = await quranService.getTafsir(surah, ayah.ayahNumber);
    log(
      'Loaded app tafsir length=${tafsir.length} surah=$surah ayah=${ayah.ayahNumber}',
      name: 'HayahQuran',
    );
    return _cleanTafsirText(tafsir);
  } catch (error) {
    log('App tafsir failed: $error', name: 'HayahQuran');
    return '';
  }
}

int _surahNumberFromGlobalAyah(AyahModel ayah) {
  var cursor = 0;
  for (var surah = 1; surah <= quran_text.totalSurahCount; surah++) {
    cursor += quran_text.getVerseCount(surah);
    if (ayah.ayahUQNumber <= cursor) return surah;
  }
  return ayah.surahNumber ?? 0;
}

Future<String> _tryLoadTafsirByIndex(
  QuranLibrary quran,
  AyahModel ayah,
  int tafsirIndex,
) async {
  try {
    if (!quran.getTafsirDownloaded(tafsirIndex) && tafsirIndex != 3) {
      if (!await _hasInternetConnection()) return '';
      await quran.tafsirDownload(tafsirIndex);
    }

    quran.changeTafsirSwitch(tafsirIndex, pageNumber: ayah.page);
    await quran.closeAndInitializeDatabase(pageNumber: ayah.page);

    final result = await quran.getTafsirOfAyah(
      ayahUniqNumber: ayah.ayahUQNumber,
      databaseName: 'tafsir',
    );
    log(
      'Loaded tafsir rows=${result.length} index=${ayah.ayahUQNumber} tafsirIndex=$tafsirIndex',
      name: 'HayahQuran',
    );
    if (result.isEmpty) return '';
    return _cleanTafsirText(result.first.tafsirText);
  } catch (_) {
    return '';
  }
}

void _showTafsirDownloads(BuildContext context, AyahModel ayah) {
  final quran = QuranLibrary();
  final tafsirs = quran.tafsirAndTraslationCollection;
  final quranService = Get.find<QuranService>();
  final appTafsirs = QuranService.tafsirEditions;

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.black,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.78,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                child: Text(
                  'التفاسير والترجمات المتاحة',
                  style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: 1 + 5 + 1 + appTafsirs.length,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return const _TafsirSectionHeader(
                        title: 'تفاسير المكتبة',
                      );
                    }
                    if (index == 6) {
                      return const _TafsirSectionHeader(
                        title: 'مصادر إضافية قابلة للتحميل',
                      );
                    }

                    if (index > 6) {
                      final appTafsir = appTafsirs[index - 7];
                      final downloaded = quranService.isTafsirEditionDownloaded(
                        appTafsir.key,
                      );
                      final selected =
                          quranService.getSelectedTafsirKey() == appTafsir.key;

                      return ListTile(
                        leading: Icon(
                          downloaded
                              ? Icons.check_circle
                              : Icons.download_outlined,
                          color: downloaded
                              ? QuranPage._goldColor
                              : Colors.white70,
                        ),
                        title: Text(
                          appTafsir.name,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          appTafsir.isTranslation
                              ? 'ترجمة كاملة تحفظ داخل التطبيق'
                              : 'تفسير كامل يحفظ داخل التطبيق',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.62),
                          ),
                        ),
                        trailing: selected
                            ? const Icon(
                                Icons.radio_button_checked,
                                color: QuranPage._goldColor,
                              )
                            : const Icon(
                                Icons.radio_button_unchecked,
                                color: Colors.white38,
                              ),
                        onTap: () => _selectAppTafsirEdition(
                          sheetContext: sheetContext,
                          parentContext: context,
                          ayah: ayah,
                          edition: appTafsir,
                        ),
                      );
                    }

                    final libraryIndex = index - 1;
                    final tafsir = tafsirs[libraryIndex];
                    final downloaded = quran.getTafsirDownloaded(libraryIndex);
                    final selected = quranService.isSelectedLibraryTafsir(
                      libraryIndex,
                    );

                    return ListTile(
                      leading: Icon(
                        downloaded
                            ? Icons.check_circle
                            : Icons.download_outlined,
                        color: downloaded
                            ? QuranPage._goldColor
                            : Colors.white70,
                      ),
                      title: Text(
                        _decodeLegacyArabic(tafsir.name),
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        _decodeLegacyArabic(tafsir.bookName),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.62),
                        ),
                      ),
                      trailing: selected
                          ? const Icon(
                              Icons.radio_button_checked,
                              color: QuranPage._goldColor,
                            )
                          : const Icon(
                              Icons.radio_button_unchecked,
                              color: Colors.white38,
                            ),
                      onTap: () async {
                        if (!downloaded) {
                          final hasInternet = await _hasInternetConnection();
                          if (!sheetContext.mounted) return;
                          if (!hasInternet) {
                            _showTafsirConnectionMessage(sheetContext);
                            return;
                          }
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            SnackBar(
                              content: Text(
                                'جاري تحميل ${_decodeLegacyArabic(tafsir.name)}',
                              ),
                            ),
                          );
                          try {
                            await quran.tafsirDownload(libraryIndex);
                          } catch (error, stackTrace) {
                            log(
                              'Tafsir download failed: $error',
                              name: 'HayahQuran',
                              stackTrace: stackTrace,
                            );
                            if (!sheetContext.mounted) return;
                            _showTafsirConnectionMessage(sheetContext);
                            return;
                          }
                          if (!sheetContext.mounted) return;
                          if (!quran.getTafsirDownloaded(libraryIndex)) {
                            _showTafsirConnectionMessage(sheetContext);
                            return;
                          }
                        }
                        if (!sheetContext.mounted) return;
                        try {
                          quran.changeTafsirSwitch(
                            libraryIndex,
                            pageNumber: ayah.page,
                          );
                          await quranService.setSelectedLibraryTafsir(
                            libraryIndex,
                          );
                          if (!sheetContext.mounted) return;
                        } catch (error, stackTrace) {
                          log(
                            'Tafsir switch failed: $error',
                            name: 'HayahQuran',
                            stackTrace: stackTrace,
                          );
                          if (!sheetContext.mounted) return;
                          _showTafsirConnectionMessage(sheetContext);
                          return;
                        }
                        Navigator.pop(sheetContext);
                        if (context.mounted) _showAyahTafsir(context, ayah);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void _showTafsirConnectionMessage(BuildContext context) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('برجاء الاتصال بالإنترنت ثم حاول تحميل التفسير مرة أخرى.'),
    ),
  );
}

Future<void> _selectAppTafsirEdition({
  required BuildContext sheetContext,
  required BuildContext parentContext,
  required AyahModel ayah,
  required TafsirEdition edition,
}) async {
  final quranService = Get.find<QuranService>();

  if (!quranService.isTafsirEditionDownloaded(edition.key)) {
    final hasInternet = await _hasInternetConnection();
    if (!sheetContext.mounted) return;
    if (!hasInternet) {
      _showTafsirConnectionMessage(sheetContext);
      return;
    }

    ScaffoldMessenger.of(
      sheetContext,
    ).showSnackBar(SnackBar(content: Text('جاري تحميل ${edition.name}')));

    try {
      await quranService.downloadTafsirEdition(edition.key);
    } catch (error, stackTrace) {
      log(
        'App tafsir edition download failed: $error',
        name: 'HayahQuran',
        stackTrace: stackTrace,
      );
      if (!sheetContext.mounted) return;
      _showTafsirConnectionMessage(sheetContext);
      return;
    }
  }

  if (!sheetContext.mounted) return;
  await quranService.setSelectedTafsir(edition.key);
  if (!sheetContext.mounted) return;
  Navigator.pop(sheetContext);
  if (parentContext.mounted) _showAyahTafsir(parentContext, ayah);
}

Future<bool> _hasInternetConnection() async {
  try {
    final lookup = await InternetAddress.lookup(
      'api.alquran.cloud',
    ).timeout(const Duration(seconds: 3));
    return lookup.isNotEmpty && lookup.first.rawAddress.isNotEmpty;
  } catch (_) {
    return false;
  }
}

class _QuranFoldPageView extends StatefulWidget {
  const _QuranFoldPageView({
    super.key,
    required this.currentPage,
    required this.onPageChanged,
    required this.onPagePress,
    required this.onAyahLongPress,
    required this.anotherMenuChildOnTap,
  });

  final int currentPage;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onPagePress;
  final void Function(LongPressStartDetails details, AyahModel ayah)
  onAyahLongPress;
  final void Function(AyahModel ayah) anotherMenuChildOnTap;

  @override
  State<_QuranFoldPageView> createState() => _QuranFoldPageViewState();
}

class _QuranFoldPageViewState extends State<_QuranFoldPageView> {
  static const _turnDuration = Duration(milliseconds: 360);
  static const _turnSettleDelay = Duration(milliseconds: 430);

  late List<int> _visiblePages;
  late int _centerPage;
  late int _initialFoldIndex;
  late TurnPageController _foldController;
  Offset? _foldPointerDownPosition;
  bool _foldPointerMoved = false;
  bool _foldLongPressHandled = false;
  int? _pendingCommitPage;
  int _viewVersion = 0;

  @override
  void initState() {
    super.initState();
    _configureWindow(widget.currentPage);
  }

  @override
  void didUpdateWidget(covariant _QuranFoldPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final page = _safePage(widget.currentPage);
    if (page != _centerPage) {
      _configureWindow(page);
    }
  }

  bool turnToPage(num page) {
    final safePage = _safePage(page.toInt());
    if (safePage == _centerPage) return true;

    final index = _visiblePages.indexOf(safePage);
    if (index == -1) {
      widget.onPageChanged(safePage);
      return true;
    }

    unawaited(_animateToPage(_foldController, index, safePage));
    return true;
  }

  Future<void> _animateToPage(
    TurnPageController controller,
    int index,
    int page,
  ) async {
    await controller.animateToPage(index);
    if (!mounted) return;
    unawaited(_commitPageAfterTurn(page));
  }

  void _handleSwipeComplete(bool isTurnForward) {
    final page = isTurnForward ? _centerPage + 1 : _centerPage - 1;
    if (page < 1 || page > quran_text.totalPagesCount) return;
    unawaited(_commitPageAfterTurn(page));
  }

  Future<void> _commitPageAfterTurn(int page) async {
    final safePage = _safePage(page);
    _pendingCommitPage = safePage;
    await Future<void>.delayed(_turnSettleDelay);
    if (!mounted) return;
    if (_pendingCommitPage != safePage) return;
    _pendingCommitPage = null;
    if (safePage == _centerPage) return;
    setState(() {
      _configureWindow(safePage);
    });
    widget.onPageChanged(safePage);
  }

  void _configureWindow(int page) {
    _centerPage = _safePage(page);
    _visiblePages = _buildVisiblePages(_centerPage);
    _initialFoldIndex = _visiblePages.indexOf(_centerPage);
    _foldController = TurnPageController(
      initialPage: _initialFoldIndex,
      direction: TurnDirection.leftToRight,
      thresholdValue: 0.34,
      duration: _turnDuration,
    );
    _viewVersion++;
  }

  static List<int> _buildVisiblePages(int page) {
    final pages = <int>[
      if (page > 1) page - 1,
      page,
      if (page < quran_text.totalPagesCount) page + 1,
    ];
    return pages;
  }

  static int _safePage(int page) {
    return page.clamp(1, quran_text.totalPagesCount).toInt();
  }

  void _handleFoldPointerDown(PointerDownEvent event) {
    _foldPointerDownPosition = event.localPosition;
    _foldPointerMoved = false;
    _foldLongPressHandled = false;
  }

  void _handleFoldPointerMove(PointerMoveEvent event) {
    final start = _foldPointerDownPosition;
    if (start == null) return;
    if ((event.localPosition - start).distance >= 10) {
      _foldPointerMoved = true;
    }
  }

  void _handleFoldPointerUp(PointerUpEvent event) {
    if (!_foldPointerMoved && !_foldLongPressHandled) widget.onPagePress();
    _foldPointerDownPosition = null;
    _foldPointerMoved = false;
    _foldLongPressHandled = false;
  }

  void _handleFoldPointerCancel(PointerCancelEvent event) {
    _foldPointerDownPosition = null;
    _foldPointerMoved = false;
    _foldLongPressHandled = false;
  }

  void _handleFoldLongPressStart(LongPressStartDetails details) {
    _foldLongPressHandled = true;
    final ayah = _ayahFromFoldLongPress(details.localPosition);
    if (ayah == null) return;
    widget.onAyahLongPress(details, ayah);
  }

  AyahModel? _ayahFromFoldLongPress(Offset localPosition) {
    final pageVerses = Get.find<QuranService>().getPageVerses(_centerPage);
    if (pageVerses.isEmpty) return null;

    final height = context.size?.height ?? MediaQuery.sizeOf(context).height;
    final topInset = MediaQuery.paddingOf(context).top + 42;
    final bottomInset = MediaQuery.paddingOf(context).bottom + 42;
    final readableHeight = (height - topInset - bottomInset).clamp(1.0, height);
    final normalizedY = ((localPosition.dy - topInset) / readableHeight).clamp(
      0.0,
      1.0,
    );
    final verseIndex = (normalizedY * pageVerses.length)
        .floor()
        .clamp(0, pageVerses.length - 1)
        .toInt();
    final verse = pageVerses[verseIndex];
    return AyahModel(
      ayahUQNumber: _globalAyahNumber(verse.surah, verse.verse),
      ayahNumber: verse.verse,
      text: '${verse.text} ',
      ayaTextEmlaey: quran_text.getVerse(
        verse.surah,
        verse.verse,
        verseEndSymbol: false,
      ),
      juz: verse.juz,
      page: verse.page,
      surahNumber: verse.surah,
      lineStart: null,
      lineEnd: null,
      quarter: null,
      hizb: null,
      englishName: quran_text.getSurahNameEnglish(verse.surah),
      arabicName: quran_text.getSurahNameArabic(verse.surah),
      sajdaBool: verse.isSajdah,
      sajda: null,
      centered: false,
      isDownloadedFonts: false,
    );
  }

  int _globalAyahNumber(int surah, int verse) {
    var ayahNumber = verse;
    for (var i = 1; i < surah; i++) {
      ayahNumber += quran_text.getVerseCount(i);
    }
    return ayahNumber;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Stack(
      fit: StackFit.expand,
      children: [
        _QuranLibraryView(
          key: ValueKey('quran-fold-library-$_centerPage'),
          withPageView: false,
          pageIndex: _centerPage - 1,
          onPageChanged: (pageIndex) => widget.onPageChanged(pageIndex + 1),
          onPagePress: widget.onPagePress,
          onAyahLongPress: widget.onAyahLongPress,
          anotherMenuChildOnTap: widget.anotherMenuChildOnTap,
        ),
        Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: _handleFoldPointerDown,
          onPointerMove: _handleFoldPointerMove,
          onPointerUp: _handleFoldPointerUp,
          onPointerCancel: _handleFoldPointerCancel,
          child: TurnPageView.builder(
            key: ValueKey('quran-fold-window-$_viewVersion'),
            controller: _foldController,
            itemCount: _visiblePages.length,
            useOnTap: false,
            useOnSwipe: true,
            animationTransitionPoint: 0.46,
            overleafColorBuilder: (_) =>
                isDark ? Colors.black : AppTheme.backgroundLight,
            overleafBorderColorBuilder: (_) =>
                (isDark ? Colors.white : Colors.black).withValues(alpha: 0.18),
            overleafBorderWidthBuilder: (_) => 0.8,
            onSwipe: _handleSwipeComplete,
            itemBuilder: (context, index) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPressStart: _handleFoldLongPressStart,
              child: const SizedBox.expand(
                child: ColoredBox(color: Color(0x01000000)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _QuranLibraryView extends StatelessWidget {
  const _QuranLibraryView({
    super.key,
    required this.withPageView,
    required this.onPageChanged,
    required this.onPagePress,
    required this.onAyahLongPress,
    required this.anotherMenuChildOnTap,
    this.pageIndex = 0,
  });

  final bool withPageView;
  final int pageIndex;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onPagePress;
  final void Function(LongPressStartDetails details, AyahModel ayah)
  onAyahLongPress;
  final void Function(AyahModel ayah) anotherMenuChildOnTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final goldColor = theme.hayahGold;
    final backgroundColor = isDark ? Colors.black : AppTheme.backgroundLight;
    final textColor = isDark ? Colors.white : Colors.black;

    return QuranLibraryScreen(
      isDark: isDark,
      languageCode: Get.locale?.languageCode ?? 'ar',
      backgroundColor: backgroundColor,
      textColor: textColor,
      ayahIconColor: goldColor,
      ayahSelectedBackgroundColor: goldColor.withValues(alpha: 0.22),
      ayahSelectedFontColor: textColor,
      bookmarksColor: goldColor,
      withPageView: withPageView,
      pageIndex: pageIndex,
      optimizeScrolling: false,
      useDefaultAppBar: false,
      showAyahBookmarkedIcon: true,
      onPageChanged: onPageChanged,
      onPagePress: onPagePress,
      onAyahLongPress: onAyahLongPress,
      anotherMenuChild: Icon(
        Icons.more_horiz,
        color: textColor.withValues(alpha: 0.58),
      ),
      anotherMenuChildOnTap: anotherMenuChildOnTap,
    );
  }
}

class _TafsirSectionHeader extends StatelessWidget {
  const _TafsirSectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
      child: Text(
        title,
        textAlign: TextAlign.right,
        style: TextStyle(
          color: QuranPage._goldColor.withValues(alpha: 0.92),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

void _showArabicMeaning(BuildContext context, AyahModel ayah) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.black,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'المعنى المبسط للآية',
                style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                ayah.text,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  height: 1.8,
                ),
              ),
              const SizedBox(height: 14),
              FutureBuilder<String>(
                future: _loadSimpleArabicMeaning(ayah),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: QuranPage._goldColor,
                      ),
                    );
                  }

                  final meaning = snapshot.data?.trim() ?? '';
                  if (meaning.isEmpty) {
                    return Text(
                      'تعذر تحميل المعنى المبسط الآن. تأكد من الاتصال بالإنترنت ثم حاول مرة أخرى.',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.76),
                        fontSize: 18,
                        height: 1.7,
                      ),
                    );
                  }

                  return Text(
                    meaning,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.76),
                      fontSize: 18,
                      height: 1.7,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<String> _loadSimpleArabicMeaning(AyahModel ayah) async {
  try {
    final quranService = Get.find<QuranService>();
    final surah = ayah.surahNumber ?? _surahNumberFromGlobalAyah(ayah);
    if (surah <= 0) return '';

    final meaning = await quranService.getTafsirForEdition(
      surah,
      ayah.ayahNumber,
      'ar.muyassar',
    );
    return _cleanTafsirText(meaning);
  } catch (error) {
    log('Simple meaning failed: $error', name: 'HayahQuran');
    return '';
  }
}

String _decodeLegacyArabic(String value) {
  try {
    return utf8.decode(latin1.encode(value));
  } catch (_) {
    return value;
  }
}

String _cleanTafsirText(String value) {
  return value
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&amp;', '&')
      .trim();
}

class _TafsirEmptyState extends StatelessWidget {
  const _TafsirEmptyState({required this.ayah, this.error});

  final AyahModel ayah;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.info_outline, color: QuranPage._goldColor, size: 34),
          const SizedBox(height: 12),
          const Text(
            'لم يتم العثور على تفسير لهذه الآية في التفسير الحالي.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 16, height: 1.5),
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(
              error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _showTafsirDownloads(context, ayah);
            },
            icon: const Icon(Icons.download_outlined),
            label: const Text('تحميل أو اختيار تفسير آخر'),
          ),
        ],
      ),
    );
  }
}

class _SimilarAyahTile extends StatelessWidget {
  const _SimilarAyahTile({required this.result});

  final SimilarQuranVerse result;

  @override
  Widget build(BuildContext context) {
    final verse = result.verse;
    final reference =
        '${quran_text.getSurahNameArabic(verse.surah)} ${verse.verse}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: QuranPage._goldColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: QuranPage._goldColor.withValues(alpha: 0.42),
                  ),
                ),
                child: Text(
                  reference,
                  style: const TextStyle(
                    color: QuranPage._goldColor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'صفحة ${verse.page}',
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.52),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            verse.text,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              height: 1.7,
            ),
          ),
          if (result.sharedWords.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'كلمات مشتركة: ${result.sharedWords.take(6).join('، ')}',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.56),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SimilarAyahsEmptyState extends StatelessWidget {
  const _SimilarAyahsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          'لم يتم العثور على آيات متشابهة كافية لهذه الآية.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.72),
            fontSize: 17,
            height: 1.6,
          ),
        ),
      ),
    );
  }
}

class _QuranOptionTile extends StatelessWidget {
  const _QuranOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: QuranPage._goldColor),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.62)),
      ),
    );
  }
}

class _QuranRangeDropdown<T> extends StatelessWidget {
  const _QuranRangeDropdown({
    required this.value,
    required this.label,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final String label;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      dropdownColor: const Color(0xFF151515),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.white24),
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: QuranPage._goldColor),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      style: const TextStyle(color: Colors.white),
      items: items,
      onChanged: onChanged,
    );
  }
}
