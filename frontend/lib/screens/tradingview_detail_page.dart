import 'package:flutter/material.dart';
import 'tradingview_chart.dart';

class TradingViewDetailPage extends StatefulWidget {
  final String symbol;
  final String title;

  const TradingViewDetailPage({
    super.key,
    required this.symbol,
    required this.title,
  });

  @override
  State<TradingViewDetailPage> createState() => _TradingViewDetailPageState();
}

class _TradingViewDetailPageState extends State<TradingViewDetailPage> {
  String _selectedPeriod = '일봉';

  static const Map<String, Map<String, String>> _periodConfig = {
    '일봉': {'interval': '1d', 'range': '6mo'},
    '주봉': {'interval': '1wk', 'range': '5y'},
    '월봉': {'interval': '1mo', 'range': '10y'},
  };

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final config = _periodConfig[_selectedPeriod]!;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text(
          '${widget.title} 차트',
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
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
                        Expanded(
                          child: Text(
                            widget.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        const Icon(Icons.show_chart_rounded, size: 18, color: Color(0xFF2563EB)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _periodConfig.keys.map((label) {
                        final selected = label == _selectedPeriod;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedPeriod = label;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                            decoration: BoxDecoration(
                              color: selected ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: selected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: selected ? Colors.white : const Color(0xFF334155),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                height: screenHeight * 0.68,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: TradingViewChart(
                  key: ValueKey('${widget.symbol}-$_selectedPeriod'),
                  symbol: widget.symbol,
                  interval: config['interval']!,
                  range: config['range']!,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
