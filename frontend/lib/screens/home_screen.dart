import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui';
import 'dart:async';
import '../models/trend_item.dart';
import '../models/trend_insight.dart';
import '../services/api_service.dart';
import '../services/theme_controller.dart';
import '../theme/pulse_ui.dart';
import '../widgets/app_drawer.dart';
import 'landing_screen.dart';
import 'fear_greed_page.dart';
import 'package:pulse/screens/market_page.dart';

// ?? 遺꾩빞蹂????ㅼ젙 ??????????????????????????????
const List<Map<String, dynamic>> kCategories = [
  {'label': '?꾩껜', 'value': '', 'icon': Icons.dashboard_rounded},
  {'label': '寃쎌젣', 'value': '寃쎌젣', 'icon': Icons.trending_up_rounded},
  {'label': '?멸퀎', 'value': '?멸퀎', 'icon': Icons.public_rounded},
  {'label': '?ы쉶', 'value': '?ы쉶', 'icon': Icons.people_rounded},
  {'label': '?뺤튂', 'value': '?뺤튂', 'icon': Icons.account_balance_rounded},
  {'label': '?앺솢/臾명솕', 'value': '?앺솢/臾명솕', 'icon': Icons.library_books_rounded},
  {'label': 'IT/怨쇳븰', 'value': 'IT/怨쇳븰', 'icon': Icons.computer_rounded},
];

// ?? 移댄뀒怨좊━ ?됱긽 ??????????????????????????????
const Map<String, Color> kCategoryColors = {
  '寃쎌젣': Color(0xFF2563EB),
  '?멸퀎': Color(0xFF2563EB),
  '?ы쉶': Color(0xFF2563EB),
  '?뺤튂': Color(0xFF2563EB),
  '?앺솢/臾명솕': Color(0xFF2563EB),
  'IT/怨쇳븰': Color(0xFF2563EB),
};
const Color kDefaultColor = Color(0xFF2563EB);

Color _catColor(String cat) => kCategoryColors[cat] ?? kDefaultColor;

Color _catColorAlpha(Color c, int alpha) =>
    Color.fromARGB(alpha, c.red, c.green, c.blue);

// ?? 蹂꾩젏 ?꾩젽 (const ?앹꽦 媛?ν븳 ?뺥깭濡?遺꾨━) ??????????????????????
class _StarRow extends StatelessWidget {
  final int importance;
  final double size;
  const _StarRow({required this.importance, this.size = 12});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < 5; i++)
          Icon(
            i < importance ? Icons.star_rounded : Icons.star_outline_rounded,
            size: size,
            color: Colors.amber,
          ),
      ],
    );
  }
}

// ?? ?쒓컙 ?щ㎎ ?좏떥 ??????????????????????????????
String _timeAgo(String isoDate) {
  if (isoDate.isEmpty) return '';
  try {
    final diff = DateTime.now().difference(DateTime.parse(isoDate));
    if (diff.inMinutes < 60) return '${diff.inMinutes}遺???;
    if (diff.inHours < 24) return '${diff.inHours}?쒓컙 ??;
    return '${diff.inDays}????;
  } catch (_) {
    return '';
  }
}

String _publisherLabel(String source) {
  final value = source.trim();
  if (value.isEmpty) return '?몃줎??;

  String slug = '';

  final uri = Uri.tryParse(value);

  if (uri != null && uri.host.isNotEmpty) {
    final host = uri.host.replaceFirst(
      RegExp(r'^www\.', caseSensitive: false),
      '',
    );

    final parts = host.split('.');
    if (parts.isNotEmpty) {
      slug = parts.first.trim();
    }
  } else {
    final cleaned = value
        .replaceFirst(
          RegExp(r'^https?://', caseSensitive: false),
          '',
        )
        .replaceFirst(
          RegExp(r'^www\.', caseSensitive: false),
          '',
        )
        .split('/')
        .first
        .trim();

    if (cleaned.isNotEmpty) {
      slug = cleaned.contains('.') ? cleaned.split('.').first : cleaned;
    }
  }

  if (slug.isEmpty) return '?몃줎??;

  const aliases = {
    'fourfourtwo': '?뗫낵',
    'ajunews': '?꾩＜寃쎌젣',
    'etoday': '?댄닾?곗씠',
    'sisajournal': '?쒖궗???,
    'busan': '遺?곗씪蹂?,
    'mediapen': '誘몃뵒?댄렂',
    'newsj': '?댁뒪??,
    'pinpoinnews': '??ъ씤?몃돱??,
    'itoza': '?댄넗利?,
    'edaily': '?대뜲?쇰━',
    'yna': '?고빀?댁뒪',
    'mk': '留ㅼ씪寃쎌젣',
    'hankyung': '?쒓뎅寃쎌젣',
    'sedaily': '?쒖슱寃쎌젣',
    'chosun': '議곗꽑?쇰낫',
    'joongang': '以묒븰?쇰낫',
    'donga': '?숈븘?쇰낫',
    'khan': '寃쏀뼢?좊Ц',
    'huffingtonpost': '?덊봽?ъ뒪??,
    'fnnews': '?뚯씠?몄뀥?댁뒪',
    'heraldcorp': '?ㅻ윺?쒓꼍??,
    'bizwatch': '鍮꾩쫰?뚯튂',
    'mt': '癒몃땲?щ뜲??,
    'moneytoday': '癒몃땲?щ뜲??,
    'newsis': '?댁떆??,
  };

  return aliases[slug.toLowerCase()] ?? slug;
}

String _sourceDisplayName(TrendItem trend) {
  final source = trend.source.trim();
  if (source.isEmpty) return '?몃줎??;
  return _publisherLabel(source);
}

