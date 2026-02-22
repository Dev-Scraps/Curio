import 'package:curio/domain/entities/study_material.dart';
import 'package:curio/presentation/common/progress_indicators.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../domain/entities/video.dart';
import '../../../core/services/ai/learning.dart';
import '../../../core/services/storage/database.dart';
import '../../../core/services/storage/storage.dart';
import '../../common/bottom_sheet_helper.dart';
import 'summary_screen.dart';
import 'notes_screen.dart';
import 'questions_screen.dart';
import 'quiz_screen.dart';
import 'analysis_screen.dart';

class StudyMaterialScreen extends ConsumerStatefulWidget {
  final Video video;
  final int initialTab;

  const StudyMaterialScreen({
    super.key,
    required this.video,
    this.initialTab = 0,
  });

  @override
  ConsumerState<StudyMaterialScreen> createState() =>
      _StudyMaterialScreenState();
}

class _StudyMaterialScreenState extends ConsumerState<StudyMaterialScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  StudyMaterial? _studyMaterial;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _loadStudyMaterial();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStudyMaterial() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final db = ref.read(databaseServiceProvider);
      final existing = await db.getStudyMaterial(widget.video.id);

      if (existing != null) {
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
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final aiService = ref.read(aiLearningServiceProvider);
      final storage = ref.read(storageServiceProvider);

      final transcript = 'Sample transcript for ${widget.video.title}';
      final apiKey = storage.geminiApiKey;

      final results = await Future.wait([
        aiService.generateSummary(transcript),
        aiService.generateStudyNotes(transcript),
        aiService.generateQuestions(transcript),
        aiService.generateQuiz(transcript),
        aiService.generateAnalysis(transcript),
      ]);

      final studyMaterial = StudyMaterial(
        videoId: widget.video.id,
        summary: results[0] as String,
        studyNotes: results[1] as String,
        questions: results[2] as List<String>,
        quiz: results[3] as List<QuizQuestion>,
        analysis: results[4] as String,
        generatedAt: DateTime.now(),
        transcript: transcript,
        hasApiKey: apiKey != null && apiKey.isNotEmpty,
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
              'Gemini API key not configured.\n\n'
              'Please go to Settings > AI Configuration and add your API key to use AI features.';
        } else {
          _error = e.toString();
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _regenerateStudyMaterial() async {
    final storage = ref.read(storageServiceProvider);
    final apiKey = storage.geminiApiKey;

    if (apiKey == null || apiKey.isEmpty) {
      final confirm = await BottomSheetHelper.showConfirmation(
        context: context,
        title: 'API Key Required',
        message:
            'You need to configure Gemini API key in Settings > AI Configuration first. Go to settings now?',
        confirmText: 'Go to Settings',
        cancelText: 'Cancel',
      );

      if (confirm && context.mounted) {
        // You'll need to import your SettingsScreen
        // Navigator.push(
        //   context,
        //   MaterialPageRoute(
        //     builder: (_) => SettingsScreen(),
        //   ),
        // );
      }
      return;
    }

    final confirm = await BottomSheetHelper.showConfirmation(
      context: context,
      title: 'Regenerate Study Material',
      message:
          'This will replace all existing study material for this video. Continue?',
      confirmText: 'Regenerate',
      cancelText: 'Cancel',
    );

    if (confirm) {
      await _generateStudyMaterial();
    }
  }

  void _showInfo() {
    BottomSheetHelper.show(
      context: context,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'About Study Materials',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Gap(16),
            Text(
              'AI Philosophy',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Gap(8),
            const Text(
              '• Content generated strictly from video transcript\n'
              '• No external knowledge or assumptions\n'
              '• Acts as a teacher, not a chatbot\n'
              '• Focus on learning over entertainment',
            ),
            const Gap(16),
            if (_studyMaterial?.hasApiKey == false) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const HugeIcon(
                      icon: HugeIcons.strokeRoundedKey01,
                      color: Colors.orange,
                      size: 20,
                    ),
                    const Gap(12),
                    Expanded(
                      child: Text(
                        'API key not configured. AI features limited.',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(16),
            ],
            if (_studyMaterial?.generatedAt != null) ...[
              Text(
                'Generated',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Gap(8),
              Text(_formatDateTime(_studyMaterial!.generatedAt!)),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // ✅ WATCH the storage service to rebuild when API key changes
    final storage = ref.watch(storageServiceProvider);
    final hasApiKey =
        storage.geminiApiKey != null && storage.geminiApiKey!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Material'),
        actions: [
          if (!hasApiKey)
            IconButton(
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedKey01,
                color: Colors.orange,
              ),
              onPressed: () {
                // You'll need to import your SettingsScreen
                // Navigator.push(
                //   context,
                //   MaterialPageRoute(
                //     builder: (_) => SettingsScreen(),
                //   ),
                // );
              },
              tooltip: 'Configure API Key',
            ),
          if (_studyMaterial != null && !_isLoading && hasApiKey)
            IconButton(
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedRefresh,
                color: Colors.grey,
              ),
              onPressed: _regenerateStudyMaterial,
              tooltip: 'Regenerate',
            ),
          IconButton(
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedInformationCircle,
              color: Colors.grey,
            ),
            onPressed: _showInfo,
            tooltip: 'Info',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight + 16),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: false,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(12.0),
                color: Theme.of(context).colorScheme.primary,
              ),
              labelColor: Theme.of(context).colorScheme.onPrimary,
              unselectedLabelColor: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant,
              tabs: const [
                Tab(text: 'Summary'),
                Tab(text: 'Notes'),
                Tab(text: 'Ques'),
                Tab(text: 'Quiz'),
                Tab(text: 'Analysis'),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _error != null
          ? _buildErrorState()
          : TabBarView(
              controller: _tabController,
              children: [
                SummaryScreen(
                  video: widget.video,
                  studyMaterial: _studyMaterial,
                ),
                NotesScreen(video: widget.video, studyMaterial: _studyMaterial),
                QuestionsScreen(
                  video: widget.video,
                  studyMaterial: _studyMaterial,
                ),
                QuizScreen(video: widget.video, studyMaterial: _studyMaterial),
                AnalysisScreen(
                  video: widget.video,
                  studyMaterial: _studyMaterial,
                ),
              ],
            ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
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
            'Generating study materials...',
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
    );
  }

  Widget _buildErrorState() {
    final hasApiKeyError = _error?.contains('API key') ?? false;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              HugeIcon(
                icon: hasApiKeyError
                    ? HugeIcons.strokeRoundedKey01
                    : HugeIcons.strokeRoundedAlert02,
                color: hasApiKeyError
                    ? Colors.orange
                    : Theme.of(context).colorScheme.error,
                size: 56,
              ),
              const Gap(16),
              Text(
                hasApiKeyError ? 'API Key Required' : 'Unable to Generate',
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
              if (hasApiKeyError) ...[
                FilledButton(
                  onPressed: () {
                    // You'll need to import your SettingsScreen
                    // Navigator.push(
                    //   context,
                    //   MaterialPageRoute(
                    //     builder: (_) => SettingsScreen(),
                    //   ),
                    // );
                  },
                  child: const Text('Configure API Key'),
                ),
                const Gap(12),
                OutlinedButton(
                  onPressed: _loadStudyMaterial,
                  child: const Text('Use Basic Mode'),
                ),
              ] else ...[
                FilledButton.icon(
                  onPressed: _loadStudyMaterial,
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedRefresh,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                  label: const Text('Try Again'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
