import '../models/trend_item.dart';

class NewsCluster {
  final String key;
  final TrendItem representative;
  final List<TrendItem> items;

  const NewsCluster({
    required this.key,
    required this.representative,
    required this.items,
  });

  int get articleCount => items.length;

  int get sourceCount => items
      .map((item) => item.source.trim())
      .where((value) => value.isNotEmpty)
      .toSet()
      .length;
}

const Set<String> _stopWords = {
  '기자',
  '단독',
  '속보',
  '오늘',
  '이번',
  '관련',
  '발표',
  '예정',
  '대비',
  '통해',
  '위해',
  '위한',
  '따르면',
  '전했다',
  '밝혔다',
  '보고',
  '기사',
  '것으로',
  '이다',
  '된다',
  '있다',
  '하는',
  '했다',
  'news',
  'the',
  'report',
  'reports',
  'breaking',
  'update',
  'live',
  'photo',
  'video',
};

List<NewsCluster> groupSimilarNews(
  List<TrendItem> items, {
  int maxClusters = 20,
}) {
  if (items.isEmpty) return const [];

  final sortedItems = items.toList()
    ..sort((a, b) => _trendTime(b).compareTo(_trendTime(a)));

  final clusters = <_MutableCluster>[];

  for (final item in sortedItems) {
    final tokens = _tokens(item);
    final canonicalKey = _canonicalKey(item, tokens);

    _MutableCluster? bestCluster;
    double bestScore = 0;

    for (final cluster in clusters) {
      final score = _similarity(
        tokensA: tokens,
        canonicalKeyA: canonicalKey,
        tokensB: cluster.tokens,
        canonicalKeyB: cluster.key,
        linkA: item.link,
        linkB: cluster.representative.link,
      );

      if (score > bestScore) {
        bestScore = score;
        bestCluster = cluster;
      }
    }

    if (bestCluster != null && bestScore >= 0.55) {
      bestCluster.items.add(item);
      bestCluster.sourceSet.add(item.source.trim());

      if (_trendTime(item) > _trendTime(bestCluster.representative)) {
        bestCluster.representative = item;
        bestCluster.tokens = tokens;
        bestCluster.key = canonicalKey;
      }
      continue;
    }

    clusters.add(_MutableCluster(
      key: canonicalKey,
      representative: item,
      tokens: tokens,
      items: [item],
      sourceSet: {item.source.trim()},
    ));
  }

  return clusters
      .take(maxClusters)
      .map(
        (cluster) => NewsCluster(
          key: cluster.key,
          representative: cluster.representative,
          items: List<TrendItem>.unmodifiable(cluster.items),
        ),
      )
      .toList();
}

double _similarity({
  required Set<String> tokensA,
  required String canonicalKeyA,
  required Set<String> tokensB,
  required String canonicalKeyB,
  required String linkA,
  required String linkB,
}) {
  if (canonicalKeyA.isNotEmpty && canonicalKeyA == canonicalKeyB) {
    return 1.0;
  }

  final normalizedLinkA = _normalizeLink(linkA);
  final normalizedLinkB = _normalizeLink(linkB);
  if (normalizedLinkA.isNotEmpty && normalizedLinkA == normalizedLinkB) {
    return 1.0;
  }

  if (tokensA.isEmpty || tokensB.isEmpty) return 0;

  final intersection = tokensA.intersection(tokensB).length;
  final union = tokensA.union(tokensB).length;
  final jaccard = union == 0 ? 0.0 : intersection / union;
  final prefix = _prefixScore(tokensA, tokensB);

  return (jaccard * 0.8) + (prefix * 0.2);
}

double _prefixScore(Set<String> a, Set<String> b) {
  final listA = a.toList()..sort();
  final listB = b.toList()..sort();
  if (listA.isEmpty || listB.isEmpty) return 0;

  final headA = listA.first;
  final headB = listB.first;
  if (headA.isEmpty || headB.isEmpty) return 0;
  if (headA == headB) return 1;

  final minLen = headA.length < headB.length ? headA.length : headB.length;
  if (minLen < 3) return 0;

  var matched = 0;
  for (var i = 0; i < minLen; i++) {
    if (headA[i] != headB[i]) break;
    matched++;
  }
  return matched / minLen;
}

Set<String> _tokens(TrendItem item) {
  final raw = '${item.koreanTitle} ${item.summaryKr}';
  final normalized = raw
      .toLowerCase()
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll(RegExp(r'[^0-9A-Za-z\uAC00-\uD7A3\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  return normalized
      .split(' ')
      .map(_stripParticle)
      .map((value) => value.trim())
      .where((value) => value.length >= 2)
      .where((value) => !_stopWords.contains(value))
      .toSet();
}

String _canonicalKey(TrendItem item, Set<String> tokens) {
  final sortedTokens = tokens.toList()..sort();
  if (sortedTokens.isEmpty) return _normalizeLink(item.link);
  return sortedTokens.take(4).join('|');
}

String _stripParticle(String value) {
  return value.replaceAll(
    RegExp(r'(으로|에서|에게|에게서|까지|부터|처럼|보다|과|와|은|는|이|가|을|를|에|도|만|으로)$'),
    '',
  );
}

String _normalizeLink(String link) {
  final value = link.trim();
  if (value.isEmpty) return '';

  try {
    final uri = Uri.parse(value);
    final host = uri.host.toLowerCase();
    final path = uri.path.replaceAll(RegExp(r'/+$'), '');
    return '$host$path';
  } catch (_) {
    return value.toLowerCase();
  }
}

int _trendTime(TrendItem item) {
  return DateTime.tryParse(item.published)?.millisecondsSinceEpoch ??
      DateTime.tryParse(item.createdAt)?.millisecondsSinceEpoch ??
      0;
}

class _MutableCluster {
  String key;
  TrendItem representative;
  Set<String> tokens;
  final List<TrendItem> items;
  final Set<String> sourceSet;

  _MutableCluster({
    required this.key,
    required this.representative,
    required this.tokens,
    required this.items,
    required this.sourceSet,
  });
}
