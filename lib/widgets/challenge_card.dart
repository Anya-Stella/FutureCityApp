import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ChallengeCard extends StatelessWidget {
  final String title;
  final String description;
  final String imageUrl;
  final String deadline;
  final String buttonText;
  final VoidCallback? onTap;

  const ChallengeCard({
    super.key,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.deadline,
    this.buttonText = '参加で100ポイント',
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 190,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0C1920).withOpacity(0.10),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(color: AppTheme.teal),
                  );
                },
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Icon(Icons.broken_image, color: Colors.white24, size: 30),
                ),
              ),
            ),
            // Gradient Overlay
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: const Alignment(-1.0, -0.3),
                    end: const Alignment(1.0, 0.3),
                    colors: [
                      const Color(0xFF060F14).withOpacity(0.90),
                      const Color(0xFF060F14).withOpacity(0.78),
                      const Color(0xFF060F14).withOpacity(0.34),
                      const Color(0xFF060F14).withOpacity(0.05),
                    ],
                    stops: const [0.0, 0.32, 0.60, 1.0],
                  ),
                ),
              ),
            ),
            // Content
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      title,
                      style: AppTheme.getNotoSansJP(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 5.28, // 0.22 * 24
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Description
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 230),
                      child: Text(
                        description,
                        style: AppTheme.getNotoSansJP(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withOpacity(0.9),
                          height: 1.65,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Deadline
                    Text(
                      '応募締切 $deadline',
                      style: AppTheme.getNotoSansJP(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // White Button
                    GestureDetector(
                      onTap: onTap,
                      child: Container(
                        height: 34,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.photo_camera,
                              size: 13,
                              color: AppTheme.text,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              buttonText,
                              style: AppTheme.getNotoSansJP(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.text,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
