import 'dart:convert';

class StudyMaterial {
  final String videoId;
  final String? summary;
  final String? studyNotes;
  final List<String>? questions;
  final List<QuizQuestion>? quiz;
  final String? analysis;
  final DateTime? generatedAt;
  final String? transcript;
  final bool hasApiKey;

  const StudyMaterial({
    required this.videoId,
    this.summary,
    this.studyNotes,
    this.questions,
    this.quiz,
    this.analysis,
    this.generatedAt,
    this.transcript,
    this.hasApiKey = true,
  });

  StudyMaterial copyWith({
    String? videoId,
    String? summary,
    String? studyNotes,
    List<String>? questions,
    List<QuizQuestion>? quiz,
    String? analysis,
    DateTime? generatedAt,
    String? transcript,
    bool? hasApiKey,
  }) {
    return StudyMaterial(
      videoId: videoId ?? this.videoId,
      summary: summary ?? this.summary,
      studyNotes: studyNotes ?? this.studyNotes,
      questions: questions ?? this.questions,
      quiz: quiz ?? this.quiz,
      analysis: analysis ?? this.analysis,
      generatedAt: generatedAt ?? this.generatedAt,
      transcript: transcript ?? this.transcript,
      hasApiKey: hasApiKey ?? this.hasApiKey,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'videoId': videoId,
      'summary': summary,
      'studyNotes': studyNotes,
      'questions': questions?.join('|||'),
      'quiz': quiz?.map((q) => q.toJson()).toList(),
      'analysis': analysis,
      'generatedAt': generatedAt?.toIso8601String(),
      'transcript': transcript,
      'hasApiKey': hasApiKey,
    };
  }

  factory StudyMaterial.fromJson(Map<String, dynamic> json) {
    return StudyMaterial(
      videoId: json['videoId']?.toString() ?? '',
      summary: json['summary']?.toString(),
      studyNotes: json['studyNotes']?.toString(),
      questions: json['questions'] != null
          ? (json['questions'] as String).split('|||')
          : null,
      quiz: json['quiz'] != null
          ? (jsonDecode(json['quiz'] as String) as List)
                .map((q) => QuizQuestion.fromJson(q as Map<String, dynamic>))
                .toList()
          : null,
      analysis: json['analysis']?.toString(),
      generatedAt: json['generatedAt'] != null
          ? DateTime.parse(json['generatedAt'] as String)
          : null,
      transcript: json['transcript']?.toString(),
      hasApiKey: (json['hasApiKey'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'videoId': videoId,
      'summary': summary,
      'studyNotes': studyNotes,
      'questions': questions?.join('|||'),
      'quiz': jsonEncode(quiz?.map((q) => q.toJson()).toList()),
      'analysis': analysis,
      'generatedAt': generatedAt?.toIso8601String(),
      'transcript': transcript,
      'hasApiKey': hasApiKey ? 1 : 0,
    };
  }

  factory StudyMaterial.fromMap(Map<String, dynamic> map) {
    return StudyMaterial(
      videoId: map['videoId']?.toString() ?? '',
      summary: map['summary']?.toString(),
      studyNotes: map['studyNotes']?.toString(),
      questions: map['questions'] != null
          ? (map['questions'] as String).split('|||')
          : null,
      quiz: map['quiz'] != null
          ? (jsonDecode(map['quiz'] as String) as List)
                .map((q) => QuizQuestion.fromJson(q as Map<String, dynamic>))
                .toList()
          : null,
      analysis: map['analysis']?.toString(),
      generatedAt: map['generatedAt'] != null
          ? DateTime.parse(map['generatedAt'] as String)
          : null,
      transcript: map['transcript']?.toString(),
      hasApiKey: (map['hasApiKey'] as int?) == 1,
    );
  }
}

class QuizQuestion {
  final String question;
  final QuizType type;
  final List<String>? options;
  final String correctAnswer;
  final String? explanation;

  const QuizQuestion({
    required this.question,
    required this.type,
    this.options,
    required this.correctAnswer,
    this.explanation,
  });

  Map<String, dynamic> toJson() {
    return {
      'question': question,
      'type': type.name,
      'options': options,
      'correct_answer': correctAnswer,
      'explanation': explanation,
    };
  }

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      question: json['question']?.toString() ?? '',
      type: QuizType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => QuizType.shortAnswer,
      ),
      options: json['options'] != null
          ? List<String>.from(json['options'] as List)
          : null,
      correctAnswer: json['correct_answer']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'question': question,
      'type': type.name,
      'options': options,
      'correct_answer': correctAnswer,
    };
  }
}

enum QuizType { mcq, trueFalse, shortAnswer, multipleChoice }

enum StudyTask { summary, studyNotes, questions, quiz, analysis }
