import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../widgets/app_drawer.dart';
import 'fear_greed_page.dart';
import 'home_screen.dart';
import 'landing_screen.dart';
import 'mini_chart_card.dart';

class MarketPage extends StatefulWidget {
  const MarketPage({super.key});

  @override
  State<MarketPage> createState() => _MarketPageState();
}

class _MarketPageState extends State<MarketPage> {
  bool _isLoading = true;
  String _errorMessage = '';
  List<Map<String, dynamic>> _marketDataList = [];

  final List<Map<String, dynamic>> _targetStocks = [
    {'yfSymbol': '^KS11', 'symbol': 'KOSPI', 'tvSymbol': 'KRX:KOSPI', 'title': '코스피', 'prefix': ''},
    {'yfSymbol': '^KQ11', 'symbol': 'KOSDAQ', 'tvSymbol': 'KRX:KOSDAQ', 'title': '코스닥', 'prefix': ''},
    {'yfSymbol': '^DJI', 'symbol': 'DJI', 'tvSymbol': 'TVC:DJI', 'title': '다우존스', 'prefix': ''},
    {'yfSymbol': '^IXIC', 'symbol': 'IXIC', 'tvSymbol': 'NASDAQ:IXIC', 'title': '나스닥 종합', 'prefix': ''},
    {'yfSymbol': '^GSPC', 'symbol': 'SPX', 'tvSymbol': 'SP:SPX', 'title': 'S&P 500', 'prefix': ''},
    {'yfSymbol': 'KRW=X', 'symbol': 'USDKRW', 'tvSymbol': 'FX_IDC:USDKRW', 'title': '달러/원 환율', 'prefix': '₩'},
    {'yfSymbol': '005930.KS', 'symbol': '005930', 'tvSymbol': 'KRX:005930', 'title': '삼성전자', 'prefix': '₩'},
    {'yfSymbol': '000660.KS', 'symbol': '000660', 'tvSymbol': 'KRX:000660', 'title': 'SK하이닉스', 'prefix': '₩'},
    {'yfSymbol': 'AAPL', 'symbol': 'AAPL', 'tvSymbol': 'NASDAQ:AAPL', 'title': 'Apple', 'prefix': '\$'},
    {'yfSymbol': 'NVDA', 'symbol': 'NVDA', 'tvSymbol': 'NASDAQ:NVDA', 'title': 'NVIDIA', 'prefix': '\$'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchRealtimeMarketData();
  }

  Future<void> _fetchRealtimeMarketData() async {
    try {
      final symbolsQuery = _targetStocks.map((e) => e['yfSymbol']).join(',');
      final uri = Uri.parse(
        'https://news-summarizer.bum2432.workers.dev/api/market-data?symbols=$symbolsQuery',
      );
      final response = await http.get(uri);

      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode}');
      }

      final decodedData = json.decode(response.body) as Map<String, dynamic>;
      if (decodedData['success'] != true) {
        throw Exception('API Success is false');
      }

      final List<dynamic> apiResults = decodedData['data'] as List<dynamic>;
      final mergedList = <Map<String, dynamic>>[];

      for (final config in _targetStocks) {
        dynamic apiData;
        for (final item in apiResults) {
          if (item['symbol'] == config['yfSymbol']) {
            apiData = item;
            break;
          }
        }

        if (apiData != null && apiData['error'] == null) {
          mergedList.add({
            ...config,
            'currentPrice': (apiData['currentPrice'] as num).toDouble(),
            'percentChange': (apiData['percentChange'] as num).toDouble(),
            'chartData': (apiData['chartData'] as List<dynamic>)
                .map((e) => (e as num).toDouble())
                .toList(),
          });
        }
      }

      setState(() {
        _marketDataList = mergedList;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _errorMessage = '실시간 데이터를 불러오지 못했습니다.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    var crossAxisCount = 4;
    if (screenWidth < 1100) crossAxisCount = 3;
    if (screenWidth < 800) crossAxisCount = 2;

    return Scaffold(
      backgroundColor: Colors.transparent,
      drawer: AppDrawer(
        currentSection: DrawerSection.market,
        homeBuilder: (context) => LandingScreen(),
        newsBuilder: (context) => HomeScreen(),
        fearGreedBuilder: (context) => FearGreedPage(),
        marketBuilder: (context) => MarketPage(),
      ),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.black87),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text(
          '증시 동향',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchRealtimeMarketData();
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.red),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '글로벌 주요 지수와 종목 흐름',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 24),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 24,
                        mainAxisSpacing: 24,
                        childAspectRatio: 1.0,
                        children: _marketDataList.map((data) {
                          return MiniChartCard(
                            symbol: data['symbol'],
                            tvSymbol: data['tvSymbol'],
                            title: data['title'],
                            prefix: data['prefix'],
                            currentPrice: data['currentPrice'],
                            percentChange: data['percentChange'],
                            chartData: data['chartData'],
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
    );
  }
}
