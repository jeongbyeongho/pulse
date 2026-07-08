import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/trend_item.dart';
import '../models/trend_insight.dart';

/// API 통신 서비스
class ApiService {
  // Cloudflare Workers 주소
  static const String baseUrl = 'https://news-summarizer.bum2432.workers.dev';

  /// 최신 트렌드 목록 가져오기
  Future<List<TrendItem>> fetchTrends(
      {int limit = 20, int offset = 0, String category = '', String sort = 'latest', String period = ''}) async {
    try {
      print('🌐 Fetching from: $baseUrl/api/trends');
      final uri = Uri.parse('$baseUrl/api/trends?limit=$limit&offset=$offset'
          '&sort=${Uri.encodeComponent(sort)}'
          '${period.isNotEmpty ? '&period=${Uri.encodeComponent(period)}' : ''}'
          '${category.isNotEmpty ? '&category=${Uri.encodeComponent(category)}' : ''}');
      print('🔗 Full URI: $uri');
      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        print('✅ Response received: ${response.body.length} bytes');
        final jsonData = json.decode(utf8.decode(response.bodyBytes));

        if (jsonData['success'] == true) {
          final List<dynamic> trendsJson = jsonData['data'];
          print('✅ Parsed ${trendsJson.length} trends');
          return trendsJson.map((json) => TrendItem.fromJson(json)).toList();
        } else {
          throw Exception('API returned success=false');
        }
      } else {
        print('❌ HTTP Error: ${response.statusCode}');
        throw Exception('Failed to load trends: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Exception: $e');
      if (offset == 0) {
        // 첫 로드 실패 시 mock 데이터 대신 에러를 throw해서 UI에서 처리
        print('API Error: $e');
        throw Exception('서버에 연결할 수 없습니다');
      }
      return [];
    }
  }

  Future<TrendInsightSnapshot> fetchTrendInsights({
    String period = '24h',
    String category = '',
  }) async {
    final keywordsFuture = fetchTrendKeywords(
      period: period,
      category: category,
      limit: 10,
    );
    final risingFuture = fetchRisingIssues(
      period: '1h',
      category: category,
      limit: 5,
    );
    final sentimentFuture = fetchNewsSentiment(
      period: period,
      category: category,
    );

    final results = await Future.wait<dynamic>([
      keywordsFuture,
      risingFuture,
      sentimentFuture,
    ]);

    return TrendInsightSnapshot(
      keywords: results[0] as List<TrendKeyword>,
      risingIssues: results[1] as List<RisingIssue>,
      sentiment: results[2] as NewsSentimentSummary,
    );
  }

