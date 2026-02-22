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

class QuizScreen extends ConsumerStatefulWidget {
  final Video? video;
  final StudyMaterial? studyMaterial;
  final bool autoGenerate;

  const QuizScreen({
    super.key,
    this.video,
    this.studyMaterial,
    this.autoGenerate = false,
  });

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  StudyMaterial? _studyMaterial;
  bool _isLoading = false;
  String? _error;
  final Map<int, String> _selectedAnswers = {};
  bool _showResults = false;
  int _currentQuestionIndex = 0;

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
        _error = 'No video specified for generating quiz.';
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

      final quiz = await aiService.generateQuiz(
        transcript,
        videoTitle: widget.video!.title,
        apiKey: apiKey,
      );

      final studyMaterial = StudyMaterial(
        videoId: widget.video!.id,
        summary: '',
        studyNotes: '',
        questions: [],
        quiz: quiz,
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

  void _selectAnswer(int questionIndex, String answer) {
    setState(() {
      _selectedAnswers[questionIndex] = answer;
    });
  }

  void _submitQuiz() {
    setState(() {
      _showResults = true;
    });
  }

  void _resetQuiz() {
    setState(() {
      _selectedAnswers.clear();
      _showResults = false;
      _currentQuestionIndex = 0;
    });
  }

  int _calculateScore() {
    int score = 0;
    for (int i = 0; i < _studyMaterial!.quiz!.length; i++) {
      if (_selectedAnswers[i] == _studyMaterial!.quiz![i].correctAnswer) {
        score++;
      }
    }
    return score;
  }

  @override
  Widget build(BuildContext context) {
    final quiz = _studyMaterial?.quiz;

    if (_studyMaterial != null && !widget.autoGenerate) {
      if (quiz == null || quiz.isEmpty) {
        return _buildEmptyState('No quiz generated yet', context);
      }

      final firstQuestion = quiz.first.question;
      final isBasicMode =
          firstQuestion.contains('⚠️') ||
          firstQuestion.contains('API Key Required');

      return Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              snap: true,
              elevation: 0,
              centerTitle: true,
              title: Text(
                'Quiz',
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
              child: ListView(
                padding: const EdgeInsets.all(24),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  if (isBasicMode)
                    _buildApiKeyWarning(context)
                  else
                    _buildInfoBanner(
                      'Test your understanding with AI-generated questions based on the video content.',
                      context,
                    ),
                  const Gap(16),
                  ...List.generate(
                    quiz.length,
                    (index) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: QuizQuestionWidget(
                        number: index + 1,
                        question: quiz[index],
                      ),
                    ),
                  ),
                ],
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
              'Quiz',
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
                : _studyMaterial?.quiz == null || _studyMaterial!.quiz!.isEmpty
                ? _buildNoQuizState()
                : _showResults
                ? _buildResultsScreen()
                : _buildQuizScreen(),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizScreen() {
    final quiz = _studyMaterial!.quiz!;
    final currentQuestion = quiz[_currentQuestionIndex];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(
            value: (_currentQuestionIndex + 1) / quiz.length,
            backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
          ),
          const Gap(8),
          Text(
            'Question ${_currentQuestionIndex + 1} of ${quiz.length}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const Gap(24),
          Text(
            'Q${_currentQuestionIndex + 1}: ${currentQuestion.question}',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const Gap(16),
          if (currentQuestion.options != null)
            ...currentQuestion.options!.asMap().entries.map((entry) {
              final optionIndex = entry.key;
              final option = entry.value;
              final isSelected =
                  _selectedAnswers[_currentQuestionIndex] == option;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => _selectAnswer(_currentQuestionIndex, option),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      color: isSelected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : null,
                    ),
                    child: Text(
                      '${String.fromCharCode(65 + optionIndex)}. $option',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isSelected
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : null,
                      ),
                    ),
                  ),
                ),
              );
            }),
          const Gap(24),
          Row(
            children: [
              if (_currentQuestionIndex > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _currentQuestionIndex--;
                      });
                    },
                    child: const Text('Previous'),
                  ),
                ),
              if (_currentQuestionIndex > 0) const Gap(12),
              Expanded(
                child: FilledButton(
                  onPressed: _selectedAnswers[_currentQuestionIndex] != null
                      ? () {
                          if (_currentQuestionIndex < quiz.length - 1) {
                            setState(() {
                              _currentQuestionIndex++;
                            });
                          } else {
                            _submitQuiz();
                          }
                        }
                      : null,
                  child: Text(
                    _currentQuestionIndex < quiz.length - 1 ? 'Next' : 'Submit',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultsScreen() {
    final score = _calculateScore();
    final totalQuestions = _studyMaterial!.quiz!.length;
    final percentage = (score / totalQuestions * 100).round();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quiz Results',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const Gap(24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$score/$totalQuestions',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$percentage%',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
          const Gap(24),
          Expanded(
            child: ListView.builder(
              itemCount: _studyMaterial!.quiz!.length,
              itemBuilder: (context, index) {
                final question = _studyMaterial!.quiz![index];
                final userAnswer = _selectedAnswers[index];
                final isCorrect = userAnswer == question.correctAnswer;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isCorrect ? Icons.check_circle : Icons.cancel,
                              color: isCorrect
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.error,
                              size: 20,
                            ),
                            const Gap(8),
                            Expanded(
                              child: Text(
                                'Q${index + 1}: ${question.question}',
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const Gap(8),
                        if (userAnswer != null)
                          Text(
                            'Your answer: $userAnswer',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: isCorrect
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.error,
                                ),
                          ),
                        Text(
                          'Correct answer: ${question.correctAnswer}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const Gap(16),
          FilledButton(onPressed: _resetQuiz, child: const Text('Retake Quiz')),
        ],
      ),
    );
  }

  Widget _buildNoQuizState() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quiz',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const Gap(16),
          Text(
            'No quiz available yet. Please generate study materials first.',
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
            label: const Text('Generate Quiz'),
          ),
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
                  'Configure Gemini API key in Settings > AI Configuration for AI-powered quizzes.',
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

  Widget _buildInfoBanner(String message, BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
        ),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message, BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedFileNotFound,
            size: 48,
            color: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const Gap(16),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
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
              'Generating quiz...',
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
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: Center(
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
      ),
    );
  }
}

class QuizQuestionWidget extends StatelessWidget {
  final int number;
  final QuizQuestion question;

  const QuizQuestionWidget({
    super.key,
    required this.number,
    required this.question,
  });

  @override
  Widget build(BuildContext context) {
    final isWarning = question.question.contains('⚠️');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isWarning
            ? Theme.of(context).colorScheme.errorContainer
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isWarning
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isWarning
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$number',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isWarning
                        ? Theme.of(context).colorScheme.onError
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const Gap(12),
              Expanded(
                child: Text(
                  question.question,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                    color: isWarning ? Colors.orange : null,
                  ),
                ),
              ),
            ],
          ),
          if (question.type == QuizType.mcq &&
              question.options != null &&
              !isWarning) ...[
            const Gap(16),
            ...question.options!.asMap().entries.map((entry) {
              final index = entry.key.toInt();
              final option = entry.value;
              final letter = String.fromCharCode(65 + index);
              return _buildMcqOption(context, letter, option);
            }),
          ],
          if (question.type == QuizType.trueFalse && !isWarning) ...[
            const Gap(16),
            Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                  size: 20,
                ),
                const Gap(8),
                const Text('True'),
                const Gap(24),
                Icon(
                  Icons.cancel_outlined,
                  color: Colors.red.withOpacity(0.7),
                  size: 20,
                ),
                const Gap(8),
                const Text('False'),
              ],
            ),
          ],
          if (question.type == QuizType.shortAnswer && !isWarning) ...[
            const Gap(16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const Gap(8),
                  Text(
                    'Short answer required',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMcqOption(BuildContext context, String letter, String option) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withOpacity(0.5),
              ),
            ),
            alignment: Alignment.center,
            child: Text(letter, style: Theme.of(context).textTheme.bodySmall),
          ),
          const Gap(12),
          Expanded(
            child: Text(option, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
