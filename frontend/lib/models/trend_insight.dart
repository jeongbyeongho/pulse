import 'trend_item.dart';

class TrendKeyword {
  final String keyword;
  final String category;
  final int newsCount;
  final int rank;
  final double score;
  final String representativeTitle;
  final int? sentimentTemperature;

  const TrendKeyword({
    required this.keyword,
    required this.category,
    required this.newsCount,
    required this.rank,
    required this.score,
    required this.representativeTitle,
    this.sentimentTemperature,
  });

  factory TrendKeyword.fromJson(Map<String, dynamic> json) {
    return TrendKeyword(
      keyword: json['keyword'] as String? ?? '',
      category: json['category'] as String? ?? '',
      newsCount: _asInt(json['newsCount']),
      rank: _asInt(json['rank']),
      score: _asDouble(json['score']),
      representativeTitle: json['representativeTitle'] as String? ?? '',
      sentimentTemperature: json['sentimentTemperature'] == null
          ? null
          : _asInt(json['sentimentTemperature']),
    );
  }
}

class RisingIssue {
  final String keyword;
  final String category;
  final int currentCount;
  final int previousCount;
  final int increaseCount;
  final bool isNew;
  final int growthRate;
  final double score;
  final String representativeTitle;
  final int? representativeNewsId;

  const RisingIssue({
    required this.keyword,
    required this.category,
    required this.currentCount,
    required this.previousCount,
    required this.increaseCount,
    required this.isNew,
    required this.growthRate,
    required this.score,
    required this.representativeTitle,
    this.representativeNewsId,
  });

  factory RisingIssue.fromJson(Map<String, dynamic> json) {
    final currentCount = _asInt(json['currentCount']);
    final previousCount = _asInt(json['previousCount']);

    return RisingIssue(
      keyword: json['keyword'] as String? ?? '',
      category: json['category'] as String? ?? '',
      currentCount: currentCount,
      previousCount: previousCount,
      increaseCount: json['increaseCount'] == null
          ? currentCount - previousCount
          : _asInt(json['increaseCount']),
      isNew: json['isNew'] is bool ? json['isNew'] as bool : previousCount == 0,
      growthRate: _asInt(json['growthRate']),
      score: _asDouble(json['score']),
      representativeTitle: json['representativeTitle'] as String? ?? '',
      representativeNewsId: json['representativeNewsId'] == null
          ? null
          : _asInt(json['representativeNewsId']),
    );
  }
}

class NewsSentimentSummary {
  final int temperature;
  final String label;
  final int positiveRatio;
  final int neutralRatio;
  final int negativeRatio;
  final int count;
  final String summary;

  const NewsSentimentSummary({
    required this.temperature,
    required this.label,
    required this.positiveRatio,
    required this.neutralRatio,
    required this.negativeRatio,
    required this.count,
    required this.summary,
  });

  factory NewsSentimentSummary.fromJson(Map<String, dynamic> json) {
    return NewsSentimentSummary(
      temperature: _asInt(json['temperature']),
      label: json['label'] as String? ?? 'neutral',
      positiveRatio: _asInt(json['positiveRatio']),
      neutralRatio: _asInt(json['neutralRatio']),
      negativeRatio: _asInt(json['negativeRatio']),
      count: _asInt(json['count']),
      summary: json['summary'] as String? ?? '',
    );
  }
}

class TrendInsightSnapshot {
  final List<TrendKeyword> keywords;
  final List<RisingIssue> risingIssues;
  final NewsSentimentSummary sentiment;

  const TrendInsightSnapshot({
    required this.keywords,
    required this.risingIssues,
    required this.sentiment,
  });
}

class KeywordNewsResult {
  final String keyword;
  final int total;
  final List<TrendItem> items;

  const KeywordNewsResult({
    required this.keyword,
    required this.total,
    required this.items,
  });
}

class IssueTimelineItem {
  final String id;
  final int rank;
  final String period;
  final String category;
  final String keyword;
  final String title;
  final String summary;
  final int articleCount;
  final int sourceCount;
  final List<int> newsIds;
  final double growthRate;
  final double score;
  final int? sentimentTemperature;
  final String stage;
  final String firstSeenAt;
  final String lastSeenAt;

  const IssueTimelineItem({
    required this.id,
    required this.rank,
    required this.period,
    required this.category,
    required this.keyword,
    required this.title,
    required this.summary,
    required this.articleCount,
    required this.sourceCount,
    required this.newsIds,
    required this.growthRate,
    required this.score,
    required this.sentimentTemperature,
    required this.stage,
    required this.firstSeenAt,
    required this.lastSeenAt,
  });

  factory IssueTimelineItem.fromJson(Map<String, dynamic> json) {
    return IssueTimelineItem(
      id: json['id'] as String? ?? '',
      rank: _asInt(json['rank']),
      period: json['period'] as String? ?? '24h',
      category: json['category'] as String? ?? '',
      keyword: json['keyword'] as String? ?? '',
      title: json['title'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      articleCount: _asInt(json['articleCount']),
      sourceCount: _asInt(json['sourceCount']),
      newsIds: (json['newsIds'] as List<dynamic>? ?? const [])
          .map((value) => _asInt(value))
          .where((value) => value > 0)
          .toList(),
      growthRate: _asDouble(json['growthRate']),
      score: _asDouble(json['score']),
      sentimentTemperature: json['sentimentTemperature'] == null
          ? null
          : _asInt(json['sentimentTemperature']),
      stage: json['stage'] as String? ?? 'rising',
      firstSeenAt: json['firstSeenAt'] as String? ?? '',
      lastSeenAt: json['lastSeenAt'] as String? ?? '',
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _asDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
