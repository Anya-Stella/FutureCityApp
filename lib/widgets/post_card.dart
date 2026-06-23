import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PostCard extends StatelessWidget {
  final String title;
  final String imageUrl;
  final int likes;
  final int comments;
  final String? author;
  final VoidCallback? onTap;

  const PostCard({
    super.key,
    required this.title,
    required this.imageUrl,
    required this.likes,
    required this.comments,
    this.author,
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
          border: Border.all(color: const Color(0xFFECECEC), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with nearly square aspect ratio (e.g. 1 / 0.9)
            AspectRatio(
              aspectRatio: 1 / 0.9,
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: const Color(0xFFF9F9F9),
                    child: const Center(
                      child: CircularProgressIndicator(color: AppTheme.teal),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  color: const Color(0xFFF5F5F5),
                  child: const Center(
                    child: Icon(Icons.broken_image, color: Colors.grey, size: 24),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Title
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.getNotoSansJP(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                        height: 1.35,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Author: "by [display_name]"
                        if (author != null)
                          Text(
                            'by $author',
                            style: AppTheme.getNotoSansJP(
                              fontSize: 11,
                              color: Colors.black54,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 6),
                        // Stats row (heart and comment bubble)
                        Row(
                          children: [
                            const Icon(
                              Icons.favorite_border,
                              size: 13,
                              color: Colors.black45,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$likes',
                              style: AppTheme.getNotoSansJP(
                                fontSize: 11,
                                color: Colors.black54,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Icon(
                              Icons.chat_bubble_outline,
                              size: 13,
                              color: Colors.black45,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$comments',
                              style: AppTheme.getNotoSansJP(
                                fontSize: 11,
                                color: Colors.black54,
                                fontWeight: FontWeight.w600,
                              ),
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
