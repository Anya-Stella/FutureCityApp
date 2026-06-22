import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PostCard extends StatelessWidget {
  final String title;
  final String imageUrl;
  final int likes;
  final int comments;
  final String? author;
  final String? area;
  final String? ago;
  final VoidCallback? onTap;

  const PostCard({
    super.key,
    required this.title,
    required this.imageUrl,
    required this.likes,
    required this.comments,
    this.author,
    this.area,
    this.ago,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Image with 57% aspect ratio (height = 57% of width, which is aspect ratio of 1 / 0.57)
            AspectRatio(
              aspectRatio: 1 / 0.57,
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
                  child: Icon(Icons.broken_image, color: Colors.white24, size: 24),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.getNotoSansJP(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.text,
                      height: 1.45,
                      letterSpacing: -0.01,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Metadata (Author/Area/Ago) if provided
                  if (author != null || area != null || ago != null) ...[
                    Text(
                      [
                        if (author != null) author,
                        if (area != null) area,
                        if (ago != null) ago,
                      ].join('・'),
                      style: AppTheme.getNotoSansJP(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.sub,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                  ],
                  // Actions (Likes & Comments)
                  Row(
                    children: [
                      // Likes Icon + Text
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.favorite_border,
                            size: 12,
                            color: AppTheme.sub,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$likes',
                            style: AppTheme.getNotoSansJP(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.sub,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      // Comments Icon + Text
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.chat_bubble_outline,
                            size: 12,
                            color: AppTheme.sub,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$comments',
                            style: AppTheme.getNotoSansJP(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.sub,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
