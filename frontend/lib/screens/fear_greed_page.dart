import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_gauges/gauges.dart';

import '../services/api_service.dart';
import '../widgets/app_drawer.dart';
import 'home_screen.dart';
import 'landing_screen.dart';
import 'market_page.dart';

class FearGreedPage extends StatefulWidget {
  const FearGreedPage({super.key});

  @override
  State<FearGreedPage> createState() => _FearGreedPageState();
}

class _FearGreedPageState extends State<FearGreedPage> {
  late Future<_StockFearGreedBundle> _stockFuture;
  late Future<_FearGreedIndex> _cryptoFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    _stockFuture = _loadStockBundle();
    _cryptoFuture = _loadFearGreed('/api/fear-greed/crypto', '비트코인');
  }

  Future<_StockFearGreedBundle> _loadStockBundle() async {
    final results = await Future.wait([
      _loadFearGreed('/api/fear-greed/stock', '증시'),
      _loadFearGreed('/api/fear-greed/stock/ai-score', 'AI 증시 심리'),
    ]);

    return _StockFearGreedBundle(cnn: results[0], ai: results[1]);
  }

  Future<_FearGreedIndex> _loadFearGreed(
      String path, String fallbackName) async {
    final uri = Uri.parse('${ApiService.baseUrl}$path');
    final response = await http.get(uri, headers: {
      'Content-Type': 'application/json'
    }).timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final json =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

    if (json['success'] == false) {
      throw Exception(json['error'] ?? 'API returned success=false');
    }

    return _FearGreedIndex.fromJson(json, fallbackName);
  }

  void _reload() {
    setState(_refresh);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F8FB),
        drawer: AppDrawer(
          currentSection: DrawerSection.fearGreed,
          homeBuilder: (context) => LandingScreen(),
          newsBuilder: (context) => HomeScreen(),
          fearGreedBuilder: (context) => FearGreedPage(),
          marketBuilder: (context) => MarketPage(),
        ),
        appBar: AppBar(
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu_rounded),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          title: const Text(
            '공포탐욕지수',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w900,
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black87),
          actions: [
            IconButton(
              tooltip: '새로고침',
              onPressed: _reload,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
          bottom: TabBar(
            labelColor: Colors.blue.shade800,
            unselectedLabelColor: Colors.grey.shade600,
            indicatorColor: Colors.blue.shade700,
            labelStyle: const TextStyle(fontWeight: FontWeight.w900),
            tabs: const [
              Tab(text: '증시'),
              Tab(text: '비트코인'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _StockFearGreedTab(future: _stockFuture, onRetry: _reload),
            _CryptoFearGreedTab(future: _cryptoFuture, onRetry: _reload),
          ],
        ),
      ),
    );
  }
}

class _StockFearGreedTab extends StatelessWidget {
  final Future<_StockFearGreedBundle> future;
  final VoidCallback onRetry;

  const _StockFearGreedTab({
    required this.future,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_StockFearGreedBundle>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingState();
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return _ErrorState(onRetry: onRetry);
        }

        final data = snapshot.data!;

        return _ResponsiveScroll(
          onRefresh: onRetry,
          children: [
            _SectionHeader(
              title: '증시 심리',
              subtitle: 'CNN 참고 지수와 Pulse 자체 AI 점수를 함께 봅니다.',
            ),
            _GaugeCard(
              index: data.cnn,
              title: 'CNN Fear & Greed 참고 지수',
              subtitle: '미국 증시 기준 · 외부 참고 데이터',
              footer: '나중에 자체 AI 지표가 안정화되면 의존도를 줄일 예정입니다.',
            ),
            const SizedBox(height: 16),
            _GaugeCard(
              index: data.ai,
              title: 'AI 증시 심리 점수',
              subtitle: '뉴스 감정, 이슈 강도, 리스크 키워드 기반',
              footer: data.ai.summary,
            ),
            if (data.ai.components.isNotEmpty) ...[
              const SizedBox(height: 16),
              _ComponentCard(components: data.ai.components),
            ],
          ],
        );
      },
    );
  }
}

class _CryptoFearGreedTab extends StatelessWidget {
  final Future<_FearGreedIndex> future;
  final VoidCallback onRetry;

  const _CryptoFearGreedTab({
    required this.future,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_FearGreedIndex>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingState();
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return _ErrorState(onRetry: onRetry);
        }

        return _ResponsiveScroll(
          onRefresh: onRetry,
          children: [
            _SectionHeader(
              title: '비트코인 심리',
              subtitle: '기존 Crypto Fear & Greed Index는 별도 탭에서 유지합니다.',
            ),
            _GaugeCard(
              index: snapshot.data!,
              title: 'Crypto Fear & Greed Index',
              subtitle: '비트코인/암호화폐 시장 기준',
              footer: '증시 심리와 비트코인 심리는 서로 다른 시장 기준입니다.',
            ),
          ],
        );
      },
    );
  }
}

class _ResponsiveScroll extends StatelessWidget {
  final List<Widget> children;
  final VoidCallback onRefresh;