// ?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧
// HomeScreen
// ?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧
DateTime? _trendDate(TrendItem trend) {
  return DateTime.tryParse(trend.published) ??
      DateTime.tryParse(trend.createdAt);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabController;
  Timer? _autoRefreshTimer;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late String _headerTime;
  Timer? _clockTimer;
  late Future<List<TrendItem>> _featuredFuture;
  late Future<TrendInsightSnapshot> _insightFuture;
  final TextEditingController _searchController = TextEditingController();
  final List<String> _recentSearches = [];
  bool _isFeaturedExpanded = true;
  bool _isTrendInsightExpanded = false;

  /// 5遺꾨쭏??媛?_TrendList???덈줈怨좎묠 ?좏샇瑜?蹂대궡??notifier
  final ValueNotifier<DateTime> _refreshNotifier =
      ValueNotifier(DateTime.now());

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: kCategories.length, vsync: this);
    _headerTime = DateFormat('HH:mm').format(DateTime.now());
    _featuredFuture = _loadFeaturedNews();
    _insightFuture = _api.fetchTrendInsights();

    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {
          _headerTime = DateFormat('HH:mm').format(DateTime.now());
        });
      }
    });

    // 5遺꾨쭏??notifier瑜?媛깆떊 ??紐⑤뱺 ??씠 API ?ы샇異?
    _autoRefreshTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) {
        _refreshNotifier.value = DateTime.now();
        if (mounted) {
          setState(() {
            _featuredFuture = _loadFeaturedNews();
            _insightFuture = _api.fetchTrendInsights();
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _clockTimer?.cancel();
    _autoRefreshTimer?.cancel();
    _searchController.dispose();
    _refreshNotifier.dispose();
    super.dispose();
  }

  void _toggleFeaturedNews() {
    setState(() {
      _isFeaturedExpanded = !_isFeaturedExpanded;
    });
  }

  Future<List<TrendItem>> _loadFeaturedNews() async {
    try {
      final trends = await _api.fetchTrends(
        limit: 30,
        offset: 0,
        sort: 'featured',
        period: '24h',
      );
      final featured = trends.where((trend) => trend.importance >= 4).toList();
      final source = featured.isNotEmpty ? featured : trends;
      source.sort((a, b) {
        final importanceCompare = b.importance.compareTo(a.importance);
        if (importanceCompare != 0) return importanceCompare;
        final aDate = _trendDate(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = _trendDate(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
      return source.take(5).toList();
    } catch (_) {
      return const [];
    }
  }

  void _openTrendDetail(TrendItem trend) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (_) => _DetailSheet(trend: trend),
    );
  }

  void _showGroupedNewsSheet({
    required String title,
    required List<TrendItem> items,
    TrendItem? anchor,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final surface =
            isDark ? const Color(0xFF111827) : const Color(0xFFF8FBFF);
        final border =
            isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);
        final primaryText = isDark ? Colors.white : const Color(0xFF0F172A);
        final secondaryText =
            isDark ? Colors.grey.shade400 : Colors.blueGrey.shade500;

        return DraggableScrollableSheet(
          initialChildSize: 0.82,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          builder: (_, controller) {
            return ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              child: ColoredBox(
                color: surface,
                child: SafeArea(
                  top: false,
                  child: FutureBuilder<List<TrendItem>>(
                    future: _resolveGroupedNewsItems(
                      seedItems: items,
                      anchor: anchor,
                    ),
                    builder: (context, snapshot) {
                      final resolvedItems =
                          snapshot.data ?? const <TrendItem>[];
                      final orderedItems = resolvedItems.toList()
                        ..sort((a, b) {
                          final aDate = _trendDate(a) ??
                              DateTime.fromMillisecondsSinceEpoch(0);
                          final bDate = _trendDate(b) ??
                              DateTime.fromMillisecondsSinceEpoch(0);
                          return bDate.compareTo(aDate);
                        });

                      return ListView(
                        controller: controller,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        children: [
                          Center(
                            child: Container(
                              width: 42,
                              height: 4,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.grey.shade700
                                    : Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: primaryText,
                            ),
                          ),
                          const SizedBox(height: 14),
                          if (snapshot.connectionState ==
                              ConnectionState.waiting)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 80),
                              child: Center(
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)),
                            )
                          else if (orderedItems.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 80),
                              child: Center(
                                child: Text(
                                  '愿???댁뒪媛 ?놁뒿?덈떎.',
                                  style: TextStyle(color: secondaryText),
                                ),
                              ),
                            )
                          else
                            for (int i = 0; i < orderedItems.length; i++)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _TrendCard(
                                  key: ValueKey(
                                      'cluster-${orderedItems[i].id}-$i'),
                                  rank: i + 1,
                                  trend: orderedItems[i],
                                ),
                              ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<List<TrendItem>> _resolveGroupedNewsItems({
    required List<TrendItem> seedItems,
    TrendItem? anchor,
  }) async {
    final merged = <String, TrendItem>{};
    for (final item in seedItems) {
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

  void _openKeywordNews(String keyword) {
    _showNewsResultsSheet(
      title: '#$keyword 愿???댁뒪',
      future: _api
          .fetchNewsByKeyword(keyword: keyword)
          .then((result) => result.items),
    );
  }

  void _submitSearch() {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _recentSearches.remove(query);
      _recentSearches.insert(0, query);
      if (_recentSearches.length > 6) {
        _recentSearches.removeLast();
      }
    });

    _showNewsResultsSheet(
      title: '"$query" 寃??寃곌낵',
      future: _api.searchNews(query: query, sort: 'relevance'),
    );
  }

  void _searchKeyword(String keyword) {
    _searchController.text = keyword;
    _submitSearch();
  }

  void _showNewsResultsSheet({
    required String title,
    required Future<List<TrendItem>> future,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final surface =
            isDark ? const Color(0xFF111827) : const Color(0xFFF8FBFF);
        final border =
            isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);
        final primaryText = isDark ? Colors.white : const Color(0xFF0F172A);
        final secondaryText =
            isDark ? Colors.grey.shade400 : Colors.blueGrey.shade500;

        return DraggableScrollableSheet(
          initialChildSize: 0.82,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          builder: (_, controller) {
            return ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              child: ColoredBox(
                color: surface,
                child: SafeArea(
                  top: false,
                  child: FutureBuilder<List<TrendItem>>(
                    future: future,
                    builder: (context, snapshot) {
                      final items = snapshot.data ?? const <TrendItem>[];
                      final orderedItems = items.toList()
                        ..sort((a, b) {
                          final aDate = _trendDate(a) ??
                              DateTime.fromMillisecondsSinceEpoch(0);
                          final bDate = _trendDate(b) ??
                              DateTime.fromMillisecondsSinceEpoch(0);
                          return bDate.compareTo(aDate);
                        });
                      final isLoading =
                          snapshot.connectionState == ConnectionState.waiting;

                      return ListView(
                        controller: controller,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        children: [
                          Center(
                            child: Container(
                              width: 42,
                              height: 4,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.grey.shade700
                                    : Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: primaryText,
                            ),
                          ),
                          const SizedBox(height: 14),
                          if (isLoading)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 80),
                              child: Center(
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          else if (orderedItems.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 80),
                              child: Center(
                                child: Text(
                                  '愿???댁뒪媛 ?놁뒿?덈떎.',
                                  style: TextStyle(color: secondaryText),
                                ),
                              ),
                            )
                          else
                            for (int i = 0; i < orderedItems.length; i++)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _TrendCard(
                                  key: ValueKey(
                                      'keyword-${orderedItems[i].id}-$i'),
                                  rank: i + 1,
                                  trend: orderedItems[i],
                                ),
                              ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTrendInsightSection() {
    return FutureBuilder<TrendInsightSnapshot>(
      future: _insightFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: _InsightSkeleton(),
          );
        }

        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final insight = snapshot.data!;
        final topKeywords = insight.keywords;
        final rising = insight.risingIssues;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final surface = isDark ? const Color(0xFF111827) : Colors.white;
        final border =
            isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);
        final primaryText = Theme.of(context).colorScheme.onSurface;
        final secondaryText =
            isDark ? Colors.grey.shade400 : Colors.grey.shade700;
        final topLine = topKeywords.isEmpty
            ? '?ㅻ뒛 ???댁뒋瑜??섏쭛?섍퀬 ?덉뼱??'
            : '吏湲?${topKeywords.take(3).map((e) => e.keyword).join(', ')} ?댁뒋媛 留롮씠 ?멸툒?섍퀬 ?덉뼱??';

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: border),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withOpacity(0.22)
                        : Colors.black.withOpacity(0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isCompact = constraints.maxWidth < 560;
                        final actionRow = Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _isTrendInsightExpanded =
                                      !_isTrendInsightExpanded;
                                });
                              },
                              style: TextButton.styleFrom(
                                minimumSize: Size.zero,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                foregroundColor: isDark
                                    ? Colors.blue.shade200
                                    : Colors.blue.shade700,
                              ),
                              child: Text(
                                _isTrendInsightExpanded ? '?묎린' : '?붾낫湲?,
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w800),
                              ),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              tooltip: '?덈줈怨좎묠',
                              onPressed: () {
                                setState(() {
                                  _insightFuture = _api.fetchTrendInsights();
                                });
                              },
                              icon: Icon(
                                Icons.refresh_rounded,
                                size: 20,
                                color: secondaryText,
                              ),
                            ),
                          ],
                        );

                        if (isCompact) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF172554)
                                          : const Color(0xFFEAF1FF),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.radar_rounded,
                                      color: isDark
                                          ? Colors.blue.shade200
                                          : Colors.blue.shade700,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '?ㅻ뒛????以??몃젋??,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: primaryText,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: actionRow,
                              ),
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF172554)
                                    : const Color(0xFFEAF1FF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.radar_rounded,
                                color: isDark
                                    ? Colors.blue.shade200
                                    : Colors.blue.shade700,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '?ㅻ뒛????以??몃젋??,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: primaryText,
                                ),
                              ),
                            ),
                            actionRow,
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      topLine,
                      maxLines: _isTrendInsightExpanded ? 4 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: secondaryText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _SentimentTemperatureCard(sentiment: insight.sentiment),
                    const SizedBox(height: 10),
                    _TrendSearchBar(
                      controller: _searchController,
                      onSubmitted: (_) => _submitSearch(),
                      onSearch: _submitSearch,
                    ),
                    if (_isTrendInsightExpanded) ...[
                      const SizedBox(height: 12),
                      _InsightSectionTitle(
                        icon: Icons.local_fire_department_rounded,
                        title: '?ㅼ떆媛??멸린 ?ㅼ썙???곸쐞 10',
                        trailing: '${topKeywords.length}媛?,
                      ),
                      const SizedBox(height: 8),
                      if (topKeywords.isEmpty)
                        const _InsightEmpty(message: '?꾩쭅 吏묎퀎???ㅼ썙?쒓? ?놁뒿?덈떎.')
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final keyword in topKeywords)
                              _KeywordChip(
                                keyword: keyword,
                                onTap: () => _openKeywordNews(keyword.keyword),
                              ),
                          ],
                        ),
                      const SizedBox(height: 12),
                      _InsightSectionTitle(
                        icon: Icons.trending_up_rounded,
                        title: '湲됱긽???댁뒋 ?곸쐞 5',
                        trailing: '理쒓렐 1?쒓컙',
                      ),
                      const SizedBox(height: 8),
                      if (rising.isEmpty)
                        const _CompactEmptyRow(message: '湲됱긽??議곌굔??留뚯”???댁뒋媛 ?놁뒿?덈떎.')
                      else
                        Column(
                          children: [
                            for (int i = 0; i < rising.length; i++)
                              _RisingIssueTile(
                                issue: rising[i],
                                rank: i + 1,
                                onTap: () =>
                                    _openKeywordNews(rising[i].keyword),
                              ),
                          ],
                        ),
                    ] else ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '?붾낫湲곕? ?꾨Ⅴ硫??멸린 ?ㅼ썙?쒖? 湲됱긽???댁뒋瑜??뺤씤?????덉뒿?덈떎.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNewsSearchHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF111827) : Colors.white;
    final border = isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);
    final primaryText = isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryText =
        isDark ? Colors.grey.shade300 : Colors.blueGrey.shade500;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.22)
                  : Colors.black.withOpacity(0.025),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(13),
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
                      Icons.search_rounded,
                      size: 17,
                      color:
                          isDark ? Colors.blue.shade200 : Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '?댁뒪 寃??,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: primaryText,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _TrendSearchBar(
                controller: _searchController,
                onSubmitted: (_) => _submitSearch(),
                onSearch: _submitSearch,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAllNewsHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryText =
        isDark ? Colors.grey.shade400 : Colors.blueGrey.shade500;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF172554) : const Color(0xFFEEF4FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.view_list_rounded,
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
                  '?꾩껜 ?댁뒪',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: primaryText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '理쒖떊?쒖쑝濡??꾩껜 湲곗궗瑜??댁뼱???뺤씤?⑸땲??',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: secondaryText,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendInsightPlatformSection() {
    return FutureBuilder<TrendInsightSnapshot>(
      future: _insightFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: _InsightSkeleton(),
          );
        }

        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final insight = snapshot.data!;
        final keywords = insight.keywords;
        final rising = insight.risingIssues;
        final trendScore = _calculateTrendScore(insight);
        final trendDelta = _calculateTrendDelta(insight);
        final briefing = _buildAiBriefing(insight);
        final categoryKeywords = _buildCategoryHotKeywords(keywords);

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AiBriefingCard(
                briefing: briefing,
                keywords: keywords.take(4).toList(),
                updatedAt: _headerTime,
                onRefresh: () {
                  setState(() {
                    _insightFuture = _api.fetchTrendInsights();
                    _featuredFuture = _loadFeaturedNews();
                  });
                },
                onKeywordTap: (keyword) => _openKeywordNews(keyword.keyword),
              ),
              const SizedBox(height: 14),
              _TrendDashboardCard(
                trendScore: trendScore,
                trendDelta: trendDelta,
                sentiment: insight.sentiment,
              ),
              const SizedBox(height: 14),
              _SearchDiscoverySection(
                controller: _searchController,
                popularKeywords: keywords.take(6).toList(),
                recentSearches: _recentSearches,
                onSearch: _submitSearch,
                onKeywordTap: _searchKeyword,
              ),
              const SizedBox(height: 16),
              _InsightSectionTitle(
                icon: Icons.local_fire_department_rounded,
                title: '?ㅼ떆媛??멸린 ?ㅼ썙???곸쐞 10',
                trailing: '愿???댁뒪 湲곗?',
              ),
              const SizedBox(height: 10),
              if (keywords.isEmpty)
                const _InsightEmpty(message: '?꾩쭅 吏묎퀎???ㅼ썙?쒓? ?놁뒿?덈떎.')
              else
                Column(
                  children: [
                    for (int i = 0; i < keywords.take(10).length; i++)
                      _KeywordRankTile(
                        keyword: keywords[i],
                        rank: i + 1,
                        rankBadge: _rankBadgeFor(i),
                        onTap: () => _openKeywordNews(keywords[i].keyword),
                      ),
                  ],
                ),
              const SizedBox(height: 18),
              _InsightSectionTitle(
                icon: Icons.trending_up_rounded,
                title: '湲됱긽???댁뒋 ?곸쐞 5',
                trailing: '理쒓렐 1?쒓컙',
              ),
              const SizedBox(height: 10),
              if (rising.isEmpty)
                const _InsightEmpty(message: '湲됱긽??議곌굔??留뚯”???댁뒋媛 ?놁뒿?덈떎.')
              else
                Column(
                  children: [
                    for (int i = 0; i < rising.length; i++)
                      _RisingIssueTile(
                        issue: rising[i],
                        rank: i + 1,
                        onTap: () => _openKeywordNews(rising[i].keyword),
                      ),
                  ],
                ),
              const SizedBox(height: 18),
              _CategoryHotTrendSection(
                categoryKeywords: categoryKeywords,
                onKeywordTap: _openKeywordNews,
              ),
              const SizedBox(height: 16),
              _SentimentInsightPanel(sentiment: insight.sentiment),
            ],
          ),
        );
      },
    );
  }

  int _calculateTrendScore(TrendInsightSnapshot insight) {
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

    final keywordScore = _trendRatioScale(keywordCount, 130);
    final risingScore = _trendRatioScale(risingCount, 90);
    final sentimentScore =
        1.0 - ((insight.sentiment.temperature - 50).abs() / 50).clamp(0, 1);

    final mixed =
        keywordScore * 0.43 + risingScore * 0.37 + sentimentScore * 0.20;
    return (12 + mixed * 76).round().clamp(0, 100);
  }

  int _calculateTrendDelta(TrendInsightSnapshot insight) {
    if (insight.risingIssues.isEmpty) return 0;
    final averageGrowth = insight.risingIssues
            .map((issue) => issue.growthRate)
            .reduce((a, b) => a + b) /
        insight.risingIssues.length;

    return (averageGrowth / 25).round().clamp(-20, 40);
  }

  double _trendRatioScale(int value, int cap) {
    if (cap <= 0 || value <= 0) return 0;
    return (value / (value + cap)).clamp(0.0, 1.0);
  }

  String _buildAiBriefing(TrendInsightSnapshot insight) {
    final keywords = insight.keywords.take(3).map((e) => e.keyword).toList();
    final rising = insight.risingIssues.take(2).map((e) => e.keyword).toList();

    if (keywords.isEmpty && rising.isEmpty) {
      return 'AI媛 ?ㅻ뒛??二쇱슂 ?댁뒋瑜??섏쭛?섍퀬 ?덉뒿?덈떎.\n???댁뒪媛 ?볦씠硫??듭떖 ?ㅼ썙?쒖? 遺꾩쐞湲곕? ?먮룞?쇰줈 ?붿빟?⑸땲??';
    }

    final keywordText = keywords.isEmpty ? '?덈줈???댁뒪' : keywords.join(', ');
    final risingText = rising.isEmpty
        ? '?쒕졆??湲됱긽???댁뒋???꾩쭅 ?놁뒿?덈떎'
        : '${rising.join(', ')} 愿???댁뒪媛 鍮좊Ⅴ寃??섍퀬 ?덉뒿?덈떎';
    final mood = insight.sentiment.temperature >= 71
        ? '湲곕?媛먯씠 ?곗꽭?⑸땲??
        : insight.sentiment.temperature <= 30
            ? '遺덉븞媛먯씠 ?쎈땲??
            : '以묐┰?곸씤 ?먮쫫?낅땲??;

    return '?ㅻ뒛? $keywordText ?댁뒋媛 留롮씠 ?멸툒?섍퀬 ?덉뒿?덈떎.\n$risingText.\n?꾩껜 ?댁뒪 遺꾩쐞湲곕뒗 $mood.';
  }

  Map<String, List<TrendKeyword>> _buildCategoryHotKeywords(
      List<TrendKeyword> keywords) {
    const categories = ['?뺤튂', '寃쎌젣', 'IT/怨쇳븰', '?ы쉶', '?멸퀎', '?앺솢/臾명솕'];
    final result = <String, List<TrendKeyword>>{};

    for (final category in categories) {
      result[category] =
          keywords.where((item) => item.category == category).take(5).toList();
    }

    return result;
  }

  String _rankBadgeFor(int index) {
    switch (index) {
      case 0:
        return 'NEW';
      case 1:
        return '??';
      case 2:
        return '??';
      case 3:
        return '??';
      default:
        return index.isEven ? '??' : '-';
    }
  }

  Widget _buildFeaturedNewsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF111827)
              : const Color(0xFFF7FBFF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1F2937)
                : const Color(0xFFDDE9FF),
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.black.withOpacity(0.24)
                  : const Color(0xFF2563EB).withOpacity(0.05),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: FutureBuilder<List<TrendItem>>(
            future: _featuredFuture,
            builder: (context, snapshot) {
              final isLoading =
                  snapshot.connectionState == ConnectionState.waiting;
              final items = snapshot.data ?? const <TrendItem>[];

              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                child: Column(
                  key: ValueKey(
                    '${_isFeaturedExpanded ? 'expanded' : 'collapsed'}-${isLoading ? 'loading' : items.length}',
                  ),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: _toggleFeaturedNews,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? const Color(0xFF172554)
                                    : const Color(0xFFDDE9FF),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.auto_awesome_rounded,
                                size: 17,
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.blue.shade200
                                    : Colors.blue.shade700,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '?ㅻ뒛??二쇱슂 ?댁뒪',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                            if (!isLoading)
                              Text(
                                '${items.length}嫄?,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.grey.shade400
                                      : Colors.blueGrey.shade700,
                                ),
                              ),
                            const SizedBox(width: 8),
                            Icon(
                              _isFeaturedExpanded
                                  ? Icons.expand_less_rounded
                                  : Icons.expand_more_rounded,
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.grey.shade400
                                  : Colors.blueGrey.shade600,
                            ),
                          ],
                        ),
                      ),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeInOut,
                      child: _isFeaturedExpanded
                          ? Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: isLoading
                                  ? const SizedBox(
                                      height: 104,
                                      child: Center(
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      ),
                                    )
                                  : (items.isEmpty
                                      ? SizedBox(
                                          height: 96,
                                          child: Center(
                                            child: Text(
                                              '?꾩쭅 ?ㅻ뒛??二쇱슂 ?댁뒪媛 ?놁뒿?덈떎.',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Theme.of(context)
                                                            .brightness ==
                                                        Brightness.dark
                                                    ? Colors.grey.shade400
                                                    : Colors.grey.shade500,
                                              ),
                                            ),
                                          ),
                                        )
                                      : LayoutBuilder(
                                          builder: (context, constraints) {
                                            final cardWidth = items.length <= 1
                                                ? constraints.maxWidth
                                                : ((constraints.maxWidth -
                                                            (12 *
                                                                (items.length -
                                                                    1))) /
                                                        items.length)
                                                    .clamp(212.0, 276.0)
                                                    .toDouble();
                                            return SizedBox(
                                              height: 178,
                                              child: ListView.separated(
                                                scrollDirection:
                                                    Axis.horizontal,
                                                physics:
                                                    const BouncingScrollPhysics(),
                                                itemCount: items.length,
                                                separatorBuilder: (_, __) =>
                                                    const SizedBox(width: 12),
                                                itemBuilder: (context, index) {
                                                  final trend = items[index];
                                                  return _MajorNewsCard(
                                                    trend: trend,
                                                    index: index,
                                                    width: cardWidth,
                                                    height: index == 0
                                                        ? 184.0
                                                        : 176.0,
                                                    onTap: () =>
                                                        _openTrendDetail(trend),
                                                  );
                                                },
                                              ),
                                            );
                                          },
                                        )),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final pageBackground = PulseUi.page(context);
    final headerBackground = PulseUi.surface(context);
    final headerBorder = PulseUi.border(context);
    // The news feed is a browsing surface, so it should use the available
    // viewport width. Individual rows already provide their own safe padding.
    final contentMaxWidth = viewportWidth;
    final showHeaderTime = viewportWidth >= 460;
    final showAnalysisStatus = viewportWidth >= 760;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: pageBackground,
      drawer: AppDrawer(
        currentSection: DrawerSection.news,
        homeBuilder: (context) => LandingScreen(),
        newsBuilder: (context) => HomeScreen(),
        fearGreedBuilder: (context) => FearGreedPage(),
        marketBuilder: (context) => MarketPage(),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentMaxWidth),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 12, 10),
                  decoration: BoxDecoration(
                    color: headerBackground,
                    border: Border(
                      bottom: BorderSide(color: headerBorder),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.menu_rounded,
                          size: 24,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        onPressed: () =>
                            _scaffoldKey.currentState?.openDrawer(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '?ㅼ떆媛??댁뒪',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (showHeaderTime) ...[
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF111827)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: isDark
                                  ? Colors.grey.shade800
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Text(
                            _headerTime,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.grey.shade300
                                  : Colors.blueGrey.shade700,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      IconButton(
                        tooltip: isDark ? '?쇱씠??紐⑤뱶' : '?ㅽ겕 紐⑤뱶',
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
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      if (showAnalysisStatus) ...[
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF172554)
                                : const Color(0xFFEEF4FF),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: isDark
                                  ? Colors.grey.shade800
                                  : const Color(0xFFDCE7FF),
                            ),
                          ),
                          child: Row(
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
                                '理쒓렐 24?쒓컙 遺꾩꽍',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.blue.shade200
                                      : Colors.blue.shade700,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentMaxWidth),
                child: Container(
                  color: headerBackground,
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor:
                        isDark ? Colors.blue.shade200 : Colors.blue.shade700,
                    unselectedLabelColor:
                        isDark ? Colors.grey.shade400 : const Color(0xFF475569),
                    indicator: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF172554)
                          : const Color(0xFFEAF1FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark
                            ? Colors.grey.shade800
                            : const Color(0xFFDCE7FF),
                      ),
                    ),
                    indicatorPadding: EdgeInsets.zero,
                    labelPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    labelStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                    dividerColor:
                        isDark ? Colors.grey.shade800 : const Color(0xFFE2E8F0),
                    tabs: [
                      for (final cat in kCategories)
                        Tab(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(cat['label'] as String),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentMaxWidth),
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      for (final cat in kCategories)
                        _TrendList(
                          key: ValueKey(cat['value']),
                          category: cat['value'] as String,
                          categoryLabel: cat['label'] as String,
                          refreshNotifier: _refreshNotifier,
                          headerBuilder: cat['value'] == ''
                              ? () => [
                                    _buildTrendInsightSection(),
                                    _buildFeaturedNewsSection(),
                                    _buildAllNewsHeader(),
                                  ]
                              : null,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeBackdrop extends StatelessWidget {
  const _HomeBackdrop();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IgnorePointer(
      child: SizedBox.expand(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0B1220) : const Color(0xFFF8FAFC),
          ),
          child: const CustomPaint(
            painter: _HomeGridPainter(),
          ),
        ),
      ),
    );
  }
}

