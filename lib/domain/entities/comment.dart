class Comment {
  final String id;
  final String author;
  final String authorId;
  final String text;
  final String publishedAt;
  final int likeCount;
  final bool isPinned;
  final String? authorProfileImageUrl;
  final List<Comment>? replies;

  const Comment({
    required this.id,
    required this.author,
    required this.authorId,
    required this.text,
    required this.publishedAt,
    required this.likeCount,
    this.isPinned = false,
    this.authorProfileImageUrl,
    this.replies,
  });

  Comment copyWith({
    String? id,
    String? author,
    String? authorId,
    String? text,
    String? publishedAt,
    int? likeCount,
    bool? isPinned,
    String? authorProfileImageUrl,
    List<Comment>? replies,
  }) {
    return Comment(
      id: id ?? this.id,
      author: author ?? this.author,
      authorId: authorId ?? this.authorId,
      text: text ?? this.text,
      publishedAt: publishedAt ?? this.publishedAt,
      likeCount: likeCount ?? this.likeCount,
      isPinned: isPinned ?? this.isPinned,
      authorProfileImageUrl:
          authorProfileImageUrl ?? this.authorProfileImageUrl,
      replies: replies ?? this.replies,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'author': author,
      'authorId': authorId,
      'text': text,
      'publishedAt': publishedAt,
      'likeCount': likeCount,
      'isPinned': isPinned,
      'authorProfileImageUrl': authorProfileImageUrl,
      'replies': replies?.map((r) => r.toJson()).toList(),
    };
  }

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id']?.toString() ?? '',
      author: json['author']?.toString() ?? 'Unknown',
      authorId: json['authorId']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      publishedAt: json['publishedAt']?.toString() ?? '',
      likeCount: int.tryParse(json['likeCount']?.toString() ?? '0') ?? 0,
      isPinned: json['isPinned'] == true,
      authorProfileImageUrl: json['authorProfileImageUrl']?.toString(),
      replies: json['replies'] != null && json['replies'] is List
          ? (json['replies'] as List).map((r) => Comment.fromJson(r)).toList()
          : null,
    );
  }
}
