enum DownloadStatus {
  queued,
  downloading,
  processing,
  paused,
  completed,
  error,
  cancelled,
}

class DownloadTask {
  final String id;
  final String url;
  final String title;
  final String thumbnailUrl;
  final String? duration;
  final double progress;
  final String speed;
  final String eta;
  final int totalBytes;
  final int downloadedBytes;
  final DownloadStatus status;
  final String? error;
  final String? filePath;
  final String? formatId;
  final int? expectedSize;
  final DateTime addedDate;
  // Metadata fields
  final String? artist;
  final String? album;
  final String? genre;
  final String? uploadDate;
  final String? description;
  final Map<String, dynamic>? embeddedMetadata;

  DownloadTask({
    required this.id,
    required this.url,
    required this.title,
    required this.thumbnailUrl,
    this.duration,
    this.progress = 0.0,
    this.speed = '',
    this.eta = '',
    this.totalBytes = 0,
    this.downloadedBytes = 0,
    this.status = DownloadStatus.queued,
    this.error,
    this.filePath,
    this.formatId,
    this.expectedSize,
    DateTime? addedDate,
    // Metadata parameters
    this.artist,
    this.album,
    this.genre,
    this.uploadDate,
    this.description,
    this.embeddedMetadata,
  }) : addedDate = addedDate ?? DateTime.now();

  DownloadTask copyWith({
    String? id,
    String? title,
    String? thumbnailUrl,
    String? duration,
    double? progress,
    String? speed,
    String? eta,
    int? totalBytes,
    int? downloadedBytes,
    DownloadStatus? status,
    String? error,
    String? filePath,
    String? formatId,
    int? expectedSize,
    DateTime? addedDate,
    // Metadata parameters
    String? artist,
    String? album,
    String? genre,
    String? uploadDate,
    String? description,
    Map<String, dynamic>? embeddedMetadata,
  }) {
    return DownloadTask(
      id: id ?? this.id,
      url: url,
      title: title ?? this.title,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      duration: duration ?? this.duration,
      progress: progress ?? this.progress,
      speed: speed ?? this.speed,
      eta: eta ?? this.eta,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      status: status ?? this.status,
      error: error ?? this.error,
      filePath: filePath ?? this.filePath,
      formatId: formatId ?? this.formatId,
      expectedSize: expectedSize ?? this.expectedSize,
      addedDate: addedDate ?? this.addedDate,
      // Metadata fields
      artist: artist ?? this.artist,
      album: album ?? this.album,
      genre: genre ?? this.genre,
      uploadDate: uploadDate ?? this.uploadDate,
      description: description ?? this.description,
      embeddedMetadata: embeddedMetadata ?? this.embeddedMetadata,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'url': url,
      'title': title,
      'thumbnailUrl': thumbnailUrl,
      'duration': duration,
      'progress': progress,
      'speed': speed,
      'eta': eta,
      'totalBytes': totalBytes,
      'downloadedBytes': downloadedBytes,
      'status': status.name,
      'error': error,
      'filePath': filePath,
      'formatId': formatId,
      'expectedSize': expectedSize,
      'addedDate': addedDate.toIso8601String(),
      // Metadata fields
      'artist': artist,
      'album': album,
      'genre': genre,
      'uploadDate': uploadDate,
      'description': description,
      'embeddedMetadata': embeddedMetadata,
    };
  }

  factory DownloadTask.fromMap(Map<String, dynamic> map) {
    return DownloadTask(
      id: map['id'] as String,
      url: map['url'] as String,
      title: map['title'] as String,
      thumbnailUrl: map['thumbnailUrl'] as String? ?? '',
      duration: map['duration'] as String?,
      progress: (map['progress'] as num?)?.toDouble() ?? 0.0,
      speed: map['speed'] as String? ?? '',
      eta: map['eta'] as String? ?? '',
      totalBytes: (map['totalBytes'] as num?)?.toInt() ?? 0,
      downloadedBytes: (map['downloadedBytes'] as num?)?.toInt() ?? 0,
      status: DownloadStatus.values.firstWhere(
        (e) => e.name == (map['status'] as String),
        orElse: () => DownloadStatus.queued,
      ),
      error: map['error'] as String?,
      filePath: map['filePath'] as String?,
      formatId: map['formatId'] as String?,
      expectedSize: (map['expectedSize'] as num?)?.toInt(),
      addedDate: DateTime.parse(map['addedDate'] as String),
      // Metadata fields - handle null values gracefully for backward compatibility
      artist: map['artist'] as String?,
      album: map['album'] as String?,
      genre: map['genre'] as String?,
      uploadDate: map['uploadDate'] as String?,
      description: map['description'] as String?,
      embeddedMetadata: map['embeddedMetadata'] as Map<String, dynamic>?,
    );
  }
}
