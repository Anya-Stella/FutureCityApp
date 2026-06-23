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
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0D2230).withOpacity(0.07),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          children: [
            Flexible(
              flex: 4,
              child: SizedBox(
                width: double.infinity,
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: AppTheme.uiGrey,
                            child: const Center(
                              child: CircularProgressIndicator(color: AppTheme.teal, strokeWidth: 2),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: AppTheme.uiGrey,
                          child: const Center(
                            child: Icon(Icons.broken_image, color: Colors.white54, size: 24),
                          ),
                        ),
                      )
                    : Container(color: AppTheme.uiGrey),
              ),
            ),
            Flexible(
              flex: 3,
              child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Title (上部)
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.getNotoSansJP(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.text,
                      height: 1.4,
                      letterSpacing: -0.01,
                    ),
                  ),
                  // by + いいね/コメント (下部)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  // Metadata (Author/Area/Ago) if provided
                  if (author != null || area != null || ago != null) ...[
                    Text(
                      author != null && author!.startsWith('by ')
                          ? author!
                          : [
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
                    const SizedBox(height: 5),
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
