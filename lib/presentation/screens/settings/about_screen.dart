import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: false,
            snap: false,
            elevation: 0,
            centerTitle: true,
            title: Text(
              'About',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Title
                  Text(
                    'Curio',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Gap(8),
                  Text(
                    'Personalized YouTube Player',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Gap(8),
                  Text(
                    'Version 1.0.0',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Gap(32),

                  // Key Features
                  Text(
                    'Features',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Gap(16),

                  // Feature List without Card
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFeatureDetail(
                        'Offline Downloads',
                        'Download entire playlists or individual videos for offline viewing. Perfect for watching content without internet connection.',
                      ),
                      const Gap(16),
                      _buildFeatureDetail(
                        'Playlist Management',
                        'Browse, organize, and sync your YouTube playlists seamlessly. Access all your favorite content in one place.',
                      ),
                      const Gap(16),
                      _buildFeatureDetail(
                        'Progress Tracking',
                        'Automatically saves and syncs your viewing progress across all videos. Never lose your place again.',
                      ),
                      const Gap(16),
                      _buildFeatureDetail(
                        'Advanced Playback',
                        'Control playback speed, video quality, and enjoy Picture-in-Picture mode for multitasking.',
                      ),
                      const Gap(16),
                      _buildFeatureDetail(
                        'Customization',
                        'Personalize themes, colors, fonts, and interface to match your preference. Dark/light modes available.',
                      ),
                      const Gap(16),
                      _buildFeatureDetail(
                        'Multi-language Support',
                        'Available in English, Spanish, Hindi, and more languages for global accessibility.',
                      ),
                    ],
                  ),
                  const Gap(32),

                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureDetail(String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        const Gap(4),
        Text(
          description,
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
      ],
    );
  }
}

// Gap widget for consistency
class Gap extends StatelessWidget {
  final double size;
  const Gap(this.size, {super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: size);
  }
}