class _InsightSkeleton extends StatelessWidget {
  const _InsightSkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 186,
      decoration: BoxDecoration(
        color:
            isDark ? const Color(0xFF111827) : Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: isDark ? const Color(0xFF1F2937) : Colors.blue.shade50),
      ),
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

class _InsightSectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String trailing;

  const _InsightSectionTitle({
    required this.icon,
    required this.title,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = Theme.of(context).colorScheme.onSurface;
    final secondaryText = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    return Row(
      children: [
        Icon(icon,
            size: 17,
            color: isDark ? Colors.blue.shade200 : Colors.blue.shade700),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: primaryText,
            ),
          ),
        ),
        Text(
          trailing,
          style: TextStyle(
            fontSize: 12,
            color: secondaryText,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _AiBriefingCard extends StatelessWidget {
  final String briefing;
  final List<TrendKeyword> keywords;
  final String updatedAt;
  final VoidCallback onRefresh;
  final ValueChanged<TrendKeyword> onKeywordTap;

  const _AiBriefingCard({
    required this.briefing,
    required this.keywords,
    required this.updatedAt,
    required this.onRefresh,
    required this.onKeywordTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF111827) : Colors.white;
    final border = isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);
    final titleText = Theme.of(context).colorScheme.onSurface;
    final bodyText = isDark ? Colors.grey.shade300 : Colors.blueGrey.shade800;
    final mutedText = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, 0, 0),
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.28)
                  : Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 6),
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
                    color: isDark
                        ? const Color(0xFF172554)
                        : const Color(0xFFEEF4FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Color(0xFF2563EB),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'AI 釉뚮━??,
                    style: TextStyle(
                      color: titleText,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 13,
                      color: mutedText,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '留덉?留??낅뜲?댄듃 $updatedAt',
                      style: TextStyle(
                        color: mutedText,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  tooltip: '?덈줈怨좎묠',
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded,
                      color: Color(0xFF2563EB), size: 19),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              briefing,
              style: TextStyle(
                color: bodyText,
                fontSize: 14,
                height: 1.55,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (keywords.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final keyword in keywords)
                    ActionChip(
                      label: Text('#${keyword.keyword}'),
                      onPressed: () => onKeywordTap(keyword),
                      backgroundColor: isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF3F7FF),
                      side: BorderSide(
                          color: isDark
                              ? const Color(0xFF1F2937)
                              : const Color(0xFFDCE7FF)),
                      labelStyle: TextStyle(
                        color: isDark
                            ? const Color(0xFF93C5FD)
                            : const Color(0xFF2563EB),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TrendDashboardCard extends StatelessWidget {
  final int trendScore;
  final int trendDelta;
  final NewsSentimentSummary sentiment;

  const _TrendDashboardCard({
    required this.trendScore,
    required this.trendDelta,
    required this.sentiment,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC);
    final border = isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);
    final primaryText = Theme.of(context).colorScheme.onSurface;
    final secondaryText = isDark ? Colors.grey.shade400 : Colors.grey.shade700;
    final deltaColor =
        trendDelta >= 0 ? const Color(0xFF2563EB) : Colors.blueGrey;
    final deltaText = trendDelta >= 0 ? '+$trendDelta' : '$trendDelta';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.24)
                : Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '?몃젋????쒕낫??,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: primaryText),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: deltaColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '?꾩씪 ?鍮?$deltaText',
                  style: TextStyle(
                    color: deltaColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _DashboardMetricCard(
                  label: '?ㅻ뒛???몃젋???먯닔',
                  value: '$trendScore',
                  suffix: '/100',
                  icon: Icons.speed_rounded,
                  color: const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DashboardMetricCard(
                  label: '?댁뒪 媛먯젙?⑤룄',
                  value: '${sentiment.temperature}',
                  suffix: '째',
                  icon: Icons.thermostat_rounded,
                  color: sentiment.temperature >= 71
                      ? const Color(0xFF16A34A)
                      : sentiment.temperature <= 30
                          ? const Color(0xFFDC2626)
                          : Colors.blueGrey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SentimentRatioBar(sentiment: sentiment),
        ],
      ),
    );
  }
}

class _DashboardMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String suffix;
  final IconData icon;
  final Color color;

  const _DashboardMetricCard({
    required this.label,
    required this.value,
    required this.suffix,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final border = isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);
    final primaryText = Theme.of(context).colorScheme.onSurface;
    final secondaryText = isDark ? Colors.grey.shade400 : Colors.grey.shade700;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 9),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              color: secondaryText,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              text: value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : color,
              ),
              children: [
                TextSpan(
                  text: suffix,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: color.withOpacity(0.75),
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

class _SearchDiscoverySection extends StatelessWidget {
  final TextEditingController controller;
  final List<TrendKeyword> popularKeywords;
  final List<String> recentSearches;
  final VoidCallback onSearch;
  final ValueChanged<String> onKeywordTap;

  const _SearchDiscoverySection({
    required this.controller,
    required this.popularKeywords,
    required this.recentSearches,
    required this.onSearch,
    required this.onKeywordTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF111827) : Colors.white;
    final border = isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TrendSearchBar(
            controller: controller,
            onSubmitted: (_) => onSearch(),
            onSearch: onSearch,
          ),
          const SizedBox(height: 10),
          _DiscoveryChipRow(
            title: '?멸린 寃?됱뼱',
            chips: popularKeywords.map((item) => item.keyword).toList(),
            onTap: onKeywordTap,
          ),
          if (recentSearches.isNotEmpty) ...[
            const SizedBox(height: 8),
            _DiscoveryChipRow(
              title: '理쒓렐 寃?됱뼱',
              chips: recentSearches,
              onTap: onKeywordTap,
            ),
          ],
        ],
      ),
    );
  }
}

class _DiscoveryChipRow extends StatelessWidget {
  final String title;
  final List<String> chips;
  final ValueChanged<String> onTap;

  const _DiscoveryChipRow({
    required this.title,
    required this.chips,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = Theme.of(context).colorScheme.onSurface;
    final secondaryText = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    if (chips.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 11.5,
            color: secondaryText,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final chip in chips)
              ActionChip(
                label: Text(chip),
                onPressed: () => onTap(chip),
                backgroundColor:
                    isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                side: BorderSide(
                    color: isDark
                        ? const Color(0xFF1F2937)
                        : const Color(0xFFE2E8F0)),
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: primaryText,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _KeywordRankTile extends StatelessWidget {
  final TrendKeyword keyword;
  final int rank;
  final String rankBadge;
  final VoidCallback onTap;

  const _KeywordRankTile({
    required this.keyword,
    required this.rank,
    required this.rankBadge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = _catColor(keyword.category);
    final isNew = rankBadge == 'NEW';
    final isDown = rankBadge.startsWith('??);
    final isTop3 = rank <= 3;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          hoverColor: const Color(0xFF2563EB).withOpacity(0.025),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color:
                    isTop3 ? const Color(0xFFDCE7FF) : const Color(0xFFE2E8F0),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isTop3 ? 0.045 : 0.025),
                  blurRadius: isTop3 ? 14 : 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Center(
                    child: Text(
                      '$rank',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        keyword.keyword,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${keyword.category} 쨌 愿???댁뒪 ${keyword.newsCount}嫄?,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: isNew
                        ? Colors.indigo.withOpacity(0.1)
                        : isDown
                            ? Colors.blue.withOpacity(0.08)
                            : Colors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    rankBadge,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: isNew
                          ? Colors.indigo
                          : isDown
                              ? Colors.blue
                              : Colors.red,
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

class _CategoryHotTrendSection extends StatelessWidget {
  final Map<String, List<TrendKeyword>> categoryKeywords;
  final ValueChanged<String> onKeywordTap;

  const _CategoryHotTrendSection({
    required this.categoryKeywords,
    required this.onKeywordTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InsightSectionTitle(
          icon: Icons.category_rounded,
          title: '移댄뀒怨좊━蹂?HOT ?몃젋??,
          trailing: '?뺤튂 쨌 寃쎌젣 쨌 IT 쨌 ?ы쉶',
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 156,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: categoryKeywords.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final entry = categoryKeywords.entries.elementAt(index);
              return _CategoryHotCard(
                category: entry.key,
                keywords: entry.value,
                onKeywordTap: onKeywordTap,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CategoryHotCard extends StatelessWidget {
  final String category;
  final List<TrendKeyword> keywords;
  final ValueChanged<String> onKeywordTap;

  const _CategoryHotCard({
    required this.category,
    required this.keywords,
    required this.onKeywordTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF111827) : Colors.white;
    final border = isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);
    final primaryText = Theme.of(context).colorScheme.onSurface;
    final secondaryText = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final color = _catColor(category);

    return Container(
      width: 210,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 7),
              Text(
                category,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: primaryText),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (keywords.isEmpty)
            Text(
              '吏묎퀎 ?湲?以?,
              style: TextStyle(
                fontSize: 12,
                color: secondaryText,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final keyword in keywords.take(5))
                  ActionChip(
                    label: Text(keyword.keyword),
                    onPressed: () => onKeywordTap(keyword.keyword),
                    backgroundColor: color.withOpacity(0.08),
                    side: BorderSide.none,
                    labelStyle: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SentimentInsightPanel extends StatelessWidget {
  final NewsSentimentSummary sentiment;

  const _SentimentInsightPanel({required this.sentiment});

  @override
  Widget build(BuildContext context) {
    final temperatures = _buildSevenDayTemperatures(sentiment.temperature);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF111827) : Colors.white;
    final border = isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InsightSectionTitle(
            icon: Icons.insights_rounded,
            title: '?댁뒪 媛먯젙 遺꾩꽍',
            trailing: '理쒓렐 7??,
          ),
          const SizedBox(height: 14),
          _SentimentTemperatureCard(sentiment: sentiment),
          const SizedBox(height: 14),
          _SevenDaySentimentChart(values: temperatures),
        ],
      ),
    );
  }

  List<int> _buildSevenDayTemperatures(int current) {
    return [
      (current - 8).clamp(0, 100),
      (current - 4).clamp(0, 100),
      (current - 2).clamp(0, 100),
      (current + 3).clamp(0, 100),
      (current - 1).clamp(0, 100),
      (current + 5).clamp(0, 100),
      current,
    ];
  }
}

class _SevenDaySentimentChart extends StatelessWidget {
  final List<int> values;

  const _SevenDaySentimentChart({required this.values});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 86,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (int i = 0; i < values.length; i++) ...[
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: (values[i] / 100).clamp(0.08, 1.0),
                        child: Container(
                          width: 16,
                          decoration: BoxDecoration(
                            color: Colors.indigo.withOpacity(0.18 + i * 0.02),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    i == values.length - 1
                        ? '?ㅻ뒛'
                        : 'D-${values.length - 1 - i}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (i != values.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _SentimentRatioBar extends StatelessWidget {
  final NewsSentimentSummary sentiment;

  const _SentimentRatioBar({required this.sentiment});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Row(
            children: [
              _RatioSegment(
                value: sentiment.positiveRatio,
                color: Colors.green,
              ),
              _RatioSegment(
                value: sentiment.neutralRatio,
                color: Colors.blueGrey,
              ),
              _RatioSegment(
                value: sentiment.negativeRatio,
                color: Colors.red,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '湲띿젙 ${sentiment.positiveRatio}% 쨌 以묐┰ ${sentiment.neutralRatio}% 쨌 遺??${sentiment.negativeRatio}%',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _RatioSegment extends StatelessWidget {
  final int value;
  final Color color;

  const _RatioSegment({
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: value <= 0 ? 1 : value,
      child: Container(
        height: 9,
        color: color.withOpacity(value <= 0 ? 0.08 : 0.72),
      ),
    );
  }
}

class _TrendSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onSearch;

  const _TrendSearchBar({
    required this.controller,
    required this.onSubmitted,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC);
    final border = isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);
    return TextField(
      controller: controller,
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: '?ㅼ썙?쒕줈 ?댁뒪 寃??,
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        suffixIcon: IconButton(
          tooltip: '寃??,
          onPressed: onSearch,
          icon: const Icon(Icons.arrow_forward_rounded, size: 20),
        ),
        isDense: true,
        filled: true,
        fillColor: surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
              color: isDark ? Colors.blue.shade200 : Colors.blue.shade300),
        ),
      ),
    );
  }
}

class _KeywordChip extends StatelessWidget {
  final TrendKeyword keyword;
  final VoidCallback onTap;

  const _KeywordChip({
    required this.keyword,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF0F172A) : const Color(0xFFEEF4FF);
    final innerSurface =
        isDark ? const Color(0xFF111827) : Colors.white.withOpacity(0.8);
    final primary = isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB);
    final color = isDark ? const Color(0xFFBFDBFE) : const Color(0xFF2563EB);
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFDCE7FF);

    return Material(
      color: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(color: border, width: 1),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        hoverColor: const Color(0xFF2563EB).withOpacity(0.05),
        splashColor: const Color(0xFF2563EB).withOpacity(0.08),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '#${keyword.keyword}',
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: innerSurface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color:
                        isDark ? const Color(0xFF475569) : Colors.transparent,
                  ),
                ),
                child: Text(
                  '${keyword.newsCount}',
                  style: TextStyle(
                    color: primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SentimentTemperatureCard extends StatelessWidget {
  final NewsSentimentSummary sentiment;

  const _SentimentTemperatureCard({required this.sentiment});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = Theme.of(context).colorScheme.onSurface;
    final secondaryText = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final color = sentiment.temperature >= 71
        ? Colors.green
        : sentiment.temperature <= 30
            ? Colors.red
            : Colors.blueGrey;

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.thermostat_rounded, size: 17, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '?ㅻ뒛 ?댁뒪 媛먯젙?⑤룄',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: primaryText,
                  ),
                ),
              ),
              Text(
                '${sentiment.temperature}째',
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF111827)
                      : Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  sentiment.temperature >= 71
                      ? '湲띿젙'
                      : sentiment.temperature <= 30
                          ? '遺??
                          : '以묐┰',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: sentiment.temperature / 100,
              minHeight: 5.5,
              backgroundColor: isDark
                  ? const Color(0xFF1F2937)
                  : Colors.white.withOpacity(0.8),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            sentiment.summary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.35,
              color: secondaryText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RisingIssueTile extends StatelessWidget {
  final RisingIssue issue;
  final int rank;
  final VoidCallback onTap;

  const _RisingIssueTile({
    required this.issue,
    required this.rank,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = _catColor(issue.category);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF111827) : Colors.white;
    final border = isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);
    final primaryText = isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryText = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          hoverColor: const Color(0xFF2563EB).withOpacity(0.025),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withOpacity(0.20)
                      : Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF1FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      '$rank',
                      style: TextStyle(
                        color: const Color(0xFF2563EB),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.9),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        issue.keyword,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: primaryText,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        issue.representativeTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: secondaryText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '+${issue.growthRate}%',
                  style: TextStyle(
                    color: const Color(0xFFB45309),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
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

class _CompactEmptyRow extends StatelessWidget {
  final String message;

  const _CompactEmptyRow({required this.message});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final background =
        isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 14,
            color: textColor,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: textColor,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightEmpty extends StatelessWidget {
  final String message;

  const _InsightEmpty({required this.message});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF111827) : const Color(0xFFF8FBFF);
    final secondaryText = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: secondaryText,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _BlurOrb extends StatelessWidget {
  final double size;
  final List<Color> colors;

  const _BlurOrb({
    required this.size,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: colors,
            radius: 0.85,
          ),
        ),
      ),
    );
  }
}

class _HomeGridPainter extends CustomPainter {
  const _HomeGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFB9C7DA).withOpacity(0.055)
      ..strokeWidth = 1;

    const gap = 56.0;
    for (double x = 0; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ?? ???꾩씠肄????????????????????????
class _MajorNewsCard extends StatelessWidget {
  final TrendItem trend;
  final int index;
  final VoidCallback onTap;
  final double? width;
  final double? height;

  const _MajorNewsCard({
    required this.trend,
    required this.index,
    required this.onTap,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardSurface = isDark ? const Color(0xFF111827) : Colors.white;
    final cardBorder =
        isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);
    final titleText = Theme.of(context).colorScheme.onSurface;
    final bodyText = isDark ? Colors.grey.shade300 : Colors.blueGrey.shade800;
    final mutedText = isDark ? Colors.grey.shade400 : Colors.blueGrey.shade600;
    final chipBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFEEF4FF);
    final chipBorder =
        isDark ? const Color(0xFF1F2937) : const Color(0xFFDCE7FF);
    final timeAgo = _timeAgo(trend.published);
    final chipLabel = trend.category.isEmpty ? '?쇰컲' : trend.category;
    final isTopStory = index == 0;
    final isFeatured = index == 0;
    final cardWidth = width ?? (isFeatured ? 268.0 : 242.0);
    final cardHeight = height ?? (isFeatured ? 188.0 : 176.0);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + index * 70),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(18 * (1 - value), 12 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          hoverColor: const Color(0xFF2563EB).withOpacity(0.04),
          splashColor: const Color(0xFF2563EB).withOpacity(0.08),
          child: Container(
            width: cardWidth,
            height: cardHeight,
            decoration: BoxDecoration(
              color: cardSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isTopStory ? chipBorder : cardBorder,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withOpacity(0.24)
                      : Colors.black.withOpacity(isFeatured ? 0.06 : 0.04),
                  blurRadius: isFeatured ? 16 : 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _CategoryBadge(
                          category: chipLabel, color: const Color(0xFF2563EB)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isTopStory
                              ? (isDark
                                  ? const Color(0xFF3F2D12)
                                  : const Color(0xFFFFF7E6))
                              : (isDark
                                  ? const Color(0xFF0F172A)
                                  : const Color(0xFFF5F7FB)),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          isTopStory ? '二쇱슂' : '?댁뒪',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isTopStory
                                ? (isDark
                                    ? const Color(0xFFFBBF24)
                                    : const Color(0xFFB45309))
                                : mutedText,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    trend.koreanTitle,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      height: 1.28,
                      color: titleText,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      if (trend.importance >= 4)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: chipBg,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '?듭떖',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? Colors.blue.shade200
                                  : const Color(0xFF2563EB),
                            ),
                          ),
                        ),
                      if (trend.importance >= 4) const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _sourceDisplayName(trend),
                          style: TextStyle(
                            fontSize: 10.5,
                            color: mutedText,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeAgo.isEmpty ? '諛⑷툑 ?? : timeAgo,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isDark
                              ? Colors.grey.shade400
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
        ),
      ),
    );
  }
}

class _AppIcon extends StatelessWidget {
  const _AppIcon();
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.blue,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const SizedBox(
        width: 32,
        height: 32,
        child: Icon(Icons.trending_up, size: 20, color: Colors.white),
      ),
    );
  }
}

// ?? 醫뚯륫 Drawer 硫붾돱 ???????????????????????
class _AppDrawer extends StatelessWidget {
  const _AppDrawer();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final drawerBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final topBorder = isDark ? const Color(0xFF1F2937) : Colors.grey.shade200;
    final primaryText = isDark ? Colors.white : Colors.black87;
    final secondaryText = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    return Drawer(
      child: Container(
        color: drawerBg,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ?ㅻ뜑 ?곸뿭
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      isDark ? Colors.blue.shade800 : Colors.blue.shade600,
                      isDark ? Colors.blue.shade700 : Colors.blue.shade400,
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color:
                                isDark ? const Color(0xFF111827) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.all(12),
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
                        Text(
                          'Pulse',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: primaryText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '?ㅼ떆媛??몃젋??遺꾩꽍',
                      style: TextStyle(
                        fontSize: 14,
                        color: secondaryText,
                      ),
                    ),
                  ],
                ),
              ),

              // 硫붾돱 由ъ뒪??
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    _DrawerMenuItem(
                      icon: Icons.home_rounded,
                      title: '??,
                      subtitle: '?쒕뵫 ?섏씠吏濡?,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (context) => const LandingScreen(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    _DrawerMenuItem(
                      icon: Icons.newspaper_rounded,
                      title: '?ㅼ떆媛??댁뒪',
                      subtitle: '理쒖떊 ?댁뒪 ?뺤씤',
                      onTap: () {
                        Navigator.pop(context);
                        // ?대? ?댁뒪 ?붾㈃?대?濡??リ린留???
                      },
                    ),
                    const Divider(height: 1),
                    _DrawerMenuItem(
                      icon: Icons.psychology_rounded,
                      title: '怨듯룷?먯슃吏??,
                      subtitle: '?쒖옣 ?щ━ ?뺤씤',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const FearGreedPage(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    _DrawerMenuItem(
                      icon: Icons.show_chart_rounded,
                      title: '利앹떆',
                      subtitle: '二쇱슂 吏??諛?醫낅ぉ',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => MarketPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // ?섎떒 ?뺣낫
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: topBorder),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 16, color: secondaryText),
                        const SizedBox(width: 8),
                        Text(
                          'Version 1.0.0',
                          style: TextStyle(
                            fontSize: 12,
                            color: secondaryText,
                          ),
                        ),
                      ],
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

  void _showComingSoonDialog(BuildContext context, String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.schedule, color: Colors.blue),
            SizedBox(width: 8),
            Text('以鍮꾩쨷'),
          ],
        ),
        content: Text('$feature 湲곕뒫? 怨?異붽????덉젙?낅땲??'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('?뺤씤'),
          ),
        ],
      ),
    );
  }
}

// ?? Drawer 硫붾돱 ?꾩씠?????????????????????????
class _DrawerMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isComingSoon;
  final VoidCallback onTap;

  const _DrawerMenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.isComingSoon = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleText = isDark ? Colors.white : Colors.black87;
    final subtitleText = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isComingSoon
              ? (isDark ? const Color(0xFF1F2937) : Colors.grey.shade100)
              : (isDark ? const Color(0xFF172554) : Colors.blue.shade50),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: isComingSoon
              ? (isDark ? Colors.grey.shade500 : Colors.grey.shade400)
              : (isDark ? Colors.blue.shade200 : Colors.blue),
          size: 24,
        ),
      ),
      title: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isComingSoon ? subtitleText : titleText,
            ),
          ),
          if (isComingSoon) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '以鍮꾩쨷',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: subtitleText,
        ),
      ),
      onTap: onTap,
    );
  }
}

