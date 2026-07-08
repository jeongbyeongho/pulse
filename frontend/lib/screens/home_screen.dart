import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui';
import 'dart:async';
import '../models/trend_item.dart';
import '../models/trend_insight.dart';
import '../services/api_service.dart';
import '../utils/news_grouping.dart';
import '../widgets/app_drawer.dart';
import 'landing_screen.dart';
import 'fear_greed_page.dart';
import 'market_page.dart';

// ── 분야별 탭 설정 ──────────────────────────────
const List<Map<String, dynamic>> kCategories = [
  {'label': '전체', 'value': '', 'icon': Icons.dashboard_rounded},
  {'label': '경제', 'value': '경제', 'icon': Icons.trending_up_rounded},
  {'label': '세계', 'value': '세계', 'icon': Icons.public_rounded},
  {'label': '사회', 'value': '사회', 'icon': Icons.people_rounded},
  {'label': '정치', 'value': '정치', 'icon': Icons.account_balance_rounded},
  {'label': '생활/문화', 'value': '생활/문화', 'icon': Icons.library_books_rounded},
  {'label': 'IT/과학', 'value': 'IT/과학', 'icon': Icons.computer_rounded},
];

// ── 카테고리 색상 ──────────────────────────────
const Map<String, Color> kCategoryColors = {
  '경제': Color(0xFF2563EB),
  '세계': Color(0xFF2563EB),
  '사회': Color(0xFF2563EB),
  '정치': Color(0xFF2563EB),
  '생활/문화': Color(0xFF2563EB),
  'IT/과학': Color(0xFF2563EB),
};
const Color kDefaultColor = Color(0xFF2563EB);

Color _catColor(String cat) => kCategoryColors[cat] ?? kDefaultColor;

Color _catColorAlpha(Color c, int alpha) =>
    Color.fromARGB(alpha, c.red, c.green, c.blue);

// ── 별점 위젯 (const 생성 가능한 형태로 분리) ──────────────────────
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

// ── 시간 포맷 유틸 ──────────────────────────────
String _timeAgo(String isoDate) {
  if (isoDate.isEmpty) return '';
  try {
    final diff = DateTime.now().difference(DateTime.parse(isoDate));
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  } catch (_) {
    return '';
  }
}

