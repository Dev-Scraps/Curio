import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:synchronized/synchronized.dart';

part 'database.g.dart';

@Riverpod(keepAlive: true)
DatabaseService databaseService(Ref ref) {
  return DatabaseService();
}

class DatabaseService {
  Database? _database;
  final _lock = Lock();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('Curio.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 12,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // ---------------- VIDEOS ----------------
    await db.execute('''
      CREATE TABLE videos (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        channelName TEXT,
        channelId TEXT,
        viewCount TEXT,
        uploadDate TEXT,
        duration TEXT,
        thumbnailUrl TEXT,
        isShort INTEGER DEFAULT 0,
        downloadProgress REAL,
        playlistId TEXT,
        position INTEGER,
        addedDate TEXT,
        isLiked INTEGER DEFAULT 0,
        isWatchLater INTEGER DEFAULT 0,
        description TEXT,
        url TEXT,
        filePath TEXT,
        isDownloaded INTEGER DEFAULT 0
      )
    ''');

    // ---------------- PLAYLISTS (FIXED) ----------------
    await db.execute('''
      CREATE TABLE playlists (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        videoCount INTEGER,
        thumbnailUrl TEXT,
        uploader TEXT,
        uploaderUrl TEXT,
        lastUpdated TEXT,
        isLiked INTEGER DEFAULT 0,
        isWatchLater INTEGER DEFAULT 0,

        channel TEXT,          -- ✅ ADDED
        channelId TEXT,        -- ✅ ADDED
        channelUrl TEXT,       -- ✅ ADDED
        availability TEXT,     -- ✅ ADDED
        modifiedDate TEXT,     -- ✅ ADDED
        viewCount INTEGER      -- ✅ ADDED
      )
    ''');

    // ---------------- VIDEO PROGRESS ----------------
    await db.execute('''
      CREATE TABLE video_progress (
        videoId TEXT PRIMARY KEY,
        watchedDuration INTEGER NOT NULL DEFAULT 0,
        totalDuration INTEGER NOT NULL DEFAULT 0,
        lastWatched INTEGER NOT NULL,
        isCompleted INTEGER DEFAULT 0,
        quality INTEGER DEFAULT 0
      )
    ''');

    // ---------------- INDEXES ----------------
    await db.execute(
      'CREATE INDEX idx_videos_playlistId ON videos (playlistId)',
    );
    await db.execute('CREATE INDEX idx_videos_isLiked ON videos (isLiked)');
    await db.execute(
      'CREATE INDEX idx_videos_isWatchLater ON videos (isWatchLater)',
    );
    await db.execute(
      'CREATE INDEX idx_videos_isDownloaded ON videos (isDownloaded)',
    );

    // ---------------- DOWNLOAD TASKS ----------------
    await db.execute('''
      CREATE TABLE download_tasks (
        id TEXT PRIMARY KEY,
        url TEXT NOT NULL,
        title TEXT NOT NULL,
        thumbnailUrl TEXT,
        duration TEXT,
        progress REAL DEFAULT 0.0,
        speed TEXT,
        eta TEXT,
        totalBytes INTEGER DEFAULT 0,
        downloadedBytes INTEGER DEFAULT 0,
        status TEXT NOT NULL,
        error TEXT,
        filePath TEXT,
        formatId TEXT,
        expectedSize INTEGER,
        addedDate TEXT NOT NULL,
        -- Metadata fields
        artist TEXT,
        album TEXT,
        genre TEXT,
        uploadDate TEXT,
        description TEXT,
        embeddedMetadata TEXT
      )
    ''');

    // ---------------- STUDY MATERIALS ----------------
    await db.execute('''
      CREATE TABLE study_materials (
        videoId TEXT PRIMARY KEY,
        summary TEXT,
        studyNotes TEXT,
        questions TEXT,
        quiz TEXT,
        analysis TEXT,
        transcript TEXT,
        generatedAt TEXT,
        hasApiKey INTEGER DEFAULT 0
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('[DatabaseService] Upgrading DB from $oldVersion to $newVersion');
    if (oldVersion < 4) {
      await db.execute('DROP TABLE IF EXISTS videos');
      await db.execute('DROP TABLE IF EXISTS playlists');
      await db.execute('DROP TABLE IF EXISTS playlist_videos');
      await db.execute('DROP TABLE IF EXISTS channels');
      await db.execute('DROP TABLE IF EXISTS comments');
      await _createDB(db, newVersion);
    } else if (oldVersion < 6) {
      // Version 6: Add download_tasks table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS download_tasks (
          id TEXT PRIMARY KEY,
          url TEXT NOT NULL,
          title TEXT NOT NULL,
          thumbnailUrl TEXT,
          duration TEXT,
          progress REAL DEFAULT 0.0,
          speed TEXT,
          eta TEXT,
          totalBytes INTEGER DEFAULT 0,
          downloadedBytes INTEGER DEFAULT 0,
          status TEXT NOT NULL,
          error TEXT,
          filePath TEXT,
          formatId TEXT,
          addedDate TEXT NOT NULL
        )
      ''');
    } else if (oldVersion < 7) {
      // Version 7: Add duration column to existing download_tasks table
      try {
        await db.execute('ALTER TABLE download_tasks ADD COLUMN duration TEXT');
      } catch (e) {
        // Column might already exist
        print('[DatabaseService] Error adding duration column: $e');
      }
    }