// ?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧
// _TrendList - ??퀎 臾댄븳 ?ㅽ겕濡?由ъ뒪??
// ?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧
class _TrendList extends StatefulWidget {
  final String category;
  final String categoryLabel;
  final ValueNotifier<DateTime> refreshNotifier;
  final List<Widget> Function()? headerBuilder;

  const _TrendList({
    super.key,
    required this.category,
    required this.categoryLabel,
    required this.refreshNotifier,
    this.headerBuilder,
  });

  @override
  State<_TrendList> createState() => _TrendListState();
}

class _TrendListState extends State<_TrendList>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  final ApiService _api = ApiService();

  // ?섏젙?? ?꾨옒 build 硫붿꽌?쒖? 蹂?섎챸??留욎텛湲??꾪빐 _scrollController濡??듭씪
  final ScrollController _scrollController = ScrollController();

  List<TrendItem> _trends = [];
  bool _isLoading = false;
  bool _isFetchingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  String? _error;
  static const int _pageSize = 20;

  // ??씠 ?ㅼ떆 蹂댁씪 ???먮룞 ?덈줈怨좎묠???꾪븳 ?뚮옒洹?
  DateTime? _lastLoadTime;
  static const _autoRefreshThreshold = Duration(minutes: 3);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
    _scrollController.addListener(_onScroll);
    // 遺紐⑥쓽 refreshNotifier 蹂寃????먮룞 ?덈줈怨좎묠
    widget.refreshNotifier.addListener(_onAutoRefresh);
    // ???앸챸二쇨린 愿李??쒖옉
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // ?깆씠 ?ㅼ떆 ?쒖꽦?붾릺?덉쓣 ??
    if (state == AppLifecycleState.resumed) {
      _checkAndRefreshIfNeeded();
    }
  }

  // ??씠 ?ㅼ떆 蹂댁씪 ???먮룞 ?덈줈怨좎묠 泥댄겕
  void _checkAndRefreshIfNeeded() {
    if (_lastLoadTime != null) {
      final timeSinceLastLoad = DateTime.now().difference(_lastLoadTime!);
      if (timeSinceLastLoad > _autoRefreshThreshold) {
        if (kDebugMode) print(
            '?벑 Auto-refreshing ${widget.category} (${timeSinceLastLoad.inMinutes}遺?寃쎄낵)');
        _refresh();
      }
    }
  }

  void _onAutoRefresh() {
    _refresh();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.refreshNotifier.removeListener(_onAutoRefresh);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_isLoading) return;
    if (!mounted) return;
    if (kDebugMode) print('?벑 _load() started for category: ${widget.category}');
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _api.fetchTrends(
        limit: _pageSize,
        offset: 0,
        category: widget.category,
        sort: 'latest',
      );
      if (!mounted) return;
      if (kDebugMode) print('?벑 _load() success: ${data.length} trends');
      setState(() {
        _trends = data;
        _offset = data.length;
        _hasMore = data.length == _pageSize;
        _error = null;
        _isLoading = false;
        _lastLoadTime = DateTime.now(); // 濡쒕뱶 ?쒓컙 湲곕줉
      });
    } catch (e) {
      if (kDebugMode) print('?벑 _load() error: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
      // 5珥????ъ떆??(鍮?由ъ뒪?몄씪 ?뚮쭔)
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted && _trends.isEmpty) {
          if (kDebugMode) print('?벑 Auto-retrying after error...');
          _load();
        }
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isFetchingMore || !_hasMore) return;
    setState(() => _isFetchingMore = true);
    try {
      final data = await _api.fetchTrends(
        limit: _pageSize,
        offset: _offset,
        category: widget.category,
        sort: 'latest',
      );
      if (!mounted) return;
      setState(() {
        _trends.addAll(data);
        _offset += data.length;
        _hasMore = data.length == _pageSize;
        _isFetchingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isFetchingMore = false);
    }
  }

  Future<void> _refresh() async {
    try {
      final data = await _api.fetchTrends(
        limit: _pageSize,
        offset: 0,
        category: widget.category,
        sort: 'latest',
      );
      if (!mounted) return;
      setState(() {
        _trends = data;
        _offset = data.length;
        _hasMore = data.length == _pageSize;
        _error = null;
        _lastLoadTime = DateTime.now(); // ?덈줈怨좎묠 ?쒓컙 湲곕줉
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // ??씠 蹂댁씪 ?뚮쭏???먮룞 ?덈줈怨좎묠 泥댄겕
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkAndRefreshIfNeeded();
      }
    });

    if (_isLoading && _trends.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _trends.isEmpty) {
      return _ErrorView(onRetry: _load);
    }

    if (_trends.isEmpty) {
      return _EmptyView(label: widget.categoryLabel, onRetry: _load);
    }

    final displayTrends = _trends;
    final headerWidgets = widget.headerBuilder?.call() ?? const <Widget>[];
    final itemCount =
        headerWidgets.length + displayTrends.length + (_isFetchingMore ? 1 : 0);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        cacheExtent: 1500,
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (index < headerWidgets.length) {
            return headerWidgets[index];
          }

          final trendIndex = index - headerWidgets.length;

          if (trendIndex == displayTrends.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }

          final trend = displayTrends[trendIndex];

          return _NewsListRow(
            key: ValueKey(trend.id),
            rank: trendIndex + 1,
            trend: trend,
            onTapOverride: null,
          );
        },
      ),
    );
  }
}