// ════════════════════════════════════════════════
// HomeScreen
// ════════════════════════════════════════════════
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

  /// 5분마다 각 _TrendList에 새로고침 신호를 보내는 notifier
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

    // 5분마다 notifier를 갱신 → 모든 탭이 API 재호출
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
        return DraggableScrollableSheet(
          initialChildSize: 0.82,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          builder: (_, controller) {
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              child: ColoredBox(
                color: const Color(0xFFF8FBFF),
                child: SafeArea(
                  top: false,
                  child: FutureBuilder<List<TrendItem>>(
                    future: _resolveGroupedNewsItems(
                      seedItems: items,
                      anchor: anchor,
                    ),
                    builder: (context, snapshot) {
                      final resolvedItems = snapshot.data ?? const <TrendItem>[];
                      final orderedItems = resolvedItems.toList()
                        ..sort((a, b) {
                          final aDate = _trendDate(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
                          final bDate = _trendDate(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
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
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 14),
                          if (snapshot.connectionState == ConnectionState.waiting)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 80),
                              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            )
                          else if (orderedItems.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 80),
                              child: Center(child: Text('관련 뉴스가 없습니다.')),
                            )
                          else
                            for (int i = 0; i < orderedItems.length; i++)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _TrendCard(
                                  key: ValueKey('cluster-${orderedItems[i].id}-$i'),
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
      title: '#$keyword 관련 뉴스',
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
      title: '"$query" 검색 결과',
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
        return DraggableScrollableSheet(
          initialChildSize: 0.82,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          builder: (_, controller) {
            return ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              child: ColoredBox(
                color: const Color(0xFFF8FBFF),
                child: SafeArea(
                  top: false,
                  child: FutureBuilder<List<TrendItem>>(
                    future: future,
                    builder: (context, snapshot) {
                      final items = snapshot.data ?? const <TrendItem>[];
                      final orderedItems = items.toList()
                        ..sort((a, b) {
                          final aDate = _trendDate(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
                          final bDate = _trendDate(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
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
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
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
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 80),
                              child: Center(child: Text('관련 뉴스가 없습니다.')),
                            )
                          else
                            for (int i = 0; i < orderedItems.length; i++)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _TrendCard(
                                  key: ValueKey('keyword-${orderedItems[i].id}-$i'),
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
        final topLine = topKeywords.isEmpty
            ? '오늘 새 이슈를 수집하고 있어요.'
            : '지금 ${topKeywords.take(3).map((e) => e.keyword).join(', ')} 이슈가 많이 언급되고 있어요.';

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: SizedBox(
            height: 360,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.indigo.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.radar_rounded,
                            color: Colors.indigo.shade600,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            '오늘의 한 줄 트렌드',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: '새로고침',
                          onPressed: () {
                            setState(() {
                              _insightFuture = _api.fetchTrendInsights();
                            });
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      topLine,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _TrendSearchBar(
                      controller: _searchController,
                      onSubmitted: (_) => _submitSearch(),
                      onSearch: _submitSearch,
                    ),
                    const SizedBox(height: 16),
                    _InsightSectionTitle(
                      icon: Icons.local_fire_department_rounded,
                      title: '실시간 인기 키워드 TOP 10',
                      trailing: '${topKeywords.length}개',
                    ),
                    const SizedBox(height: 10),
                    if (topKeywords.isEmpty)
                      const _InsightEmpty(message: '아직 집계된 키워드가 없습니다.')
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
                    const SizedBox(height: 18),
                    _SentimentTemperatureCard(sentiment: insight.sentiment),
                    const SizedBox(height: 18),
                    _InsightSectionTitle(
                      icon: Icons.trending_up_rounded,
                      title: '급상승 이슈 TOP 5',
                      trailing: '최근 1시간',
                    ),
                    const SizedBox(height: 10),
                    if (rising.isEmpty)
                      const _InsightEmpty(message: '급상승 조건을 만족한 이슈가 없습니다.')
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.025),
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
                      color: const Color(0xFFEEF4FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.search_rounded,
                      size: 17,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      '뉴스 검색',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
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
                title: '실시간 인기 키워드 TOP 10',
                trailing: '관련 뉴스 기준',
              ),
              const SizedBox(height: 10),
              if (keywords.isEmpty)
                const _InsightEmpty(message: '아직 집계된 키워드가 없습니다.')
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
                title: '급상승 이슈 TOP 5',
                trailing: '최근 1시간',
              ),
              const SizedBox(height: 10),
              if (rising.isEmpty)
                const _InsightEmpty(message: '급상승 조건을 만족한 이슈가 없습니다.')
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

  Map<String, List<TrendKeyword>> _buildCategoryHotKeywords(
      List<TrendKeyword> keywords) {
    const categories = ['정치', '경제', 'IT/과학', '사회', '세계', '생활/문화'];
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
        return '▲3';
      case 2:
        return '▲1';
      case 3:
        return '▼2';
      default:
        return index.isEven ? '▲1' : '-';
    }
  }

  Widget _buildFeaturedNewsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF7FBFF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFDDE9FF)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2563EB).withOpacity(0.05),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
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
                                color: const Color(0xFFDDE9FF),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.auto_awesome_rounded,
                                size: 17,
                                color: Colors.blue.shade700,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                '오늘의 TOP 뉴스',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            if (!isLoading)
                              Text(
                                '${items.length}건',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.blueGrey.shade700,
                                ),
                              ),
                            const SizedBox(width: 8),
                            Icon(
                              _isFeaturedExpanded
                                  ? Icons.expand_less_rounded
                                  : Icons.expand_more_rounded,
                              color: Colors.blueGrey.shade600,
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
                                              'No featured news right now.',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade500,
                                              ),
                                            ),
                                          ),
                                        )
                                      : SizedBox(
                                          height: 194,
                                          child: ListView.separated(
                                            scrollDirection: Axis.horizontal,
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
                                                onTap: () =>
                                                    _openTrendDetail(trend),
                                              );
                                            },
                                          ),
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
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF8FAFC),
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
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.menu_rounded, size: 24),
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    '실시간 뉴스',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      _headerTime,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blueGrey.shade700,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF4FF),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFDCE7FF)),
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
                          '최근 24시간 분석',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              color: const Color(0xFFF8FAFC),
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.blue.shade700,
                unselectedLabelColor: const Color(0xFF475569),
                indicator: BoxDecoration(
                  color: const Color(0xFFEEF4FF),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFDCE7FF)),
                ),
                indicatorPadding: EdgeInsets.zero,
                labelPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                labelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
                dividerColor: const Color(0xFFE2E8F0),
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
            Expanded(
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
                                _buildNewsSearchHeader(),
                                _buildFeaturedNewsSection(),
                              ]
                          : null,
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

class _HomeBackdrop extends StatelessWidget {
  const _HomeBackdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
        child: const SizedBox.expand(
          child: DecoratedBox(
            decoration: BoxDecoration(
            color: Color(0xFFF8FAFC),
            ),
            child: CustomPaint(
              painter: const _HomeGridPainter(),
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
    return Container(
      height: 186,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.blue.shade50),
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
    return Row(
      children: [
        Icon(icon, size: 17, color: Colors.blue.shade700),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Text(
          trailing,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
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
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, 0, 0),
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
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
                    color: const Color(0xFFEEF4FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Color(0xFF2563EB),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'AI 브리핑',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
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
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Updated $updatedAt',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  tooltip: '새로고침',
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
                color: Colors.blueGrey.shade800,
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
                      backgroundColor: const Color(0xFFF3F7FF),
                      side: const BorderSide(color: Color(0xFFDCE7FF)),
                      labelStyle: const TextStyle(
                        color: Color(0xFF2563EB),
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
    final deltaColor = trendDelta >= 0 ? const Color(0xFF2563EB) : Colors.blueGrey;
    final deltaText = trendDelta >= 0 ? '+$trendDelta' : '$trendDelta';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
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
              const Expanded(
                child: Text(
                  '트렌드 대시보드',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: deltaColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '전일 대비 $deltaText',
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
                  label: '오늘의 트렌드 점수',
                  value: '$trendScore',
                  suffix: '/100',
                  icon: Icons.speed_rounded,
                  color: const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DashboardMetricCard(
                  label: '뉴스 감정온도',
                  value: '${sentiment.temperature}',
                  suffix: '°',
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
          const SizedBox(height: 14),
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              text: value,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: color,
              ),
              children: [
                TextSpan(
                  text: suffix,
                  style: TextStyle(
                    fontSize: 13,
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TrendSearchBar(
            controller: controller,
            onSubmitted: (_) => onSearch(),
            onSearch: onSearch,
          ),
          const SizedBox(height: 12),
          _DiscoveryChipRow(
            title: '인기 검색어',
            chips: popularKeywords.map((item) => item.keyword).toList(),
            onTap: onKeywordTap,
          ),
          if (recentSearches.isNotEmpty) ...[
            const SizedBox(height: 10),
            _DiscoveryChipRow(
              title: '최근 검색어',
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
    if (chips.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final chip in chips)
              ActionChip(
                label: Text(chip),
                onPressed: () => onTap(chip),
                backgroundColor: const Color(0xFFF8FAFC),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                labelStyle: const TextStyle(fontWeight: FontWeight.w700),
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
    final isDown = rankBadge.startsWith('▼');
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
                color: isTop3
                    ? const Color(0xFFDCE7FF)
                    : const Color(0xFFE2E8F0),
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
                        '${keyword.category} · 관련 뉴스 ${keyword.newsCount}건',
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
          title: '카테고리별 HOT 트렌드',
          trailing: '정치 · 경제 · IT · 사회',
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
    final color = _catColor(category);

    return Container(
      width: 210,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (keywords.isEmpty)
            Text(
              '집계 대기 중',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InsightSectionTitle(
            icon: Icons.insights_rounded,
            title: '뉴스 감정 분석',
            trailing: '최근 7일',
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
                        ? '오늘'
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
          '긍정 ${sentiment.positiveRatio}% · 중립 ${sentiment.neutralRatio}% · 부정 ${sentiment.negativeRatio}%',
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
    return TextField(
      controller: controller,
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: '키워드로 뉴스 검색',
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        suffixIcon: IconButton(
          tooltip: '검색',
          onPressed: onSearch,
          icon: const Icon(Icons.arrow_forward_rounded, size: 20),
        ),
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.blue.shade300),
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
    const color = Color(0xFF2563EB);

    return Material(
      color: const Color(0xFFEEF4FF),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
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
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${keyword.newsCount}',
                  style: TextStyle(
                    color: color,
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
    final color = sentiment.temperature >= 71
        ? Colors.green
        : sentiment.temperature <= 30
            ? Colors.red
            : Colors.blueGrey;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.thermostat_rounded, size: 18, color: color),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  '오늘 뉴스 감정온도',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                '${sentiment.temperature}°',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: sentiment.temperature / 100,
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.8),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            sentiment.summary,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '긍정 ${sentiment.positiveRatio}% · 중립 ${sentiment.neutralRatio}% · 부정 ${sentiment.negativeRatio}%',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w700,
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
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
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
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
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        issue.representativeTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
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

class _InsightEmpty extends StatelessWidget {
  final String message;

  const _InsightEmpty({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: Colors.grey.shade600,
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

// ── 앱 아이콘 ───────────────────────
class _MajorNewsCard extends StatelessWidget {
  final TrendItem trend;
  final int index;
  final VoidCallback onTap;

  const _MajorNewsCard({
    required this.trend,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final timeAgo = _timeAgo(trend.published);
    final chipLabel = trend.category.isEmpty ? 'General' : trend.category;
    final isTopStory = index == 0;
    final isFeatured = index == 0;

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
            width: isFeatured ? 268 : 242,
            height: isFeatured ? 188 : 176,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isTopStory
                    ? const Color(0xFFDCE7FF)
                    : const Color(0xFFE2E8F0),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isFeatured ? 0.06 : 0.04),
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
                      _CategoryBadge(category: chipLabel, color: const Color(0xFF2563EB)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isTopStory
                              ? const Color(0xFFFFF7E6)
                              : const Color(0xFFF5F7FB),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          isTopStory ? 'TOP' : 'NEWS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isTopStory
                                ? const Color(0xFFB45309)
                                : Colors.blueGrey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    trend.koreanTitle,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      height: 1.28,
                      color: Color(0xFF0F172A),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (trend.importance >= 4)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF4FF),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            '핵심',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ),
                      if (trend.importance >= 4) const SizedBox(width: 8),
                      const Spacer(),
                      Text(
                        trend.source,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Colors.blueGrey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    timeAgo.isEmpty ? 'just now' : timeAgo,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: Colors.blueGrey.shade500,
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

// ── 좌측 Drawer 메뉴 ───────────────────────
class _AppDrawer extends StatelessWidget {
  const _AppDrawer();

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        color: Colors.white,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더 영역
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.blue.shade600,
                      Colors.blue.shade400,
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
                            color: Colors.white,
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
                    const SizedBox(height: 8),
                    const Text(
                      '실시간 트렌드 분석',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),

              // 메뉴 리스트
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    _DrawerMenuItem(
                      icon: Icons.home_rounded,
                      title: '홈',
                      subtitle: '랜딩 페이지로',
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
                      title: '실시간 뉴스',
                      subtitle: '최신 뉴스 확인',
                      onTap: () {
                        Navigator.pop(context);
                        // 이미 뉴스 화면이므로 닫기만 함
                      },
                    ),
                    const Divider(height: 1),
                    _DrawerMenuItem(
                      icon: Icons.psychology_rounded,
                      title: '공포탐욕지수',
                      subtitle: '시장 심리 확인',
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
                      title: '증시',
                      subtitle: '주요 지수 및 종목',
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

              // 하단 정보
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(
                          'Version 1.0.0',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
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
            Text('준비중'),
          ],
        ),
        content: Text('$feature 기능은 곧 추가될 예정입니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
}

// ── Drawer 메뉴 아이템 ───────────────────────
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
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isComingSoon ? Colors.grey.shade100 : Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: isComingSoon ? Colors.grey.shade400 : Colors.blue,
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
              color: isComingSoon ? Colors.grey.shade400 : Colors.black87,
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
                '준비중',
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
          color: Colors.grey.shade600,
        ),
      ),
      onTap: onTap,
    );
  }
}

// ════════════════════════════════════════════════
// _TrendList - 탭별 무한 스크롤 리스트
// ════════════════════════════════════════════════
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

  // 수정됨: 아래 build 메서드와 변수명을 맞추기 위해 _scrollController로 통일
  final ScrollController _scrollController = ScrollController();

  List<TrendItem> _trends = [];
  bool _isLoading = false;
  bool _isFetchingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  String? _error;
  static const int _pageSize = 20;

  // 탭이 다시 보일 때 자동 새로고침을 위한 플래그
  DateTime? _lastLoadTime;
  static const _autoRefreshThreshold = Duration(minutes: 3);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
    _scrollController.addListener(_onScroll);
    // 부모의 refreshNotifier 변경 시 자동 새로고침
    widget.refreshNotifier.addListener(_onAutoRefresh);
    // 앱 생명주기 관찰 시작
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 앱이 다시 활성화되었을 때
    if (state == AppLifecycleState.resumed) {
      _checkAndRefreshIfNeeded();
    }
  }

  // 탭이 다시 보일 때 자동 새로고침 체크
  void _checkAndRefreshIfNeeded() {
    if (_lastLoadTime != null) {
      final timeSinceLastLoad = DateTime.now().difference(_lastLoadTime!);
      if (timeSinceLastLoad > _autoRefreshThreshold) {
        print(
            '📱 Auto-refreshing ${widget.category} (${timeSinceLastLoad.inMinutes}분 경과)');
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
    print('📱 _load() started for category: ${widget.category}');
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
      print('📱 _load() success: ${data.length} trends');
      setState(() {
        _trends = data;
        _offset = data.length;
        _hasMore = data.length == _pageSize;
        _error = null;
        _isLoading = false;
        _lastLoadTime = DateTime.now(); // 로드 시간 기록
      });
    } catch (e) {
      print('📱 _load() error: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
      // 5초 후 재시도 (빈 리스트일 때만)
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted && _trends.isEmpty) {
          print('📱 Auto-retrying after error...');
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
        _lastLoadTime = DateTime.now(); // 새로고침 시간 기록
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // 탭이 보일 때마다 자동 새로고침 체크
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

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _TrendCard(
              key: ValueKey(trend.id),
              rank: trendIndex + 1,
              trend: trend,
            ),
          );
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════
// _TrendCard
// ════════════════════════════════════════════════
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
    final timeStr = _timeAgo(widget.trend.published);
    final isTop3 = widget.rank <= 3;
    final accent = isTop3 ? const Color(0xFF2563EB) : Colors.blueGrey.shade400;

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
                  transform: Matrix4.translationValues(
                    0,
                    _isHovered ? -2 : 0,
                    0,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: Colors.white,
                    border: Border.all(
                      color: isTop3
                          ? const Color(0xFFDCE7FF)
                          : const Color(0xFFE2E8F0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isTop3 ? 0.05 : 0.03),
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
                                ? const Color(0xFFEEF4FF)
                                : const Color(0xFFF8FAFC),
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
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  height: 1.3,
                                  color: Color(0xFF0F172A),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 7),
                              Row(
                                children: [
                                  _CategoryBadge(
                                    category: widget.trend.category.isEmpty
                                        ? 'General'
                                        : widget.trend.category,
                                    color: accent,
                                    isImportant: false,
                                  ),
                                  const SizedBox(width: 8),
                                  if (widget.trend.importance >= 4)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEEF4FF),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: const Text(
                                        '핵심',
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
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isTop3
                                          ? const Color(0xFFFFF7E6)
                                          : const Color(0xFFF6F7F9),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      isTop3 ? 'TOP' : 'NEWS',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: isTop3
                                            ? const Color(0xFFB45309)
                                            : Colors.blueGrey.shade600,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Icon(
                                    Icons.access_time_rounded,
                                    size: 12,
                                    color: Colors.blueGrey.shade400,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    timeStr,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.blueGrey.shade500,
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFEEF4FF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFDCE7FF), width: 1),
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
            color: const Color(0xFF2563EB),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════
// _DetailSheet
// ════════════════════════════════════════════════
class _DetailSheet extends StatelessWidget {
  final TrendItem trend;
  const _DetailSheet({required this.trend});

  @override
  Widget build(BuildContext context) {
    final catColor = _catColor(trend.category);

    return GestureDetector(
      onTap: () => Navigator.pop(context), // 바깥 영역 클릭 시 닫기
      behavior: HitTestBehavior.opaque, // 투명 영역도 탭 감지
      child: GestureDetector(
        onTap: () {}, // Sheet 내부 클릭은 전파 안 되도록
        child: DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (_, ctrl) => ColoredBox(
            color: Colors.white,
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
                        color: Colors.grey[300],
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
                            style: const TextStyle(
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
                          trend.source,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _timeAgo(trend.published),
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    trend.koreanTitle,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF1FF),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFDDE9FF)),
                    ),
                    child: Text(
                      trend.importance >= 4 ? '핵심 이슈' : '일반 이슈',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFAFA),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFEEEEEE)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        trend.summaryKr.isNotEmpty
                            ? trend.summaryKr
                            : 'Summary not available.',
                        style: const TextStyle(fontSize: 15, height: 1.7),
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
                          'Open article',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.blue,
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
          const SnackBar(content: Text('링크를 열 수 없습니다.')),
        );
      }
    }
  }
}

// ── 에러/빈 화면 위젯 ────────────────────────────
class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_rounded,
              size: 64, color: Color(0xFFDDDDDD)),
          const SizedBox(height: 16),
          const Text('백엔드 서버 연결 중...',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('https://news-summarizer.bum2432.workers.dev',
              style: TextStyle(fontSize: 13, color: Color(0xFF9E9E9E))),
          const SizedBox(height: 4),
          const Text('Ollama 분석 완료 후 자동 로드됩니다',
              style: TextStyle(fontSize: 12, color: Color(0xFFBDBDBD))),
          const SizedBox(height: 24),
          const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('지금 재시도'),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.newspaper, size: 60, color: Color(0xFFDDDDDD)),
          const SizedBox(height: 12),
          Text('$label 뉴스가 없습니다',
              style: const TextStyle(color: Color(0xFF9E9E9E))),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('새로고침'),
          ),
        ],
      ),
    );
  }
}
