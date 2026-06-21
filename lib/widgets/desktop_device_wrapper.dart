import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class DesktopDeviceWrapper extends StatelessWidget {
  final Widget child;

  const DesktopDeviceWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // If screen size is mobile (< 600px), render fullscreen directly
    if (screenWidth <= 600) {
      return child;
    }

    return Scaffold(
      body: Stack(
        children: [
          // 1. Radial gradient background matching the HTML #fc-scene
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.5,
                  colors: [
                    Color(0xFF0C2030),
                    Color(0xFF0A1722),
                    Color(0xFF060E15),
                  ],
                  stops: [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),

          // 2. Skyline background image with linear gradient overlay matching #fc-backdrop
          Positioned.fill(
            child: Opacity(
              opacity: 0.75,
              child: Image.asset(
                'assets/bg-skyline.png',
                fit: BoxFit.cover,
                alignment: Alignment.bottomCenter,
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF060E15).withOpacity(0.55),
                    const Color(0xFF060E15).withOpacity(0.15),
                    const Color(0xFF060E15).withOpacity(0.0),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),

          // 3. Main desktop content structure
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Desktop Header matching HTML #fc-header
                  Container(
                    margin: const EdgeInsets.only(bottom: 24.0),
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/logo-mark.png',
                              width: 54,
                              height: 54,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'FUTURE CITY',
                                  style: AppTheme.getManrope(
                                    fontSize: 23,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    letterSpacing: 6.0,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'つくる、評価する、街に届く。',
                                  style: AppTheme.getNotoSansJP(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.accent,
                                    letterSpacing: 3.0,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'みんなのアイデアが、街の未来になる。',
                          style: AppTheme.getNotoSansJP(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 1.0,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  // Phone Frame Mockup matching HTML #fc-phone
                  Container(
                    width: 390,
                    height: 844,
                    decoration: BoxDecoration(
                      color: AppTheme.navy,
                      borderRadius: BorderRadius.circular(54),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.6),
                          blurRadius: 110,
                          offset: const Offset(0, 50),
                        ),
                        BoxShadow(
                          color: Colors.white.withOpacity(0.05),
                          blurRadius: 0,
                          spreadRadius: 2,
                        ),
                      ],
                      border: Border.all(
                        color: const Color(0xFF0A0F13),
                        width: 6,
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Inner content viewport with rounded corners matching #fc-phone-inner
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(47),
                            child: child,
                          ),
                        ),

                        // Notch overlay at the top matching #fc-notch
                        Positioned(
                          top: 5,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              width: 120,
                              height: 30,
                              decoration: const BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.only(
                                  bottomLeft: Radius.circular(20),
                                  bottomRight: Radius.circular(20),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Home Indicator bar at the bottom matching #fc-home-indicator
                        Positioned(
                          bottom: 9,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              width: 128,
                              height: 5,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