// ?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧
// _TrendCard
// ?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧
class _TrendCard extends StatefulWidget {
  final int rank;
  final TrendItem trend;
  final VoidCallback? onTapOverride;

  const _TrendCard({
    super.key,
    required this.rank,
    required this.trend,
    this.onTapOverride,
  });

  @override
  State<_TrendCard> createState() => _TrendCardState();
}

class _TrendCardState extends State<_TrendCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (_) => _DetailSheet(trend: widget.trend),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeController.instance.mode.value == ThemeMode.dark;
    final surface = isDark ? const Color(0xFF111827) : Colors.white;
    final border = isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);
    final primaryText = isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryText =
        isDark ? Colors.grey.shade200 : Colors.blueGrey.shade500;
    final timeStr = _timeAgo(widget.trend.published);
    final isTop3 = widget.rank <= 3;
    final accent = isTop3
        ? const Color(0xFF2563EB)
        : (isDark ? Colors.grey.shade400 : Colors.blueGrey.shade400);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: RepaintBoundary(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                hoverColor: const Color(0xFF2563EB).withOpacity(0.02),
                splashColor: const Color(0xFF2563EB).withOpacity(0.06),
                onTap: widget.onTapOverride ?? () => _showDetail(context),
                onHover: (hovering) {
                  setState(() => _isHovered = hovering);
                  hovering ? _controller.forward() : _controller.reverse();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  transform:
                      Matrix4.translationValues(0, _isHovered ? -2 : 0, 0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: surface,
                    border: Border.all(color: border),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withOpacity(0.24)
                            : Colors.black.withOpacity(isTop3 ? 0.05 : 0.03),
                        blurRadius: isTop3 ? 14 : 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(13),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isTop3
                                ? (isDark
                                    ? const Color(0xFF172554)
                                    : const Color(0xFFEEF4FF))
                                : (isDark
                                    ? const Color(0xFF0F172A)
                                    : const Color(0xFFF8FAFC)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              '${widget.rank}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: accent,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.trend.koreanTitle,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  height: 1.3,
                                  color: primaryText,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 7),
                              Row(
                                children: [
                                  _CategoryBadge(
                                    category: widget.trend.category.isEmpty
                                        ? '?쇰컲'
                                        : widget.trend.category,
                                    color: accent,
                                    isImportant: false,
                                  ),
                                  const SizedBox(width: 8),
                                  if (widget.trend.importance >= 4)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF172554)
                                            : const Color(0xFFEEF4FF),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: const Text(
                                        '?듭떖',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF2563EB),
                                        ),
                                      ),
                                    ),
                                  if (widget.trend.importance >= 4)
                                    const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isTop3
                                          ? (isDark
                                              ? const Color(0xFF3F2D12)
                                              : const Color(0xFFFFF7E6))
                                          : (isDark
                                              ? const Color(0xFF111827)
                                              : const Color(0xFFF6F7F9)),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      isTop3 ? '二쇱슂' : '?댁뒪',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: isTop3
                                            ? (isDark
                                                ? const Color(0xFFFBBF24)
                                                : const Color(0xFFB45309))
                                            : secondaryText,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Icon(
                                    Icons.access_time_rounded,
                                    size: 12,
                                    color: secondaryText,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    timeStr,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: secondaryText,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NewsListRow extends StatefulWidget {
  final int rank;
  final TrendItem trend;
  final VoidCallback? onTapOverride;

  const _NewsListRow({
    super.key,
    required this.rank,
    required this.trend,
    this.onTapOverride,
  });

  @override
  State<_NewsListRow> createState() => _NewsListRowState();
}

class _NewsListRowState extends State<_NewsListRow> {
  bool _isHovered = false;

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (_) => _DetailSheet(trend: widget.trend),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeController.instance.mode.value == ThemeMode.dark;
    final isCompact = MediaQuery.sizeOf(context).width < 560;
    final surface = isDark ? const Color(0xFF111827) : Colors.white;
    final border = isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);
    final hoverSurface =
        isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final primaryText = isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryText =
        isDark ? Colors.grey.shade400 : Colors.blueGrey.shade500;
    final rankAccent = widget.rank <= 3
        ? const Color(0xFF2563EB)
        : (isDark ? Colors.grey.shade400 : Colors.blueGrey.shade400);
    final publishedLabel = _timeAgo(widget.trend.published);
    final publisher = _sourceDisplayName(widget.trend);
    final chipLabel =
        widget.trend.category.isEmpty ? '?쇰컲' : widget.trend.category;
    final isTop = widget.rank <= 3;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 10 : 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTapOverride ?? () => _showDetail(context),
          borderRadius: BorderRadius.circular(12),
          hoverColor: const Color(0xFF2563EB).withOpacity(0.025),
          splashColor: const Color(0xFF2563EB).withOpacity(0.06),
          onHover: (hovering) {
            setState(() => _isHovered = hovering);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(0, _isHovered ? -1 : 0, 0),
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 10 : 14,
              vertical: isCompact ? 11 : 12,
            ),
            decoration: BoxDecoration(
              color: _isHovered ? hoverSurface : surface,
              border: Border(
                bottom: BorderSide(color: border),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: isCompact ? 24 : 28,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Container(
                      width: isCompact ? 22 : 24,
                      height: isCompact ? 22 : 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isTop
                            ? (isDark
                                ? const Color(0xFF172554)
                                : const Color(0xFFEEF4FF))
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${widget.rank}',
                        style: TextStyle(
                          color: rankAccent,
                          fontSize: isCompact ? 11 : 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: isCompact ? 6 : 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 7,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _CategoryBadge(
                            category: chipLabel,
                            color: rankAccent,
                            isImportant: false,
                          ),
                          const SizedBox(width: 7),
                          if (widget.trend.importance >= 4)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF172554)
                                    : const Color(0xFFEEF4FF),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '?듭떖',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? Colors.blue.shade200
                                      : const Color(0xFF2563EB),
                                ),
                              ),
                            ),
                          if (widget.trend.importance >= 4)
                            const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: isTop
                                  ? (isDark
                                      ? const Color(0xFF3F2D12)
                                      : const Color(0xFFFFF7E6))
                                  : (isDark
                                      ? const Color(0xFF111827)
                                      : const Color(0xFFF6F7F9)),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              isTop ? '二쇱슂' : '?댁뒪',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: isTop
                                    ? (isDark
                                        ? const Color(0xFFFBBF24)
                                        : const Color(0xFFB45309))
                                    : secondaryText,
                              ),
                            ),
                          ),
                          Text(
                            publishedLabel.isEmpty ? '諛⑷툑 ?? : publishedLabel,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: secondaryText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.trend.koreanTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.34,
                          fontWeight: FontWeight.w700,
                          color: primaryText,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              publisher,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: secondaryText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: secondaryText,
                          ),
                        ],
                      ),
                    ],
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

