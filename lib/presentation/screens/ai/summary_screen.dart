import 'package:curio/presentation/common/progress_indicators.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../domain/entities/video.dart';
import '../../../domain/entities/study_material.dart';
import '../../../core/services/ai/learning.dart';
import '../../../core/services/storage/database.dart';
import '../../../core/services/storage/storage.dart';

class SummaryScreen extends ConsumerStatefulWidget {
  final Video? video;
  final StudyMaterial? studyMaterial;
  final bool autoGenerate;

  const SummaryScreen({
    super.key,
    this.video,
    this.studyMaterial,
    this.autoGenerate = false,
  });

  @override
  ConsumerState<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends ConsumerState<SummaryScreen> {
  StudyMaterial? _studyMaterial;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _studyMaterial = widget.studyMaterial;
    if (_studyMaterial == null && widget.video != null) {
      _loadStudyMaterial(forceRegenerate: widget.autoGenerate);
    }
  }

  Future<void> _loadStudyMaterial({bool forceRegenerate = false}) async {
    if (widget.video == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final db = ref.read(databaseServiceProvider);
      final existing = await db.getStudyMaterial(widget.video!.id);

      if (existing != null && !forceRegenerate) {
        setState(() {
          _studyMaterial = StudyMaterial.fromMap(existing);
          _isLoading = false;
        });
      } else {
        await _generateStudyMaterial();
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _generateStudyMaterial() async {
    if (widget.video == null) {
      setState(() {
        _error = 'No video specified for generating summary.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final aiService = ref.read(aiLearningServiceProvider);
      final storage = ref.read(storageServiceProvider);

      final transcript = 'Sample transcript for ${widget.video!.title}';
      final selectedProvider = storage.selectedAIProvider;
      final apiKey = selectedProvider == 'perplexity'
          ? storage.perplexityApiKey
          : storage.geminiApiKey;

      if (apiKey == null || apiKey.isEmpty) {
        throw Exception(
          'API key not configured. Please go to Settings > AI Configuration and add your API key to use AI features.',
        );
      }

      String summary;
      try {
        summary = await aiService
            .generateSummary(
              transcript,
              videoTitle: widget.video!.title,
              apiKey: apiKey,
            )
            .timeout(
              Duration(seconds: 30),
              onTimeout: () {
                throw Exception(
                  'AI service request timed out. Please check your internet connection and try again.',
                );
              },
            );
      } catch (e) {
        rethrow;
      }

      final studyMaterial = StudyMaterial(
        videoId: widget.video!.id,
        summary: summary,
        studyNotes: '',
        questions: [],
        quiz: [],
        analysis: '',
        generatedAt: DateTime.now(),
        transcript: transcript,
        hasApiKey: true,
      );

      final db = ref.read(databaseServiceProvider);
      await db.saveStudyMaterial(studyMaterial.toMap());

      setState(() {
        _studyMaterial = studyMaterial;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        if (e.toString().contains('API key not configured')) {
          _error =
              'API key not configured.\n\n'
              'Please go to Settings > AI Configuration and add your API key to use AI features.';
        } else {
          _error = e.toString();
        }
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _studyMaterial?.summary ?? '';
    final isBasicMode =
        summary.isEmpty ||
        summary.contains('⚠️') ||
        summary.contains('API Key Required') ||
        summary == 'No summary available';

    if (_studyMaterial != null && !widget.autoGenerate) {
      return Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              snap: true,
              elevation: 0,
              centerTitle: true,
              title: Text(
                'Summary',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              actions: [
                IconButton(
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedRefresh,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                  onPressed: _generateStudyMaterial,
                  tooltip: 'Regenerate',
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isBasicMode)
                      _buildApiKeyWarning(context)
                    else
                      _buildInfoBanner(
                        context,
                        'Quick revision notes...',
                        HugeIcons.strokeRoundedFileEdit,
                      ),
                    const Gap(24),
                    Text(
                      summary,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.6,
                        color: Theme.of(context).colorScheme.onSurface,
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

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            elevation: 0,
            centerTitle: true,
            title: Text(
              'Summary',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            actions: [
              if (_studyMaterial != null && !_isLoading)
                IconButton(
                  icon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedRefresh,
                    color: Colors.grey,
                  ),
                  onPressed: _generateStudyMaterial,
                  tooltip: 'Regenerate',
                ),
            ],
          ),
          SliverToBoxAdapter(
            child: _isLoading
                ? _buildLoadingState()
                : _error != null
                ? _buildErrorState()
                : _buildSummaryContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryContent() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_studyMaterial?.summary != null)
            Text(
              _studyMaterial!.summary!,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                height: 1.6,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            )
          else ...[
            Text(
              'No summary available yet. Tap below to generate a fresh summary.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const Gap(16),
            FilledButton.icon(
              onPressed: _generateStudyMaterial,
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedSparkles,
                color: Theme.of(context).colorScheme.onPrimary,
                size: 18,
              ),
              label: const Text('Generate Summary'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildApiKeyWarning(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.error.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedKey01,
            color: Theme.of(context).colorScheme.error,
            size: 20,
          ),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Using Basic Mode',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                const Gap(4),
                Text(
                  'Configure Gemini API key in Settings > AI Configuration for AI-powered summary.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner(BuildContext context, String message, dynamic icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          HugeIcon(
            icon: icon,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          const Gap(12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
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
              'Generating summary...',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const Gap(8),
            Text(
              'This may take a moment',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedAlert02,
                color: Theme.of(context).colorScheme.error,
                size: 56,
              ),
              const Gap(16),
              Text(
                'Unable to Generate',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Gap(12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const Gap(24),
              FilledButton.icon(
                onPressed: () => _loadStudyMaterial(forceRegenerate: true),
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedRefresh,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
