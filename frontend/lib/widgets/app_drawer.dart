import 'package:flutter/material.dart';

enum DrawerSection {
  home,
  news,
  fearGreed,
  market,
}

class AppDrawer extends StatelessWidget {
  final DrawerSection currentSection;
  final WidgetBuilder homeBuilder;
  final WidgetBuilder newsBuilder;
  final WidgetBuilder fearGreedBuilder;
  final WidgetBuilder marketBuilder;

  const AppDrawer({
    super.key,
    required this.currentSection,
    required this.homeBuilder,
    required this.newsBuilder,
    required this.fearGreedBuilder,
    required this.marketBuilder,
  });

  @override
  Widget build(BuildContext context) {
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
                        if (currentSection != DrawerSection.home) {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: homeBuilder),
                          );
                        }
                      },
                    ),
                    const Divider(height: 1),
                    _DrawerMenuItem(
                      icon: Icons.newspaper_rounded,
                      title: '실시간 뉴스',
                      subtitle: '최신 뉴스 확인',
                      onTap: () {
                        Navigator.pop(context);
                        if (currentSection != DrawerSection.news) {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: newsBuilder),
                          );
                        }
                      },
                    ),
                    const Divider(height: 1),
                    _DrawerMenuItem(
                      icon: Icons.psychology_rounded,
                      title: '공포탐욕지수',
                      subtitle: '시장 심리 확인',
                      onTap: () {
                        Navigator.pop(context);
                        if (currentSection != DrawerSection.fearGreed) {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: fearGreedBuilder),
                          );
                        }
                      },
                    ),
                    const Divider(height: 1),
                    _DrawerMenuItem(
                      icon: Icons.show_chart_rounded,
                      title: '증시',
                      subtitle: '주요 지수 및 종목',
                      onTap: () {
                        Navigator.pop(context);
                        if (currentSection != DrawerSection.market) {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: marketBuilder),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
