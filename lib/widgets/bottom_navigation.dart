import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_theme.dart';

class CustomBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const CustomBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double safeBottom = MediaQuery.of(context).padding.bottom;
    final double bottomPadding = safeBottom > 0 ? 0.0 : 26.0;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xF7FFFFFF), // background: rgba(255, 255, 255, 0.97)
        border: Border(
          top: BorderSide(color: AppTheme.border, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(top: 12, bottom: bottomPadding, left: 4, right: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildNavItem(
                index: 0,
                label: 'ホーム',
                svgString: (fill, stroke) => '''
                  <svg width="24" height="24" viewBox="0 0 24 24" fill="$fill" stroke="$stroke" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M10 20.5v-5.5h4v5.5h5v-9.2h2.2L12 3 0.8 11.3H3v9.2z"/>
                  </svg>
                ''',
              ),
              _buildNavItem(
                index: 1,
                label: 'フリック',
                svgString: (fill, stroke) => '''
                  <svg width="24" height="24" viewBox="0 0 24 24" fill="$fill" stroke="$stroke" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">
                    <rect x="8.5" y="3.5" width="12" height="17" rx="2.4"/>
                    <path d="M4.5 6.5C3.7 6.8 3.2 7.7 3.5 8.6L7 18.4" fill="none"/>
                  </svg>
                ''',
              ),
              _buildCenterCreateItem(),
              _buildNavItem(
                index: 3,
                label: '統計',
                svgString: (fill, stroke) => '''
                  <svg width="24" height="24" viewBox="0 0 24 24" fill="$fill" stroke="$stroke" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">
                    <rect x="3" y="12" width="4" height="8" rx="1"/>
                    <rect x="10" y="7" width="4" height="13" rx="1"/>
                    <rect x="17" y="3.5" width="4" height="16.5" rx="1"/>
                  </svg>
                ''',
              ),
              _buildNavItem(
                index: 4,
                label: 'マイページ',
                svgString: (fill, stroke) => '''
                  <svg width="24" height="24" viewBox="0 0 24 24" fill="$fill" stroke="$stroke" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">
                    <circle cx="12" cy="8" r="4.2"/>
                    <path d="M4 20.5c0-4.2 3.7-7 8-7s8 2.8 8 7z"/>
                  </svg>
                ''',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String label,
    required String Function(String fill, String stroke) svgString,
  }) {
    final bool isActive = currentIndex == index;
    final String fill = isActive ? '#006C74' : 'none';
    final String stroke = isActive ? '#006C74' : '#6E777C';
    final Color textColor = isActive ? AppTheme.teal : AppTheme.sub;
    final FontWeight fontWeight = isActive ? FontWeight.w700 : FontWeight.w600;

    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 56,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            SvgPicture.string(
              svgString(fill, stroke),
              width: 24,
              height: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTheme.getNotoSansJP(
                fontSize: 10,
                fontWeight: fontWeight,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterCreateItem() {
    return GestureDetector(
      onTap: () => onTap(2),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 56,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF070D14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF070D14).withOpacity(0.30),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: SvgPicture.string(
                  '''
                  <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round">
                    <path d="M12 5v14M5 12h14"/>
                  </svg>
                  ''',
                  width: 22,
                  height: 22,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'つくる',
              style: AppTheme.getNotoSansJP(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppTheme.sub,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