  Future<List<IssueTimelineItem>> fetchTrendTimeline({
    String period = '24h',
    String category = '',
    int limit = 10,
    int minScore = 0,
  }) async {
    final uri = Uri.parse('$baseUrl/api/trend/timeline').replace(
      queryParameters: {
        'period': period,
        'limit': '$limit',
        'min_score': '$minScore',
        if (category.isNotEmpty) 'category': category,
      },
    );
    final jsonData = await _getJson(uri);
    final items = jsonData['items'] as List<dynamic>? ?? const [];

    return items
        .map((item) => IssueTimelineItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<TrendItem>> fetchIssueTimelineNews({
    required String issueId,
    String? keyword,
    List<int> newsIds = const [],
  }) async {
    final uri = Uri.parse('$baseUrl/api/trend/timeline/${Uri.encodeComponent(issueId)}/news').replace(
      queryParameters: {
        if (keyword != null && keyword.trim().isNotEmpty) 'keyword': keyword.trim(),
        if (newsIds.isNotEmpty) 'news_ids': newsIds.join(','),
      },
    );
    final jsonData = await _getJson(uri);
    final items = jsonData['items'] as List<dynamic>? ?? const [];

    return items
        .map((item) => TrendItem.fromJson(_newsItemToTrendJson(item)))
        .toList();
  }

  Future<List<TrendKeyword>> fetchTrendKeywords({
    String period = '24h',
    String category = '',
    int limit = 10,
  }) async {
    final uri = Uri.parse('$baseUrl/api/trends/keywords').replace(
      queryParameters: {
        'period': period,
        'limit': '$limit',
        if (category.isNotEmpty) 'category': category,
      },
    );
    final jsonData = await _getJson(uri);
    final items = jsonData['items'] as List<dynamic>? ?? const [];

    return items
        .map((item) => TrendKeyword.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<RisingIssue>> fetchRisingIssues({
    String period = '1h',
    String category = '',
    int limit = 5,
  }) async {
    final uri = Uri.parse('$baseUrl/api/trends/rising').replace(
      queryParameters: {
        'period': period,
        'limit': '$limit',
        if (category.isNotEmpty) 'category': category,
      },
    );
    final jsonData = await _getJson(uri);
    final items = jsonData['items'] as List<dynamic>? ?? const [];

    return items
        .map((item) => RisingIssue.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<NewsSentimentSummary> fetchNewsSentiment({
    String period = '24h',
    String category = '',
    String keyword = '',
  }) async {
    final uri = Uri.parse('$baseUrl/api/trends/sentiment').replace(
      queryParameters: {
        'period': period,
        if (category.isNotEmpty) 'category': category,
        if (keyword.isNotEmpty) 'keyword': keyword,
      },
    );
    final jsonData = await _getJson(uri);

    return NewsSentimentSummary.fromJson(jsonData);
  }

  Future<KeywordNewsResult> fetchNewsByKeyword({
    required String keyword,
    String period = '24h',
    String category = '',
    int limit = 20,
  }) async {
    final uri = Uri.parse('$baseUrl/api/news/by-keyword').replace(
      queryParameters: {
        'keyword': keyword,
        'period': period,
        'limit': '$limit',
        if (category.isNotEmpty) 'category': category,
      },
    );
    final jsonData = await _getJson(uri);
    final items = jsonData['items'] as List<dynamic>? ?? const [];

    return KeywordNewsResult(
      keyword: jsonData['keyword'] as String? ?? keyword,
      total: _asInt(jsonData['total']),
      items: items
          .map((item) => TrendItem.fromJson(_newsItemToTrendJson(item)))
          .toList(),
    );
  }

  Future<List<TrendItem>> searchNews({
    required String query,
    String category = '',
    String period = '24h',
    String sort = 'latest',
    int limit = 20,
  }) async {
    final uri = Uri.parse('$baseUrl/api/news/search').replace(
      queryParameters: {
        'q': query,
        'period': period,
        'sort': sort,
        'limit': '$limit',
        if (category.isNotEmpty) 'category': category,
      },
    );
    final jsonData = await _getJson(uri);
    final items = jsonData['items'] as List<dynamic>? ?? const [];

    return items
        .map((item) => TrendItem.fromJson(_newsItemToTrendJson(item)))
        .toList();
  }

  /// 특정 트렌드 상세 정보 가져오기
  Future<TrendItem?> fetchTrendDetail(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/trends/$id'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonData = json.decode(utf8.decode(response.bodyBytes));

        if (jsonData['success'] == true) {
          return TrendItem.fromJson(jsonData['data']);
        }
      }
      return null;
    } catch (e) {
      print('API Error: $e');
      return null;
    }
  }

  /// 스케줄러 상태 확인
  Future<Map<String, dynamic>> getSchedulerStatus() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/scheduler/status'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'status': 'error'};
    } catch (e) {
      print('API Error: $e');
      return {'status': 'offline'};
    }
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final response = await http.get(
      uri,
      headers: {'Content-Type': 'application/json'},
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('API error: ${response.statusCode}');
    }

    final jsonData =
        json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

    if (jsonData['success'] == false) {
      throw Exception(jsonData['error'] ?? 'API returned success=false');
    }

    return jsonData;
  }

  Map<String, dynamic> _newsItemToTrendJson(dynamic item) {
    final json = item as Map<String, dynamic>;

    return {
      'id': json['id'],
      'korean_title': json['title'],
      'original_title': json['original_title'] ?? json['title'],
      'summary_kr': json['summary'],
      'importance': json['importance'],
      'tickers': const <String>[],
      'category': json['category'],
      'link': json['link'],
      'source': json['source'],
      'published': json['publishedAt'],
      'created_at': json['publishedAt'],
      'view_count': 0,
    };
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
