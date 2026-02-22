import 'dart:io' as io;
import 'dart:async';
import 'dart:io';
import 'package:curio/core/services/content/sync.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../domain/entities/download_task.dart';
import '../../../domain/entities/video.dart';
import '../../../presentation/providers/videos_provider.dart';
import '../yt_dlp/extractor.dart';
import '../yt_dlp/ytdlp.dart';

import '../storage/database.dart';
import '../storage/storage.dart';
import '../system/logger.dart';
import '../system/notifications.dart';

part 'downloader.g.dart';

@Riverpod(keepAlive: true)
class DownloadService extends _$DownloadService {
  static const List<String> _formatSuffixesToStrip = ['-drc', '-hdr'];
  late YtDlpService _ytDlpService;
  late DatabaseService _databaseService;
  late NotificationService _notificationService;
  late StorageService _storageService;

  // Poll timer
  Timer? _pollTimer;

  // Track active task IDs to poll
  final Set<String> _activeTaskIds = {};

  @override
  List<DownloadTask> build() {
    _ytDlpService = ref.read(ytDlpServiceProvider);
    _databaseService = ref.read(databaseServiceProvider);
    _notificationService = ref.read(notificationServiceProvider);
    _storageService = ref.read(storageServiceProvider);

    // Start polling when provider initializes
    _startPolling();

    // Load tasks from database
    _loadTasksFromDb();

    // Clean up on dispose
    ref.onDispose(() {
      _pollTimer?.cancel();
    });

    return [];
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _pollActiveTasks();
    });
  }

  Future<void> _loadTasksFromDb() async {
    try {
      final tasksData = await _databaseService.getDownloadTasks();
      final tasks = tasksData.map((m) => DownloadTask.fromMap(m)).toList();

      state = tasks;

      // Add active tasks to polling
      for (final task in tasks) {
        if (task.status == DownloadStatus.downloading ||
            task.status == DownloadStatus.processing ||
            task.status == DownloadStatus.paused || // Added this line
            task.status == DownloadStatus.queued) {
          _activeTaskIds.add(task.id);
        }
      }
    } catch (e) {
      LogService.e('Error loading tasks from DB: $e', 'DownloadService');
    }
  }

  Future<void> _pollActiveTasks() async {
    if (_activeTaskIds.isEmpty) return;

    for (final taskId in _activeTaskIds.toList()) {
      try {
        final statusMap = await _ytDlpService.getDownloadStatus(taskId);

        if (statusMap != null) {
          final status = statusMap['status'] as String? ?? 'unknown';
          final progress = (statusMap['progress'] as num?)?.toDouble() ?? 0.0;
          final filename = statusMap['filename'] as String? ?? '';
          final error = statusMap['error'] as String?;
          final speed = statusMap['speed'] as String? ?? '';
          final eta = statusMap['eta'] as String? ?? '';
          final totalBytes = (statusMap['total_bytes'] as num?)?.toInt() ?? 0;
          final downloadedBytes =
              (statusMap['downloaded_bytes'] as num?)?.toInt() ?? 0;

          // Use expectedSize from task if totalBytes is 0 or very small (inaccurate)
          final currentTask = state.firstWhere(
            (t) => t.id == taskId,
            orElse: () => DownloadTask(
              id: taskId,
              url: '',
              title: 'Unknown',
              thumbnailUrl: '',
            ),
          );

          int displayTotalBytes = totalBytes;
          if (totalBytes == 0 || totalBytes < 1000000) {
            // Less than 1MB seems inaccurate
            displayTotalBytes = currentTask.expectedSize ?? totalBytes;
          }

          // Map Python status to Dart enum
          DownloadStatus dartStatus;
          switch (status) {
            case 'queued':
              dartStatus = DownloadStatus.queued;
              break;
            case 'downloading':
              dartStatus = DownloadStatus.downloading;
              break;
            case 'paused': // Added this case
              dartStatus = DownloadStatus.paused;
              break;
            case 'converting':
              dartStatus = DownloadStatus.processing;
              break;
            case 'finished':
            case 'completed':
              dartStatus = DownloadStatus.completed;
              break;
            case 'error':
              dartStatus = DownloadStatus.error;
              // No fallback - if format not available, return error
              break;
            case 'cancelled':
              dartStatus = DownloadStatus.cancelled;
              break;
            default:
              dartStatus = DownloadStatus.queued;
          }

          // Update state
          state = state.map((task) {
            if (task.id == taskId) {
              final updatedTask = task.copyWith(
                status: dartStatus,
                progress: progress,
                filePath: filename.isNotEmpty ? filename : null,
                error: error,
                speed: speed,
                eta: eta,
                totalBytes: displayTotalBytes,
                downloadedBytes: downloadedBytes,
              );

              // Update notification for active downloads
              if (dartStatus == DownloadStatus.downloading ||
                  dartStatus == DownloadStatus.processing) {
                _notificationService.showDownloadProgress(
                  taskId: taskId,
                  title: task.title,
                  progress: progress.toInt(),
                  speed: speed,
                  eta: eta,
                );
              }

              // Save to DB periodically (or on significant status change)
              _databaseService.insertDownloadTask(updatedTask.toMap());

              return updatedTask;
            }
            return task;
          }).toList();

          // Handle completion/error
          if (dartStatus == DownloadStatus.completed ||
              dartStatus == DownloadStatus.error ||
              dartStatus == DownloadStatus.cancelled) {
            _activeTaskIds.remove(taskId);

            final task = state.firstWhere((t) => t.id == taskId);

            if (dartStatus == DownloadStatus.completed) {
              _notificationService.showDownloadComplete(
                taskId: taskId,
                title: task.title,
              );

              // Remove completed task from active state after a short delay
              // This allows user to see completion briefly before it moves to downloaded section
              Future.delayed(const Duration(seconds: 3), () {
                state = state.where((t) => t.id != taskId).toList();
              });
            } else if (dartStatus == DownloadStatus.error) {
              _notificationService.showDownloadError(
                taskId: taskId,
                title: task.title,
                error: error ?? 'Unknown error',
              );
            } else if (dartStatus == DownloadStatus.cancelled) {
              _notificationService.cancel(taskId);
            }

            if (dartStatus == DownloadStatus.completed && filename.isNotEmpty) {
              // Save to database as downloaded video
              LogService.i('Download completed: $filename', 'DownloadService');

              // Find the task to get metadata
              final task = state.firstWhere(
                (t) => t.id == taskId,
                orElse: () => DownloadTask(
                  id: taskId,
                  url: '',
                  title: 'Unknown',
                  thumbnailUrl: '',
                ),
              );

              if (task.url.isNotEmpty) {
                // Extract metadata from downloaded file (Native mode)
                String? extractedThumbnailPath;
                String? extractedDuration;
                String? fileTitle = task.title;
                try {
                  final metadata =
                      await MetadataExtractor.extractThumbnailAndDuration(
                        filename,
                      );
                  if (metadata != null) {
                    extractedThumbnailPath = metadata['thumbnailPath'];
                    extractedDuration = metadata['duration'];
                    LogService.d(
                      'Extracted metadata - Thumbnail: $extractedThumbnailPath, Duration: $extractedDuration',
                      'DownloadService',
                    );
                  }
                } catch (e) {
                  LogService.e(
                    'Failed to extract metadata from downloaded file: $e',
                    'DownloadService',
                  );
                }

                // Try to extract a better title from metadata if available
                final fullMetadata = await MetadataExtractor.extractMetadata(
                  filename,
                );
                if (fullMetadata != null && fullMetadata['title'] is String) {
                  fileTitle = fullMetadata['title'] as String;
                }

                // Create video entry with extracted metadata
                final video = {
                  'id': task.id,
                  'title': fileTitle,
                  'thumbnailUrl': extractedThumbnailPath?.isNotEmpty == true
                      ? extractedThumbnailPath
                      : task.thumbnailUrl, // Fallback to original thumbnail
                  'duration': extractedDuration?.isNotEmpty == true
                      ? extractedDuration
                      : task.duration, // Fallback to original duration
                  'url': task.url,
                  'filePath': filename,
                  'isDownloaded': 1,
                  'channelName': 'Unknown Channel', // Could be enhanced later
                  'viewCount': '0',
                  'uploadDate': '',
                  'addedDate': DateTime.now().toIso8601String(),
                };

                await _databaseService.insertVideo(video);

                // Refresh downloaded videos list
                ref.invalidate(downloadedVideosProvider);
              }
            }
          }
        }
      } catch (e) {
        LogService.e('Error polling task $taskId: $e', 'DownloadService');
      }
    }
  }

  Future<String> downloadVideoEnhanced(
    String url, {
    List<String>? formatIds,
    String outputDir = '/storage/emulated/0/Download/Curio',
    bool extractAudio = false,
    String audioFormat = 'mp3',
    bool embedMetadata = true,
  }) async {
    LogService.d(
      'DownloadService.downloadVideoEnhanced called with URL: $url',
      'DownloadService',
    );

    final taskId = DateTime.now().millisecondsSinceEpoch.toString();

    try {
      // 1. Get video info using enhanced method
      final videoInfo = await _ytDlpService.getEnhancedVideoInfo(url);
      final title = videoInfo['title'] as String? ?? 'Downloading...';
      final thumbnail = videoInfo['thumbnail'] as String? ?? '';

      // 2. Get output directory
      final downloadDir = await _storageService.getDownloadDirectory();

      // 3. Add task to state
      final newTask = DownloadTask(
        id: taskId,
        url: url,
        title: title,
        thumbnailUrl: thumbnail,
        status: DownloadStatus.downloading,
        progress: 0.0,
        expectedSize: (videoInfo['duration'] as num?)?.toInt(),
      );

      state = [...state, newTask];
      await _databaseService.insertDownloadTask(newTask.toMap());

      // 4. Start enhanced download
      final result = await _ytDlpService.startEnhancedDownload(
        url: url,
        formatIds: formatIds ?? ['best'],
        outputDir: downloadDir.path,
        extractAudio: extractAudio,
        audioFormat: audioFormat,
        embedMetadata: embedMetadata,
      );

      // 5. Handle completion (Native mode)
      if (result['success'] == true) {
        final files = result['files'] as List<dynamic>? ?? [];
        String filePath = files.isNotEmpty ? files.first as String : '';

        LogService.i(
          'Enhanced download completed: $filePath',
          'DownloadService',
        );

        final completedTask = newTask.copyWith(
          status: DownloadStatus.completed,
          progress: 100.0,
          filePath: filePath.isNotEmpty ? filePath : null,
          error: null,
        );

        state = state.map((t) => t.id == taskId ? completedTask : t).toList();
        await _databaseService.insertDownloadTask(completedTask.toMap());

        _notificationService.showDownloadComplete(taskId: taskId, title: title);

        if (filePath.isNotEmpty) {
          String? extractedThumbnailPath;
          String? extractedDuration;
          String? fileTitle = title;

          try {
            final metadata =
                await MetadataExtractor.extractThumbnailAndDuration(filePath);
            if (metadata != null) {
              extractedThumbnailPath = metadata['thumbnailPath'];
              extractedDuration = metadata['duration'];
            }
          } catch (e) {
            LogService.e(
              'Failed to extract metadata from enhanced download: $e',
              'DownloadService',
            );
          }

          try {
            final fullMetadata = await MetadataExtractor.extractMetadata(
              filePath,
            );
            if (fullMetadata != null && fullMetadata['title'] is String) {
              fileTitle = fullMetadata['title'] as String;
            }
          } catch (e) {
            LogService.e(
              'Failed to extract full metadata from enhanced download: $e',
              'DownloadService',
            );
          }

          final video = {
            'id': taskId,
            'title': fileTitle,
            'thumbnailUrl': extractedThumbnailPath?.isNotEmpty == true
                ? extractedThumbnailPath
                : thumbnail,
            'duration': extractedDuration?.isNotEmpty == true
                ? extractedDuration
                : completedTask.duration,
            'url': url,
            'filePath': filePath,
            'isDownloaded': 1,
            'channelName': 'Unknown Channel',
            'viewCount': '0',
            'uploadDate': '',
            'addedDate': DateTime.now().toIso8601String(),
          };

          await _databaseService.insertVideo(video);
          ref.invalidate(downloadedVideosProvider);
        }

        Future.delayed(const Duration(seconds: 3), () {
          if (!ref.mounted) return;
          state = state.where((t) => t.id != taskId).toList();
        });

        return taskId;
      } else {
        throw Exception(
          result['message'] as String? ?? 'Enhanced download failed',
        );
      }
    } catch (e) {
      // Update task with error
      state = state.map((task) {
        if (task.id == taskId) {
          final updatedTask = task.copyWith(
            status: DownloadStatus.error,
            error: e.toString(),
          );
          _databaseService.insertDownloadTask(updatedTask.toMap());
          _notificationService.showDownloadError(
            taskId: taskId,
            title: task.title,
            error: e.toString(),
          );
          return updatedTask;
        }
        return task;
      }).toList();

      LogService.e('Enhanced download failed: $e', 'DownloadService');
      rethrow;
    }
  }

  Future<void> downloadVideo(
    String url, {
    String? formatId,
    int? expectedSize,
    String? existingTaskId,
  }) async {
    final normalizedFormatId = _normalizeFormatSelector(formatId);

    LogService.d(
      'DownloadService.downloadVideo called with URL: $url, formatId: $formatId (normalized: $normalizedFormatId), expectedSize: $expectedSize, existingTaskId: $existingTaskId',
      'DownloadService',
    );

    // Get active cookie path
    final syncService = ref.read(syncServiceProvider.notifier);
    final cookiePath = await syncService.getActiveCookiePath();

    // Get output directory - Use proper download directory logic
    final downloadDir = await _storageService.getDownloadDirectory();
    LogService.d(
      'Using download directory: ${downloadDir.path}',
      'DownloadService',
    );

    // Add initial task to state
    // Note: We use tempId initially, but we might want to map it to the python task ID later.
    // Ideally, we start the task, get the real ID, then add to state.

    try {
      // 1. Fetch Basic Metadata for UI immediately
      final metadata = await _ytDlpService.fetchBasicMetadata(url);
      final title = metadata['title'] as String? ?? 'Downloading...';
      final thumbnail = metadata['thumbnail'] as String? ?? '';

      // Start download in Python
      String taskId;

      try {
        taskId = await _ytDlpService.startDownload(
          url,
          outputPath: downloadDir.path,
          formatId: normalizedFormatId,
          cookiePath: cookiePath,
          taskId: existingTaskId,
        );
      } catch (e) {
        // No fallback - if format not available, return error
        LogService.e('Download failed: $e', 'DownloadService');
        rethrow;
      }

      // If reusing an existing task, update it
      if (existingTaskId != null) {
        DownloadTask? updatedTask;
        state = state.map((t) {
          if (t.id == existingTaskId) {
            updatedTask = t.copyWith(
              id: taskId,
              status: DownloadStatus.queued,
              error: null, // Clear error
              progress: 0.0,
              downloadedBytes: 0,
              totalBytes: 0,
            );
            return updatedTask!;
          }
          return t;
        }).toList();

        if (updatedTask == null) {
          LogService.w(
            'Existing download task $existingTaskId not found in state. Creating new entry.',
            'DownloadService',
          );

          final fallbackTask = DownloadTask(
            id: taskId,
            url: url,
            title: title,
            thumbnailUrl: thumbnail,
            duration: _extractDurationFromMetadata(metadata),
            status: DownloadStatus.queued,
            progress: 0.0,
            formatId: _normalizeFormatSelector(
              normalizedFormatId,
            ), // Normalize format ID before storing in state
            expectedSize: expectedSize,
          );

          state = [...state, fallbackTask];
          updatedTask = fallbackTask;
        }

        if (taskId != existingTaskId) {
          _activeTaskIds.remove(existingTaskId);
          try {
            await _databaseService.deleteDownloadTask(existingTaskId);
          } catch (e) {
            LogService.w(
              'Failed to delete old download task $existingTaskId from DB: $e',
              'DownloadService',
            );
          }
        }

        _activeTaskIds.add(taskId);

        await _databaseService.insertDownloadTask(updatedTask!.toMap());
        LogService.i(
          taskId == existingTaskId
              ? 'Restarted existing download task $taskId'
              : 'Restarted download task $existingTaskId with new backend id $taskId',
          'DownloadService',
        );
      } else {
        // Add new task to state
        final newTask = DownloadTask(
          id: taskId,
          url: url,
          title: title,
          thumbnailUrl: thumbnail,
          duration: _extractDurationFromMetadata(metadata),
          status: DownloadStatus.queued,
          progress: 0,
          formatId: normalizedFormatId,
          expectedSize: expectedSize,
        );

        state = [...state, newTask];
        _activeTaskIds.add(taskId);

        // Save to database
        await _databaseService.insertDownloadTask(newTask.toMap());
        LogService.i(
          'Started download task $taskId for $url',
          'DownloadService',
        );
      }
    } catch (e) {
      LogService.e('Download setup error: $e', 'DownloadService');
      // Show error in UI (maybe add a transient error task)
      rethrow;
    }
  }

  Future<void> pauseDownload(String taskId) async {
    final success = await _ytDlpService.pauseDownload(taskId);
    if (success) {
      state = state.map((task) {
        if (task.id == taskId) {
          final updatedTask = task.copyWith(status: DownloadStatus.paused);
          _databaseService.insertDownloadTask(updatedTask.toMap());
          return updatedTask;
        }
        return task;
      }).toList();
      // _activeTaskIds.remove(taskId); // Keep polling for paused tasks
      _notificationService.cancel(taskId); // Or a new paused notification
    }
  }

  Future<void> resumeDownload(String taskId) async {
    final success = await _ytDlpService.resumeDownload(taskId);
    if (success) {
      state = state.map((task) {
        if (task.id == taskId) {
          final updatedTask = task.copyWith(status: DownloadStatus.downloading);
          _databaseService.insertDownloadTask(updatedTask.toMap());
          return updatedTask;
        }
        return task;
      }).toList();
      _activeTaskIds.add(taskId);
    }
  }

  /// Cancel enhanced download
  Future<void> cancelEnhancedDownload(String taskId) async {
    try {
      await _ytDlpService.cancelEnhancedDownload();

      // Update task state
      state = state.map((task) {
        if (task.id == taskId) {
          return task.copyWith(status: DownloadStatus.cancelled);
        }
        return task;
      }).toList();

      LogService.i('Enhanced download cancelled: $taskId', 'DownloadService');
    } catch (e) {
      LogService.e('Failed to cancel enhanced download: $e', 'DownloadService');
    }
  }

  Future<void> cancelDownload(String taskId) async {
    await _ytDlpService.cancelDownload(taskId);
    _activeTaskIds.remove(taskId);
    _notificationService.cancel(taskId);

    state = state.map((task) {
      if (task.id == taskId) {
        final updatedTask = task.copyWith(status: DownloadStatus.cancelled);
        _databaseService.insertDownloadTask(updatedTask.toMap());
        return updatedTask;
      }
      return task;
    }).toList();
  }

  Future<void> retryDownload(String taskId) async {
    final task = state.firstWhere((t) => t.id == taskId);
    if (task.status == DownloadStatus.error ||
        task.status == DownloadStatus.cancelled) {
      // Restart the download with same URL and format, REUSING the taskId
      await downloadVideo(
        task.url,
        formatId: task.formatId,
        existingTaskId: taskId,
      );
    }
  }

  Future<void> deleteDownloadTask(String taskId) async {
    await _ytDlpService.cancelDownload(taskId);
    _activeTaskIds.remove(taskId);
    _notificationService.cancel(taskId);

    // Find the task to get the file path BEFORE removing it from state
    DownloadTask? taskToDelete;
    try {
      taskToDelete = state.firstWhere((task) => task.id == taskId);
    } catch (e) {
      taskToDelete = null;
    }

    state = state.where((task) => task.id != taskId).toList();
    await _databaseService.deleteDownloadTask(taskId);
    await _databaseService.deleteVideo(taskId);

    // Now delete the file from storage
    if (taskToDelete?.filePath != null) {
      final filePath = taskToDelete!.filePath!;
      try {
        final file = io.File(filePath);
        if (await file.exists()) {
          await file.delete();
          LogService.i('Deleted file: $filePath', 'DownloadService');
        }
      } catch (e) {
        LogService.e('Error deleting file $filePath: $e', 'DownloadService');
      }
    }
  }

  Future<void> deleteMultipleVideos(List<String> taskIds) async {
    for (final taskId in taskIds) {
      await _ytDlpService.cancelDownload(taskId);
      _activeTaskIds.remove(taskId);
      _notificationService.cancel(taskId);
    }

    final tasksToDelete = state
        .where((task) => taskIds.contains(task.id))
        .toList();

    state = state.where((task) => !taskIds.contains(task.id)).toList();
    for (final taskId in taskIds) {
      await _databaseService.deleteDownloadTask(taskId);
      await _databaseService.deleteVideo(taskId);
    }

    for (final task in tasksToDelete) {
      if (task.filePath != null) {
        try {
          final file = io.File(task.filePath!);
          if (await file.exists()) {
            await file.delete();
            LogService.i('Deleted file: ${task.filePath}', 'DownloadService');
          }
        } catch (e) {
          LogService.e(
            'Error deleting file ${task.filePath}: $e',
            'DownloadService',
          );
        }
      }
    }
  }

  String? _extractDurationFromMetadata(Map<String, dynamic>? metadata) {
    if (metadata == null) return null;

    final duration = metadata['duration'];
    if (duration == null) return null;

    // Convert duration to formatted string
    if (duration is int) {
      return _formatDuration(duration);
    } else if (duration is num) {
      return _formatDuration(duration.toInt());
    }

    return duration.toString();
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    } else {
      return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
    }
  }

  Future<bool> isVideoDownloaded(String videoId) async {
    final videos = await _databaseService.getVideos(isDownloaded: true);
    return videos.any((v) => v['id'] == videoId);
  }

  Future<void> clearCompleted() async {
    // Only clear from UI state if needed, but DB keeps them for history.
    // If the user wants to clear the list, we might want to keep the DB intact
    // or provide a "Clear History" button.
    // For now, let's keep them in state as history.
  }

  Future<void> updateExistingDownloadedVideosMetadata() async {
    try {
      LogService.i(
        'Starting metadata update for existing downloaded videos',
        'DownloadService',
      );

      final videos = await _databaseService.getVideos(isDownloaded: true);
      int updatedCount = 0;

      for (final videoData in videos) {
        final video = Video.fromJson(videoData);
        final filePath = video.filePath;

        if (filePath != null && File(filePath).existsSync()) {
          try {
            // Extract metadata from the file
            final metadata =
                await MetadataExtractor.extractThumbnailAndDuration(filePath);
            if (metadata != null) {
              final extractedThumbnailPath = metadata['thumbnailPath'];
              final extractedDuration = metadata['duration'];

              // Only update if we have new metadata
              bool needsUpdate = false;
              final updatedVideo = Map<String, dynamic>.from(videoData);

              if (extractedThumbnailPath?.isNotEmpty == true &&
                  extractedThumbnailPath != video.thumbnailUrl) {
                updatedVideo['thumbnailUrl'] = extractedThumbnailPath;
                needsUpdate = true;
              }

              if (extractedDuration?.isNotEmpty == true &&
                  extractedDuration != video.duration) {
                updatedVideo['duration'] = extractedDuration;
                needsUpdate = true;
              }

              if (needsUpdate) {
                await _databaseService.saveVideos([updatedVideo]);
                updatedCount++;
                LogService.d(
                  'Updated metadata for video: ${video.title}',
                  'DownloadService',
                );
              }
            }
          } catch (e) {
            LogService.e(
              'Failed to extract metadata for ${video.title}: $e',
              'DownloadService',
            );
          }
        }
      }

      LogService.i(
        'Metadata update completed. Updated $updatedCount videos',
        'DownloadService',
      );

      // Refresh the downloaded videos provider
      ref.invalidate(downloadedVideosProvider);
    } catch (e) {
      LogService.e(
        'Error updating existing video metadata: $e',
        'DownloadService',
      );
    }
  }

  Future<void> syncLocalFiles() async {
    try {
      final downloadDir = await _storageService.getDownloadDirectory();
      LogService.d(
        'Syncing local files in: ${downloadDir.path}',
        'DownloadService',
      );

      final curioDownloadDir = downloadDir;

      // If directory doesn't exist, remove all local video records
      if (!curioDownloadDir.existsSync()) {
        final allTasks = await _databaseService.getDownloadTasks();
        for (final taskMap in allTasks) {
          final task = DownloadTask.fromMap(taskMap);
          if (task.status == DownloadStatus.completed &&
              task.filePath != null) {
            await _databaseService.deleteDownloadTask(task.id);
            await _databaseService.deleteVideo(task.id);
          }
        }
        await _loadTasksFromDb();
        LogService.w(
          'Download directory not found. Cleared all local video entries.',
          'DownloadService',
        );
        return;
      }

      // 1. Get local files and DB tasks
      final localFilePaths = curioDownloadDir
          .listSync(recursive: true)
          .whereType<io.File>()
          .where((file) {
            // Filter for video files only
            final videoExtensions = [
              '.mp4',
              '.mkv',
              '.webm',
              '.m4v',
              '.avi',
              '.mov',
              '.m4a',
              '.mp3',
            ];
            final ext = p.extension(file.path).toLowerCase();
            final filename = p.basename(file.path);
            return videoExtensions.contains(ext) &&
                !filename.endsWith('.part') &&
                !filename.endsWith('.ytdl') &&
                !filename.endsWith('.tmp');
          })
          .map((f) => f.path)
          .toSet();

      final dbTasksMaps = await _databaseService.getDownloadTasks();
      final dbTasks = dbTasksMaps.map((m) => DownloadTask.fromMap(m)).toList();

      final dbCompletedTasks = dbTasks
          .where(
            (t) => t.status == DownloadStatus.completed && t.filePath != null,
          )
          .toList();

      final dbFilePaths = dbCompletedTasks.map((t) => t.filePath!).toSet();

      LogService.i(
        'Found ${localFilePaths.length} local files, ${dbFilePaths.length} DB entries',
        'DownloadService',
      );

      // Debug: Log local file paths
      if (localFilePaths.isNotEmpty) {
        LogService.d('Local files found:', 'DownloadService');
        for (final path in localFilePaths.take(5)) {
          LogService.d('  - $path', 'DownloadService');
        }
        if (localFilePaths.length > 5) {
          LogService.d(
            '  ... and ${localFilePaths.length - 5} more',
            'DownloadService',
          );
        }
      }

      // Debug: Log DB file paths
      if (dbFilePaths.isNotEmpty) {
        LogService.d('DB file paths found:', 'DownloadService');
        for (final path in dbFilePaths.take(5)) {
          LogService.d('  - $path', 'DownloadService');
        }
        if (dbFilePaths.length > 5) {
          LogService.d(
            '  ... and ${dbFilePaths.length - 5} more',
            'DownloadService',
          );
        }
      }

      // 2. Find and delete stale DB entries (in DB but not on disk)
      final pathsToDelete = dbFilePaths.difference(localFilePaths);
      if (pathsToDelete.isNotEmpty) {
        LogService.i(
          'Removing ${pathsToDelete.length} stale DB entries',
          'DownloadService',
        );
        // Debug: Log paths to delete
        for (final path in pathsToDelete) {
          LogService.d('  To delete: $path', 'DownloadService');
        }
      }

      for (final path in pathsToDelete) {
        try {
          final taskToDelete = dbCompletedTasks.firstWhere(
            (t) => t.filePath == path,
          );
          LogService.i(
            'Sync: Deleting stale DB entry for ${taskToDelete.title}',
            'DownloadService',
          );
          await _databaseService.deleteDownloadTask(taskToDelete.id);
          await _databaseService.deleteVideo(taskToDelete.id);
        } catch (e) {
          LogService.e(
            'Error finding task to delete for path: $path',
            'DownloadService',
          );
        }
      }

      // 3. Find and add new local files (on disk but not in DB)
      final pathsToAdd = localFilePaths.difference(dbFilePaths);
      if (pathsToAdd.isNotEmpty) {
        LogService.i(
          'Adding ${pathsToAdd.length} new local files',
          'DownloadService',
        );
        // Debug: Log paths to add
        for (final path in pathsToAdd) {
          LogService.d('  To add: $path', 'DownloadService');
        }
      }

      for (final path in pathsToAdd) {
        final filename = p.basename(path);
        LogService.i(
          'Sync: Found new local file to add: $filename',
          'DownloadService',
        );

        // Generate a unique ID based on filename and timestamp
        final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        final taskId = '${timestamp}_${filename.hashCode}';

        final file = io.File(path);
        final lastModified = await file.lastModified();
        final fileSize = await file.length();

        final task = DownloadTask(
          id: taskId,
          url: '', // We don't know the URL for manually added files
          title: p.basenameWithoutExtension(filename),
          thumbnailUrl: '',
          status: DownloadStatus.completed,
          progress: 100.0,
          filePath: path,
          addedDate: lastModified,
          totalBytes: fileSize,
          downloadedBytes: fileSize,
        );
        await _databaseService.insertDownloadTask(task.toMap());

        // Extract metadata from the file
        String? extractedThumbnailPath;
        String? extractedDuration;
        String? fileTitle = p.basenameWithoutExtension(filename);

        try {
          final metadata = await MetadataExtractor.extractThumbnailAndDuration(
            path,
          );
          if (metadata != null) {
            extractedThumbnailPath = metadata['thumbnailPath'];
            extractedDuration = metadata['duration'];
            LogService.d(
              'Sync extracted metadata - Thumbnail: $extractedThumbnailPath, Duration: $extractedDuration',
              'DownloadService',
            );

            // Try to extract a better title from metadata if available
            final fullMetadata = await MetadataExtractor.extractMetadata(path);
            if (fullMetadata != null && fullMetadata['title'] is String) {
              fileTitle = fullMetadata['title'] as String;
            }
          }
        } catch (e) {
          LogService.e(
            'Failed to extract metadata during sync: $e',
            'DownloadService',
          );
        }

        final video = {
          'id': taskId,
          'title': fileTitle,
          'thumbnailUrl': extractedThumbnailPath ?? '',
          'duration': extractedDuration ?? '',
          'url': '',
          'filePath': path,
          'isDownloaded': 1,
          'channelName': 'Unknown Channel',
          'viewCount': '0',
          'uploadDate': '',
          'addedDate': lastModified.toIso8601String(),
        };
        await _databaseService.insertVideo(video);
      }

      LogService.i(
        'Sync completed: ${pathsToAdd.length} added, ${pathsToDelete.length} removed',
        'DownloadService',
      );

      // Debug: Final summary
      if (pathsToAdd.isEmpty && pathsToDelete.isEmpty) {
        LogService.d(
          'Sync: No changes needed - all files already in sync',
          'DownloadService',
        );
        LogService.d('Local files match DB entries exactly', 'DownloadService');
      }
    } catch (e) {
      LogService.e('Error syncing local files: $e', 'DownloadService');
      rethrow;
    }
  }

  String? _normalizeFormatSelector(String? value) {
    if (value == null || value.isEmpty) return value;

    final selectors = value.split(',');
    final normalizedSelectors = selectors
        .map((selector) {
          final parts = selector.split('+');
          final normalizedParts = parts
              .map((part) {
                var cleaned = part.trim();
                for (final suffix in _formatSuffixesToStrip) {
                  if (cleaned.endsWith(suffix)) {
                    cleaned = cleaned.substring(
                      0,
                      cleaned.length - suffix.length,
                    );
                    break;
                  }
                }
                return cleaned;
              })
              .where((segment) => segment.isNotEmpty);

          return normalizedParts.join('+');
        })
        .where((segment) => segment.isNotEmpty);

    final normalized = normalizedSelectors.join(',');
    return normalized.isEmpty ? null : normalized;
  }
}