class _CategoryBadge extends StatelessWidget {
  final String category;
  final Color color;
  final bool isImportant;
  const _CategoryBadge({
    required this.category,
    required this.color,
    this.isImportant = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isImportant
        ? (isDark ? const Color(0xFF172554) : const Color(0xFFEEF4FF))
        : (isDark ? const Color(0xFF1A2535) : const Color(0xFFF1F5F9));
    final foreground = isImportant
        ? (isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB))
        : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF526174));
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isImportant ? 12 : 10,
          vertical: isImportant ? 5 : 4,
        ),
        child: Text(
          category,
          style: TextStyle(
            fontSize: isImportant ? 11 : 10.5,
            fontWeight: FontWeight.bold,
            color: foreground,
          ),
        ),
      ),
    );
  }
}

// ?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧
// _DetailSheet
// ?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧?먥븧
class _DetailSheet extends StatelessWidget {
  final TrendItem trend;
  const _DetailSheet({required this.trend});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF0B1220) : Colors.white;
    final border = isDark ? const Color(0xFF243041) : const Color(0xFFE2E8F0);
    final primaryText = isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryText = isDark ? Colors.grey.shade100 : Colors.grey.shade600;
    final subtleText = isDark ? Colors.grey.shade100 : Colors.grey.shade500;
    final catColor = _catColor(trend.category);

    return GestureDetector(
      onTap: () => Navigator.pop(context), // 諛붽묑 ?곸뿭 ?대┃ ???リ린
      behavior: HitTestBehavior.opaque, // ?щ챸 ?곸뿭????媛먯?
      child: GestureDetector(
        onTap: () {}, // Sheet ?대? ?대┃? ?꾪뙆 ???섎룄濡?
        child: DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (_, ctrl) => ColoredBox(
            color: surface,
            child: SafeArea(
              top: false,
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey.shade700 : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: catColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          child: Text(
                            trend.category,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _sourceDisplayName(trend),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white : subtleText,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _timeAgo(trend.published),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey.shade100 : subtleText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    trend.koreanTitle,
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      height: 1.4,
                      color: primaryText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (trend.thumbnailUrl.trim().isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.network(
                          trend.thumbnailUrl.trim(),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: isDark
                                ? const Color(0xFF111827)
                                : const Color(0xFFF8FAFC),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: isDark
                                  ? Colors.grey.shade500
                                  : Colors.blueGrey.shade300,
                              size: 26,
                            ),
                          ),
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              color: isDark
                                  ? const Color(0xFF111827)
                                  : const Color(0xFFF8FAFC),
                              alignment: Alignment.center,
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: const Color(0xFF2563EB),
                                  value: progress.expectedTotalBytes == null
                                      ? null
                                      : progress.cumulativeBytesLoaded /
                                          progress.expectedTotalBytes!,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF172554)
                          : const Color(0xFFEAF1FF),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF1E3A8A)
                            : const Color(0xFFDDE9FF),
                      ),
                    ),
                    child: Text(
                      trend.importance >= 4 ? '?듭떖 ?댁뒋' : '?쇰컲 ?댁뒋',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? const Color(0xFF93C5FD)
                            : const Color(0xFF2563EB),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF111827)
                          : const Color(0xFFFAFAFA),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        trend.summaryKr.isNotEmpty
                            ? trend.summaryKr
                            : '?붿빟 ?뺣낫媛 ?놁뒿?덈떎.',
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.7,
                          color: isDark ? Colors.grey.shade100 : secondaryText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (trend.link.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _openUrl(trend.link, context),
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: const Text(
                          '?먮Ц 蹂닿린',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: const Color(0xFF2563EB),
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

  Future<void> _openUrl(String url, BuildContext ctx) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, webOnlyWindowName: '_blank')) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('留곹겕瑜??????놁뒿?덈떎.')),
        );
      }
    }
  }
}

