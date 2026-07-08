import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../models/trend_insight.dart';
import '../models/trend_item.dart';
import '../services/api_service.dart';
import '../utils/news_grouping.dart';
import 'home_screen.dart';
import 'fear_greed_page.dart';
import 'market_page.dart';

String _landingTimeLabel() {
  final now = DateTime.now();
  final hour = now.hour.toString().padLeft(2, '0');
  final minute = now.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _landingCompactTime(String value) {
  final parsed = DateTime.tryParse(value.trim());
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

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();
  late Future<TrendInsightSnapshot> _insightFuture;
  late Future<List<IssueTimelineItem>> _timelineFuture;
  late Future<List<TrendItem>> _latestNewsFuture;

  @override
  void initState() {
    super.initState();
    _insightFuture = _api.fetchTrendInsights();
    _timelineFuture = _api.fetchTrendTimeline(period: '24h', limit: 3, minScore: 45);
    _latestNewsFuture = _api.fetchTrends(limit: 12, sort: 'latest', period: '24h');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      drawer: isMobile ? _buildDrawer(context) : null,
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: DotPatternPainter(),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.1),
                    Colors.white.withOpacity(0.8),
                    Colors.white,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            child: Column(
              children: [
                _buildAppBar(isMobile),
                _FadeInOnScroll(
                  child: _buildPlatformHero(isMobile),
                ),
                _FadeInOnScroll(
                  delay: 120,
                  child: _buildIssueTimelineSection(),
                ),
                _FadeInOnScroll(
                  delay: 180,
                  child: _buildLatestNewsSection(),
                ),
                const SizedBox(height: 40),
                _FadeInOnScroll(
                  delay: 240,
                  child: _buildMarketLinksSection(),
                ),
                const SizedBox(height: 70),
                _FadeInOnScroll(
                  child: _buildFooter(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(bool isMobile) {
    return FutureBuilder<TrendInsightSnapshot>(
      future: _insightFuture,
      builder: (context, snapshot) {
        final insight = snapshot.data;
        final analyzedCount = insight?.sentiment.count ?? 0;
        final sectorMood = insight == null
            ? '분석 대기'
            : _landingSectorMoodLabel(insight);

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 20 : 60,
            vertical: 20,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
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
                  const Text(
                    'Pulse',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (!isMobile) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF4FF),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFDCE7FF)),
                  ),
                  child: snapshot.connectionState == ConnectionState.waiting
                      ? Text(
                          '분석 중',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.blue.shade700,
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
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '분석 기사 ${analyzedCount}건',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.blue.shade700,
                                    letterSpacing: 0,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  '경제·세계 분위기 · $sectorMood',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.blueGrey.shade600,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                ),
                const SizedBox(width: 24),
                _navItem(
                  '실시간뉴스',
                  () => _openPage(const HomeScreen()),
                ),
                const SizedBox(width: 40),
                _navItem(
                  '공포탐욕지수',
                  () => _openPage(const FearGreedPage()),
                ),
                const SizedBox(width: 40),
                _navItem(
                  '증시',
                  () => _openPage(const MarketPage()),
                ),
              ],
              if (isMobile)
                IconButton(
                  icon: const Icon(Icons.menu, color: Colors.black87),
                  onPressed: () {
                    _scaffoldKey.currentState?.openDrawer();
                  },
                ),
            ],
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

  Widget _navItem(String text, VoidCallback onTap) {
    return _HoverButton(
      onTap: onTap,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: Container(
        color: Colors.white,
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
                    colors: [Colors.blue.shade600, Colors.blue.shade400],
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
                    ListTile(
                      leading: const Icon(Icons.home, color: Colors.blue),
                      title: const Text('Pulse'),
                      subtitle: const Text('메인 화면'),
                      onTap: () {
                        Navigator.pop(context);
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.newspaper_rounded,
                          color: Colors.blue),
                      title: const Text('실시간뉴스'),
                      subtitle: const Text('최신 뉴스'),
                      onTap: () {
                        Navigator.pop(context);
                        _openPage(const HomeScreen());
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.psychology_rounded,
                          color: Colors.blue),
                      title: const Text('공포탐욕지수'),
                      subtitle: const Text('시장 심리'),
                      onTap: () {
                        Navigator.pop(context);
                        _openPage(const FearGreedPage());
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.show_chart_rounded,
                          color: Colors.blue),
                      title: const Text('증시'),
                      subtitle: const Text('주요 시장 데이터'),
                      onTap: () {
                        Navigator.pop(context);
                        _openPage(const MarketPage());
                      },
                    ),
                    const Divider(height: 1),
                  ],
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

  Widget _buildPlatformHero(bool isMobile) {
    return FutureBuilder<TrendInsightSnapshot>(
      future: _insightFuture,
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final insight = snapshot.data;

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1020),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                isMobile ? 20 : 20,
                isMobile ? 20 : 20,
                isMobile ? 20 : 20,
                isMobile ? 18 : 20,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFBFC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFF0F4F8)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withOpacity(0.05),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    isMobile ? 20 : 24,
                    isMobile ? 20 : 24,
                    isMobile ? 20 : 24,
                    isMobile ? 20 : 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 4,
                            height: isMobile ? 44 : 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 9,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEEF4FF),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: const Text(
                                        '오늘의 주요 이슈',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF2563EB),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        '지금 가장 뜨거운 흐름을 빠르게 확인하세요',
                                        style: TextStyle(
                                          fontSize: isMobile ? 20 : 22,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF0F172A),
                                          height: 1.18,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '오늘의 핵심 이슈, 키워드, 최신 뉴스를 한 화면에서 이어서 봅니다.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blueGrey.shade700,
                                    height: 1.4,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!isMobile)
                            Container(
                              margin: const EdgeInsets.only(left: 12, top: 2),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Text(
                                _landingTimeLabel(),
                                style: TextStyle(
                                  color: Colors.blueGrey.shade600,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _LandingTrendPanel(
                        isLoading: isLoading,
                        insight: insight,
                        searchController: _searchController,
                        onRefresh: _refreshInsights,
                        onSearch: _submitLandingSearch,
                        onKeywordTap: _searchLandingKeyword,
                        onRisingIssueTap: _searchLandingRisingIssue,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _refreshInsights() {
    setState(() {
      _insightFuture = _api.fetchTrendInsights();
      _timelineFuture = _api.fetchTrendTimeline(period: '24h', limit: 3, minScore: 45);
      _latestNewsFuture = _api.fetchTrends(limit: 12, sort: 'latest', period: '24h');
    });
  }

  Widget _buildIssueTimelineSection() {
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
                  color: const Color(0xFFFAFBFC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE8EEF5)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withOpacity(0.04),
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
                            color: const Color(0xFFEEF4FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.timeline_rounded,
                            size: 17,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            '실시간 이슈 타임라인',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        Text(
                          '중요 이슈만',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.blueGrey.shade500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '시간순으로 묶인 핵심 이슈만 보여줍니다.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blueGrey.shade500,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 28),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    else if (items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          '아직 타임라인으로 묶을 만큼 충분한 이슈가 없습니다.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
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

  Future<List<TrendItem>> _resolveTimelineRelatedNews(IssueTimelineItem item) async {
    try {
      return await _api.fetchIssueTimelineNews(
        issueId: item.id,
        keyword: item.keyword,
        newsIds: item.newsIds,
      );
    } catch (_) {}

    return const <TrendItem>[];
  }

  Future<List<TrendItem>> _resolveClusterRelatedNews(NewsCluster cluster) async {
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
        return DraggableScrollableSheet(
          initialChildSize: 0.82,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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

                  return CustomScrollView(
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
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: '닫기',
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.close_rounded),
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
                            title: '관련 뉴스를 불러오지 못했습니다.',
                            subtitle: '잠시 후 다시 시도해 주세요.',
                          ),
                        )
                      else if (orderedItems.isEmpty)
                        const SliverFillRemaining(
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
    return FutureBuilder<List<TrendItem>>(
      future: _latestNewsFuture,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final rawItems = (snapshot.data ?? const <TrendItem>[])
            .toList()
          ..sort((a, b) {
            final aDate = _landingTrendDate(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bDate = _landingTrendDate(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
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
                  color: const Color(0xFFFAFBFC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE8EEF5)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withOpacity(0.05),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '최신 뉴스',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '지금 들어온 기사부터 바로 확인합니다.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blueGrey.shade500,
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
                          style: TextStyle(color: Colors.grey[600]),
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

  Widget _buildMarketLinksSection() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Row(
            children: [
              Expanded(
                child: _smallNavCard(
                  icon: Icons.psychology_rounded,
                  title: '공포탐욕지수',
                  subtitle: '비트코인 / 증시 심리',
                  onTap: () => _openPage(const FearGreedPage()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _smallNavCard(
                  icon: Icons.show_chart_rounded,
                  title: '증시 정보',
                  subtitle: '주요 지수와 차트',
                  onTap: () => _openPage(const MarketPage()),
                ),
              ),
            ],
          ),
        ),
      ),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.withOpacity(0.12)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.blue.shade700),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
        return DraggableScrollableSheet(
          initialChildSize: 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
                child: FutureBuilder<List<TrendItem>>(
                  future: future,
                  builder: (context, snapshot) {
                    final items = snapshot.data ?? const <TrendItem>[];
                    final clusters = groupSimilarNews(items, maxClusters: 20);

                    return CustomScrollView(
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
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: '닫기',
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.close_rounded),
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
                                  onTap: () => _openLandingNewsCluster(cluster),
                                );
                              }
                              return _LandingSearchResultTile(
                                item: cluster.representative,
                              );
                            },
                          ),
                        ),
                    ],
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
              color: Colors.black87,
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
              color: Colors.grey[600],
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
    return _HoverCard(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
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
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 24, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style:
                  TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.4),
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
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 80),
      child: Column(
        children: [
          const Text(
            '다양한 분야의 뉴스',
            style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
                letterSpacing: -0.5),
          ),
          const SizedBox(height: 12),
          Text(
            '관심 있는 카테고리를 골라 필요한 뉴스만 빠르게 확인해보세요.',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
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
    return _HoverCard(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
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
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style:
                  TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.4),
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
    return Container(
      decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.grey[200]!, width: 1))),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 48),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration:
                          BoxDecoration(borderRadius: BorderRadius.circular(6)),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.asset(
                          'assets/icon/app_icon.png',
                          width: 32,
                          height: 32,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text('Pulse',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87)),
                  ],
                ),
                const SizedBox(height: 32),
                Text('2026 Pulse. All rights reserved.',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500])),
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

    final data = insight!;
    final score = _landingTrendScore(data);
    final delta = _landingTrendDelta(data);
    final briefing = _landingBriefing(data);
    final keywords = data.keywords.take(8).toList();
    final rising = data.risingIssues.take(3).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF101827),
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
                  color: const Color(0xFFEAF1FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFDDE9FF)),
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: Color(0xFF2563EB), size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'AI Briefing',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                tooltip: '새로고침',
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded,
                    color: Colors.white, size: 19),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            briefing,
            style: TextStyle(
              color: Colors.white.withOpacity(0.92),
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
              color: Colors.white.withOpacity(0.64),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: searchController,
            onSubmitted: (_) => onStart(),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'AI, 환율, 비트코인 검색',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.45)),
              prefixIcon: Icon(Icons.search_rounded,
                  color: Colors.white.withOpacity(0.7)),
              suffixIcon: IconButton(
                tooltip: '검색',
                onPressed: onStart,
                icon: const Icon(Icons.arrow_forward_rounded,
                    color: Colors.white),
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.09),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.32)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '실시간 인기 키워드',
            style: TextStyle(
              color: Colors.white,
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
                  backgroundColor: Colors.white.withOpacity(0.11),
                  side: BorderSide(color: Colors.white.withOpacity(0.12)),
                  labelStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          if (rising.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              '급상승 이슈',
              style: TextStyle(
                color: Colors.white,
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
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
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
    return Container(
      height: 420,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _skeletonBar(width: 150, height: 24),
          const SizedBox(height: 18),
          _skeletonBar(width: double.infinity, height: 16),
          const SizedBox(height: 8),
          _skeletonBar(width: 280, height: 16),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(child: _skeletonBar(width: double.infinity, height: 96)),
              const SizedBox(width: 10),
              Expanded(child: _skeletonBar(width: double.infinity, height: 96)),
            ],
          ),
          const SizedBox(height: 18),
          _skeletonBar(width: double.infinity, height: 48),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (int i = 0; i < 6; i++) _skeletonBar(width: 86, height: 34),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _skeletonBar({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFEAF1FF),
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

    final data = insight!;
    final score = _landingTrendScore(data);
    final delta = _landingTrendDelta(data);
    final timeLabel = _landingTimeLabel();
    final bullets = _landingBriefingTextSafe(data)
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .take(3)
        .toList();
    final keywords = data.keywords
        .where((item) => _isLandingKeywordUseful(item.keyword))
        .take(6)
        .toList();
    final risingMap = {
      for (final item in data.risingIssues) item.keyword: item,
    };
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0F4F8)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.05),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 900;

          Widget panel(Widget child, {bool expand = false, double padding = 24}) {
            return Container(
              width: double.infinity,
              height: expand ? double.infinity : null,
              padding: EdgeInsets.all(padding),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE8EEF5)),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromRGBO(15, 23, 42, 0.05),
                    blurRadius: 24,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: child,
            );
          }

          Widget sectionTitle(String title, String subtitle, {bool compact = false}) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: const Color(0xFF0F172A),
                    fontSize: compact ? 15 : 15,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.blueGrey.shade500,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
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
                    const Text(
                      '트렌드 점수',
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '$score',
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      delta >= 0 ? '+$delta' : '$delta',
                      style: TextStyle(
                        color: delta >= 0
                            ? const Color(0xFF2563EB)
                            : Colors.blueGrey,
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
                        backgroundColor: const Color(0xFFE8EEF7),
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
                    color: Colors.blueGrey.shade500,
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

          final leftPanel = panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                sectionTitle(
                  '오늘의 주요 이슈',
                  '지금 가장 뜨거운 흐름을 빠르게 확인하세요',
                ),
                const SizedBox(height: 18),
                const Text(
                  'AI 브리핑',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                for (final bullet in bullets)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '• ',
                          style: TextStyle(
                            color: Color(0xFF2563EB),
                            height: 1.4,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            bullet,
                            style: TextStyle(
                              color: Colors.blueGrey.shade800,
                              fontSize: 14,
                              height: 1.42,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                trendScoreBlock(),
              ],
            ),
            expand: !isCompact,
          );

          final middlePanel = panel(
            isCompact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      keywordsBlock(),
                      const SizedBox(height: 16),
                      _buildSearchAndCta(searchController, onSearch),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      keywordsBlock(),
                      const Spacer(),
                      _buildSearchAndCta(searchController, onSearch),
                    ],
                ),
            expand: !isCompact,
          );

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                leftPanel,
                const SizedBox(height: 14),
                middlePanel,
              ],
            );
          }

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 50, child: leftPanel),
                const SizedBox(width: 14),
                Expanded(flex: 50, child: middlePanel),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchAndCta(
    TextEditingController searchController,
    VoidCallback onSearch,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: searchController,
                onSubmitted: (_) => onSearch(),
                style: const TextStyle(color: Color(0xFF0F172A)),
                decoration: InputDecoration(
                  hintText: '뉴스 키워드 검색',
                  hintStyle: TextStyle(color: Colors.blueGrey.shade500),
                  prefixIcon: Icon(Icons.search_rounded,
                      color: Colors.blueGrey.shade500),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFF2563EB)),
                  ),
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _HoverButton(
              onTap: onSearch,
              child: FilledButton.icon(
                onPressed: onSearch,
                icon: const Icon(Icons.bolt_rounded, size: 18),
                label: const Text('실시간 뉴스 보기'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 1,
                  shadowColor: const Color(0xFF2563EB).withOpacity(0.20),
                ),
              ),
            ),
          ],
        ),
      ],
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
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOut,
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE6ECF3)),
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
                    color: leadingColor ?? Colors.blueGrey.shade500,
                  ),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: Colors.blueGrey.shade500,
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
                      ? const Color(0xFF0F172A)
                      : (leadingColor ?? const Color(0xFF0F172A)),
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
                      color: const Color(0xFFECFDF3),
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
                          style: const TextStyle(
                            color: Color(0xFF166534),
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
                      style: TextStyle(
                        color: leadingColor ?? const Color(0xFF0F172A),
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
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6ECF3)),
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
                  color: Colors.blueGrey.shade500,
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
              color: Colors.blueGrey.shade600,
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE6ECF3)),
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
                      color: const Color(0xFFEEF4FF),
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
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
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
                  color: Colors.blueGrey.shade600,
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
                    background: const Color(0xFFEEF4FF),
                  ),
                  _LandingTinyBadge(
                    text: '기사 ${item.articleCount}건',
                    foreground: const Color(0xFF334155),
                    background: const Color(0xFFF1F5F9),
                  ),
                  _LandingTinyBadge(
                    text: growthLabel,
                    foreground: const Color(0xFFB45309),
                    background: const Color(0xFFFFF7E6),
                  ),
                  _LandingTinyBadge(
                    text: stageLabel,
                    foreground: const Color(0xFF475569),
                    background: const Color(0xFFF8FAFC),
                  ),
                  Text(
                    timeLabel,
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
        color: const Color(0xFFF3F4F6),
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
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextSpan(
                    text: ' · $secondary',
                    style: TextStyle(
                      color: Colors.blueGrey.shade500,
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
                  color: const Color(0xFFEEF4FF),
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
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 14,
                        height: 1.35,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '관련 기사 ${issue.currentCount}건',
                      style: TextStyle(
                        color: Colors.blueGrey.shade600,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF334155),
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
  State<_LandingGroupedNewsTile> createState() => _LandingGroupedNewsTileState();
}

class _LandingGroupedNewsTileState extends State<_LandingGroupedNewsTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.cluster.representative;
    final hasLink = item.link.trim().isNotEmpty;
    final source = item.source.trim().isEmpty ? 'News' : item.source.trim();
    final category = item.category.trim().isEmpty ? 'General' : item.category.trim();
    final timeLabel = _landingCompactTime(item.published.isNotEmpty
        ? item.published
        : item.createdAt);
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
          color: Colors.white,
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
                      ? const Color(0xFFD8E5FF)
                      : const Color(0xFFE5E7EB),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withOpacity(_isHovered ? 0.06 : 0.04),
                    blurRadius: _isHovered ? 24 : 20,
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
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF4FF),
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
                            color: Colors.blueGrey.shade700,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            color: Colors.blueGrey.shade600,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeLabel,
                        style: TextStyle(
                          color: Colors.blueGrey.shade500,
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
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
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
                        color: Colors.blueGrey.shade600,
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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF4FF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          extraCount > 0 ? '묶음 ${widget.cluster.articleCount}건' : '단일 기사',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '언론사 ${widget.cluster.sourceCount}곳',
                          style: TextStyle(
                            color: Colors.blueGrey.shade600,
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
                            color: Colors.blueGrey.shade500,
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
  State<_LandingSearchResultTile> createState() => _LandingSearchResultTileState();
}

class _LandingSearchResultTileState extends State<_LandingSearchResultTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final hasLink = item.link.trim().isNotEmpty;
    final source = item.source.trim().isEmpty ? 'News' : item.source.trim();
    final category = item.category.trim().isEmpty ? 'General' : item.category.trim();
    final timeLabel = _landingCompactTime(item.published.isNotEmpty
        ? item.published
        : item.createdAt);

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
          color: Colors.white,
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
                      ? const Color(0xFFD8E5FF)
                      : const Color(0xFFE5E7EB),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withOpacity(_isHovered ? 0.06 : 0.04),
                    blurRadius: _isHovered ? 24 : 20,
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
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF4FF),
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
                            color: Colors.blueGrey.shade700,
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
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            color: Colors.blueGrey.shade600,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeLabel,
                        style: TextStyle(
                          color: Colors.blueGrey.shade500,
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
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
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
                        color: Colors.blueGrey.shade600,
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: Colors.grey.shade500),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: Colors.grey.shade600,
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.09),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.66),
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

  final mixed = keywordScore * 0.43 + risingScore * 0.37 + sentimentScore * 0.20;
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

  if (temperature >= 71) return '좋음';
  if (temperature <= 30) return '나쁨';
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
  final parsed = DateTime.tryParse(value.trim());
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
  final VoidCallback onTap;
  const _HoverButton({required this.child, required this.onTap});

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
      cursor: SystemMouseCursors.click,
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
