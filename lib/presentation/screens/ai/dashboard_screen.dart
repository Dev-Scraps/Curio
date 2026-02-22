import 'package:curio/presentation/common/progress_indicators.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../../core/services/storage/database.dart';
import 'aichathistory.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Map<String, int> _aiCounts = {};
  Map<String, dynamic> _overallStats = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final db = ref.read(databaseServiceProvider);
      final aiCounts = await db.getAIHistoryCounts();

      // Calculate overall statistics
      final totalContent =
          (aiCounts['summary'] ?? 0) +
          (aiCounts['notes'] ?? 0) +
          (aiCounts['questions'] ?? 0) +
          (aiCounts['quiz'] ?? 0) +
          (aiCounts['analysis'] ?? 0);

      final mostUsedService = aiCounts.entries
          .where((e) => e.key != 'all')
          .fold<MapEntry<String, int>>(
            MapEntry('none', 0),
            (max, entry) => entry.value > max.value ? entry : max,
          );

      setState(() {
        _aiCounts = aiCounts;
        _overallStats = {
          'totalContent': totalContent,
          'mostUsedService': mostUsedService.key,
          'mostUsedCount': mostUsedService.value,
          'servicesUsed': aiCounts.entries.where((e) => e.value > 0).length,
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

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
              ' Dashboard',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          SliverToBoxAdapter(
            child: _isLoading ? _buildLoadingState() : _buildDashboardContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeHeader(),
          const Gap(32),
          _buildStatsOverview(),
          const Gap(32),
          _buildProgressSection(),
          const Gap(32),
          _buildServicesGrid(),
        ],
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    final totalContent = _overallStats['totalContent'] ?? 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary.withOpacity(0.1),
            Theme.of(context).colorScheme.primary.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Learning Journey',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w300,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const Gap(8),
          Text(
            '$totalContent pieces of AI-generated content',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const Gap(16),
        Row(
          children: [
            Expanded(
              child: _buildCleanStatCard(
                'Total Content',
                '${_overallStats['totalContent'] ?? 0}',
                Theme.of(context).colorScheme.primary,
              ),
            ),
            const Gap(16),
            Expanded(
              child: _buildCleanStatCard(
                'Services Used',
                '${_overallStats['servicesUsed'] ?? 0}/5',
                Theme.of(context).colorScheme.secondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCleanStatCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const Gap(4),
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection() {
    final servicesUsed = _overallStats['servicesUsed'] as int? ?? 0;
    final totalServices = 5;
    final progress = servicesUsed / totalServices;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Learning Progress',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const Gap(16),
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.secondary,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const Gap(12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$servicesUsed of $totalServices services explored',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServicesGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AI Services',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const Gap(16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.4,
          children: [
            _buildCleanServiceCard(
              'Summary',
              _aiCounts['summary'] ?? 0,
              Theme.of(context).colorScheme.tertiary,
              () => _navigateToHistory('summary', 'Summaries'),
            ),
            _buildCleanServiceCard(
              ' Notes',
              _aiCounts['notes'] ?? 0,
              Theme.of(context).colorScheme.primary,
              () => _navigateToHistory('notes', ' Notes'),
            ),
            _buildCleanServiceCard(
              'Analysis',
              _aiCounts['analysis'] ?? 0,
              Theme.of(context).colorScheme.secondary,
              () => _navigateToHistory('analysis', 'Analysis'),
            ),
            _buildCleanServiceCard(
              'Questions',
              _aiCounts['questions'] ?? 0,
              Theme.of(context).colorScheme.tertiaryContainer,
              () => _navigateToHistory('questions', 'Questions'),
            ),
            _buildCleanServiceCard(
              'Quiz',
              _aiCounts['quiz'] ?? 0,
              Theme.of(context).colorScheme.error,
              () => _navigateToHistory('quiz', 'Quizzes'),
            ),
            _buildCleanServiceCard(
              'All Content',
              (_aiCounts['summary'] ?? 0) +
                  (_aiCounts['notes'] ?? 0) +
                  (_aiCounts['questions'] ?? 0) +
                  (_aiCounts['quiz'] ?? 0) +
                  (_aiCounts['analysis'] ?? 0),
              Theme.of(context).colorScheme.onSurfaceVariant,
              () => _navigateToHistory('all', 'All AI Content'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCleanServiceCard(
    String title,
    int count,
    Color color,
    VoidCallback onTap,
  ) {
    final hasContent = count > 0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasContent
                ? color.withOpacity(0.3)
                : Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.shadow.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: hasContent
                    ? color
                    : Theme.of(context).colorScheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Spacer(),
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: hasContent ? color : null,
              ),
            ),
            const Gap(4),
            Text(
              hasContent ? '$count items' : 'Not started',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: M3CircularProgressIndicator(
                strokeWidth: 3,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const Gap(24),
            Text(
              'Loading dashboard...',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToHistory(String type, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AIHistoryListScreen(type: type, title: title),
      ),
    );
  }
}
