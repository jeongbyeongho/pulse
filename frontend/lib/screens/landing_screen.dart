import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../models/trend_insight.dart';
import '../models/trend_item.dart';
import '../services/api_service.dart';
import '../services/theme_controller.dart';
import '../theme/pulse_ui.dart';
import '../utils/news_grouping.dart';
import 'home_screen.dart';
import 'fear_greed_page.dart';
import './market_page.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

String _landingTimeLabel() {
  final now = DateTime.now();
  final hour = now.hour.toString().padLeft(2, '0');
  final minute = now.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _landingCompactTime(String value) {
  final parsed = _landingParseTimestamp(value);
  if (parsed == null) return _landingTimeLabel();
  final diff = DateTime.now().difference(parsed);
  if (!diff.isNegative) {
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
  }
  final month = parsed.month.toString().padLeft(2, '0');
  final day = parsed.day.toString().padLeft(2, '0');
  final hour = parsed.hour.toString().padLeft(2, '0');
  final minute = parsed.minute.toString().padLeft(2, '0');
  return '$month.$day $hour:$minute';
}

String _landingClockLabel(DateTime? dateTime) {
  if (dateTime == null) return '--:--';
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _landingRelativeTimeLabel(DateTime? dateTime) {
  if (dateTime == null) return '방금 전';
  final diff = DateTime.now().difference(dateTime);
  if (diff.inMinutes < 1) return '방금 전';
  if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
  if (diff.inHours < 24) return '${diff.inHours}시간 전';
  return _landingCompactTime(dateTime.toIso8601String());
}

String _landingFormatCompactPrice(double value) {
  final abs = value.abs();
  if (abs >= 1000) return value.toStringAsFixed(0);
  if (abs >= 100) return value.toStringAsFixed(1);
  return value.toStringAsFixed(2);
}

String _landingFormatNumber(num value, {int decimals = 0}) {
  final fixed = value.toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final whole = parts[0];
  final isNegative = whole.startsWith('-');
  final digits = isNegative ? whole.substring(1) : whole;
  final buffer = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    buffer.write(digits[i]);
    final remaining = digits.length - i - 1;
    if (remaining > 0 && remaining % 3 == 0) {
      buffer.write(',');
    }
  }
  final formattedWhole =
      isNegative ? '-${buffer.toString()}' : buffer.toString();
  if (parts.length > 1 && decimals > 0) {
    return '$formattedWhole.${parts[1]}';
  }
  return formattedWhole;
}

String _landingFormatPercent(double value) {
  final sign = value > 0
      ? '+'
      : value < 0
          ? '-'
          : '';
  return '$sign${value.abs().toStringAsFixed(2)}%';
}

String _landingFormatPrice(
  double value, {
  required String marketType,
  String? symbol,
}) {
  switch (marketType) {
    case 'kr':
      return '${_landingFormatNumber(value.round())}원';
    case 'usd':
      return '\$${_landingFormatNumber(value.round())}';
    case 'index':
      return _landingFormatNumber(value.round());
    case 'crypto':
      return '\$${_landingFormatNumber(value.round())}';
    case 'fx':
      return _landingFormatCurrencyPair(value, symbol ?? '');
    default:
      return _landingFormatNumber(value.round());
  }
}

String _landingFormatCurrencyPair(double value, String pair) {
  final upper = pair.toUpperCase();
  if (upper.contains('EUR/USD')) {
    return _landingFormatNumber(value, decimals: 4);
  }
  if (upper.contains('USD/JPY')) {
    return _landingFormatNumber(value, decimals: 2);
  }
  if (upper.contains('USD/KRW')) {
    return _landingFormatNumber(value, decimals: 2);
  }
  return _landingFormatNumber(value, decimals: 2);
}

String _landingFormatStockCode(String symbol) {
  return symbol.replaceFirst(RegExp(r'\.(KS|KQ|US|NASD|NYSE|AMEX)$'), '');
}

String _landingFormatUpdatedAt(DateTime? dateTime) {
  if (dateTime == null) return '--:--';
  final local = dateTime.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String? _landingNaverFinanceUrl(_LandingMarketQuote quote) {
  final symbol = _landingFormatStockCode(quote.symbol).trim();
  if (symbol.isEmpty || quote.symbol.startsWith('^') || quote.symbol.contains('=')) {
    return null;
  }
  return 'https://finance.naver.com/item/main.naver?code=$symbol';
}

String? _landingDelaySummary(DateTime? dateTime) {
  if (dateTime == null) return '시세 확인 중';
  final age = DateTime.now().difference(dateTime).inMinutes;
  if (age > 30) return '시세 지연 가능 · ${_landingFormatUpdatedAt(dateTime)} 기준';
  if (age > 10) return '시세 지연 가능 · ${_landingFormatUpdatedAt(dateTime)} 기준';
  return null;
}

DateTime? _landingLatestUpdatedAt(Iterable<_LandingMarketQuote> quotes) {
  final dates =
      quotes.map((item) => item.priceUpdatedAt).whereType<DateTime>().toList();
  if (dates.isEmpty) return null;
  dates.sort();
  return dates.last;
}

_LandingMarketQuote? _landingQuoteByTitle(
  List<_LandingMarketQuote> quotes,
  String title,
) {
  for (final quote in quotes) {
    if (quote.title == title) return quote;
  }
  return null;
}

String _landingMarketPriceLabel(_LandingMarketQuote quote) {
  switch (quote.group) {
    case 'fx':
      return _landingFormatCurrencyPair(quote.currentPrice, quote.title);
    case 'crypto':
      return _landingFormatPrice(quote.currentPrice, marketType: 'crypto');
    case 'index':
      return _landingFormatPrice(quote.currentPrice, marketType: 'index');
    case 'equity':
    default:
      return _landingFormatPrice(quote.currentPrice, marketType: 'kr');
  }
}

DateTime? _landingTryParseDate(String value) {
  return _landingParseTimestamp(value);
}

DateTime? _landingParseTimestamp(String value) {
  final raw = value.trim();
  if (raw.isEmpty) return null;

  final candidates = <String>[
    raw,
    raw.replaceFirst(' ', 'T'),
    raw.replaceAll('/', '-').replaceFirst(' ', 'T'),
  ];

  for (final candidate in candidates) {
    final parsed = DateTime.tryParse(candidate);
    if (parsed == null) continue;

    final hasTimezone = RegExp(r'(Z|[+-]\d{2}:?\d{2})$', caseSensitive: false)
        .hasMatch(candidate);
    if (hasTimezone) return parsed.toLocal();
    return DateTime.utc(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
      parsed.millisecond,
      parsed.microsecond,
    ).toLocal();
  }

  return null;
}

String? _landingSourceLabel(String source) {
  final value = source.trim();
  if (value.isEmpty) return null;
  final lower = value.toLowerCase();
  final looksLikeUrl = lower.startsWith('http://') ||
      lower.startsWith('https://') ||
      lower.contains('www.');
  if (looksLikeUrl) return null;
  if (value.contains('.') || value.contains('/')) return null;
  return value;
}

Future<void> _landingOpenArticle(BuildContext context, String url) async {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return;

  final opened = await launchUrl(uri, webOnlyWindowName: '_blank');
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('기사 원문을 열 수 없습니다.')),
    );
  }
}

