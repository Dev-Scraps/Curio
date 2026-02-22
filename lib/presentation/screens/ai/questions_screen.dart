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

class QuestionsScreen extends ConsumerStatefulWidget {
  final Video? video;
  final StudyMaterial? studyMaterial;
  final bool autoGenerate;

  const QuestionsScreen({
    super.key,
    this.video,
    this.studyMaterial,
    this.autoGenerate = false,
  });

  @override
  ConsumerState<QuestionsScreen> createState() => _QuestionsScreenState();
}

class _QuestionsScreenState extends ConsumerState<QuestionsScreen> {
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
        _error = 'No video specified for generating questions.';
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

      final questions = await aiService.generateQuestions(
        transcript,
        videoTitle: widget.video!.title,
        apiKey: apiKey,
      );

      final studyMaterial = StudyMaterial(
        videoId: widget.video!.id,
        summary: '',
        studyNotes: '',
        questions: questions,
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
    final questions = _studyMaterial?.questions ?? [];
    final isBasicMode =
        questions.isEmpty ||
        (questions.isNotEmpty &&
            (questions.first.contains('⚠️') ||
                questions.first.contains('API Key Required')));

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
                'Questions',
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isBasicMode)
                      _buildApiKeyWarning(context)
                    else
                      _buildInfoBanner(
                        context,
                        'Conceptual questions to deepen understanding',
                        HugeIcons.strokeRoundedQuestion,
                      ),
                    const Gap(24),
                    if (questions.isEmpty)
                      Center(
                        child: Text(
                          'No questions available',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      )
                    else
                      ...questions.asMap().entries.map((entry) {
                        final index = entry.key;
                        final question = entry.value;
                        return _buildQuestionItem(context, index + 1, question);
                      }),
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
              'Questions',
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
                : _buildQuestionsContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionsContent() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_studyMaterial?.questions != null &&
              _studyMaterial!.questions!.isNotEmpty)
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _studyMaterial!.questions!.length,
              itemBuilder: (context, index) {
                final question = _studyMaterial!.questions![index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Q${index + 1}: $question',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            )
          else ...[
            Text(
              'No questions available yet. Tap below to generate practice questions.',
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
              label: const Text('Generate Questions'),
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
                  'Configure Gemini API key in Settings > AI Configuration for AI-powered questions.',
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

  Widget _buildQuestionItem(BuildContext context, int number, String question) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$number',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const Gap(12),
          Expanded(
            child: Text(
              question,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.5),
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
              'Generating questions...',
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
