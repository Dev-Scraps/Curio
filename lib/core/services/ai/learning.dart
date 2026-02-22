import 'dart:convert';
import 'package:curio/core/services/storage/storage.dart';
import 'package:curio/domain/entities/study_material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:http/http.dart' as http;

part 'learning.g.dart';

/// AI Learning Service - Calls Perplexity API directly
///
/// This service handles AI operations by calling the Perplexity API directly via HTTP.
/// It replaces the previous Python-based implementation.
@riverpod
class AiLearningService extends _$AiLearningService {
  @override
  AiLearningService build() => this;

  bool _isInitialized = false;
  String? _apiKey;
  static const String _baseUrl = 'https://api.perplexity.ai/chat/completions';
  static const String _model = 'sonar';

  /// Initialize AI service with API key
  Future<void> initialize(String apiKey) async {
    if (apiKey.isEmpty) {
      throw Exception(
        'API key cannot be empty. Please configure your API key in Settings > AI Configuration.',
      );
    }
    _apiKey = apiKey;
    _isInitialized = true;
  }

  /// Generate content using Perplexity API
  Future<String> _generateContent(String prompt, {String? apiKey}) async {
    final key = apiKey ?? _apiKey;
    if (key == null || key.isEmpty) {
      throw Exception(
        'API key not configured. Please go to Settings > AI Configuration and add your API key to use AI features.',
      );
    }

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $key',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are a focused teaching assistant. Return only the requested output without preambles.',
            },
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.3,
          'top_p': 0.9,
          'max_tokens': 2048,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final content = data['choices']?[0]?['message']?['content'];
        if (content != null) {
          return _cleanResponse(content.toString());
        } else {
          throw Exception('Empty response from AI service');
        }
      } else {
        throw Exception(
          'AI Service Error: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Failed to connect to AI service: $e');
    }
  }

  String _cleanResponse(String text) {
    // Remove code fences if present
    final codeFencePattern = RegExp(r'```(?:json|text)?\s*([\s\S]*?)\s*```');
    final match = codeFencePattern.firstMatch(text);
    if (match != null) {
      return match.group(1)?.trim() ?? text.trim();
    }
    return text.trim();
  }

  /// Generate summary for transcript
  Future<String> generateSummary(
    String transcript, {
    String videoTitle = '',
    String playlistTitle = '',
    String language = 'en',
    String? apiKey,
  }) async {
    final prompt = _buildSummaryPrompt(transcript, videoTitle, language);
    return await _generateContent(prompt, apiKey: apiKey);
  }

  String _buildSummaryPrompt(
    String transcript,
    String videoTitle,
    String language,
  ) {
    String langInstruction = language != 'en' ? ' Respond in $language.' : '';
    return '''
Generate a concise, informative summary of the following video transcript.

Video Title: $videoTitle

Transcript:
$transcript

Requirements:
- Create a clear, well-structured summary using bullet points
- Start with the main topic and key insights
- Use bullet points (• or *) for important information and key takeaways
- Focus on the main points and essential information
- Use clear, accessible language
- Keep it comprehensive but concise
- Structure the summary with:
  • Main topic/theme
  • Key points and insights
  • Important conclusions or takeaways
- Do not include phrases like "Here is a summary" or "The summary is"
- Write the summary directly$langInstruction

Summary:
''';
  }

  /// Generate study notes for transcript
  Future<String> generateNotes(
    String transcript, {
    String videoTitle = '',
    String playlistTitle = '',
    String language = 'en',
    String? apiKey,
  }) async {
    final prompt = _buildNotesPrompt(transcript, videoTitle, language);
    return await _generateContent(prompt, apiKey: apiKey);
  }

  String _buildNotesPrompt(
    String transcript,
    String videoTitle,
    String language,
  ) {
    String langInstruction = language != 'en' ? ' Respond in $language.' : '';
    return '''
Create comprehensive study notes from the following video transcript.

Video Title: $videoTitle

Transcript:
$transcript

Requirements:
- Create detailed, well-structured study notes
- Use clear headings and subheadings
- Break down complex concepts into easy-to-understand points
- Include definitions for key terms
- Highlight important formulas, dates, or names if applicable
- Use bullet points for lists
- Format as Markdown
- Do not include conversational filler
- Write the notes directly$langInstruction

Study Notes:
''';
  }

  /// Generate quiz for transcript
  Future<List<QuizQuestion>> generateQuiz(
    String transcript, {
    String videoTitle = '',
    String playlistTitle = '',
    String language = 'en',
    String? apiKey,
  }) async {
    final prompt = _buildQuizPrompt(transcript, videoTitle, language);
    final jsonString = await _generateContent(prompt, apiKey: apiKey);

    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((item) {
        return QuizQuestion(
          question: item['question'] ?? '',
          type: QuizType.multipleChoice,
          options: item['options'] != null
              ? List<String>.from(item['options'])
              : [],
          correctAnswer: item['correctAnswer'] ?? '',
          explanation: null,
        );
      }).toList();
    } catch (e) {
      // Fallback or retry logic could go here
      print('Error parsing quiz JSON: $e');
      return [];
    }
  }

  String _buildQuizPrompt(
    String transcript,
    String videoTitle,
    String language,
  ) {
    String langInstruction = language != 'en'
        ? ' Ensure questions and answers are in $language.'
        : '';
    return '''
Generate a multiple-choice quiz based on the following video transcript.

Video Title: $videoTitle

Transcript:
$transcript

Requirements:
- Create 5-10 challenging but fair multiple-choice questions
- Focus on key concepts and important details
- Provide 4 options for each question
- Clearly indicate the correct answer
- Return the result ONLY as a valid JSON array of objects
- Each object must have: "question", "options" (array of 4 strings), and "correctAnswer" (string matching one option)
- No other text, markdown, or explanations outside the JSON array$langInstruction

JSON:
''';
  }

  /// Generate complete study material
  Future<StudyMaterial> generateStudyMaterial({
    required String videoId,
    required String transcript,
    String videoTitle = '',
    String playlistTitle = '',
    String language = 'en',
    bool includeSummary = true,
    bool includeNotes = true,
    bool includeQuiz = true,
    String? apiKey,
  }) async {
    String? summary;
    String? studyNotes;
    List<QuizQuestion>? quiz;

    // Initialize if needed (using provided key or stored key)
    if (apiKey != null && apiKey.isNotEmpty) {
      _apiKey = apiKey;
      _isInitialized = true;
    }

    // Generate each component if requested
    if (includeSummary) {
      try {
        summary = await generateSummary(
          transcript,
          videoTitle: videoTitle,
          playlistTitle: playlistTitle,
          language: language,
          apiKey: apiKey,
        );
      } catch (e) {
        summary = null;
      }
    }

    if (includeNotes) {
      try {
        studyNotes = await generateNotes(
          transcript,
          videoTitle: videoTitle,
          playlistTitle: playlistTitle,
          language: language,
          apiKey: apiKey,
        );
      } catch (e) {
        studyNotes = null;
      }
    }

    if (includeQuiz) {
      try {
        quiz = await generateQuiz(
          transcript,
          videoTitle: videoTitle,
          playlistTitle: playlistTitle,
          language: language,
          apiKey: apiKey,
        );
      } catch (e) {
        quiz = null;
      }
    }

    return StudyMaterial(
      videoId: videoId,
      summary: summary,
      studyNotes: studyNotes,
      questions: [],
      quiz: quiz ?? [],
      analysis: '',
      generatedAt: DateTime.now(),
      transcript: transcript,
      hasApiKey: _apiKey != null && _apiKey!.isNotEmpty,
    );
  }

  /// Check if AI service is ready
  bool get isInitialized => _isInitialized;

  /// Get current API key status
  bool get hasApiKey => _apiKey != null && _apiKey!.isNotEmpty;

  /// Fetch available AI models based on selected provider
  Future<List<String>> fetchAvailableModels({String? provider}) async {
    if (provider == 'perplexity') {
      return ['sonar', 'sonar-pro', 'sonar-reasoning'];
    } else {
      return ['gemini-2.0-flash', 'gemini-1.5-pro'];
    }
  }

  /// Generate study notes (alias for generateNotes)
  Future<String> generateStudyNotes(
    String transcript, {
    String videoTitle = '',
    String playlistTitle = '',
    String language = 'en',
    String? apiKey,
  }) async {
    return generateNotes(
      transcript,
      videoTitle: videoTitle,
      playlistTitle: playlistTitle,
      language: language,
      apiKey: apiKey,
    );
  }

  // Placeholder for missing methods
  Future<String> generateAnalysis(
    String transcript, {
    String videoTitle = '',
    String playlistTitle = '',
    String language = 'en',
    String? apiKey,
  }) async {
    return "";
  }

  Future<List<String>> generateQuestions(
    String transcript, {
    String videoTitle = '',
    String playlistTitle = '',
    String language = 'en',
    String? apiKey,
  }) async {
    return [];
  }
}

// Provider for initialized AI service (lazy initialization)
final initializedAIServiceProvider = Provider<AiLearningService>((ref) {
  final service = ref.watch(aiLearningServiceProvider);
  final storage = ref.watch(storageServiceProvider);
  final apiKey = storage.perplexityApiKey;

  if (apiKey != null && apiKey.isNotEmpty) {
    service.initialize(apiKey);
  }

  return service;
});