  const _ResponsiveScroll({
    required this.children,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final horizontal = width < 640 ? 16.0 : 28.0;

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(horizontal, 20, horizontal, 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _GaugeCard extends StatelessWidget {
  final _FearGreedIndex index;
  final String title;
  final String subtitle;
  final String footer;

  const _GaugeCard({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final gaugeSize = width < 640 ? width * 0.72 : 360.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: index.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.speed_rounded,
                  color: index.color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Center(
            child: SizedBox(
              width: gaugeSize,
              height: gaugeSize * 0.56,
              child: SfRadialGauge(
                axes: [
                  RadialAxis(
                    minimum: 0,
                    maximum: 100,
                    startAngle: 180,
                    endAngle: 0,
                    showLabels: false,
                    showTicks: false,
                    radiusFactor: 1,
                    ranges: [
                      GaugeRange(
                        startValue: 0,
                        endValue: 25,
                        color: Colors.red.shade600,
                      ),
                      GaugeRange(
                        startValue: 25,
                        endValue: 45,
                        color: Colors.orange.shade500,
                      ),
                      GaugeRange(
                        startValue: 45,
                        endValue: 55,
                        color: Colors.amber.shade500,
                      ),
                      GaugeRange(
                        startValue: 55,
                        endValue: 75,
                        color: Colors.lightGreen.shade500,
                      ),
                      GaugeRange(
                        startValue: 75,
                        endValue: 100,
                        color: Colors.green.shade600,
                      ),
                    ],
                    pointers: [
                      NeedlePointer(
                        value: index.score.toDouble(),
                        enableAnimation: true,
                        animationDuration: 900,
                        needleColor: Colors.black87,
                        needleLength: 0.72,
                        needleStartWidth: 1,
                        needleEndWidth: 5,
                        knobStyle: const KnobStyle(color: Colors.black87),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Center(
            child: Column(
              children: [
                Text(
                  '${index.score}',
                  style: TextStyle(
                    fontSize: width < 640 ? 38 : 46,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  index.koreanRating,
                  style: TextStyle(
                    fontSize: 15,
                    color: index.color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            footer,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 13,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            index.source,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComponentCard extends StatelessWidget {
  final Map<String, int> components;

  const _ComponentCard({required this.components});

  @override
  Widget build(BuildContext context) {
    final labels = {
      'newsSentiment': '뉴스 감정',
      'issueMomentum': '이슈 강도',
      'riskBalance': '리스크 균형',
      'importance': '뉴스 중요도',
    };

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AI 점수 구성',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 14),
          for (final entry in components.entries) ...[
            _ComponentBar(
              label: labels[entry.key] ?? entry.key,
              value: entry.value,
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _ComponentBar extends StatelessWidget {
  final String label;
  final int value;

  const _ComponentBar({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '$value',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: value.clamp(0, 100) / 100,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(_scoreColor(value)),
          ),
        ),
      ],
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded,
                size: 48, color: Colors.grey.shade500),
            const SizedBox(height: 14),
            const Text(
              '지수를 불러오지 못했습니다.',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              '잠시 후 다시 시도해 주세요.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('다시 불러오기'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StockFearGreedBundle {
  final _FearGreedIndex cnn;
  final _FearGreedIndex ai;

  const _StockFearGreedBundle({
    required this.cnn,
    required this.ai,
  });
}

class _FearGreedIndex {
  final int score;
  final String rating;
  final String source;
  final String summary;
  final Map<String, int> components;

  const _FearGreedIndex({
    required this.score,
    required this.rating,
    required this.source,
    required this.summary,
    required this.components,
  });

  factory _FearGreedIndex.fromJson(
    Map<String, dynamic> json,
    String fallbackName,
  ) {
    final rawComponents = json['components'];
    final components = <String, int>{};
    if (rawComponents is Map<String, dynamic>) {
      for (final entry in rawComponents.entries) {
        final value = entry.value;
        components[entry.key] = value is num
            ? value.round()
            : int.tryParse(value?.toString() ?? '') ?? 0;
      }
    }

    final rawScore = json['score'];
    final score = rawScore is num
        ? rawScore.round()
        : int.tryParse(rawScore?.toString() ?? '') ?? 50;

    return _FearGreedIndex(
      score: score.clamp(0, 100),
      rating: json['rating']?.toString() ?? 'neutral',
      source: json['source']?.toString() ?? fallbackName,
      summary: json['summary']?.toString() ?? '',
      components: components,
    );
  }

  String get koreanRating => _translateRating(rating);

  Color get color => _scoreColor(score);
}

String _translateRating(String rating) {
  switch (rating.toLowerCase()) {
    case 'extreme fear':
      return '극단적 공포';
    case 'fear':
      return '공포';
    case 'neutral':
      return '중립';
    case 'greed':
      return '탐욕';
    case 'extreme greed':
      return '극단적 탐욕';
    default:
      return '중립';
  }
}

Color _scoreColor(int score) {
  if (score <= 25) return Colors.red.shade600;
  if (score <= 45) return Colors.orange.shade600;
  if (score <= 55) return Colors.amber.shade700;
  if (score <= 75) return Colors.lightGreen.shade700;
  return Colors.green.shade700;
}