    if (oldVersion < 7) {
      // Version 7: Add formatId column to download_tasks if it doesn't exist
      try {
        await db.execute('ALTER TABLE download_tasks ADD COLUMN formatId TEXT');
      } catch (e) {
        // Column might already exist if migration ran partially
        print('[DatabaseService] Error adding formatId column: $e');
      }
    }

    if (oldVersion < 8) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS study_materials (
            videoId TEXT PRIMARY KEY,
            summary TEXT,
            studyNotes TEXT,
            questions TEXT,
            quiz TEXT,
            analysis TEXT,
            transcript TEXT,
            generatedAt TEXT,
            hasApiKey INTEGER DEFAULT 0
          )
        ''');
      } catch (e) {
        print('[DatabaseService] Error creating study_materials table: $e');
      }
    }

    if (oldVersion < 9) {
      try {
        await db.execute(
          'ALTER TABLE study_materials ADD COLUMN hasApiKey INTEGER DEFAULT 0',
        );
      } catch (e) {
        // Column might already exist if migration ran partially
        print(
          '[DatabaseService] Error adding hasApiKey column to study_materials: $e',
        );
      }
    }

    if (oldVersion < 11) {
      try {
        await db.execute(
          'ALTER TABLE download_tasks ADD COLUMN expectedSize INTEGER',
        );
      } catch (e) {
        // Column might already exist
        print('[DatabaseService] Error adding expectedSize column: $e');
      }
    }

    if (oldVersion < 12) {
      try {
        // Add metadata columns to download_tasks table
        await db.execute('ALTER TABLE download_tasks ADD COLUMN artist TEXT');
        await db.execute('ALTER TABLE download_tasks ADD COLUMN album TEXT');
        await db.execute('ALTER TABLE download_tasks ADD COLUMN genre TEXT');
        await db.execute(
          'ALTER TABLE download_tasks ADD COLUMN uploadDate TEXT',
        );
        await db.execute(
          'ALTER TABLE download_tasks ADD COLUMN description TEXT',
        );
        await db.execute(
          'ALTER TABLE download_tasks ADD COLUMN embeddedMetadata TEXT',
        );
      } catch (e) {
        // Columns might already exist
        print('[DatabaseService] Error adding metadata columns: $e');
      }
    }
  }

  // ---------------- PLAYLIST OPS ----------------

  Future<void> savePlaylists(List<Map<String, dynamic>> playlists) async {
    await _lock.synchronized(() async {
      final db = await database;
      await db.transaction((txn) async {
        final batch = txn.batch();

        for (final playlist in playlists) {
          final playlistData = Map<String, dynamic>.from(playlist);
          playlistData['isLiked'] =
              (playlistData['isLiked'] == true || playlistData['isLiked'] == 1)
              ? 1
              : 0;
          playlistData['isWatchLater'] =
              (playlistData['isWatchLater'] == true ||
                  playlistData['isWatchLater'] == 1)
              ? 1
              : 0;

          batch.insert(
            'playlists',
            playlistData,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        await batch.commit(noResult: true);
      });
    });
  }

  Future<void> replacePlaylists(List<Map<String, dynamic>> playlists) async {
    await _lock.synchronized(() async {
      final db = await database;
      await db.transaction((txn) async {
        final batch = txn.batch();

        final newIds = playlists.map((p) => p['id'] as String).toList();

        final rows = await txn.query('playlists', columns: ['id']);
        final currentIds = rows.map((r) => r['id'] as String).toSet();
        final keepingIds = newIds.toSet();
        final idsToDelete = currentIds.difference(keepingIds);

        for (final id in idsToDelete) {
          if (id == 'LL' || id == 'WL') continue;
          batch.delete('playlists', where: 'id = ?', whereArgs: [id]);
        }

        for (final playlist in playlists) {
          final playlistData = Map<String, dynamic>.from(playlist);
          playlistData['isLiked'] =
              (playlistData['isLiked'] == true || playlistData['isLiked'] == 1)
              ? 1
              : 0;
          playlistData['isWatchLater'] =
              (playlistData['isWatchLater'] == true ||
                  playlistData['isWatchLater'] == 1)
              ? 1
              : 0;

          batch.insert(
            'playlists',
            playlistData,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        await batch.commit(noResult: true);
      });
    });
  }

  Future<List<Map<String, dynamic>>> getPlaylists() async {
    final db = await database;
    return await db.query('playlists');
  }

  Future<Map<String, dynamic>?> getPlaylist(String id) async {
    final db = await database;
    final results = await db.query(
      'playlists',
      where: 'id = ?',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  // ---------------- VIDEO OPS ----------------

  Future<void> saveVideos(List<Map<String, dynamic>> videos) async {
    await _lock.synchronized(() async {
      final db = await database;
      await db.transaction((txn) async {
        final batch = txn.batch();

        for (final video in videos) {
          final videoData = Map<String, dynamic>.from(video);
          videoData['isShort'] =
              (videoData['isShort'] == true || videoData['isShort'] == 1)
              ? 1
              : 0;
          videoData['isLiked'] =
              (videoData['isLiked'] == true || videoData['isLiked'] == 1)
              ? 1
              : 0;
          videoData['isWatchLater'] =
              (videoData['isWatchLater'] == true ||
                  videoData['isWatchLater'] == 1)
              ? 1
              : 0;
          videoData['isDownloaded'] =
              (videoData['isDownloaded'] == true ||
                  videoData['isDownloaded'] == 1)
              ? 1
              : 0;

          batch.insert(
            'videos',
            videoData,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        await batch.commit(noResult: true);
      });
    });
  }

  Future<List<Map<String, dynamic>>> getVideos({
    String? playlistId,
    bool? isLiked,
    bool? isWatchLater,
    bool? isDownloaded,
  }) async {
    final db = await database;
    String? whereClause;
    List<dynamic>? whereArgs;

    if (playlistId != null) {
      whereClause = 'playlistId = ?';
      whereArgs = [playlistId];
    } else if (isLiked == true) {
      whereClause = 'isLiked = ?';
      whereArgs = [1];
    } else if (isWatchLater == true) {
      whereClause = 'isWatchLater = ?';
      whereArgs = [1];
    } else if (isDownloaded == true) {
      whereClause = 'isDownloaded = ?';
      whereArgs = [1];
    }

    return await db.query(
      'videos',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'position ASC, addedDate DESC',
    );
  }

  Future<void> clearPlaylistVideos(String playlistId) async {
    await _lock.synchronized(() async {
      final db = await database;
      await db.delete(
        'videos',
        where: 'playlistId = ?',
        whereArgs: [playlistId],
      );
    });
  }

  Future<void> deleteVideo(String id) async {
    await _lock.synchronized(() async {
      final db = await database;
      await db.delete('videos', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> deleteMultipleVideos(List<String> ids) async {
    if (ids.isEmpty) return;
    await _lock.synchronized(() async {
      final db = await database;
      await db.transaction((txn) async {
        final batch = txn.batch();
        for (final id in ids) {
          batch.delete('videos', where: 'id = ?', whereArgs: [id]);
        }
        await batch.commit(noResult: true);
      });
    });
  }

  Future<void> clearLikedVideos() async {
    await _lock.synchronized(() async {
      final db = await database;
      await db.delete('videos', where: 'isLiked = ?', whereArgs: [1]);
    });
  }

  Future<void> clearWatchLaterVideos() async {
    await _lock.synchronized(() async {
      final db = await database;
      await db.delete('videos', where: 'isWatchLater = ?', whereArgs: [1]);
    });
  }

  Future<void> insertVideo(Map<String, dynamic> video) async {
    await saveVideos([video]);
  }

  Future<List<Map<String, dynamic>>> getDownloadedVideos() async {
    return await getVideos(isDownloaded: true);
  }

  // ---------------- VIDEO PROGRESS OPS ----------------

  Future<void> saveVideoProgress(Map<String, dynamic> progress) async {
    await _lock.synchronized(() async {
      final db = await database;
      await db.insert(
        'video_progress',
        progress,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<Map<String, dynamic>?> getVideoProgress(String videoId) async {
    final db = await database;
    final results = await db.query(
      'video_progress',
      where: 'videoId = ?',
      whereArgs: [videoId],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> getAllVideoProgress() async {
    final db = await database;
    return await db.query('video_progress', orderBy: 'lastWatched DESC');
  }

  Future<void> deleteVideoProgress(String videoId) async {
    await _lock.synchronized(() async {
      final db = await database;
      await db.delete(
        'video_progress',
        where: 'videoId = ?',
        whereArgs: [videoId],
      );
    });
  }

  Future<void> clearOldVideoProgress({int daysOld = 30}) async {
    await _lock.synchronized(() async {
      final db = await database;
      final cutoffTime = DateTime.now()
          .subtract(Duration(days: daysOld))
          .millisecondsSinceEpoch;
      await db.delete(
        'video_progress',
        where: 'lastWatched < ?',
        whereArgs: [cutoffTime],
      );
    });
  }

  // ---------------- DOWNLOAD TASK OPS ----------------

  Future<void> insertDownloadTask(Map<String, dynamic> task) async {
    await _lock.synchronized(() async {
      final db = await database;
      await db.insert(
        'download_tasks',
        task,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<List<Map<String, dynamic>>> getDownloadTasks() async {
    final db = await database;
    return await db.query('download_tasks', orderBy: 'addedDate DESC');
  }

  Future<void> deleteDownloadTask(String id) async {
    await _lock.synchronized(() async {
      final db = await database;
      await db.delete('download_tasks', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> deleteMultipleDownloadTasks(List<String> ids) async {
    if (ids.isEmpty) return;
    await _lock.synchronized(() async {
      final db = await database;
      await db.transaction((txn) async {
        final batch = txn.batch();
        for (final id in ids) {
          batch.delete('download_tasks', where: 'id = ?', whereArgs: [id]);
        }
        await batch.commit(noResult: true);
      });
    });
  }

  // ---------------- STUDY MATERIALS OPS ----------------

  Future<void> saveStudyMaterial(Map<String, dynamic> material) async {
    await _lock.synchronized(() async {
      final db = await database;
      await db.insert(
        'study_materials',
        material,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<Map<String, dynamic>?> getStudyMaterial(String videoId) async {
    final db = await database;
    final results = await db.query(
      'study_materials',
      where: 'videoId = ?',
      whereArgs: [videoId],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> deleteStudyMaterial(String videoId) async {
    await _lock.synchronized(() async {
      final db = await database;
      await db.delete(
        'study_materials',
        where: 'videoId = ?',
        whereArgs: [videoId],
      );
    });
  }

  Future<bool> hasStudyMaterial(String videoId) async {
    final material = await getStudyMaterial(videoId);
    return material != null;
  }

  // ---------------- AI HISTORY OPS ----------------

  Future<List<Map<String, dynamic>>> getAIHistoryByType(String type) async {
    final db = await database;
    String column;

    switch (type.toLowerCase()) {
      case 'summary':
        column = 'summary';
        break;
      case 'notes':
        column = 'studyNotes';
        break;
      case 'questions':
        column = 'questions';
        break;
      case 'quiz':
        column = 'quiz';
        break;
      case 'analysis':
        column = 'analysis';
        break;
      default:
        return [];
    }

    return await db.rawQuery('''
      SELECT 
        sm.videoId,
        sm.generatedAt,
        v.title,
        v.thumbnailUrl,
        v.channelName,
        v.duration,
        sm.$column as content
      FROM study_materials sm
      INNER JOIN videos v ON sm.videoId = v.id
      WHERE sm.$column IS NOT NULL AND sm.$column != ''
      ORDER BY sm.generatedAt DESC
    ''');
  }

  Future<List<Map<String, dynamic>>> getAIHistoryByTypeAndDate(
    String type,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;
    String column;

    switch (type.toLowerCase()) {
      case 'summary':
        column = 'summary';
        break;
      case 'notes':
        column = 'studyNotes';
        break;
      case 'questions':
        column = 'questions';
        break;
      case 'quiz':
        column = 'quiz';
        break;
      case 'analysis':
        column = 'analysis';
        break;
      default:
        return [];
    }

    final startMs = startDate.millisecondsSinceEpoch;
    final endMs = endDate.millisecondsSinceEpoch;

    return await db.rawQuery(
      '''
      SELECT 
        sm.videoId,
        sm.generatedAt,
        v.title,
        v.thumbnailUrl,
        v.channelName,
        v.duration,
        sm.$column as content
      FROM study_materials sm
      INNER JOIN videos v ON sm.videoId = v.id
      WHERE sm.$column IS NOT NULL 
        AND sm.$column != ''
        AND sm.generatedAt >= ?
        AND sm.generatedAt <= ?
      ORDER BY sm.generatedAt DESC
    ''',
      [startMs, endMs],
    );
  }

  Future<Map<String, int>> getAIHistoryCounts() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT 
        COUNT(CASE WHEN summary IS NOT NULL AND summary != '' THEN 1 END) as summary_count,
        COUNT(CASE WHEN studyNotes IS NOT NULL AND studyNotes != '' THEN 1 END) as notes_count,
        COUNT(CASE WHEN questions IS NOT NULL AND questions != '' THEN 1 END) as questions_count,
        COUNT(CASE WHEN quiz IS NOT NULL AND quiz != '' THEN 1 END) as quiz_count,
        COUNT(CASE WHEN analysis IS NOT NULL AND analysis != '' THEN 1 END) as analysis_count
      FROM study_materials
    ''');

    final row = result.first;
    return {
      'summary': row['summary_count'] as int? ?? 0,
      'notes': row['notes_count'] as int? ?? 0,
      'questions': row['questions_count'] as int? ?? 0,
      'quiz': row['quiz_count'] as int? ?? 0,
      'analysis': row['analysis_count'] as int? ?? 0,
    };
  }

  Future<List<Map<String, dynamic>>> getRecentAIHistory({
    int limit = 10,
  }) async {
    final db = await database;
    return await db.rawQuery(
      '''
      SELECT 
        sm.videoId,
        sm.generatedAt,
        v.title,
        v.thumbnailUrl,
        v.channelName,
        CASE 
          WHEN sm.summary IS NOT NULL AND sm.summary != '' THEN 'summary'
          WHEN sm.studyNotes IS NOT NULL AND sm.studyNotes != '' THEN 'notes'
          WHEN sm.questions IS NOT NULL AND sm.questions != '' THEN 'questions'
          WHEN sm.quiz IS NOT NULL AND sm.quiz != '' THEN 'quiz'
          WHEN sm.analysis IS NOT NULL AND sm.analysis != '' THEN 'analysis'
          ELSE 'unknown'
        END as type
      FROM study_materials sm
      INNER JOIN videos v ON sm.videoId = v.id
      WHERE (
        sm.summary IS NOT NULL AND sm.summary != '' OR
        sm.studyNotes IS NOT NULL AND sm.studyNotes != '' OR
        sm.questions IS NOT NULL AND sm.questions != '' OR
        sm.quiz IS NOT NULL AND sm.quiz != '' OR
        sm.analysis IS NOT NULL AND sm.analysis != ''
      )
      ORDER BY sm.generatedAt DESC
      LIMIT ?
    ''',
      [limit],
    );
  }
}
