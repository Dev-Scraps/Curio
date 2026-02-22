import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../domain/entities/study_material.dart';

/// Study History Service
/// Stores all generated study materials as history
/// Like a premium LMS app with comprehensive tracking
class StudyHistoryService {
  static const String _studyHistoryKey = 'study_history';

  /// Save study material to history
  Future<void> saveStudyMaterial({
    required String videoId,
    required String videoTitle,
    required String materialType,
    required String content,
    Map<String, dynamic>? metadata,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(_studyHistoryKey) ?? [];

    final studyItem = {
      'videoId': videoId,
      'videoTitle': videoTitle,
      'materialType': materialType,
      'content': content,
      'metadata': metadata ?? {},
      'timestamp': DateTime.now().toIso8601String(),
    };

    history.add(jsonEncode(studyItem));
    await prefs.setStringList(_studyHistoryKey, history);
  }

  /// Save quiz attempt with marks
  Future<void> saveQuizAttempt({
    required String videoId,
    required String videoTitle,
    required List<QuizQuestion> questions,
    required List<int> userAnswers,
    required int score,
    required int totalQuestions,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(_studyHistoryKey) ?? [];

    final quizAttempt = {
      'videoId': videoId,
      'videoTitle': videoTitle,
      'materialType': 'quiz_attempt',
      'questions': questions
          .map(
            (q) => {
              'question': q.question,
              'type': q.type.name,
              'options': q.options,
              'correctAnswer': q.correctAnswer,
              'explanation': q.explanation,
            },
          )
          .toList(),
      'userAnswers': userAnswers,
      'score': score,
      'totalQuestions': totalQuestions,
      'percentage': totalQuestions > 0
          ? ((score / totalQuestions) * 100).round()
          : 0,
      'timestamp': DateTime.now().toIso8601String(),
    };

    history.add(jsonEncode(quizAttempt));
    await prefs.setStringList(_studyHistoryKey, history);
  }

  /// Get all study history items
  Future<List<Map<String, dynamic>>> getStudyHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(_studyHistoryKey) ?? [];

    return history.map((item) {
      try {
        return jsonDecode(item) as Map<String, dynamic>;
      } catch (e) {
        return {
          'error': 'Failed to parse history item',
          'timestamp': DateTime.now().toIso8601String(),
        };
      }
    }).toList();
  }

  /// Get quiz attempts for a specific video
  Future<List<Map<String, dynamic>>> getQuizAttempts(String videoId) async {
    final history = await getStudyHistory();

    return history.where((item) {
      return item['videoId'] == videoId &&
          item['materialType'] == 'quiz_attempt';
    }).toList();
  }

  /// Get study materials for a specific video
  Future<List<Map<String, dynamic>>> getVideoStudyMaterials(
    String videoId,
  ) async {
    final history = await getStudyHistory();

    return history.where((item) {
      return item['videoId'] == videoId &&
          [
            'summary',
            'study_notes',
            'questions',
            'analysis',
          ].contains(item['materialType']);
    }).toList();
  }

  /// Clear all study history
  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_studyHistoryKey);
  }

  /// Get study statistics
  Future<Map<String, dynamic>> getStudyStatistics() async {
    final history = await getStudyHistory();

    int totalMaterials = 0;
    int totalQuizAttempts = 0;
    double averageScore = 0.0;

    for (final item in history) {
      if ([
        'summary',
        'study_notes',
        'questions',
        'analysis',
      ].contains(item['materialType'])) {
        totalMaterials++;
      }
      if (item['materialType'] == 'quiz_attempt') {
        totalQuizAttempts++;
        if (item['percentage'] != null) {
          averageScore = (averageScore + (item['percentage'] as double)) / 2;
        }
      }
    }

    return {
      'totalMaterials': totalMaterials,
      'totalQuizAttempts': totalQuizAttempts,
      'averageScore': averageScore.round(),
      'lastStudyDate': history.isNotEmpty ? history.first['timestamp'] : null,
    };
  }
}

/// Provider for study history service
@Riverpod(keepAlive: true)
StudyHistoryService studyHistoryService(Ref ref) {
  return StudyHistoryService();
}