Future<void> _landingOpenExternalLink(BuildContext context, String url) async {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return;

  final opened = await launchUrl(uri, webOnlyWindowName: '_blank');
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('외부 링크를 열 수 없습니다.')),
    );
  }
}

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();
  late Future<TrendInsightSnapshot> _insightFuture;
  late Future<List<IssueTimelineItem>> _timelineFuture;
  late Future<List<TrendItem>> _latestNewsFuture;
  final List<_LandingMarketQuote> _marketQuotes = [];
  final Set<int> _readNewsIds = <int>{};
  Timer? _marketRefreshTimer;
  bool _marketFetching = false;
  bool _marketRefreshing = false;
  bool _insightRefreshing = false;
  String? _marketError;
  DateTime? _marketLastUpdatedAt;
  DateTime? _lastInsightRefreshAt;

  bool get isDark => Theme.of(context).brightness == Brightness.dark;
  Color get titleText => isDark ? Colors.white : const Color(0xFF0F172A);
  Color get mutedText =>
      isDark ? Colors.grey.shade400 : Colors.blueGrey.shade500;
  Color get bodyText =>
      isDark ? Colors.grey.shade300 : Colors.blueGrey.shade800;
  Color get chipBg =>
      isDark ? const Color(0xFF0F172A) : const Color(0xFFEEF4FF);
  Color get chipBorder =>
      isDark ? const Color(0xFF1F2937) : const Color(0xFFDCE7FF);
  Color get inputFill =>
      isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
  Color get inputBorder =>
      isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);
  Color get surface =>
      isDark ? const Color(0xFF111827) : const Color(0xFFFAFBFC);
  Color get surfaceBorder =>
      isDark ? const Color(0xFF1F2937) : const Color(0xFFF0F4F8);
  Color get cardBorder =>
      isDark ? const Color(0xFF1F2937) : const Color(0xFFE8EEF5);
  Color get ctaBg => isDark ? Colors.blue.shade600 : const Color(0xFF2563EB);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _insightFuture = _api.fetchTrendInsights();
    _timelineFuture =
        _api.fetchTrendTimeline(period: '24h', limit: 3, minScore: 45);
    _latestNewsFuture =
        _api.fetchTrends(limit: 12, sort: 'latest', period: '24h');
    _refreshMarketData(force: true);
    _marketRefreshTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _refreshMarketData(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _marketRefreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshMarketDataIfNeeded();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: PulseUi.page(context),
      drawer: isMobile ? _buildDrawer(context) : null,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildAppBar(isMobile),
            _FadeInOnScroll(child: _buildPlatformHero(isMobile)),
            _FadeInOnScroll(
              delay: 70,
              child: _buildBreakingNewsSection(isMobile),
            ),
            _FadeInOnScroll(
              delay: 120,
              child: _buildMarketMoodSection(isMobile),
            ),
            _FadeInOnScroll(
              delay: 170,
              child: _buildMarketOverviewSection(isMobile),
            ),
            _FadeInOnScroll(
              delay: 220,
              child: _buildPopularStocksSection(isMobile),
            ),
            _FadeInOnScroll(
              delay: 270,
              child: _buildMarketDominanceSection(isMobile),
            ),
            const SizedBox(height: 32),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(bool isMobile) {
    return FutureBuilder<TrendInsightSnapshot>(
      future: _insightFuture,
      builder: (context, snapshot) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final insight = snapshot.data;
        final analyzedCount = insight?.sentiment.count ?? 0;
        final sectorMood =
            insight == null ? '분석 대기' : _landingSectorMoodLabel(insight);
        final viewportWidth = MediaQuery.sizeOf(context).width;
        final compactHeader = viewportWidth < 1080;
        final showFxSummary = viewportWidth >= 1400;
        final fxTargets = [
          _landingQuoteByTitle(_marketQuotes, 'USD/KRW'),
          _landingQuoteByTitle(_marketQuotes, 'JPY/KRW'),
          _landingQuoteByTitle(_marketQuotes, 'EUR/KRW'),
          _landingQuoteByTitle(_marketQuotes, 'CNY/KRW'),
        ].whereType<_LandingMarketQuote>().toList();

        return Container(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF111827).withOpacity(0.96)
                : Colors.white.withOpacity(0.92),
            border: Border(
              bottom: BorderSide(
                color:
                    isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0),
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.20 : 0.03),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: PulseUi.maxContentWidth),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: isMobile ? 12 : 14,
                ),
                child: Row(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(
                              'assets/icon/app_icon.png',
                              width: 36,
                              height: 36,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Pulse',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (!compactHeader) ...[
                      if (showFxSummary && fxTargets.isNotEmpty) ...[
                        _LandingHeaderFxInlineBar(quotes: fxTargets),
                        const SizedBox(width: 14),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF172554)
                              : const Color(0xFFEEF4FF),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF1E3A8A)
                                : const Color(0xFFDCE7FF),
                          ),
                        ),
                        child:
                            snapshot.connectionState == ConnectionState.waiting
                                ? Text(
                                    '분석 중',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: isDark
                                          ? Colors.blue.shade100
                                          : Colors.blue.shade700,
                                      letterSpacing: 0,
                                    ),
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF2563EB),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '분석 ${analyzedCount}건 · $sectorMood',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.blue.shade700,
                                          letterSpacing: 0,
                                        ),
                                      ),
                                    ],
                                  ),
                      ),
                      const SizedBox(width: 18),
                      _navItem(
                        '실시간 뉴스',
                        () => _openPage(const HomeScreen()),
                      ),
                      const SizedBox(width: 24),
                      _navItem(
                        '공포탐욕지수',
                        () => _openPage(const FearGreedPage()),
                      ),
                      const SizedBox(width: 24),
                      _navItem(
                        '증시',
                        () => _openPage(const MarketPage()),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        tooltip: isDark ? '라이트 모드' : '다크 모드',
                        onPressed: () =>
                            ThemeController.instance.toggleThemeMode(
                          brightness:
                              isDark ? Brightness.dark : Brightness.light,
                        ),
                        icon: Icon(
                          isDark
                              ? Icons.light_mode_rounded
                              : Icons.dark_mode_rounded,
                          color: isDark
                              ? Colors.blue.shade200
                              : Colors.blue.shade700,
                        ),
                      ),
                    ],
                    if (compactHeader)
                      IconButton(
                        tooltip: isDark ? '라이트 모드' : '다크 모드',
                        onPressed: () =>
                            ThemeController.instance.toggleThemeMode(
                          brightness:
                              isDark ? Brightness.dark : Brightness.light,
                        ),
                        icon: Icon(
                          isDark
                              ? Icons.light_mode_rounded
                              : Icons.dark_mode_rounded,
                          color: isDark
                              ? Colors.blue.shade200
                              : Colors.blue.shade700,
                        ),
                      ),
                    if (compactHeader)
                      IconButton(
                        icon: Icon(
                          Icons.menu,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        onPressed: () {
                          _scaffoldKey.currentState?.openDrawer();
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _openPage(Widget page) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => page),
    );
  }

  Future<void> _openLandingTrendItemArticle(TrendItem item) async {
    if (item.id > 0) {
      setState(() {
        _readNewsIds.add(item.id);
      });
    }
    await _landingOpenArticle(context, item.link);
  }

  Widget _navItem(String text, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _HoverButton(
      onTap: onTap,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.grey.shade300 : Colors.grey[700],
        ),
      ),
    );
  }

  Widget _themeChip(
    BuildContext context,
    String label,
    bool selected,
    VoidCallback onTap,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: selected
            ? (isDark ? const Color(0xFF08111F) : Colors.white)
            : (isDark ? Colors.grey.shade200 : Colors.blueGrey.shade700),
      ),
      selectedColor: isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB),
      backgroundColor: isDark ? const Color(0xFF111827) : Colors.grey.shade100,
      side: BorderSide(
        color: selected
            ? Colors.transparent
            : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final drawerBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    return Drawer(
      child: Container(
        color: drawerBg,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [const Color(0xFF1D4ED8), const Color(0xFF0F172A)]
                        : [Colors.blue.shade600, Colors.blue.shade400],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.asset(
                          'assets/icon/app_icon.png',
                          width: 32,
                          height: 32,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Pulse',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    _buildDrawerNavTile(
                      context: context,
                      isDark: isDark,
                      icon: Icons.home,
                      title: 'Pulse',
                      subtitle: '메인 화면',
                      onTap: () {
                        Navigator.pop(context);
                      },
                    ),
                    const SizedBox(height: 4),
                    _buildDrawerNavTile(
                      context: context,
                      isDark: isDark,
                      icon: Icons.newspaper_rounded,
                      title: '실시간 뉴스',
                      subtitle: '최신 뉴스',
                      onTap: () {
                        Navigator.pop(context);
                        _openPage(const HomeScreen());
                      },
                    ),
                    const SizedBox(height: 4),
                    _buildDrawerNavTile(
                      context: context,
                      isDark: isDark,
                      icon: Icons.psychology_rounded,
                      title: '공포탐욕지수',
                      subtitle: '시장 심리',
                      onTap: () {
                        Navigator.pop(context);
                        _openPage(const FearGreedPage());
                      },
                    ),
                    const SizedBox(height: 4),
                    _buildDrawerNavTile(
                      context: context,
                      isDark: isDark,
                      icon: Icons.show_chart_rounded,
                      title: '증시',
                      subtitle: '주요 시장 데이터',
                      onTap: () {
                        Navigator.pop(context);
                        _openPage(const MarketPage());
                      },
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  '테마',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ValueListenableBuilder<ThemeMode>(
                  valueListenable: ThemeController.instance.mode,
                  builder: (context, themeMode, _) {
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _themeChip(
                            context,
                            '시스템',
                            themeMode == ThemeMode.system,
                            () => ThemeController.instance
                                .setThemeMode(ThemeMode.system)),
                        _themeChip(
                            context,
                            '라이트',
                            themeMode == ThemeMode.light,
                            () => ThemeController.instance
                                .setThemeMode(ThemeMode.light)),
                        _themeChip(
                            context,
                            '다크',
                            themeMode == ThemeMode.dark,
                            () => ThemeController.instance
                                .setThemeMode(ThemeMode.dark)),
                      ],
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      'Version 1.0.0',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerNavTile({
    required BuildContext context,
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final tileBg = isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC);
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor =
        isDark ? Colors.grey.shade400 : Colors.blueGrey.shade600;

    return Material(
      color: tileBg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: ListTile(
          dense: true,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color:
                  isDark ? const Color(0xFF172554) : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: isDark ? Colors.blue.shade200 : const Color(0xFF2563EB),
              size: 20,
            ),
          ),
          title: Text(
            title,
            style: TextStyle(
              color: titleColor,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              color: subtitleColor,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: isDark ? Colors.grey.shade500 : Colors.blueGrey.shade300,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        ),
      ),
    );
  }

  Widget _buildPlatformHero(bool isMobile) {
    return FutureBuilder<TrendInsightSnapshot>(
      future: _insightFuture,
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final insight = snapshot.data;

        return Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: PulseUi.maxContentWidth),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              child: _LandingTrendPanel(
                isLoading: isLoading,
                insight: insight,
                searchController: _searchController,
                onRefresh: _refreshInsights,
                onSearch: _submitLandingSearch,
                onKeywordTap: _searchLandingKeyword,
                onRisingIssueTap: _searchLandingRisingIssue,
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _refreshInsights() async {
    if (!mounted) return;
    if (_insightRefreshing) return;
    if (_lastInsightRefreshAt != null &&
        DateTime.now().difference(_lastInsightRefreshAt!) <
            const Duration(seconds: 8)) {
      return;
    }
    _insightRefreshing = true;
    try {
      setState(() {
        _insightFuture = _api.fetchTrendInsights();
        _timelineFuture =
            _api.fetchTrendTimeline(period: '24h', limit: 3, minScore: 45);
        _latestNewsFuture =
            _api.fetchTrends(limit: 12, sort: 'latest', period: '24h');
      });
      await _refreshMarketData(force: true);
      _lastInsightRefreshAt = DateTime.now();
    } finally {
      _insightRefreshing = false;
    }
  }

  bool _shouldRefreshMarketData() {
    if (_marketLastUpdatedAt == null) return true;
    return DateTime.now().difference(_marketLastUpdatedAt!) >=
        const Duration(minutes: 5);
  }

  Future<void> _refreshMarketDataIfNeeded() async {
    if (!_shouldRefreshMarketData()) return;
    await _refreshMarketData();
  }

  Future<void> _refreshMarketData({bool force = false}) async {
    if (_marketFetching) return;
    if (!force && !_shouldRefreshMarketData()) return;

    _marketFetching = true;
    if (mounted) {
      setState(() {
        if (_marketQuotes.isNotEmpty) {
          _marketRefreshing = true;
        } else {
          _marketRefreshing = true;
          _marketError = null;
        }
      });
    }

    try {
      final quotes = await _fetchLandingMarketQuotes();
      if (!mounted) return;
      setState(() {
        _marketQuotes
          ..clear()
          ..addAll(quotes);
        _marketError = null;
        _marketLastUpdatedAt = DateTime.now();
        _marketRefreshing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _marketError = '업데이트 실패';
        _marketRefreshing = false;
      });
    } finally {
      _marketFetching = false;
    }
  }

  Widget _buildBreakingNewsSection(bool isMobile) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxItems = 5;
    return FutureBuilder<List<TrendItem>>(
      future: _latestNewsFuture,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final rawItems = (snapshot.data ?? const <TrendItem>[]).toList()
          ..sort((a, b) {
            final ai = _landingNewsPriorityRank(a);
            final bi = _landingNewsPriorityRank(b);
            if (ai != bi) return ai.compareTo(bi);
            final aDate =
                _landingTrendDate(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bDate =
                _landingTrendDate(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bDate.compareTo(aDate);
          });
        final items = rawItems.take(maxItems).toList();

        return Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: PulseUi.maxContentWidth),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Container(
                padding: EdgeInsets.all(isMobile ? 16 : 20),
                decoration: PulseUi.sectionDecoration(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PulseSectionHeader(
                      icon: Icons.bolt_rounded,
                      title: '실시간 속보',
                      subtitle: '방금 들어온 뉴스를 최신순으로 확인하세요',
                      trailing: TextButton(
                        onPressed: () => _openPage(const HomeScreen()),
                        style: TextButton.styleFrom(
                          foregroundColor: isDark
                              ? Colors.blue.shade200
                              : Colors.blue.shade700,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          minimumSize: Size.zero,
                        ),
                        child: const Text(
                          '더 보기 →',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 28),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else if (items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          '아직 불러온 속보가 없습니다.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.grey.shade300
                                : Colors.grey.shade600,
                          ),
                        ),
                      )
                    else
                      Column(
                        children: [
                          for (int i = 0; i < items.length; i++) ...[
                            _BreakingNewsTimelineTile(
                              item: items[i],
                              isFeatured: i == 0,
                              isRead: _readNewsIds.contains(items[i].id),
                              onTap: items[i].link.trim().isNotEmpty
                                  ? () => _openLandingTrendItemArticle(items[i])
                                  : null,
                            ),
                            if (i != items.length - 1)
                              Divider(
                                height: 18,
                                thickness: 0.5,
                                color: isDark
                                    ? Colors.grey.shade800
                                    : const Color(0xFFE8EEF5),
                              ),
                          ],
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMarketMoodSection(bool isMobile) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FutureBuilder<TrendInsightSnapshot>(
      future: _insightFuture,
      builder: (context, snapshot) {
        final insight = snapshot.data;
        final domesticMood =
            insight == null ? '분석 대기' : _landingSectorMoodLabel(insight);
        final sentiment = insight?.sentiment;
        final sentimentLabel = sentiment == null
            ? '시황 관찰 중'
            : '${sentiment.temperature} · ${_landingSentimentLabel(sentiment.temperature)}';
        final sentimentDetail = sentiment == null
            ? '최근 뉴스 흐름을 집계 중입니다.'
            : sentiment.summary.trim().isEmpty
                ? '뉴스 감정과 시장 흐름을 함께 보고 있습니다.'
                : sentiment.summary.trim();

        final nasdaqQuote = _landingQuoteByTitle(_marketQuotes, '나스닥100 선물');
        final fxQuote = _landingQuoteByTitle(_marketQuotes, 'USD/KRW');
        final usMood = nasdaqQuote == null
            ? '관찰 중'
            : nasdaqQuote.percentChange > 0
                ? '긍정'
                : nasdaqQuote.percentChange < 0
                    ? '부정'
                    : '중립';
        final fxMood = fxQuote == null
            ? '관찰 중'
            : fxQuote.percentChange > 0
                ? '원화 약세'
                : fxQuote.percentChange < 0
                    ? '원화 강세'
                    : '중립';
        final updatedAt = _marketLastUpdatedAt;
        final updatedLabel = updatedAt == null
            ? '업데이트 대기'
            : '마지막 업데이트 ${_landingFormatUpdatedAt(updatedAt)}';

        return Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: PulseUi.maxContentWidth),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF111827)
                      : const Color(0xFFFAFBFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF1F2937)
                        : const Color(0xFFE8EEF5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF172554)
                                : const Color(0xFFEEF4FF),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Icon(
                            Icons.insights_rounded,
                            size: 16,
                            color: isDark
                                ? Colors.blue.shade200
                                : Colors.blue.shade700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '시장 분위기',
                                style: TextStyle(
                                  fontSize: 13.8,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                updatedLabel,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: isDark
                                      ? Colors.grey.shade300
                                      : Colors.blueGrey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (snapshot.connectionState == ConnectionState.waiting)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.6,
                                color: isDark
                                    ? Colors.blue.shade200
                                    : Colors.blue.shade600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (insight == null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF1F2937)
                                : const Color(0xFFE8EEF5),
                          ),
                        ),
                        child: Text(
                          '시장 분위기를 분석하는 중입니다.',
                          style: TextStyle(
                            color: isDark
                                ? Colors.grey.shade300
                                : Colors.blueGrey.shade500,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      _LandingMarketMoodRow(
                        data: insight,
                        marketQuotes: _marketQuotes,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMarketOverviewSection(bool isMobile) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final targets = [
      _landingQuoteByTitle(_marketQuotes, '코스피'),
      _landingQuoteByTitle(_marketQuotes, '코스닥'),
      _landingQuoteByTitle(_marketQuotes, '나스닥100 선물'),
      _landingQuoteByTitle(_marketQuotes, '비트코인'),
    ].whereType<_LandingMarketQuote>().toList();
    final updatedAt = _landingLatestUpdatedAt(targets) ?? _marketLastUpdatedAt;
    final updatedLabel = updatedAt == null
        ? '시세 확인 중'
        : '최근 업데이트 ${_landingFormatUpdatedAt(updatedAt)}';
    final loading = _marketRefreshing && _marketQuotes.isEmpty;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: PulseUi.maxContentWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF111827) : const Color(0xFFFAFBFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color:
                    isDark ? const Color(0xFF1F2937) : const Color(0xFFE8EEF5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF172554)
                            : const Color(0xFFEEF4FF),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        Icons.show_chart_rounded,
                        size: 16,
                        color: isDark
                            ? Colors.blue.shade200
                            : Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '지금 시장',
                            style: TextStyle(
                              fontSize: 13.8,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            updatedLabel,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isDark
                                  ? Colors.grey.shade300
                                  : Colors.blueGrey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_marketRefreshing && _marketQuotes.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.6,
                            color: isDark
                                ? Colors.blue.shade200
                                : Colors.blue.shade600,
                          ),
                        ),
                      ),
                    TextButton(
                      onPressed: () => _openPage(const MarketPage()),
                      style: TextButton.styleFrom(
                        foregroundColor: isDark
                            ? Colors.blue.shade200
                            : Colors.blue.shade700,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        minimumSize: Size.zero,
                      ),
                      child: const Text(
                        '전체 차트 →',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                else if (targets.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      _marketError ?? '시장 데이터를 불러오지 못했습니다.',
                      style: TextStyle(
                        color: isDark
                            ? Colors.grey.shade300
                            : Colors.grey.shade600,
                        fontSize: 11,
                      ),
                    ),
                  )
                else
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: isMobile ? 2 : 4,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: isMobile ? 1.45 : 1.95,
                    children: targets
                        .map((quote) => _LandingMarketSummaryCard(quote: quote))
                        .toList(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExchangeRateSection(bool isMobile) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final targets = [
      _landingQuoteByTitle(_marketQuotes, 'USD/KRW'),
      _landingQuoteByTitle(_marketQuotes, 'JPY/KRW'),
      _landingQuoteByTitle(_marketQuotes, 'EUR/KRW'),
      _landingQuoteByTitle(_marketQuotes, 'CNY/KRW'),
    ].whereType<_LandingMarketQuote>().toList();
    final updatedAt = _landingLatestUpdatedAt(targets) ?? _marketLastUpdatedAt;
    final updatedLabel = updatedAt == null
        ? '시세 확인 중'
        : '시세 기준 ${_landingFormatUpdatedAt(updatedAt)}';
    final loading = _marketRefreshing && _marketQuotes.isEmpty;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: PulseUi.maxContentWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF111827) : const Color(0xFFFAFBFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color:
                    isDark ? const Color(0xFF1F2937) : const Color(0xFFE8EEF5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF172554)
                            : const Color(0xFFEEF4FF),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        Icons.currency_exchange_rounded,
                        size: 16,
                        color: isDark
                            ? Colors.blue.shade200
                            : Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '환율',
                            style: TextStyle(
                              fontSize: 13.8,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            updatedLabel,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isDark
                                  ? Colors.grey.shade300
                                  : Colors.blueGrey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_marketRefreshing && _marketQuotes.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.6,
                            color: isDark
                                ? Colors.blue.shade200
                                : Colors.blue.shade600,
                          ),
                        ),
                      ),
                    TextButton(
                      onPressed: () => _openPage(const MarketPage()),
                      style: TextButton.styleFrom(
                        foregroundColor: isDark
                            ? Colors.blue.shade200
                            : Colors.blue.shade700,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        minimumSize: Size.zero,
                      ),
                      child: const Text(
                        '매크로 →',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                else if (targets.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      _marketError ?? '환율 데이터를 불러오지 못했습니다.',
                      style: TextStyle(
                        color: isDark
                            ? Colors.grey.shade300
                            : Colors.grey.shade600,
                        fontSize: 11,
                      ),
                    ),
                  )
                else
                  Column(
                    children: [
                      for (int i = 0; i < targets.length; i++) ...[
                        _LandingExchangeRateRow(quote: targets[i]),
                        if (i != targets.length - 1)
                          Divider(
                            height: 10,
                            thickness: 0.5,
                            color: isDark
                                ? Colors.grey.shade800
                                : const Color(0xFFE8EEF5),
                          ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPopularStocksSection(bool isMobile) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final equityOrder = <String>[
      '삼성전자',
      'SK하이닉스',
      'SK스퀘어',
      '삼성전기',
      '현대차',
    ];
    final items = equityOrder
        .map((title) => _landingQuoteByTitle(_marketQuotes, title))
        .toList();
    final availableItems = items.whereType<_LandingMarketQuote>().toList();
    final updatedAt = _landingLatestUpdatedAt(availableItems) ?? _marketLastUpdatedAt;
    final updatedLabel = updatedAt == null
        ? '시세 확인 중'
        : '최근 업데이트 ${_landingFormatUpdatedAt(updatedAt)}';
    final delayLabel = _landingDelaySummary(updatedAt);
    final loading = _marketRefreshing && _marketQuotes.isEmpty;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: PulseUi.maxContentWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF111827) : const Color(0xFFFAFBFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color:
                    isDark ? const Color(0xFF1F2937) : const Color(0xFFE8EEF5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF172554)
                            : const Color(0xFFEEF4FF),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        Icons.trending_up_rounded,
                        size: 16,
                        color: isDark
                            ? Colors.blue.shade200
                            : Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '24시간 가격 변동 종목',
                            style: TextStyle(
                              fontSize: 13.8,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            updatedLabel,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isDark
                                  ? Colors.grey.shade300
                                  : Colors.blueGrey.shade500,
                            ),
                          ),
                          if (delayLabel != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              delayLabel,
                              style: TextStyle(
                                fontSize: 10.3,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.blueGrey.shade500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (_marketRefreshing && _marketQuotes.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.6,
                            color: isDark
                                ? Colors.blue.shade200
                                : Colors.blue.shade600,
                          ),
                        ),
                      ),
                    TextButton(
                      onPressed: () => _openPage(const MarketPage()),
                      style: TextButton.styleFrom(
                        foregroundColor: isDark
                            ? Colors.blue.shade200
                            : Colors.blue.shade700,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        minimumSize: Size.zero,
                      ),
                      child: const Text(
                        '전체 차트 →',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '최근 24시간 변동률 기준으로 큰 움직임이 있었던 종목을 정리합니다.',
                  style: TextStyle(
                    fontSize: 11.2,
                    color: isDark
                        ? Colors.grey.shade300
                        : Colors.blueGrey.shade600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                if (loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                else if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      _marketError ?? '종목 데이터를 불러오지 못했습니다.',
                      style: TextStyle(
                        color: isDark
                            ? Colors.grey.shade300
                            : Colors.grey.shade600,
                        fontSize: 11,
                      ),
                    ),
                  )
                else
                  Column(
                    children: [
                      for (int i = 0; i < equityOrder.length; i++) ...[
                        items[i] != null
                            ? _LandingMarketRankRow(
                                rank: i + 1,
                                quote: items[i]!,
                              )
                            : _LandingMarketRankPlaceholderRow(
                                rank: i + 1,
                                title: equityOrder[i],
                              ),
                        if (i != equityOrder.length - 1)
                          Divider(
                            height: 10,
                            thickness: 0.5,
                            color: isDark
                                ? Colors.grey.shade800
                                : const Color(0xFFE8EEF5),
                          ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMarketDominanceSection(bool isMobile) {
    return FutureBuilder<TrendInsightSnapshot>(
      future: _insightFuture,
      builder: (context, snapshot) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final insight = snapshot.data;
        final sectors = _landingSectorDominanceRows(insight)
            .where((item) => item.ratio > 0)
            .take(isMobile ? 4 : 5)
            .toList();

        return Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: PulseUi.maxContentWidth),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF111827)
                      : const Color(0xFFFAFBFC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF1F2937)
                        : const Color(0xFFE8EEF5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF172554)
                                : const Color(0xFFEEF4FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.donut_large_rounded,
                            size: 17,
                            color: isDark
                                ? Colors.blue.shade200
                                : Colors.blue.shade700,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '뉴스 관심 섹터',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '최근 뉴스에서 많이 언급된 섹터 비중을 요약합니다.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.grey.shade300
                                      : Colors.blueGrey.shade500,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (insight == null || sectors.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          '유의미한 섹터 비중 데이터를 준비 중입니다.',
                          style: TextStyle(
                            color: isDark
                                ? Colors.grey.shade300
                                : Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      )
                    else
                      Column(
                        children: sectors.map((sector) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _LandingDominanceRow(
                              label: sector.label,
                              valueText: sector.valueText,
                              changeText: sector.changeText,
                              ratio: sector.ratio,
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<List<_LandingMarketQuote>> _fetchLandingMarketQuotes() async {
    const configs = <_LandingMarketConfig>[
      _LandingMarketConfig(
        symbol: '^KS11',
        tvSymbol: 'KRX:KOSPI',
        title: '코스피',
        prefix: '',
        group: 'index',
      ),
      _LandingMarketConfig(
        symbol: '^KQ11',
        tvSymbol: 'KRX:KOSDAQ',
        title: '코스닥',
        prefix: '',
        group: 'index',
      ),
      _LandingMarketConfig(
        symbol: 'NQ=F',
        tvSymbol: 'CME_MINI:NQ1!',
        title: '나스닥100 선물',
        prefix: '',
        group: 'index',
      ),
      _LandingMarketConfig(
        symbol: 'BTC-USD',
        tvSymbol: 'COINBASE:BTCUSD',
        title: '비트코인',
        prefix: '\$',
        group: 'crypto',
      ),
      _LandingMarketConfig(
        symbol: 'KRW=X',
        tvSymbol: 'FX_IDC:USDKRW',
        title: 'USD/KRW',
        prefix: '',
        group: 'fx',
      ),
      _LandingMarketConfig(
        symbol: 'EURUSD=X',
        tvSymbol: 'FX:EURUSD',
        title: 'EUR/USD',
        prefix: '',
        group: 'fx',
      ),
      _LandingMarketConfig(
        symbol: 'JPY=X',
        tvSymbol: 'FX:USDJPY',
        title: 'USD/JPY',
        prefix: '',
        group: 'fx',
      ),
      _LandingMarketConfig(
        symbol: 'CNY=X',
        tvSymbol: 'FX:USDCNY',
        title: 'USD/CNY',
        prefix: '',
        group: 'fx',
      ),
      _LandingMarketConfig(
        symbol: '005930.KS',
        tvSymbol: 'KRX:005930',
        title: '삼성전자',
        prefix: '',
        group: 'equity',
      ),
      _LandingMarketConfig(
        symbol: '000660.KS',
        tvSymbol: 'KRX:000660',
        title: 'SK하이닉스',
        prefix: '',
        group: 'equity',
      ),
      _LandingMarketConfig(
        symbol: '402340.KS',
        tvSymbol: 'KRX:402340',
        title: 'SK스퀘어',
        prefix: '',
        group: 'equity',
      ),
      _LandingMarketConfig(
        symbol: '009150.KS',
        tvSymbol: 'KRX:009150',
        title: '삼성전기',
        prefix: '',
        group: 'equity',
      ),
      _LandingMarketConfig(
        symbol: '005380.KS',
        tvSymbol: 'KRX:005380',
        title: '현대차',
        prefix: '',
        group: 'equity',
      ),
    ];

    final symbolsQuery = configs.map((item) => item.symbol).join(',');
    final uri = Uri.parse(
      'https://news-summarizer.bum2432.workers.dev/api/market-data?symbols=$symbolsQuery&interval=5m&range=1d',
    );
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Market data request failed: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (decoded['success'] != true) {
      throw Exception('Market data response was not successful');
    }

    final results = (decoded['data'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final bySymbol = {
      for (final item in results) item['symbol']?.toString() ?? '': item,
    };

    final quotes = <_LandingMarketQuote>[];

    _LandingMarketQuote? buildBaseQuote(
      _LandingMarketConfig config, {
      String? titleOverride,
    }) {
      final raw = bySymbol[config.symbol];
      final previous = _marketQuotes.cast<_LandingMarketQuote?>().firstWhere(
            (item) =>
                item != null &&
                (item.symbol == config.symbol ||
                    item.title == (titleOverride ?? config.title)),
            orElse: () => null,
          );
      if (raw == null || raw['error'] != null) return previous;
      final currentPrice = (raw['currentPrice'] as num?)?.toDouble();
      final percentChange = (raw['percentChange'] as num?)?.toDouble();
      if (currentPrice == null || percentChange == null) return previous;
      final priceUpdatedAt = _landingParseTimestamp(
        raw['priceUpdatedAt']?.toString() ?? '',
      ) ?? previous?.priceUpdatedAt;
      final chartData = (raw['chartData'] as List<dynamic>?)
              ?.whereType<num>()
              .map((value) => value.toDouble())
              .toList() ??
          previous?.chartData ?? const <double>[];

      return _LandingMarketQuote(
        symbol: config.symbol,
        tvSymbol: config.tvSymbol,
        title: titleOverride ?? config.title,
        prefix: config.prefix,
        group: config.group,
        currentPrice: currentPrice,
        percentChange: percentChange,
        priceUpdatedAt: priceUpdatedAt,
        chartData: chartData,
      );
    }

    final baseQuotes = <String, _LandingMarketQuote>{};
    for (final config in configs) {
      if (config.group != 'fx') {
        final quote = buildBaseQuote(config);
        if (quote != null) {
          quotes.add(quote);
        }
      } else {
        final quote = buildBaseQuote(config);
        if (quote != null) {
          baseQuotes[config.symbol] = quote;
        }
      }
    }

    final usdKrw = baseQuotes['KRW=X'];
    final eurUsd = baseQuotes['EURUSD=X'];
    final usdJpy = baseQuotes['JPY=X'];
    final usdCny = baseQuotes['CNY=X'];

    _LandingMarketQuote? derivedFxQuote({
      required String title,
      required String symbol,
      required double currentPrice,
      required double percentChange,
      required DateTime? updatedAt,
    }) {
      return _LandingMarketQuote(
        symbol: symbol,
        tvSymbol: symbol,
        title: title,
        prefix: '',
        group: 'fx',
        currentPrice: currentPrice,
        percentChange: percentChange,
        priceUpdatedAt: updatedAt,
      );
    }

    if (usdKrw != null) {
      quotes.add(derivedFxQuote(
        title: 'USD/KRW',
        symbol: 'KRW=X',
        currentPrice: usdKrw.currentPrice,
        percentChange: usdKrw.percentChange,
        updatedAt: usdKrw.priceUpdatedAt,
      )!);
    }

    if (usdKrw != null && usdJpy != null && usdJpy.currentPrice > 0) {
      final currentPrice = usdKrw.currentPrice / usdJpy.currentPrice;
      final percentChange = (((1 + usdKrw.percentChange / 100) /
                  (1 + usdJpy.percentChange / 100)) -
              1) *
          100;
      quotes.add(derivedFxQuote(
        title: 'JPY/KRW',
        symbol: 'JPY=X',
        currentPrice: currentPrice,
        percentChange: percentChange,
        updatedAt: [
          usdKrw.priceUpdatedAt,
          usdJpy.priceUpdatedAt
        ].whereType<DateTime>().fold<DateTime?>(null,
            (prev, item) => prev == null || item.isAfter(prev) ? item : prev),
      )!);
    }

    if (usdKrw != null && eurUsd != null) {
      final currentPrice = usdKrw.currentPrice * eurUsd.currentPrice;
      final percentChange = (((1 + usdKrw.percentChange / 100) *
                  (1 + eurUsd.percentChange / 100)) -
              1) *
          100;
      quotes.add(derivedFxQuote(
        title: 'EUR/KRW',
        symbol: 'EURUSD=X',
        currentPrice: currentPrice,
        percentChange: percentChange,
        updatedAt: [
          usdKrw.priceUpdatedAt,
          eurUsd.priceUpdatedAt
        ].whereType<DateTime>().fold<DateTime?>(null,
            (prev, item) => prev == null || item.isAfter(prev) ? item : prev),
      )!);
    }

    if (usdKrw != null && usdCny != null && usdCny.currentPrice > 0) {
      final currentPrice = usdKrw.currentPrice / usdCny.currentPrice;
      final percentChange = (((1 + usdKrw.percentChange / 100) /
                  (1 + usdCny.percentChange / 100)) -
              1) *
          100;
      quotes.add(derivedFxQuote(
        title: 'CNY/KRW',
        symbol: 'CNY=X',
        currentPrice: currentPrice,
        percentChange: percentChange,
        updatedAt: [
          usdKrw.priceUpdatedAt,
          usdCny.priceUpdatedAt
        ].whereType<DateTime>().fold<DateTime?>(null,
            (prev, item) => prev == null || item.isAfter(prev) ? item : prev),
      )!);
    }

    return quotes;
  }

  _LandingMarketQuote? _landingQuoteByTitle(
    List<_LandingMarketQuote> quotes,
    String title,
  ) {
    for (final quote in quotes) {
      if (quote.title == title) return quote;
    }
    return null;
  }

  List<_LandingSectorDominanceRowData> _landingSectorDominanceRows(
    TrendInsightSnapshot? insight,
  ) {
    if (insight == null) return const [];

    final rows = <_LandingSectorDominanceRowData>[
      _LandingSectorDominanceRowData(
        '반도체',
        [
          '반도체',
          'HBM',
          'D램',
          '낸드',
          '파운드리',
          '팹리스',
          '메모리',
          '칩',
          '삼성전자',
          'SK하이닉스',
          '엔비디아'
        ],
      ),
      _LandingSectorDominanceRowData(
        '2차전지',
        ['2차전지', '배터리', '전기차', '리튬', '양극재', '음극재', '전해질', '셀'],
      ),
      _LandingSectorDominanceRowData(
        '바이오/제약',
        ['바이오', '제약', '신약', '임상', '헬스케어', 'FDA', '의약'],
      ),
      _LandingSectorDominanceRowData(
        '방산',
        ['방산', 'K방산', '무기', '군수', '전차', '미사일', '드론'],
      ),
      _LandingSectorDominanceRowData(
        '시장 거래대금',
        ['거래대금', '증시', '코스피', '코스닥', '환율', '금리', '채권', '달러', '연준', 'FOMC'],
      ),
    ];

    final scores = rows.map((row) {
      double total = 0;

      for (final keyword in insight.keywords) {
        if (row.matchesText(keyword.keyword) ||
            row.matchesText(keyword.representativeTitle) ||
            row.matchesText(keyword.category)) {
          total += keyword.newsCount * 1.4;
          total += (keyword.sentimentTemperature ?? 50) >= 70
              ? 0.5
              : (keyword.sentimentTemperature ?? 50) <= 30
                  ? 0.25
                  : 0.1;
        }
      }

      for (final issue in insight.risingIssues) {
        if (row.matchesText(issue.keyword) ||
            row.matchesText(issue.representativeTitle) ||
            row.matchesText(issue.category)) {
          total += issue.currentCount * 1.15;
          total +=
              issue.growthRate > 0 ? (issue.growthRate.clamp(0, 200) / 80) : 0;
          total += issue.isNew ? 0.4 : 0.1;
        }
      }

      if (row.label == '시장 거래대금') {
        final marketBias = insight.keywords.where((item) {
          final text =
              '${item.keyword} ${item.representativeTitle} ${item.category}'
                  .toLowerCase();
          return text.contains('코스피') ||
              text.contains('코스닥') ||
              text.contains('증시') ||
              text.contains('금리') ||
              text.contains('환율') ||
              text.contains('달러') ||
              text.contains('채권');
        }).fold<double>(0, (sum, item) => sum + item.newsCount * 0.9);
        total += marketBias;
      }

      return MapEntry(row, total);
    }).toList();

    final totalScore =
        scores.fold<double>(0, (sum, entry) => sum + entry.value);
    if (totalScore <= 0) return const [];

    final output = scores.map((entry) {
      final ratio = entry.value / totalScore;
      return _LandingSectorDominanceRowData(
        entry.key.label,
        entry.key.keywords,
        ratio: ratio,
        valueText: '${(ratio * 100).round()}%',
        changeText: ratio >= 0.25 ? '상위' : '관심',
      );
    }).toList()
      ..sort((a, b) => b.ratio.compareTo(a.ratio));

    return output;
  }

  Widget _buildIssueTimelineSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FutureBuilder<List<IssueTimelineItem>>(
      future: _timelineFuture,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final items = snapshot.data ?? const <IssueTimelineItem>[];

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1020),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF111827)
                      : const Color(0xFFFAFBFC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF1F2937)
                        : const Color(0xFFE8EEF5),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withOpacity(0.24)
                          : const Color(0xFF0F172A).withOpacity(0.04),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF172554)
                                : const Color(0xFFEEF4FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.timeline_rounded,
                            size: 17,
                            color: isDark
                                ? Colors.blue.shade200
                                : Colors.blue.shade700,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '실시간 이슈 타임라인',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        Text(
                          '중요 이슈만',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.blueGrey.shade500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '시간순으로 묶인 핵심 이슈만 보여줍니다.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.blueGrey.shade500,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 28),
                        child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    else if (items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          '아직 타임라인으로 묶을 만큼 충분한 이슈가 없습니다.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                        ),
                      )
                    else
                      Column(
                        children: [
                          for (final item in items)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _LandingTimelineItemTile(
                                item: item,
                                onTap: () => _openLandingTimelineItem(item),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _openLandingTimelineItem(IssueTimelineItem item) {
    _showLandingRelatedArticlesSheet(
      title: '${item.keyword} 관련 이슈',
      future: _resolveTimelineRelatedNews(item),
    );
  }

  void _openLandingNewsCluster(NewsCluster cluster) {
    _showLandingRelatedArticlesSheet(
      title: cluster.articleCount > 1
          ? '${cluster.representative.koreanTitle} 외 ${cluster.articleCount - 1}건'
          : cluster.representative.koreanTitle,
      future: _resolveClusterRelatedNews(cluster),
    );
  }

  Future<List<TrendItem>> _resolveTimelineRelatedNews(
      IssueTimelineItem item) async {
    try {
      return await _api.fetchIssueTimelineNews(
        issueId: item.id,
        keyword: item.keyword,
        newsIds: item.newsIds,
      );
    } catch (_) {}

    return const <TrendItem>[];
  }

  Future<List<TrendItem>> _resolveClusterRelatedNews(
      NewsCluster cluster) async {
    final merged = <String, TrendItem>{};
    for (final item in cluster.items) {
      final key = item.id > 0
          ? 'id:${item.id}'
          : [
              item.link.trim(),
              item.koreanTitle.trim(),
              item.source.trim(),
              item.published.trim(),
            ].join('|');
      merged.putIfAbsent(key, () => item);
    }
    return merged.values.toList();
  }

  void _showLandingRelatedArticlesSheet({
    required String title,
    required Future<List<TrendItem>> future,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = ThemeController.instance.mode.value == ThemeMode.dark;
        final surface = isDark ? const Color(0xFF111827) : Colors.white;
        final border =
            isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);
        final primaryText = isDark ? Colors.white : const Color(0xFF0F172A);
        final secondaryText =
            isDark ? Colors.grey.shade200 : Colors.blueGrey.shade500;

        return DraggableScrollableSheet(
          initialChildSize: 0.82,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(
                  top: BorderSide(color: border),
                  left: BorderSide(color: border),
                  right: BorderSide(color: border),
                ),
              ),
              child: FutureBuilder<List<TrendItem>>(
                future: future,
                builder: (context, snapshot) {
                  final items = snapshot.data ?? const <TrendItem>[];
                  final orderedItems = items.toList()
                    ..sort((a, b) {
                      final aDate = _landingTrendDate(a) ??
                          DateTime.fromMillisecondsSinceEpoch(0);
                      final bDate = _landingTrendDate(b) ??
                          DateTime.fromMillisecondsSinceEpoch(0);
                      return bDate.compareTo(aDate);
                    });

                  return DefaultTextStyle.merge(
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    child: CustomScrollView(
                      controller: scrollController,
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 4,
                                  margin: const EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.grey.shade700
                                        : Colors.grey.shade300,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    title,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color:
                                          isDark ? Colors.white : primaryText,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: '닫기',
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: Icon(
                                    Icons.close_rounded,
                                    color: secondaryText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (snapshot.connectionState == ConnectionState.waiting)
                          const SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                                child:
                                    CircularProgressIndicator(strokeWidth: 2)),
                          )
                        else if (snapshot.hasError)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: _LandingSearchStateMessage(
                              icon: Icons.error_outline_rounded,
                              title: '관련 뉴스를 불러오지 못했습니다.',
                              subtitle: '잠시 후 다시 시도해 주세요.',
                            ),
                          )
                        else if (orderedItems.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: _LandingSearchStateMessage(
                              icon: Icons.search_off_rounded,
                              title: '관련 뉴스가 없습니다.',
                              subtitle: '다른 키워드로 다시 확인해 보세요.',
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            sliver: SliverList.separated(
                              itemCount: orderedItems.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                return _LandingSearchResultTile(
                                  item: orderedItems[index],
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLatestNewsSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FutureBuilder<List<TrendItem>>(
      future: _latestNewsFuture,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final rawItems = (snapshot.data ?? const <TrendItem>[]).toList()
          ..sort((a, b) {
            final aDate =
                _landingTrendDate(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bDate =
                _landingTrendDate(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bDate.compareTo(aDate);
          });
        final clusters = groupSimilarNews(rawItems, maxClusters: 6);

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1020),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF111827)
                      : const Color(0xFFFAFBFC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF1F2937)
                        : const Color(0xFFE8EEF5),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withOpacity(0.24)
                          : const Color(0xFF0F172A).withOpacity(0.05),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '최신 뉴스',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '지금 들어온 기사부터 바로 확인합니다.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.blueGrey.shade500,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 36),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (clusters.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          '아직 불러온 뉴스가 없습니다.',
                          style: TextStyle(
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey[600]),
                        ),
                      )
                    else
                      Column(
                        children: [
                          for (final cluster in clusters)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _LandingGroupedNewsTile(
                                cluster: cluster,
                                onTap: () => _openLandingNewsCluster(cluster),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  DateTime? _landingTrendDate(TrendItem trend) {
    return _landingParseDate(trend.published) ??
        _landingParseDate(trend.createdAt);
  }

  DateTime? _landingParseDate(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return null;

    return DateTime.tryParse(raw) ??
        DateTime.tryParse(raw.replaceFirst(' ', 'T')) ??
        DateTime.tryParse(raw.replaceAll('/', '-').replaceFirst(' ', 'T'));
  }

  Widget _smallNavCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF111827) : Colors.white;
    final border =
        isDark ? const Color(0xFF1F2937) : Colors.grey.withOpacity(0.12);
    final primaryText = isDark ? Colors.white : Colors.black87;
    final secondaryText = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF172554)
                    : Colors.blue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon,
                  color: isDark ? Colors.blue.shade200 : Colors.blue.shade700),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: primaryText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: secondaryText),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submitLandingSearch() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      _openPage(const HomeScreen());
      return;
    }

    _showLandingSearchSheet(
      title: '"$query" 검색 결과',
      future: _api.searchNews(query: query, sort: 'relevance', limit: 30),
    );
  }

  void _searchLandingKeyword(TrendKeyword keyword) {
    final query = keyword.keyword.trim();
    if (query.isEmpty) return;

    _searchController.text = query;
    _showLandingSearchSheet(
      title: '#$query 관련 뉴스',
      future: _api
          .fetchNewsByKeyword(keyword: query, limit: 30)
          .then((result) => result.items),
    );
  }

  void _searchLandingRisingIssue(RisingIssue issue) {
    final query = issue.keyword.trim();
    if (query.isEmpty) return;

    _searchController.text = query;
    _showLandingSearchSheet(
      title: '#$query 관련 뉴스 · 최근 1시간 ${issue.currentCount}건',
      future: _api
          .fetchNewsByKeyword(keyword: query, period: '6h', limit: 30)
          .then((result) => result.items),
    );
  }

  void _showLandingSearchSheet({
    required String title,
    required Future<List<TrendItem>> future,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = ThemeController.instance.mode.value == ThemeMode.dark;
        final surface = isDark ? const Color(0xFF111827) : Colors.white;
        final border =
            isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);
        final primaryText = isDark ? Colors.white : const Color(0xFF0F172A);
        final secondaryText =
            isDark ? Colors.grey.shade200 : Colors.blueGrey.shade500;

        return DraggableScrollableSheet(
          initialChildSize: 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(
                  top: BorderSide(color: border),
                  left: BorderSide(color: border),
                  right: BorderSide(color: border),
                ),
              ),
              child: FutureBuilder<List<TrendItem>>(
                future: future,
                builder: (context, snapshot) {
                  final items = snapshot.data ?? const <TrendItem>[];
                  final clusters = groupSimilarNews(items, maxClusters: 20);

                  return DefaultTextStyle.merge(
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    child: CustomScrollView(
                      controller: scrollController,
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 4,
                                  margin: const EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.grey.shade700
                                        : Colors.grey.shade300,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    title,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color:
                                          isDark ? Colors.white : primaryText,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: '닫기',
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: Icon(
                                    Icons.close_rounded,
                                    color: secondaryText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (snapshot.connectionState == ConnectionState.waiting)
                          const SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (snapshot.hasError)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: _LandingSearchStateMessage(
                              icon: Icons.error_outline_rounded,
                              title: '검색 결과를 불러오지 못했습니다.',
                              subtitle: '잠시 후 다시 시도해 주세요.',
                            ),
                          )
                        else if (items.isEmpty)
                          const SliverFillRemaining(
                            hasScrollBody: false,
                            child: _LandingSearchStateMessage(
                              icon: Icons.search_off_rounded,
                              title: '검색 결과가 없습니다.',
                              subtitle: '다른 키워드로 다시 검색해 보세요.',
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            sliver: SliverList.separated(
                              itemCount: clusters.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final cluster = clusters[index];
                                if (cluster.articleCount > 1) {
                                  return _LandingGroupedNewsTile(
                                    cluster: cluster,
                                    onTap: () =>
                                        _openLandingNewsCluster(cluster),
                                  );
                                }
                                return _LandingSearchResultTile(
                                  item: cluster.representative,
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeroSection(bool isMobile) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? Colors.white : Colors.black87;
    final secondaryText = isDark ? Colors.grey.shade300 : Colors.grey[600];
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : 80,
        vertical: isMobile ? 60 : 100,
      ),
      child: Column(
        children: [
          Text(
            'AI가 분석하는\n실시간 뉴스 인사이트',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isMobile ? 36 : 64,
              fontWeight: FontWeight.w800,
              color: primaryText,
              height: 1.1,
              letterSpacing: -1.5,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '경제, 사회, 정치, 세계 뉴스를 AI가 실시간 분석합니다.\n중요한 뉴스만 빠르게 확인해보세요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isMobile ? 16 : 20,
              fontWeight: FontWeight.w400,
              color: secondaryText,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 48),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: [
              _HoverButton(
                onTap: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => const HomeScreen()),
                  );
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.apple, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text('App Store',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                    ],
                  ),
                ),
              ),
              _HoverButton(
                onTap: () {},
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.android, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text('Play Store',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCoreFeatures(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 80),
      child: isMobile
          ? GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.85,
              children: [
                _featureCard(
                    Icons.bolt_rounded, '실시간 속보', '중요 뉴스를 빠르게 확인할 수 있어요.'),
                _featureCard(
                    Icons.psychology_rounded, 'AI 요약', '핵심만 짧고 정확하게 정리합니다.'),
                _featureCard(Icons.category_rounded, '카테고리 분류',
                    '경제, 사회, 정치, 세계별로 나눠 봅니다.'),
                _featureCard(
                    Icons.public_rounded, '글로벌 뉴스', '해외 주요 이슈도 함께 확인할 수 있어요.'),
              ],
            )
          : Row(
              children: [
                Expanded(
                    child: _featureCard(Icons.bolt_rounded, '실시간 속보',
                        '중요 뉴스를 빠르게\n확인할 수 있어요.')),
                const SizedBox(width: 24),
                Expanded(
                    child: _featureCard(Icons.psychology_rounded, 'AI 요약',
                        '핵심만 짧고 정확하게\n정리합니다.')),
                const SizedBox(width: 24),
                Expanded(
                    child: _featureCard(Icons.category_rounded, '카테고리 분류',
                        '경제, 사회, 정치, 세계별로\n나눠 볼 수 있어요.')),
              ],
            ),
    );
  }

  Widget _featureCard(IconData icon, String title, String description) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF111827) : Colors.white;
    final border =
        isDark ? const Color(0xFF1F2937) : Colors.grey.withOpacity(0.1);
    final iconBg = isDark ? const Color(0xFF0F172A) : Colors.grey[50];
    final primaryText = isDark ? Colors.white : Colors.black87;
    final secondaryText = isDark ? Colors.grey.shade400 : Colors.grey[600];
    return _HoverCard(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.24)
                    : Colors.black.withOpacity(0.04),
                blurRadius: 30,
                offset: const Offset(0, 10)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 24, color: primaryText),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: primaryText),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: TextStyle(fontSize: 12, color: secondaryText, height: 1.4),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesSection(bool isMobile) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? Colors.white : Colors.black87;
    final secondaryText = isDark ? Colors.grey.shade400 : Colors.grey[600];
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 80),
      child: Column(
        children: [
          Text(
            '다양한 분야의 뉴스',
            style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: primaryText,
                letterSpacing: -0.5),
          ),
          const SizedBox(height: 12),
          Text(
            '관심 있는 카테고리를 골라 필요한 뉴스만 빠르게 확인해보세요.',
            style: TextStyle(fontSize: 16, color: secondaryText),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          isMobile
              ? GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.85,
                  children: [
                    _categoryCard(Icons.trending_up_rounded, '경제',
                        '주식, 환율, 금리, 증시', Colors.green),
                    _categoryCard(Icons.public_rounded, '세계', '국제 정세, 해외 이슈',
                        Colors.purple),
                    _categoryCard(Icons.people_rounded, '사회', '사건, 사고, 지역 소식',
                        Colors.orange),
                    _categoryCard(Icons.account_balance_rounded, '정치',
                        '국회, 정부, 정책 이슈', Colors.red),
                    _categoryCard(Icons.library_books_rounded, '생활/문화',
                        '여행, 공연, 전시, 엔터', Colors.pink),
                    _categoryCard(Icons.computer_rounded, 'IT/과학',
                        '기술, AI, 반도체, 테크', Colors.blue),
                  ],
                )
              : Wrap(
                  spacing: 24,
                  runSpacing: 24,
                  children: [
                    SizedBox(
                        width:
                            (MediaQuery.of(context).size.width - 160 - 48) / 3,
                        child: _categoryCard(Icons.trending_up_rounded, '경제',
                            '주식, 환율, 금리, 증시', Colors.green)),
                    SizedBox(
                        width:
                            (MediaQuery.of(context).size.width - 160 - 48) / 3,
                        child: _categoryCard(Icons.public_rounded, '세계',
                            '국제 정세, 해외 이슈', Colors.purple)),
                    SizedBox(
                        width:
                            (MediaQuery.of(context).size.width - 160 - 48) / 3,
                        child: _categoryCard(Icons.people_rounded, '사회',
                            '사건, 사고, 지역 소식', Colors.orange)),
                    SizedBox(
                        width:
                            (MediaQuery.of(context).size.width - 160 - 48) / 3,
                        child: _categoryCard(Icons.account_balance_rounded,
                            '정치', '국회, 정부, 정책 이슈', Colors.red)),
                    SizedBox(
                        width:
                            (MediaQuery.of(context).size.width - 160 - 48) / 3,
                        child: _categoryCard(Icons.library_books_rounded,
                            '생활/문화', '여행, 공연, 전시, 엔터', Colors.pink)),
                    SizedBox(
                        width:
                            (MediaQuery.of(context).size.width - 160 - 48) / 3,
                        child: _categoryCard(Icons.computer_rounded, 'IT/과학',
                            '기술, AI, 반도체, 테크', Colors.blue)),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _categoryCard(
      IconData icon, String title, String description, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF111827) : Colors.white;
    final border =
        isDark ? const Color(0xFF1F2937) : Colors.grey.withOpacity(0.1);
    final primaryText = isDark ? Colors.white : Colors.black87;
    final secondaryText = isDark ? Colors.grey.shade400 : Colors.grey[600];
    return _HoverCard(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.24)
                    : Colors.black.withOpacity(0.04),
                blurRadius: 30,
                offset: const Offset(0, 10)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: primaryText),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(fontSize: 12, color: secondaryText, height: 1.4),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topBorder = isDark ? Colors.grey.shade800 : Colors.grey[200]!;
    return Container(
      decoration: BoxDecoration(
          border: Border(top: BorderSide(color: topBorder, width: 1))),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: PulseUi.maxContentWidth),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
            child: Column(
              children: [
                const _LandingFooterBrandBlock(),
                const SizedBox(height: 16),
                Text(
                  '© 2026 Pulse',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LandingInsightPanel extends StatelessWidget {
  final bool isLoading;
  final TrendInsightSnapshot? insight;
  final TextEditingController searchController;
  final VoidCallback onRefresh;
  final VoidCallback onStart;
  final ValueChanged<TrendKeyword> onKeywordTap;

  const _LandingInsightPanel({
    required this.isLoading,
    required this.insight,
    required this.searchController,
    required this.onRefresh,
    required this.onStart,
    required this.onKeywordTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading || insight == null) {
      return const _LandingInsightSkeleton();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final data = insight!;
    final score = _landingTrendScore(data);
    final delta = _landingTrendDelta(data);
    final briefing = _landingBriefing(data);
    final keywords = data.keywords.take(8).toList();
    final rising = data.risingIssues.take(3).toList();
    final titleText = isDark ? Colors.white : const Color(0xFF0F172A);
    final mutedText = isDark ? Colors.grey.shade400 : Colors.blueGrey.shade500;
    final bodyText = isDark ? Colors.grey.shade300 : Colors.blueGrey.shade800;
    final chipBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFEEF4FF);
    final chipBorder =
        isDark ? const Color(0xFF1F2937) : const Color(0xFFDCE7FF);
    final chipText = isDark ? Colors.blue.shade200 : Colors.blue.shade700;
    final inputFill =
        isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final inputBorder =
        isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);
    final ctaBg = isDark ? Colors.blue.shade600 : const Color(0xFF2563EB);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : const Color(0xFF101827),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: chipBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: chipBorder),
                ),
                child:
                    Icon(Icons.auto_awesome_rounded, color: chipText, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'AI Briefing',
                  style: TextStyle(
                    color: titleText,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                tooltip: '새로고침',
                onPressed: onRefresh,
                icon: Icon(Icons.refresh_rounded, color: mutedText, size: 19),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            briefing,
            style: TextStyle(
              color: bodyText,
              fontSize: 15,
              height: 1.55,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _LandingMetricCard(
                  label: '오늘 이슈강도',
                  value: '$score',
                  suffix: '/100',
                  color: Colors.indigoAccent,
                  changeText: '${delta.abs()}',
                  changeUp: delta >= 0,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _LandingMetricCard(
                  label: '감정온도',
                  value: '${data.sentiment.temperature}',
                  suffix: '°',
                  color: data.sentiment.temperature >= 71
                      ? Colors.greenAccent
                      : data.sentiment.temperature <= 30
                          ? Colors.redAccent
                          : Colors.lightBlueAccent,
                  caption: _sentimentCaption(data.sentiment.temperature),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '전일 대비 ${delta >= 0 ? '+' : ''}$delta · 긍정 ${data.sentiment.positiveRatio}% · 중립 ${data.sentiment.neutralRatio}% · 부정 ${data.sentiment.negativeRatio}%',
            style: TextStyle(
              color: mutedText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: searchController,
            onSubmitted: (_) => onStart(),
            style: TextStyle(color: titleText),
            decoration: InputDecoration(
              hintText: 'AI, 환율, 비트코인 검색',
              hintStyle: TextStyle(color: mutedText),
              prefixIcon: Icon(Icons.search_rounded, color: mutedText),
              suffixIcon: IconButton(
                tooltip: '검색',
                onPressed: onStart,
                icon: Icon(Icons.arrow_forward_rounded, color: titleText),
              ),
              filled: true,
              fillColor: chipBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: chipBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: chipBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                    color: isDark
                        ? Colors.blue.shade200
                        : const Color(0xFF2563EB)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '실시간 인기 키워드',
            style: TextStyle(
              color: titleText,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (int i = 0; i < keywords.length; i++)
                ActionChip(
                  label: Text(
                    '${i + 1}. ${keywords[i].keyword} · ${keywords[i].newsCount}',
                  ),
                  onPressed: () => onKeywordTap(keywords[i]),
                  backgroundColor: chipBg.withOpacity(isDark ? 0.9 : 1.0),
                  side: BorderSide(color: chipBorder),
                  labelStyle: TextStyle(
                    color: chipText,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          if (rising.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              '급상승 이슈',
              style: TextStyle(
                color: titleText,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            for (final issue in rising)
              _LandingRisingIssueRow(issue: issue, onTap: onStart),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.bolt_rounded, size: 18),
              label: const Text('실시간 뉴스 분석 보기'),
              style: FilledButton.styleFrom(
                backgroundColor: ctaBg,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LandingInsightSkeleton extends StatelessWidget {
  const _LandingInsightSkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeController.instance.mode.value == ThemeMode.dark;
    return Container(
      height: 420,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.20)
                : Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _skeletonBar(isDark: isDark, width: 150, height: 24),
          const SizedBox(height: 18),
          _skeletonBar(isDark: isDark, width: double.infinity, height: 16),
          const SizedBox(height: 8),
          _skeletonBar(isDark: isDark, width: 280, height: 16),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                  child: _skeletonBar(
                      isDark: isDark, width: double.infinity, height: 96)),
              const SizedBox(width: 10),
              Expanded(
                  child: _skeletonBar(
                      isDark: isDark, width: double.infinity, height: 96)),
            ],
          ),
          const SizedBox(height: 18),
          _skeletonBar(isDark: isDark, width: double.infinity, height: 48),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (int i = 0; i < 6; i++)
                _skeletonBar(isDark: isDark, width: 86, height: 34),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _skeletonBar({
    required bool isDark,
    required double width,
    required double height,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : const Color(0xFFEAF1FF),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

class _LandingTrendPanel extends StatelessWidget {
  final bool isLoading;
  final TrendInsightSnapshot? insight;
  final TextEditingController searchController;
  final VoidCallback onRefresh;
  final VoidCallback onSearch;
  final ValueChanged<TrendKeyword> onKeywordTap;
  final ValueChanged<RisingIssue> onRisingIssueTap;

  const _LandingTrendPanel({
    required this.isLoading,
    required this.insight,
    required this.searchController,
    required this.onRefresh,
    required this.onSearch,
    required this.onKeywordTap,
    required this.onRisingIssueTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading || insight == null) {
      return const _LandingInsightSkeleton();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final data = insight!;
    final score = _landingTrendScore(data);
    final delta = _landingTrendDelta(data);
    final timeLabel = _landingTimeLabel();
    final coreIssue = _landingCoreIssueLine(data);
    final marketImpact = _landingMarketImpactLines(data);
    final keywords = data.keywords
        .where((item) => _isLandingKeywordUseful(item.keyword))
        .take(6)
        .toList();
    final risingMap = {
      for (final item in data.risingIssues) item.keyword: item,
    };
    final titleText = Theme.of(context).colorScheme.onSurface;
    final bodyText = isDark ? Colors.grey.shade300 : Colors.blueGrey.shade800;
    final mutedText = isDark ? Colors.grey.shade400 : Colors.blueGrey.shade500;
    final ctaBg = isDark ? Colors.blue.shade600 : const Color(0xFF2563EB);

    Widget briefingHeader() {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF172554)
                        : const Color(0xFFEEF4FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 17,
                    color: isDark ? Colors.blue.shade200 : Colors.blue.shade700,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI 브리핑',
                        style: TextStyle(
                          color: titleText,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '마지막 분석 $timeLabel',
                        style: TextStyle(
                          color: mutedText,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            tooltip: '새로고침',
            onPressed: onRefresh,
            icon: Icon(
              Icons.refresh_rounded,
              size: 19,
              color: mutedText,
            ),
            splashRadius: 18,
            visualDensity: VisualDensity.compact,
          ),
        ],
      );
    }

    return Container(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 16 : 22),
      decoration: PulseUi.sectionDecoration(context, prominent: true),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 1040;

          Widget sectionTitle(String title, String subtitle,
              {bool compact = false}) {
            final hasSubtitle = subtitle.trim().isNotEmpty;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: titleText,
                    fontSize: compact ? 16 : 16,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
                if (hasSubtitle) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: mutedText,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            );
          }

          Widget trendScoreBlock() {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '트렌드 점수',
                      style: TextStyle(
                        color: titleText,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '$score',
                      style: TextStyle(
                        color: titleText,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      delta >= 0 ? '+$delta' : '$delta',
                      style: TextStyle(
                        color: delta >= 0 ? const Color(0xFF2563EB) : mutedText,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: score / 100),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) {
                      return LinearProgressIndicator(
                        value: value,
                        minHeight: 5,
                        backgroundColor: isDark
                            ? const Color(0xFF1F2937)
                            : const Color(0xFFE8EEF7),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF2563EB),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '현재 흐름을 100점 기준으로 간단히 보여줍니다.',
                  style: TextStyle(
                    color: mutedText,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
              ],
            );
          }

          Widget keywordsBlock() {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                sectionTitle(
                  '실시간 인기 키워드',
                  '지금 많이 언급되는 흐름을 빠르게 확인하세요',
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 12,
                  children: [
                    for (final keyword in keywords)
                      _LandingKeywordChipV2(
                        keyword: keyword,
                        risingIssue: risingMap[keyword.keyword],
                        onTap: () => onKeywordTap(keyword),
                      ),
                  ],
                ),
              ],
            );
          }

          Widget briefingBlock() {
            final summary = data.sentiment.summary.trim().isEmpty
                ? '오늘의 뉴스 흐름을 간단히 정리합니다.'
                : data.sentiment.summary.trim();
            final impactLine = marketImpact.isEmpty
                ? '시장 영향은 집계 중입니다.'
                : marketImpact.take(2).join(' · ');
            final metaLine =
                '분석 ${data.keywords.length}개 · ${_sentimentCaption(data.sentiment.temperature)} · $impactLine';

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '오늘의 핵심 이슈',
                  style: TextStyle(
                    color: titleText,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  coreIssue,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: bodyText,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF1F2937)
                          : const Color(0xFFE8EEF5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.blue.shade200
                                  : const Color(0xFF2563EB),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '핵심 요약',
                            style: TextStyle(
                              color: mutedText,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        summary,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: bodyText,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        metaLine,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: mutedText,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => _LandingInsightDetailSheet(
                        insight: data,
                        score: score,
                        delta: delta,
                        marketImpact: marketImpact,
                      ),
                    ),
                    icon: Icon(
                      Icons.auto_awesome_rounded,
                      size: 18,
                      color: ctaBg,
                    ),
                    label: Text(
                      '상세 AI 요약',
                      style: TextStyle(
                        color: ctaBg,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ],
            );
          }

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                briefingHeader(),
                const SizedBox(height: 16),
                briefingBlock(),
                const SizedBox(height: 14),
                trendScoreBlock(),
                const SizedBox(height: 16),
                keywordsBlock(),
                const SizedBox(height: 16),
                _buildSearchAndCta(context, searchController, onSearch),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              briefingHeader(),
              const SizedBox(height: 18),
              briefingBlock(),
              const SizedBox(height: 16),
              trendScoreBlock(),
              const SizedBox(height: 16),
              keywordsBlock(),
              const SizedBox(height: 16),
              _buildSearchAndCta(context, searchController, onSearch),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchAndCta(
    BuildContext context,
    TextEditingController searchController,
    VoidCallback onSearch,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final mutedText = isDark ? Colors.grey.shade400 : Colors.blueGrey.shade500;
    final surface = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final border = isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        final searchField = TextField(
          controller: searchController,
          onSubmitted: (_) => onSearch(),
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            hintText: '뉴스 키워드 검색',
            hintStyle: TextStyle(color: mutedText),
            prefixIcon: Icon(Icons.search_rounded, color: mutedText),
            filled: true,
            fillColor: surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                  color:
                      isDark ? Colors.blue.shade200 : const Color(0xFF2563EB)),
            ),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          ),
        );
        final actionButton = FilledButton.icon(
          onPressed: onSearch,
          icon: const Icon(Icons.bolt_rounded, size: 18),
          label: const Text('실시간 뉴스 보기'),
          style: FilledButton.styleFrom(
            backgroundColor:
                isDark ? Colors.blue.shade600 : const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 1,
            shadowColor: const Color(0xFF2563EB).withOpacity(0.20),
          ),
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              searchField,
              const SizedBox(height: 10),
              SizedBox(height: 44, child: actionButton),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: searchField),
            const SizedBox(width: 10),
            actionButton,
          ],
        );
      },
    );
  }
}

class _LandingMetaStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData? leadingIcon;
  final Color? leadingColor;
  final String? trailingBadge;

  const _LandingMetaStat({
    required this.label,
    required this.value,
    this.leadingIcon,
    this.leadingColor,
    this.trailingBadge,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeController.instance.mode.value == ThemeMode.dark;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOut,
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color:
                  isDark ? const Color(0xFF1F2937) : const Color(0xFFE6ECF3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (leadingIcon != null) ...[
                  Icon(
                    leadingIcon,
                    size: 13,
                    color: leadingColor ??
                        (isDark
                            ? Colors.grey.shade400
                            : Colors.blueGrey.shade500),
                  ),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.blueGrey.shade500,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            if (trailingBadge == null)
              Text(
                value,
                style: TextStyle(
                  color: trailingBadge == null
                      ? (isDark ? Colors.white : const Color(0xFF0F172A))
                      : (leadingColor ??
                          (isDark ? Colors.white : const Color(0xFF0F172A))),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              )
            else
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF063B22)
                          : const Color(0xFFECFDF3),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF16A34A),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          trailingBadge!,
                          style: TextStyle(
                            color: isDark
                                ? const Color(0xFF86EFAC)
                                : const Color(0xFF166534),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: leadingColor ??
                            (isDark ? Colors.white : const Color(0xFF0F172A)),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _LandingSentimentMiniBar extends StatelessWidget {
  final NewsSentimentSummary sentiment;

  const _LandingSentimentMiniBar({required this.sentiment});

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeController.instance.mode.value == ThemeMode.dark;
    final total = sentiment.positiveRatio +
        sentiment.neutralRatio +
        sentiment.negativeRatio;
    final positive = total == 0 ? 1 : sentiment.positiveRatio;
    final neutral = total == 0 ? 1 : sentiment.neutralRatio;
    final negative = total == 0 ? 1 : sentiment.negativeRatio;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE6ECF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withOpacity(0.75),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '감정 비율',
                style: TextStyle(
                  color:
                      isDark ? Colors.grey.shade400 : Colors.blueGrey.shade500,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              child: Row(
                children: [
                  Expanded(
                    flex: positive,
                    child: Container(
                      height: 4.5,
                      color: Colors.green.withOpacity(0.68),
                    ),
                  ),
                  Expanded(
                    flex: neutral,
                    child: Container(
                      height: 4.5,
                      color: Colors.blueGrey.withOpacity(0.48),
                    ),
                  ),
                  Expanded(
                    flex: negative,
                    child: Container(
                      height: 4.5,
                      color: Colors.red.withOpacity(0.60),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            '긍정 ${sentiment.positiveRatio}% · 중립 ${sentiment.neutralRatio}% · 부정 ${sentiment.negativeRatio}%',
            style: TextStyle(
              color: isDark ? Colors.grey.shade400 : Colors.blueGrey.shade600,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LandingTimelineItemTile extends StatelessWidget {
  final IssueTimelineItem item;
  final VoidCallback onTap;

  const _LandingTimelineItemTile({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stageLabel = _landingTimelineStageLabel(item.stage);
    final timeLabel = _landingTimelineTimeLabel(item.lastSeenAt);
    final growthLabel = item.growthRate >= 999
        ? 'NEW'
        : item.growthRate > 0
            ? '+${item.growthRate}%'
            : item.growthRate < 0
                ? '${item.growthRate}%'
                : '0%';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        hoverColor: const Color(0xFF2563EB).withOpacity(0.03),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF111827) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color:
                    isDark ? const Color(0xFF1F2937) : const Color(0xFFE6ECF3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF172554)
                          : const Color(0xFFEEF4FF),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Center(
                      child: Text(
                        '${item.rank}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.title.isNotEmpty ? item.title : item.keyword,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 14.5,
                        height: 1.35,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                item.summary.isNotEmpty
                    ? item.summary
                    : '관련 기사 ${item.articleCount}건이 묶여 있는 이슈입니다.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  color:
                      isDark ? Colors.grey.shade400 : Colors.blueGrey.shade600,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _LandingTinyBadge(
                    text: item.category.isNotEmpty ? item.category : '이슈',
                    foreground: const Color(0xFF2563EB),
                    background: isDark
                        ? const Color(0xFF172554)
                        : const Color(0xFFEEF4FF),
                  ),
                  _LandingTinyBadge(
                    text: '기사 ${item.articleCount}건',
                    foreground:
                        isDark ? Colors.grey.shade100 : const Color(0xFF334155),
                    background: isDark
                        ? const Color(0xFF1F2937)
                        : const Color(0xFFF1F5F9),
                  ),
                  _LandingTinyBadge(
                    text: growthLabel,
                    foreground: isDark
                        ? const Color(0xFFFBBF24)
                        : const Color(0xFFB45309),
                    background: isDark
                        ? const Color(0xFF3F2D12)
                        : const Color(0xFFFFF7E6),
                  ),
                  _LandingTinyBadge(
                    text: stageLabel,
                    foreground:
                        isDark ? Colors.grey.shade100 : const Color(0xFF475569),
                    background: isDark
                        ? const Color(0xFF111827)
                        : const Color(0xFFF8FAFC),
                  ),
                  Text(
                    timeLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? Colors.grey.shade200
                          : Colors.blueGrey.shade500,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LandingTinyBadge extends StatelessWidget {
  final String text;
  final Color foreground;
  final Color background;

  const _LandingTinyBadge({
    required this.text,
    required this.foreground,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: foreground,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _LandingUrgencyBadge extends StatelessWidget {
  final String label;
  final int severity;

  const _LandingUrgencyBadge({
    required this.label,
    required this.severity,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = severity >= 5
        ? (isDark ? const Color(0xFF3F1D1D) : const Color(0xFFFFF1F2))
        : severity >= 4
            ? (isDark ? const Color(0xFF172554) : const Color(0xFFEEF4FF))
            : (isDark ? const Color(0xFF1F2937) : const Color(0xFFF3F4F6));
    final foreground = severity >= 5
        ? (isDark ? Colors.red.shade200 : Colors.red.shade600)
        : severity >= 4
            ? (isDark ? Colors.blue.shade200 : Colors.blue.shade700)
            : (isDark ? Colors.grey.shade200 : Colors.blueGrey.shade600);
    final dotColor = severity >= 5
        ? (isDark ? Colors.red.shade200 : Colors.red.shade500)
        : severity >= 4
            ? (isDark ? Colors.blue.shade200 : Colors.blue.shade500)
            : (isDark ? Colors.grey.shade300 : Colors.blueGrey.shade400);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _LandingInfoPill extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;
  final Color background;

  const _LandingInfoPill({
    required this.label,
    required this.value,
    required this.accent,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.transparent : accent.withOpacity(0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.grey.shade300 : Colors.blueGrey.shade500,
              fontSize: 10.3,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontSize: 13.2,
              fontWeight: FontWeight.w800,
              height: 1.28,
            ),
          ),
        ],
      ),
    );
  }
}

class _LandingDetailStatTile extends StatelessWidget {
  final String label;
  final String value;
  final String detail;
  final Color accent;
  final Color background;

  const _LandingDetailStatTile({
    required this.label,
    required this.value,
    required this.detail,
    required this.accent,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF1F2937) : accent.withOpacity(0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.grey.shade400 : Colors.blueGrey.shade500,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: accent,
                fontSize: 26,
                height: 1,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isDark ? Colors.grey.shade300 : Colors.blueGrey.shade600,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LandingMiniStateChip extends StatelessWidget {
  final String label;
  final String value;
  final String detail;

  const _LandingMiniStateChip({
    required this.label,
    required this.value,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE8EEF5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.grey.shade400 : Colors.blueGrey.shade500,
              fontSize: 10.0,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontSize: 13.0,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            detail,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isDark ? Colors.grey.shade400 : Colors.blueGrey.shade500,
              fontSize: 9.8,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _LandingMarketMoodRow extends StatelessWidget {
  final TrendInsightSnapshot data;
  final List<_LandingMarketQuote> marketQuotes;

  const _LandingMarketMoodRow({
    required this.data,
    required this.marketQuotes,
  });

  @override
  Widget build(BuildContext context) {
    final sentiment = data.sentiment;
    final domestic = _landingSectorMoodLabel(data);
    final usQuote = _landingQuoteByTitle(marketQuotes, '나스닥100 선물');
    final fxQuote = _landingQuoteByTitle(marketQuotes, 'USD/KRW');
    final usLabel = usQuote == null
        ? '관찰 중'
        : usQuote.percentChange > 0
            ? '긍정'
            : usQuote.percentChange < 0
                ? '부정'
                : '중립';
    final fxLabel = fxQuote == null
        ? '관찰 중'
        : fxQuote.percentChange > 0
            ? '원화 약세'
            : fxQuote.percentChange < 0
                ? '원화 강세'
                : '중립';
    final greedLabel = _landingSentimentLabel(sentiment.temperature);

    final chips = [
      _LandingMiniStateChip(
        label: '국내 증시',
        value: domestic,
        detail: '경제·세계 뉴스 기준',
      ),
      _LandingMiniStateChip(
        label: '미국 선물',
        value: usLabel,
        detail: usQuote == null
            ? '데이터 대기'
            : '변동 ${_landingFormatPercent(usQuote.percentChange)}',
      ),
      _LandingMiniStateChip(
        label: '환율',
        value: fxLabel,
        detail: fxQuote == null
            ? '데이터 대기'
            : '변동 ${_landingFormatPercent(fxQuote.percentChange)}',
      ),
      _LandingMiniStateChip(
        label: '공포·탐욕',
        value: '$greedLabel ${sentiment.temperature}',
        detail: '뉴스 감정 집계',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 680 ? 2 : 4;
        final spacing = 8.0;
        final chipWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: chips
              .map(
                (chip) => SizedBox(
                  width: chipWidth,
                  child: chip,
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _LandingInsightDetailSheet extends StatelessWidget {
  final TrendInsightSnapshot insight;
  final int score;
  final int delta;
  final List<String> marketImpact;

  const _LandingInsightDetailSheet({
    required this.insight,
    required this.score,
    required this.delta,
    required this.marketImpact,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF0F172A) : Colors.white;
    final border = isDark ? const Color(0xFF1F2937) : const Color(0xFFE8EEF5);
    final title = isDark ? Colors.white : const Color(0xFF0F172A);
    final body = isDark ? Colors.grey.shade300 : Colors.blueGrey.shade700;
    final summaryText = insight.sentiment.summary.trim();
    final bullets = _landingDetailBullets(summaryText);
    final leadLine = bullets.isNotEmpty
        ? bullets.first
        : (summaryText.isEmpty
            ? '오늘 뉴스 흐름을 요약하고 있습니다.'
            : summaryText);
    final extraLines = bullets.length > 1 ? bullets.skip(1).take(2).toList() : const <String>[];
    final trendCaption = _sentimentCaption(insight.sentiment.temperature);
    final marketImpacts = marketImpact.take(3).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.48,
      maxChildSize: 0.92,
      builder: (context, controller) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.30 : 0.12),
                blurRadius: 24,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: Container(
              color: surface,
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
                children: [
                  Center(
                    child: Container(
                      width: 46,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1F2937)
                            : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF111827)
                              : const Color(0xFFEEF4FF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_awesome_rounded,
                              size: 14,
                              color: isDark
                                  ? Colors.blue.shade200
                                  : const Color(0xFF2563EB),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '실시간 브리핑',
                              style: TextStyle(
                                color: isDark
                                    ? Colors.blue.shade100
                                    : const Color(0xFF2563EB),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${insight.keywords.length}개 키워드',
                        style: TextStyle(
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.blueGrey.shade500,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF111827)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF1F2937)
                            : const Color(0xFFE8EEF5),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.blue.shade200
                                    : const Color(0xFF2563EB),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '상세 AI 요약',
                              style: TextStyle(
                                color: title,
                                fontSize: 16.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1F2937)
                                    : const Color(0xFFEEF4FF),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                trendCaption,
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.blue.shade100
                                      : const Color(0xFF2563EB),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '오늘의 핵심 한 줄',
                          style: TextStyle(
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.blueGrey.shade500,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          leadLine,
                          style: TextStyle(
                            color: title,
                            fontSize: 16,
                            height: 1.42,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (extraLines.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          for (final line in extraLines) ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(top: 7),
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.blue.shade200
                                        : const Color(0xFF2563EB),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    line,
                                    style: TextStyle(
                                      color: body,
                                      fontSize: 13.4,
                                      height: 1.45,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                          ],
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _LandingDetailStatTile(
                          label: '트렌드 점수',
                          value: '$score',
                          detail: delta == 0
                              ? '전일과 비슷한 흐름'
                              : '전일 대비 ${delta >= 0 ? '+' : ''}$delta',
                          accent: isDark
                              ? Colors.blue.shade200
                              : const Color(0xFF2563EB),
                          background: isDark
                              ? const Color(0xFF111827)
                              : const Color(0xFFEEF4FF),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _LandingDetailStatTile(
                          label: '감정 온도',
                          value: '${insight.sentiment.temperature}°',
                          detail: _sentimentCaption(insight.sentiment.temperature),
                          accent: isDark
                              ? Colors.amber.shade200
                              : const Color(0xFFF59E0B),
                          background: isDark
                              ? const Color(0xFF1F2937)
                              : const Color(0xFFFFFBEB),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF111827)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF1F2937)
                            : const Color(0xFFE8EEF5),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '시장 영향',
                          style: TextStyle(
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.blueGrey.shade500,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: marketImpacts.isEmpty
                              ? [
                                  _LandingTinyBadge(
                                    text: '집계 중',
                                    foreground: isDark
                                        ? Colors.grey.shade200
                                        : Colors.blueGrey.shade600,
                                    background: isDark
                                        ? const Color(0xFF1F2937)
                                        : const Color(0xFFF3F4F6),
                                  ),
                                ]
                              : marketImpacts.map((impact) {
                                  return _LandingTinyBadge(
                                    text: impact,
                                    foreground: isDark
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                                    background: isDark
                                        ? const Color(0xFF1F2937)
                                        : const Color(0xFFF3F4F6),
                                  );
                                }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF111827)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF1F2937)
                            : const Color(0xFFE8EEF5),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '핵심 키워드',
                          style: TextStyle(
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.blueGrey.shade500,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: insight.keywords.take(6).map((item) {
                            final weight = item.newsCount >= 8
                                ? FontWeight.w900
                                : item.newsCount >= 5
                                    ? FontWeight.w800
                                    : FontWeight.w700;
                            return Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: item.newsCount >= 8 ? 12 : 10,
                                vertical: item.newsCount >= 8 ? 6 : 5,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1F2937)
                                    : const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF374151)
                                      : const Color(0xFFE5E7EB),
                                ),
                              ),
                              child: Text(
                                item.keyword,
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                                  fontSize: item.newsCount >= 8 ? 12.5 : 11.5,
                                  fontWeight: weight,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LandingSparkline extends StatelessWidget {
  final List<double> values;
  final Color color;

  const _LandingSparkline({
    required this.values,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 0.0;
        final height =
            constraints.maxHeight.isFinite && constraints.maxHeight > 0
                ? constraints.maxHeight
                : 24.0;
        return SizedBox(
          width: width,
          height: height,
          child: CustomPaint(
            painter: _LandingSparklinePainter(values: values, color: color),
          ),
        );
      },
    );
  }
}

class _LandingSparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;

  const _LandingSparklinePainter({
    required this.values,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0 || values.length < 2) return;
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final range =
        (maxValue - minValue).abs() < 0.0001 ? 1.0 : (maxValue - minValue);

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final fill = Paint()
      ..color = color.withOpacity(0.08)
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();
    for (int i = 0; i < values.length; i++) {
      final x = (size.width * i) / (values.length - 1);
      final normalized = (values[i] - minValue) / range;
      final y = size.height - (normalized * (size.height - 4)) - 2;
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fill);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant _LandingSparklinePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.values != values;
  }
}

class _BreakingNewsTimelineTile extends StatelessWidget {
  final TrendItem item;
  final bool isFeatured;
  final bool isRead;
  final VoidCallback? onTap;

  const _BreakingNewsTimelineTile({
    required this.item,
    this.isFeatured = false,
    this.isRead = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateTime = _landingTryParseDate(
      item.published.isNotEmpty ? item.published : item.createdAt,
    );
    final timeLabel = _landingClockLabel(dateTime);
    final relativeLabel = _landingRelativeTimeLabel(dateTime);
    final category =
        item.category.trim().isNotEmpty ? item.category.trim() : '속보';
    final titleColor = isDark
        ? (isRead ? Colors.grey.shade300 : Colors.white)
        : (isRead ? Colors.blueGrey.shade600 : const Color(0xFF0F172A));
    final lineColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB);
    final dotColor = isDark ? Colors.blue.shade300 : Colors.blue.shade700;
    final isLatest = isFeatured ||
        (dateTime != null &&
            DateTime.now().difference(dateTime).inMinutes <= 10);
    final latestDotColor =
        isDark ? Colors.blue.shade200 : const Color(0xFF1D4ED8);

    return MouseRegion(
      cursor:
          onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        hoverColor: const Color(0xFF2563EB).withOpacity(0.03),
        splashColor: const Color(0xFF2563EB).withOpacity(0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 18,
                  child: Column(
                    children: [
                      Container(
                        width: isLatest ? 12 : 10,
                        height: isLatest ? 12 : 10,
                        margin: const EdgeInsets.only(top: 5),
                        decoration: BoxDecoration(
                          color: isLatest ? latestDotColor : dotColor,
                          shape: BoxShape.circle,
                          boxShadow: isLatest
                              ? [
                                  BoxShadow(
                                    color: latestDotColor.withOpacity(0.24),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: Container(
                          width: 2,
                          color: lineColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              timeLabel,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                                height: 1.0,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              relativeLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? Colors.grey.shade300
                                    : Colors.blueGrey.shade500,
                              ),
                            ),
                            _LandingUrgencyBadge(
                              label:
                                  _landingNewsImportanceLabel(item.importance),
                              severity: item.importance,
                            ),
                            _LandingTinyBadge(
                              text: category,
                              foreground: isDark
                                  ? Colors.white
                                  : const Color(0xFF2563EB),
                              background: isDark
                                  ? const Color(0xFF172554)
                                  : const Color(0xFFEEF4FF),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.koreanTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: titleColor,
                            fontSize: 15,
                            height: 1.35,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LandingSectionDivider extends StatelessWidget {
  const _LandingSectionDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 0.4,
      color: Color(0xFFF5F7FA),
    );
  }
}

class _LandingKeywordChipV2 extends StatelessWidget {
  final TrendKeyword keyword;
  final RisingIssue? risingIssue;
  final VoidCallback onTap;

  const _LandingKeywordChipV2({
    required this.keyword,
    required this.risingIssue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary = risingIssue == null
        ? '관심도 ${keyword.newsCount}'
        : risingIssue?.isNew == true
            ? 'NEW'
            : (risingIssue?.growthRate ?? 0) > 0
                ? '▲${risingIssue!.growthRate}'
                : (risingIssue?.growthRate ?? 0) < 0
                    ? '▼${risingIssue!.growthRate.abs()}'
                    : '관심도 ${keyword.newsCount}';
    return _HoverButton(
      onTap: onTap,
      child: Material(
        color: isDark ? const Color(0xFF111827) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          hoverColor: const Color(0xFF2563EB).withOpacity(0.06),
          splashColor: const Color(0xFF2563EB).withOpacity(0.08),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: keyword.keyword,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextSpan(
                    text: ' · $secondary',
                    style: TextStyle(
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.blueGrey.shade500,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
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

class _LandingHotIssueCard extends StatelessWidget {
  final RisingIssue issue;
  final List<String> keywords;
  final VoidCallback onTap;

  const _LandingHotIssueCard({
    required this.issue,
    required this.keywords,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayKeywords = keywords.take(2).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        hoverColor: const Color(0xFF2563EB).withOpacity(0.03),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF172554)
                      : const Color(0xFFEEF4FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Icon(
                    Icons.trending_up_rounded,
                    size: 14,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      issue.representativeTitle.isNotEmpty
                          ? issue.representativeTitle
                          : issue.keyword,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 14,
                        height: 1.35,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '관련 기사 ${issue.currentCount}건',
                      style: TextStyle(
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.blueGrey.shade600,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.end,
                  children: [
                    if (issue.keyword.trim().isNotEmpty)
                      _LandingMiniTag(text: issue.keyword.trim()),
                    for (final keyword in displayKeywords
                        .where((item) => item != issue.keyword))
                      _LandingMiniTag(text: keyword),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LandingMiniTag extends StatelessWidget {
  final String text;

  const _LandingMiniTag({required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isDark ? Colors.grey.shade300 : const Color(0xFF334155),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LandingGroupedNewsTile extends StatefulWidget {
  final NewsCluster cluster;
  final VoidCallback onTap;

  const _LandingGroupedNewsTile({
    required this.cluster,
    required this.onTap,
  });

  @override
  State<_LandingGroupedNewsTile> createState() =>
      _LandingGroupedNewsTileState();
}

class _LandingGroupedNewsTileState extends State<_LandingGroupedNewsTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final item = widget.cluster.representative;
    final hasLink = item.link.trim().isNotEmpty;
    final source = item.source.trim().isEmpty ? 'News' : item.source.trim();
    final category =
        item.category.trim().isEmpty ? 'General' : item.category.trim();
    final timeLabel = _landingCompactTime(
        item.published.isNotEmpty ? item.published : item.createdAt);
    final extraCount = widget.cluster.articleCount - 1;

    return MouseRegion(
      cursor: hasLink ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) {
        if (mounted) setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (mounted) setState(() => _isHovered = false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _isHovered ? -2 : 0, 0),
        child: Material(
          color: isDark ? const Color(0xFF111827) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: widget.onTap,
            hoverColor: const Color(0xFF2563EB).withOpacity(0.03),
            splashColor: const Color(0xFF2563EB).withOpacity(0.05),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _isHovered
                      ? (isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFD8E5FF))
                      : (isDark
                          ? const Color(0xFF1F2937)
                          : const Color(0xFFE5E7EB)),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withOpacity(_isHovered ? 0.30 : 0.20)
                        : const Color(0xFF0F172A)
                            .withOpacity(_isHovered ? 0.06 : 0.04),
                    blurRadius: _isHovered ? 24 : 20,
                    offset: const Offset(0, 8),
                  ),
                ],
                color: isDark ? const Color(0xFF111827) : Colors.white,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF172554)
                              : const Color(0xFFEEF4FF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            source.isNotEmpty ? source[0].toUpperCase() : 'N',
                            style: const TextStyle(
                              color: Color(0xFF2563EB),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          source,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : Colors.blueGrey.shade700,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1F2937)
                              : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            color: isDark
                                ? Colors.grey.shade100
                                : Colors.blueGrey.shade600,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeLabel,
                        style: TextStyle(
                          color: isDark
                              ? Colors.grey.shade100
                              : Colors.blueGrey.shade500,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.koreanTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontSize: 15,
                      height: 1.28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (item.summaryKr.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      item.summaryKr.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark
                            ? Colors.grey.shade200
                            : Colors.blueGrey.shade600,
                        fontSize: 14,
                        height: 1.42,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF172554)
                              : const Color(0xFFEEF4FF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          extraCount > 0
                              ? '묶음 ${widget.cluster.articleCount}건'
                              : '단일 기사',
                          style: TextStyle(
                            color: isDark
                                ? Colors.blue.shade200
                                : Colors.blue.shade700,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF111827)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '언론사 ${widget.cluster.sourceCount}곳',
                          style: TextStyle(
                            color: isDark
                                ? Colors.grey.shade200
                                : Colors.blueGrey.shade600,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (extraCount > 0) ...[
                        const Spacer(),
                        Text(
                          '외 $extraCount건',
                          style: TextStyle(
                            color: isDark
                                ? Colors.grey.shade100
                                : Colors.blueGrey.shade500,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
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

class _LandingSearchResultTile extends StatefulWidget {
  final TrendItem item;

  const _LandingSearchResultTile({required this.item});

  @override
  State<_LandingSearchResultTile> createState() =>
      _LandingSearchResultTileState();
}

class _LandingSearchResultTileState extends State<_LandingSearchResultTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final item = widget.item;
    final hasLink = item.link.trim().isNotEmpty;
    final source = item.source.trim().isEmpty ? 'News' : item.source.trim();
    final category =
        item.category.trim().isEmpty ? 'General' : item.category.trim();
    final timeLabel = _landingCompactTime(
        item.published.isNotEmpty ? item.published : item.createdAt);

    return MouseRegion(
      cursor: hasLink ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) {
        if (mounted) setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (mounted) setState(() => _isHovered = false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _isHovered ? -2 : 0, 0),
        child: Material(
          color: isDark ? const Color(0xFF111827) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: hasLink ? () => _openArticle(context, item.link) : null,
            hoverColor: const Color(0xFF2563EB).withOpacity(0.03),
            splashColor: const Color(0xFF2563EB).withOpacity(0.05),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _isHovered
                      ? (isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFD8E5FF))
                      : (isDark
                          ? const Color(0xFF1F2937)
                          : const Color(0xFFE5E7EB)),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withOpacity(_isHovered ? 0.30 : 0.20)
                        : const Color(0xFF0F172A)
                            .withOpacity(_isHovered ? 0.06 : 0.04),
                    blurRadius: _isHovered ? 24 : 20,
                    offset: const Offset(0, 8),
                  ),
                ],
                color: isDark ? const Color(0xFF111827) : Colors.white,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF172554)
                              : const Color(0xFFEEF4FF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            source.isNotEmpty ? source[0].toUpperCase() : 'N',
                            style: const TextStyle(
                              color: Color(0xFF2563EB),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          source,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isDark
                                ? Colors.grey.shade200
                                : Colors.blueGrey.shade700,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1F2937)
                              : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            color: isDark
                                ? Colors.grey.shade300
                                : Colors.blueGrey.shade600,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeLabel,
                        style: TextStyle(
                          color: isDark
                              ? Colors.grey.shade100
                              : Colors.blueGrey.shade500,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.koreanTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontSize: 15,
                      height: 1.28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (item.summaryKr.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      item.summaryKr.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark
                            ? Colors.grey.shade100
                            : Colors.blueGrey.shade600,
                        fontSize: 14,
                        height: 1.42,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF4FF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_graph_rounded,
                              size: 13,
                              color: Colors.blue.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '중요도 ${item.importance}',
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (hasLink) ...[
                        const Spacer(),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 170),
                          curve: Curves.easeOut,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _isHovered
                                ? const Color(0xFFEEF4FF)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: _isHovered
                                  ? const Color(0xFFD8E5FF)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.open_in_new_rounded,
                                size: 13,
                                color: _isHovered
                                    ? const Color(0xFF2563EB)
                                    : Colors.blueGrey.shade500,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '원문 보기',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: _isHovered
                                      ? const Color(0xFF2563EB)
                                      : Colors.blueGrey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openArticle(BuildContext context, String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return;

    final opened = await launchUrl(uri, webOnlyWindowName: '_blank');
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('기사 원문을 열 수 없습니다.')),
      );
    }
  }
}

class _LandingSearchStateMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _LandingSearchStateMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.grey.shade200 : Colors.grey.shade500;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: iconColor),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: isDark ? Colors.grey.shade200 : Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LandingMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String suffix;
  final Color color;
  final String? caption;
  final String? changeText;
  final bool changeUp;

  const _LandingMetricCard({
    required this.label,
    required this.value,
    required this.suffix,
    required this.color,
    this.caption,
    this.changeText,
    this.changeUp = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            isDark ? const Color(0xFF111827) : Colors.white.withOpacity(0.09),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: isDark
                ? const Color(0xFF1F2937)
                : Colors.white.withOpacity(0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isDark
                  ? Colors.grey.shade400
                  : Colors.white.withOpacity(0.66),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: RichText(
                  text: TextSpan(
                    text: value,
                    style: TextStyle(
                      color: color,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                    ),
                    children: [
                      TextSpan(
                        text: suffix,
                        style: TextStyle(
                          color: color.withOpacity(0.78),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (changeText != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: (changeUp ? Colors.greenAccent : Colors.redAccent)
                        .withOpacity(0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        changeUp
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 12,
                        color: changeUp ? Colors.greenAccent : Colors.redAccent,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        changeText!,
                        style: TextStyle(
                          color:
                              changeUp ? Colors.greenAccent : Colors.redAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (caption != null) ...[
            const SizedBox(height: 7),
            Text(
              caption!,
              style: TextStyle(
                color: Colors.white.withOpacity(0.58),
                fontSize: 11,
                height: 1.25,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LandingRisingIssueRow extends StatelessWidget {
  final RisingIssue issue;
  final VoidCallback onTap;

  const _LandingRisingIssueRow({required this.issue, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final badgeText = issue.isNew ? 'NEW' : '+${issue.increaseCount}건';
    final detailText = issue.isNew
        ? '최근 1시간 새롭게 포착 · 관련 기사 ${issue.currentCount}건'
        : '직전 1시간보다 기사 ${issue.increaseCount}건 증가';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                badgeText,
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    issue.keyword,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detailText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.62),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
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

int _landingTrendScore(TrendInsightSnapshot insight) {
  final topKeywords = insight.keywords.take(5).toList();
  final topRising = insight.risingIssues.take(3).toList();

  final keywordCount = topKeywords.isEmpty
      ? 0
      : topKeywords.fold<int>(0, (sum, item) => sum + item.newsCount) ~/
          topKeywords.length;
  final risingCount = topRising.isEmpty
      ? 0
      : topRising.fold<int>(
            0,
            (sum, item) => sum + item.currentCount + item.increaseCount,
          ) ~/
          topRising.length;

  final keywordScore = _landingTrendRatioScale(keywordCount, 130);
  final risingScore = _landingTrendRatioScale(risingCount, 90);
  final sentimentScore =
      1.0 - ((insight.sentiment.temperature - 50).abs() / 50).clamp(0, 1);

  final mixed =
      keywordScore * 0.43 + risingScore * 0.37 + sentimentScore * 0.20;
  return (12 + mixed * 76).round().clamp(0, 100);
}

int _landingTrendDelta(TrendInsightSnapshot insight) {
  if (insight.risingIssues.isEmpty) return 0;
  final averageIncrease = insight.risingIssues
          .map((issue) => issue.increaseCount)
          .reduce((a, b) => a + b) /
      insight.risingIssues.length;

  return (averageIncrease * 2).round().clamp(-20, 40);
}

List<String> _landingBriefingBullets(TrendInsightSnapshot insight) {
  final bullets = <String>[];
  final keywords = insight.keywords
      .map((item) => _cleanLandingKeyword(item.keyword))
      .where(_isLandingKeywordUseful)
      .take(3)
      .toList();
  final rising = insight.risingIssues
      .map((item) => _cleanLandingKeyword(item.keyword))
      .where(_isLandingKeywordUseful)
      .take(2)
      .toList();

  if (keywords.isNotEmpty) {
    bullets.add('${_joinKoreanListSafe(keywords)} 관련 기사 급증');
  }
  if (rising.isNotEmpty) {
    bullets.add('${_joinKoreanListSafe(rising)} 이슈가 빠르게 확대 중');
  }

  if (insight.sentiment.temperature >= 71) {
    bullets.add('전체 분위기는 긍정적으로 유지되고 있습니다');
  } else if (insight.sentiment.temperature <= 30) {
    bullets.add('전체 분위기는 다소 불안한 흐름입니다');
  } else {
    bullets.add('전체 분위기는 중립권에서 움직이고 있습니다');
  }

  while (bullets.length < 3) {
    bullets.add('실시간 뉴스 흐름을 계속 추적 중입니다');
  }

  return bullets.take(5).toList();
}

List<String> _landingIssueKeywords(RisingIssue issue) {
  final base = _cleanLandingKeyword(issue.keyword);
  final derived = _cleanLandingKeyword(issue.representativeTitle)
      .split(' ')
      .where(_isLandingKeywordUseful)
      .where((value) => value != base)
      .take(2)
      .toList();

  return [
    if (_isLandingKeywordUseful(base)) base,
    ...derived,
  ];
}

String _landingKeywordLabel(TrendKeyword keyword, RisingIssue? risingIssue) {
  final base = _cleanLandingKeyword(keyword.keyword);
  if (risingIssue != null) {
    if (risingIssue.isNew) return '$base NEW';
    if (risingIssue.growthRate > 0) return '$base ▲${risingIssue.growthRate}';
    if (risingIssue.growthRate < 0) {
      return '$base ▼${risingIssue.growthRate.abs()}';
    }
  }

  return '$base · 관심도 ${keyword.newsCount}';
}

String _sentimentCaption(int temperature) {
  if (temperature >= 71) {
    return '뉴스 분위기: 기대감 우세';
  }
  if (temperature <= 30) {
    return '뉴스 분위기: 불안감 우세';
  }
  return '뉴스 분위기: 중립 흐름';
}

List<String> _landingDetailBullets(String summary) {
  final text = summary.trim();
  if (text.isEmpty) return const [];
  final normalized = text.replaceAll('\n', ' ').trim();
  final parts = normalized
      .split(RegExp(r'(?<=[。.!?])\s+|[•·]+'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
  if (parts.isEmpty) return [normalized];
  final cleaned = <String>[];
  for (final item in parts) {
    if (cleaned.contains(item)) continue;
    cleaned.add(item);
    if (cleaned.length == 3) break;
  }
  return cleaned;
}

String _landingSentimentLabel(int temperature) {
  if (temperature >= 71) return '탐욕';
  if (temperature <= 30) return '불안';
  return '중립';
}

String _landingSectorMoodLabel(TrendInsightSnapshot insight) {
  final sectorTemperatures = insight.keywords
      .where((item) =>
          (item.category == '경제' || item.category == '세계') &&
          item.sentimentTemperature != null)
      .map((item) => item.sentimentTemperature!)
      .toList();

  final temperature = sectorTemperatures.isNotEmpty
      ? (sectorTemperatures.reduce((a, b) => a + b) / sectorTemperatures.length)
          .round()
      : insight.sentiment.temperature;

  if (temperature >= 71) return '긍정 우세';
  if (temperature <= 30) return '경계';
  return '보통';
}

String _landingTimelineStageLabel(String stage) {
  switch (stage) {
    case 'new':
      return '신규';
    case 'peak':
      return '정점';
    case 'cooling':
      return '하락';
    case 'ended':
      return '종료';
    case 'rising':
    default:
      return '상승';
  }
}

String _landingTimelineTimeLabel(String value) {
  final parsed = _landingParseTimestamp(value);
  if (parsed == null) return '방금 전';
  final diff = DateTime.now().difference(parsed);
  if (!diff.isNegative) {
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
  }
  final hour = parsed.hour.toString().padLeft(2, '0');
  final minute = parsed.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _landingBriefing(TrendInsightSnapshot insight) {
  final keywords = insight.keywords.take(3).map((e) => e.keyword).toList();
  final rising = insight.risingIssues.take(2).map((e) => e.keyword).toList();

  if (keywords.isEmpty && rising.isEmpty) {
    return 'AI가 오늘의 주요 이슈를 수집하고 있습니다.\n새 뉴스가 쌓이면 핵심 키워드와 분위기를 자동으로 요약합니다.';
  }

  final keywordText = keywords.isEmpty ? '새로운 뉴스' : keywords.join(', ');
  final risingText = rising.isEmpty
      ? '뚜렷한 급상승 이슈는 아직 없습니다'
      : '${rising.join(', ')} 관련 뉴스가 빠르게 늘고 있습니다';
  final mood = insight.sentiment.temperature >= 71
      ? '기대감이 우세합니다'
      : insight.sentiment.temperature <= 30
          ? '불안감이 큽니다'
          : '중립적인 흐름입니다';

  return '오늘은 $keywordText 이슈가 많이 언급되고 있습니다.\n$risingText.\n전체 뉴스 분위기는 $mood.';
}

String _landingBriefingText(TrendInsightSnapshot insight) {
  final keywords = insight.keywords
      .map((item) => item.keyword.trim())
      .where((keyword) => keyword.isNotEmpty)
      .take(3)
      .toList();
  final rising = insight.risingIssues
      .map((item) => item.keyword.trim())
      .where((keyword) => keyword.isNotEmpty)
      .take(2)
      .toList();

  if (keywords.isEmpty && rising.isEmpty) {
    return 'AI가 오늘의 주요 뉴스를 분석하고 있습니다.\n데이터가 쌓이면 핵심 이슈와 뉴스 분위기를 자동으로 요약합니다.';
  }

  final keywordSentence = keywords.length == 1
      ? '${keywords.first} 관련 뉴스가 많이 언급되고 있습니다.'
      : '${_joinKoreanList(keywords)} 관련 뉴스가 많이 언급되고 있습니다.';
  final risingSentence = rising.isEmpty
      ? '아직 뚜렷한 급상승 이슈는 감지되지 않았습니다.'
      : '${_joinKoreanList(rising)} 이슈의 언급량이 빠르게 늘고 있습니다.';
  final mood = insight.sentiment.temperature >= 71
      ? '기대감이 우세한 편입니다.'
      : insight.sentiment.temperature <= 30
          ? '불안감이 커진 흐름입니다.'
          : '전반적으로 중립적인 흐름입니다.';

  return '오늘은 $keywordSentence\n$risingSentence\n전체 뉴스 분위기는 $mood';
}

double _landingTrendRatioScale(int value, int cap) {
  if (cap <= 0 || value <= 0) return 0;
  return (value / (value + cap)).clamp(0.0, 1.0);
}

String _joinKoreanList(List<String> values) {
  if (values.length <= 1) return values.join();
  if (values.length == 2) return '${values[0]}와 ${values[1]}';

  return '${values.take(values.length - 1).join(', ')}와 ${values.last}';
}

String _landingBriefingTextSafe(TrendInsightSnapshot insight) {
  final keywords = insight.keywords
      .map((item) => _cleanLandingKeyword(item.keyword))
      .where(_isLandingKeywordUseful)
      .take(3)
      .toList();
  final rising = insight.risingIssues
      .map((item) => _cleanLandingKeyword(item.keyword))
      .where(_isLandingKeywordUseful)
      .take(2)
      .toList();

  if (keywords.isEmpty && rising.isEmpty) {
    return 'AI가 오늘의 주요 뉴스를 분석하고 있습니다.\n데이터가 쌓이면 핵심 이슈와 뉴스 분위기를 자동으로 요약합니다.';
  }

  final lines = <String>[];

  if (keywords.isNotEmpty) {
    lines.add('오늘은 ${_joinKoreanListSafe(keywords)} 관련 보도가 많이 나오고 있습니다.');
  }

  if (rising.isNotEmpty) {
    lines.add('${_joinKoreanListSafe(rising)} 관련 보도는 최근 더 빠르게 늘고 있습니다.');
  }

  if (insight.sentiment.temperature >= 71) {
    lines.add('뉴스 분위기는 기대감이 우세한 편입니다.');
  } else if (insight.sentiment.temperature <= 30) {
    lines.add('뉴스 분위기는 다소 불안한 흐름입니다.');
  } else {
    lines.add('뉴스 분위기는 전반적으로 중립에 가깝습니다.');
  }

  return lines.join('\n');
}

String _landingCoreIssueLine(TrendInsightSnapshot insight) {
  final keyword = insight.keywords.isNotEmpty
      ? _cleanLandingKeyword(insight.keywords.first.keyword)
      : '';
  final rising = insight.risingIssues.isNotEmpty
      ? _cleanLandingKeyword(insight.risingIssues.first.keyword)
      : '';

  if (keyword.isEmpty && rising.isEmpty) {
    return '오늘의 주요 이슈를 분석하고 있습니다. 새로 들어오는 뉴스를 기반으로 핵심 흐름을 정리합니다.';
  }

  if (keyword.isNotEmpty && rising.isNotEmpty) {
    return '$keyword 관련 이슈와 $rising 흐름이 오늘 뉴스의 중심입니다.';
  }

  final base = keyword.isNotEmpty ? keyword : rising;
  return '$base 관련 보도가 오늘 시장과 뉴스 흐름을 이끌고 있습니다.';
}

String _landingRisingIssueLine(TrendInsightSnapshot insight) {
  final issue =
      insight.risingIssues.isNotEmpty ? insight.risingIssues.first : null;
  if (issue == null || issue.keyword.trim().isEmpty) {
    return '뚜렷한 상승 이슈는 아직 제한적입니다.';
  }

  final keyword = _cleanLandingKeyword(issue.keyword);
  final count = issue.currentCount;
  return '$keyword 언급이 빠르게 늘고 있습니다. ($count건)';
}

String _landingFallingIssueLine(TrendInsightSnapshot insight) {
  final weakKeyword = insight.keywords
      .where((item) => (item.sentimentTemperature ?? 50) <= 45)
      .toList()
    ..sort((a, b) {
      final aTemp = a.sentimentTemperature ?? 50;
      final bTemp = b.sentimentTemperature ?? 50;
      return aTemp.compareTo(bTemp);
    });

  if (weakKeyword.isEmpty) {
    return '하락 이슈는 아직 뚜렷하지 않습니다.';
  }

  final item = weakKeyword.first;
  return '${_cleanLandingKeyword(item.keyword)} 관련 뉴스는 상대적으로 약한 흐름입니다.';
}

List<String> _landingMarketImpactLines(TrendInsightSnapshot insight) {
  final lines = <String>[];
  final temp = insight.sentiment.temperature;
  final domestic = temp >= 66
      ? '국내 증시 긍정 흐름'
      : temp <= 40
          ? '국내 증시 경계 흐름'
          : '국내 증시 중립 흐름';
  lines.add(domestic);

  final topKeyword = insight.keywords.isNotEmpty
      ? _cleanLandingKeyword(insight.keywords.first.keyword)
      : '';
  if (topKeyword.contains('반도체') ||
      topKeyword.contains('HBM') ||
      topKeyword.contains('AI')) {
    lines.add('반도체 관심 확대');
  } else if (topKeyword.contains('비트코인') || topKeyword.contains('가상자산')) {
    lines.add('가상자산 변동성 확대');
  } else if (topKeyword.contains('환율') || topKeyword.contains('달러')) {
    lines.add('환율 이슈 주목');
  } else {
    lines.add('업종별 혼조 흐름');
  }

  lines.add(temp >= 66
      ? '환율 부담 낮음'
      : temp <= 40
          ? '환율 변동 주의'
          : '환율 관망');

  return lines;
}

String _landingNewsImportanceLabel(int importance) {
  if (importance >= 5) return '긴급';
  if (importance >= 4) return '주요';
  return '일반';
}

int _landingNewsPriorityRank(TrendItem item) {
  final importance = item.importance;
  if (importance >= 5) return 0;
  if (importance >= 4) return 1;
  return 2;
}

String _landingMarketStageLabel(_LandingMarketQuote quote) {
  final updatedAt = quote.priceUpdatedAt;
  if (updatedAt == null) return '시세 지연';
  final age = DateTime.now().difference(updatedAt);
  if (age.inMinutes > 30) return '시세 지연';

  if (quote.group == 'fx' || quote.group == 'crypto') {
    return '시간외';
  }

  final now = DateTime.now();
  final weekday = now.weekday;
  if (weekday == DateTime.saturday || weekday == DateTime.sunday) {
    return '휴장';
  }

  final minutes = now.hour * 60 + now.minute;
  if (minutes < 8 * 60 + 30) return '개장 전';
  if (minutes >= 9 * 60 && minutes < 15 * 60 + 30) return '장중';
  if (minutes >= 15 * 60 + 30 && minutes < 18 * 60) return '시간외';
  return '장 마감';
}

String _landingMarketStageDetail(_LandingMarketQuote quote) {
  final updatedAt = quote.priceUpdatedAt;
  if (updatedAt == null) return '시세 확인 중';
  final age = DateTime.now().difference(updatedAt);
  if (age.inMinutes > 30) return '30분 이상 지연';
  if (age.inMinutes > 10) return '${age.inMinutes}분 지연';
  return '${_landingFormatUpdatedAt(updatedAt)} 기준';
}

String _cleanLandingKeyword(String keyword) {
  return keyword
      .replaceAll(RegExp(r'[^\w가-힣/+.-]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

bool _isLandingKeywordUseful(String keyword) {
  final value = _cleanLandingKeyword(keyword);
  if (value.length < 2 || value.length > 24) return false;
  if (RegExp(r'^[0-9]+$').hasMatch(value)) return false;

  const blocked = {
    '있다',
    '있는',
    '있습니다',
    '했다',
    '한다',
    '된다',
    '됐다',
    '없다',
    '예정',
    '예정이다',
    '계획',
    '계획이다',
    '위한',
    '위해',
    '통해',
    '따르면',
    '가운데',
    '것으로',
    '것이다',
    '밝혔다',
    '전했다',
    '말했다',
    '문제',
    '시대',
    '상황',
    '경우',
    '부분',
    '내용',
    '결과',
    '과정',
    '수준',
    '기준',
    '대한',
    '관련',
    '오늘',
    '이번',
    '속보',
    '단독',
    '기자',
    '뉴스',
    '보도',
    '사진',
    '영상',
    '그리고',
    '하지만',
  };

  if (blocked.contains(value)) return false;
  if (RegExp(
    r'^[가-힣]+(?:이다|입니다|했다|한다|된다|됐다|있다|없다|나선다|밝혔다|전했다|말했다)$',
  ).hasMatch(value)) {
    return false;
  }

  return true;
}

String _joinKoreanListSafe(List<String> values) {
  final cleanValues =
      values.map(_cleanLandingKeyword).where(_isLandingKeywordUseful).toList();
  if (cleanValues.isEmpty) return '';
  if (cleanValues.length == 1) return cleanValues.first;
  if (cleanValues.length == 2) return '${cleanValues[0]}와 ${cleanValues[1]}';

  return '${cleanValues.take(cleanValues.length - 1).join(', ')}와 ${cleanValues.last}';
}

class _FadeInOnScroll extends StatefulWidget {
  final Widget child;
  final int delay;

  const _FadeInOnScroll({required this.child, this.delay = 0});

  @override
  State<_FadeInOnScroll> createState() => _FadeInOnScrollState();
}

class _FadeInOnScrollState extends State<_FadeInOnScroll>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;
  bool _isAnimated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart),
    );
    _slide =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: ObjectKey(widget),
      onVisibilityChanged: (info) {
        if (info.visibleFraction > 0.1 && !_isAnimated) {
          _isAnimated = true;
          Future.delayed(Duration(milliseconds: widget.delay), () {
            if (mounted) _controller.forward();
          });
        }
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Opacity(
          opacity: _fade.value,
          child: SlideTransition(
            position: _slide,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class _HoverCard extends StatefulWidget {
  final Widget child;
  const _HoverCard({required this.child});

  @override
  State<_HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<_HoverCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _isHovered ? -8 : 0, 0),
        child: widget.child,
      ),
    );
  }
}

class _HoverButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _HoverButton({required this.child, this.onTap});

  @override
  State<_HoverButton> createState() => _HoverButtonState();
}

class _HoverButtonState extends State<_HoverButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _isHovered ? -2 : 0, 0),
          child: widget.child,
        ),
      ),
    );
  }
}

class _LandingMarketConfig {
  final String symbol;
  final String tvSymbol;
  final String title;
  final String prefix;
  final String group;

  const _LandingMarketConfig({
    required this.symbol,
    required this.tvSymbol,
    required this.title,
    required this.prefix,
    required this.group,
  });
}

class _LandingMarketQuote {
  final String symbol;
  final String tvSymbol;
  final String title;
  final String prefix;
  final String group;
  final double currentPrice;
  final double percentChange;
  final DateTime? priceUpdatedAt;
  final List<double> chartData;

  const _LandingMarketQuote({
    required this.symbol,
    required this.tvSymbol,
    required this.title,
    required this.prefix,
    required this.group,
    required this.currentPrice,
    required this.percentChange,
    required this.priceUpdatedAt,
    this.chartData = const [],
  });
}

class _LandingSectorDominanceRowData {
  final String label;
  final List<String> keywords;
  final double ratio;
  final String valueText;
  final String changeText;

  const _LandingSectorDominanceRowData(
    this.label,
    this.keywords, {
    this.ratio = 0,
    this.valueText = '',
    this.changeText = '',
  });

  bool matchesText(String keyword) {
    final lower = keyword.toLowerCase();
    return keywords.any((item) => lower.contains(item.toLowerCase()));
  }
}

class _LandingMarketRankRow extends StatelessWidget {
  final int rank;
  final _LandingMarketQuote quote;

  const _LandingMarketRankRow({
    required this.rank,
    required this.quote,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final up = quote.percentChange >= 0;
    final changeColor = quote.percentChange == 0
        ? (isDark ? Colors.grey.shade300 : Colors.blueGrey.shade500)
        : up
            ? (isDark ? Colors.red.shade300 : Colors.red.shade600)
            : (isDark ? Colors.blue.shade300 : Colors.blue.shade600);
    final surface = isDark ? const Color(0xFF0F172A) : Colors.white;
    final border = isDark ? const Color(0xFF1F2937) : const Color(0xFFE8EEF5);
    final priceTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final muted = isDark ? Colors.grey.shade300 : Colors.blueGrey.shade500;
    final code = _landingFormatStockCode(quote.symbol);
    final naverUrl = _landingNaverFinanceUrl(quote);
    final updatedAt = quote.priceUpdatedAt;
    final ageMinutes = updatedAt == null
        ? null
        : DateTime.now().difference(updatedAt).inMinutes;
    final staleState = ageMinutes == null ? '시세 확인 중' : null;

    return _HoverButton(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 34,
              child: Text(
                rank.toString().padLeft(2, '0'),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  color:
                      isDark ? Colors.grey.shade300 : Colors.blueGrey.shade500,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 11,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quote.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.2,
                      fontWeight: FontWeight.w800,
                      color: priceTextColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    code,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9.8,
                      fontWeight: FontWeight.w600,
                      color: muted,
                    ),
                  ),
                  if (naverUrl != null) ...[
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () => _landingOpenExternalLink(context, naverUrl),
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF172554)
                              : const Color(0xFFEEF4FF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '실시간 시세 보기',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? Colors.blue.shade100
                                : const Color(0xFF2563EB),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: changeColor.withOpacity(isDark ? 0.18 : 0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          fit: FlexFit.loose,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  up
                                      ? Icons.arrow_upward_rounded
                                      : Icons.arrow_downward_rounded,
                                  size: 13,
                                  color: changeColor,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  _landingFormatPercent(quote.percentChange),
                                  style: TextStyle(
                                    fontSize: 10.8,
                                    fontWeight: FontWeight.w800,
                                    color: changeColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '24시간 변동률',
                    style: TextStyle(
                      fontSize: 9.6,
                      fontWeight: FontWeight.w600,
                      color: muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      _landingFormatPrice(
                        quote.currentPrice,
                        marketType: 'kr',
                        symbol: quote.symbol,
                      ),
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: priceTextColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    updatedAt == null
                        ? '시간 확인 중'
                        : '${_landingFormatUpdatedAt(updatedAt)} 기준',
                    style: TextStyle(
                      fontSize: 9.8,
                      fontWeight: FontWeight.w600,
                      color: muted,
                    ),
                  ),
                  if (staleState != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      staleState,
                      style: TextStyle(
                        fontSize: 9.2,
                        fontWeight: FontWeight.w600,
                        color: muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LandingMarketRankPlaceholderRow extends StatelessWidget {
  final int rank;
  final String title;

  const _LandingMarketRankPlaceholderRow({
    required this.rank,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF0F172A) : Colors.white;
    final border = isDark ? const Color(0xFF1F2937) : const Color(0xFFE8EEF5);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final muted = isDark ? Colors.grey.shade300 : Colors.blueGrey.shade500;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 34,
            child: Text(
              rank.toString().padLeft(2, '0'),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.grey.shade300 : Colors.blueGrey.shade500,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.2,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '시세 확인 중',
                  style: TextStyle(
                    fontSize: 9.8,
                    fontWeight: FontWeight.w600,
                    color: muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1F2937) : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '대기',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LandingFooterBrandBlock extends StatelessWidget {
  const _LandingFooterBrandBlock();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final bodyColor = isDark ? Colors.grey.shade400 : Colors.blueGrey.shade600;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(6)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.asset(
              'assets/icon/app_icon.png',
              width: 26,
              height: 26,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pulse',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '뉴스와 시장 흐름을 빠르게 확인합니다.',
              style: TextStyle(
                fontSize: 11.5,
                color: bodyColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LandingHeaderFxStrip extends StatelessWidget {
  final List<_LandingMarketQuote> quotes;

  const _LandingHeaderFxStrip({
    required this.quotes,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? Colors.grey.shade300 : Colors.blueGrey.shade600;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final border = isDark ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB);
    final surface = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            for (int i = 0; i < quotes.take(4).length; i++) ...[
              _LandingHeaderFxItem(quote: quotes[i]),
              if (i != quotes.take(4).length - 1)
                Container(
                  width: 1,
                  height: 18,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  color: border,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LandingHeaderFxInlineBar extends StatelessWidget {
  final List<_LandingMarketQuote> quotes;

  const _LandingHeaderFxInlineBar({
    required this.quotes,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? Colors.grey.shade300 : Colors.blueGrey.shade600;
    final border = isDark ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB);

    String shortLabel(String title) {
      switch (title) {
        case 'USD/KRW':
          return 'USD';
        case 'JPY/KRW':
          return 'JPY';
        case 'EUR/KRW':
          return 'EUR';
        case 'CNY/KRW':
          return 'CNY';
        default:
          return title;
      }
    }

    String shortPrice(_LandingMarketQuote quote) {
      if (quote.title == 'USD/KRW' ||
          quote.title == 'JPY/KRW' ||
          quote.title == 'CNY/KRW') {
        return _landingFormatNumber(quote.currentPrice, decimals: 0);
      }
      if (quote.title == 'EUR/KRW') {
        return _landingFormatNumber(quote.currentPrice, decimals: 0);
      }
      return _landingMarketPriceLabel(quote);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < quotes.take(2).length; i++) ...[
            Builder(
              builder: (context) {
                final quote = quotes[i];
                final changeColor = quote.percentChange == 0
                    ? muted
                    : quote.percentChange > 0
                        ? (isDark ? Colors.red.shade300 : Colors.red.shade600)
                        : (isDark
                            ? Colors.blue.shade300
                            : Colors.blue.shade600);
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      shortLabel(quote.title),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: muted,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      shortPrice(quote),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _landingFormatPercent(quote.percentChange),
                      style: TextStyle(
                        fontSize: 9.8,
                        fontWeight: FontWeight.w800,
                        color: changeColor,
                      ),
                    ),
                  ],
                );
              },
            ),
            if (i != quotes.take(4).length - 1) ...[
              const SizedBox(width: 10),
              Container(
                width: 1,
                height: 12,
                color: border,
              ),
              const SizedBox(width: 10),
            ],
          ],
        ],
      ),
    );
  }
}

class _LandingHeaderFxItem extends StatelessWidget {
  final _LandingMarketQuote quote;

  const _LandingHeaderFxItem({
    required this.quote,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? Colors.grey.shade300 : Colors.blueGrey.shade600;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final changeColor = quote.percentChange == 0
        ? muted
        : quote.percentChange > 0
            ? (isDark ? Colors.red.shade300 : Colors.red.shade600)
            : (isDark ? Colors.blue.shade300 : Colors.blue.shade600);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          quote.title,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: muted,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _landingMarketPriceLabel(quote),
          style: TextStyle(
            fontSize: 11.8,
            fontWeight: FontWeight.w800,
            color: textColor,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _landingFormatPercent(quote.percentChange),
          style: TextStyle(
            fontSize: 10.8,
            fontWeight: FontWeight.w800,
            color: changeColor,
          ),
        ),
      ],
    );
  }
}

class _LandingMarketSummaryCard extends StatelessWidget {
  final _LandingMarketQuote quote;

  const _LandingMarketSummaryCard({
    required this.quote,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final up = quote.percentChange >= 0;
    final accent = up
        ? (isDark ? Colors.red.shade300 : Colors.red.shade600)
        : (isDark ? Colors.blue.shade300 : Colors.blue.shade600);
    final surface = isDark ? const Color(0xFF0F172A) : Colors.white;
    final border = isDark ? const Color(0xFF1F2937) : const Color(0xFFE8EEF5);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final muted = isDark ? Colors.grey.shade300 : Colors.blueGrey.shade500;
    final formattedPrice = _landingMarketPriceLabel(quote);
    final updatedAt = quote.priceUpdatedAt;
    final ageMinutes = updatedAt == null
        ? null
        : DateTime.now().difference(updatedAt).inMinutes;
    final staleState = ageMinutes == null
        ? '시세 확인 중'
        : ageMinutes > 30
            ? '시세 지연 가능'
            : ageMinutes > 10
                ? '시세 지연 가능'
                : null;
    final stageLine = staleState != null
        ? '${_landingMarketStageLabel(quote)} · $staleState'
        : updatedAt != null
            ? '${_landingMarketStageLabel(quote)} · ${_landingFormatUpdatedAt(updatedAt)} 기준'
            : _landingMarketStageLabel(quote);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            quote.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.0,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formattedPrice,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 17.0,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                fit: FlexFit.loose,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        up
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 13,
                        color: accent,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        _landingFormatPercent(quote.percentChange),
                        style: TextStyle(
                          fontSize: 10.8,
                          fontWeight: FontWeight.w800,
                          color: accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            stageLine,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9.4,
              fontWeight: FontWeight.w700,
              color: muted,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 18,
            child: _LandingSparkline(
              values: quote.chartData,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _LandingExchangeRateRow extends StatelessWidget {
  final _LandingMarketQuote quote;

  const _LandingExchangeRateRow({
    required this.quote,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final up = quote.percentChange >= 0;
    final accent = up
        ? (isDark ? Colors.red.shade300 : Colors.red.shade600)
        : (isDark ? Colors.blue.shade300 : Colors.blue.shade600);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final muted = isDark ? Colors.grey.shade300 : Colors.blueGrey.shade500;
    final deltaValue = quote.currentPrice * quote.percentChange / 100;
    final deltaLabel =
        '${deltaValue >= 0 ? '+' : ''}${_landingFormatNumber(deltaValue.abs(), decimals: 2)}원';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quote.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '전일 대비',
                  style: TextStyle(
                    color: muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _landingMarketPriceLabel(quote),
              textAlign: TextAlign.right,
              style: TextStyle(
                color: textColor,
                fontSize: 14.0,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                size: 13,
                color: accent,
              ),
              const SizedBox(width: 3),
              Text(
                _landingFormatPercent(quote.percentChange),
                style: TextStyle(
                  color: accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Text(
            '전일 대비 $deltaLabel',
            style: TextStyle(
              color: muted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            quote.priceUpdatedAt == null
                ? '기준 시각 --:--'
                : '${_landingFormatUpdatedAt(quote.priceUpdatedAt)} 기준',
            style: TextStyle(
              color: muted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LandingDominanceRow extends StatelessWidget {
  final String label;
  final String valueText;
  final String changeText;
  final double ratio;

  const _LandingDominanceRow({
    required this.label,
    required this.valueText,
    required this.changeText,
    required this.ratio,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final muted = isDark ? Colors.grey.shade300 : Colors.blueGrey.shade500;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              valueText,
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              changeText,
              style: TextStyle(
                color: muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 5,
            value: ratio.clamp(0.0, 1.0),
            backgroundColor:
                isDark ? const Color(0xFF1F2937) : const Color(0xFFE8EEF7),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
          ),
        ),
      ],
    );
  }
}

class DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    const double spacing = 30.0;
    const double radius = 1.5;

    for (double y = 0; y < size.height; y += spacing) {
      for (double x = 0; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