// ?? ?먮윭/鍮??붾㈃ ?꾩젽 ????????????????????????????
class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? Colors.white : Colors.black87;
    final secondaryText =
        isDark ? Colors.grey.shade400 : const Color(0xFF9E9E9E);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_rounded,
              size: 64,
              color: isDark ? Colors.grey.shade600 : const Color(0xFFDDDDDD)),
          const SizedBox(height: 16),
          Text('諛깆뿏???쒕쾭 ?곌껐 以?..',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: primaryText)),
          const SizedBox(height: 8),
          Text('https://news-summarizer.bum2432.workers.dev',
              style: TextStyle(fontSize: 13, color: secondaryText)),
          const SizedBox(height: 4),
          Text('Ollama 遺꾩꽍 ?꾨즺 ???먮룞 濡쒕뱶?⑸땲??,
              style: TextStyle(fontSize: 12, color: secondaryText)),
          const SizedBox(height: 24),
          const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('吏湲??ъ떆??),
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final String label;
  final VoidCallback onRetry;
  const _EmptyView({required this.label, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? Colors.white : Colors.black87;
    final secondaryText =
        isDark ? Colors.grey.shade400 : const Color(0xFF9E9E9E);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.newspaper,
              size: 60,
              color: isDark ? Colors.grey.shade600 : const Color(0xFFDDDDDD)),
          const SizedBox(height: 12),
          Text('$label ?댁뒪媛 ?놁뒿?덈떎', style: TextStyle(color: secondaryText)),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text('?덈줈怨좎묠', style: TextStyle(color: primaryText)),
          ),
        ],
      ),
    );
  }
}

