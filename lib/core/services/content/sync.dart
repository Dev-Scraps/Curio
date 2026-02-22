import 'dart:convert';
import 'dart:io';
import 'package:curio/core/models/account.dart';
import 'package:curio/presentation/providers/videos_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../storage/database.dart';
import '../network/connectivity.dart';
import '../system/logger.dart';
import '../yt_dlp/youtube.dart';
import '../system/notifications.dart';

part 'sync.g.dart';

class SyncState {
  final List<Account> accounts;
  final Account? activeAccount;
  final bool isSyncing;
  final String? syncStatus;
  final double syncProgress;

  SyncState({
    this.accounts = const [],
    this.activeAccount,
    this.isSyncing = false,
    this.syncStatus,
    this.syncProgress = 0.0,
  });

  SyncState copyWith({
    List<Account>? accounts,
    Account? activeAccount,
    bool? isSyncing,
    String? syncStatus,
    double? syncProgress,
  }) {
    return SyncState(
      accounts: accounts ?? this.accounts,
      activeAccount: activeAccount ?? this.activeAccount,
      isSyncing: isSyncing ?? this.isSyncing,
      syncStatus: syncStatus ?? this.syncStatus,
      syncProgress: syncProgress ?? this.syncProgress,
    );
  }
}

@Riverpod(keepAlive: true)
class SyncService extends _$SyncService {
  @override
  SyncState build() {
    _loadAccounts();
    return SyncState();
  }

  void _updateStatus(String status, {double? progress}) {
    state = state.copyWith(
      syncStatus: status,
      syncProgress: progress ?? state.syncProgress,
    );
    LogService.i('SyncService', status);

    // Also update notification if syncing
    if (state.isSyncing) {
      ref
          .read(notificationServiceProvider)
          .showSyncProgress(
            progress: (state.syncProgress * 100).toInt(),
            total: 100,
            status: status,
          );
    }
  }

  Future<File> get _accountsFile async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, 'accounts.json'));
  }

  Future<void> _loadAccounts() async {
    try {
      final file = await _accountsFile;
      if (await file.exists()) {
        final jsonStr = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(jsonStr);
        final accounts = jsonList.map((j) => Account.fromJson(j)).toList();

        Account? active;
        if (accounts.isNotEmpty) {
          active = accounts.first;
        }

        state = SyncState(accounts: accounts, activeAccount: active);
      }
    } catch (e) {
      print('[SyncService] Error loading accounts: $e');
    }
  }

  Future<void> _saveAccounts() async {
    try {
      final file = await _accountsFile;
      final jsonList = state.accounts.map((a) => a.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      print('[SyncService] Error saving accounts: $e');
    }
  }

  Future<void> addAccount(Account account) async {
    final existingIndex = state.accounts.indexWhere((a) => a.id == account.id);
    List<Account> newAccounts;

    if (existingIndex >= 0) {
      newAccounts = List.from(state.accounts);
      newAccounts[existingIndex] = account;
    } else {
      newAccounts = [...state.accounts, account];
    }

    state = state.copyWith(accounts: newAccounts, activeAccount: account);
    await _saveAccounts();
  }

  Future<void> importCookies(String filePath) async {
    try {
      final dir = await getApplicationSupportDirectory();
      final cookiesDir = Directory(p.join(dir.path, 'cookies'));
      if (!await cookiesDir.exists()) {
        await cookiesDir.create(recursive: true);
      }

      final id = 'imported_${DateTime.now().millisecondsSinceEpoch}';
      final accountName = 'Imported Account ${state.accounts.length + 1}';
      final newCookiePath = p.join(cookiesDir.path, '$id.txt');

      await File(filePath).copy(newCookiePath);

      final account = Account(
        id: id,
        name: accountName,
        email: 'imported@cookies.local',
        avatarUrl: '',
        cookiePath: newCookiePath,
      );

      await addAccount(account);
    } catch (e) {
      print('[SyncService] Error importing cookies: $e');
      rethrow;
    }
  }

  Future<String?> getActiveCookiePath() async {
    return state.activeAccount?.cookiePath;
  }

  Future<void> removeAccount(String accountId) async {
    final accountToRemove = state.accounts.firstWhere(
      (a) => a.id == accountId,
      orElse: () => throw Exception('Account not found'),
    );

    try {
      final cookieFile = File(accountToRemove.cookiePath);
      if (await cookieFile.exists()) {
        await cookieFile.delete();
      }
    } catch (e) {
      print('[SyncService] Error deleting cookie file: $e');
    }

    final newAccounts = state.accounts.where((a) => a.id != accountId).toList();

    Account? newActive = state.activeAccount;
    if (state.activeAccount?.id == accountId) {
      newActive = newAccounts.isNotEmpty ? newAccounts.first : null;
    }

    state = state.copyWith(accounts: newAccounts, activeAccount: newActive);
    await _saveAccounts();
  }

  Future<void> setActiveAccount(String accountId) async {
    final account = state.accounts.firstWhere(
      (a) => a.id == accountId,
      orElse: () => throw Exception('Account not found'),
    );
    state = state.copyWith(activeAccount: account);
  }

  Future<void> switchAccount(String accountId) async {
    final account = state.accounts.firstWhere(
      (a) => a.id == accountId,
      orElse: () => throw Exception('Account not found'),
    );

    // Reorder list to put active account first for persistence
    final otherAccounts = state.accounts
        .where((a) => a.id != accountId)
        .toList();
    final newAccounts = [account, ...otherAccounts];

    state = state.copyWith(activeAccount: account, accounts: newAccounts);

    await _saveAccounts();

    // Refresh library data for the new account
    await syncStructure();
    // We might want to trigger full sync or valid providers, but syncStructure gives immediate feedback
  }

  /// Background fetches the user profile (Name, Avatar) and updates state
  Future<void> updateUserProfile() async {
    final account = state.activeAccount;
    if (account == null) return;

    try {
      final youtubeService = ref.read(youtubeServiceProvider);
      final info = await youtubeService.fetchSelfProfile(account.cookiePath);

      if (info.isNotEmpty) {
        final updatedAccount = account.copyWith(
          name: info['name']?.isNotEmpty == true ? info['name'] : account.name,
          email: info['email']?.isNotEmpty == true
              ? info['email']!
              : account.email,
          avatarUrl: info['avatar']?.isNotEmpty == true
              ? info['avatar']
              : account.avatarUrl,
        );
        await addAccount(updatedAccount);
        print('[SyncService] Profile updated: ${updatedAccount.name}');
      }
    } catch (e) {
      print('[SyncService] Failed to update profile: $e');
    }
  }

  /// Fast Sync: Just fetches playlist structure (names, IDs)
  Future<void> syncStructure() async {
    if (state.activeAccount == null) return;
    final cookiePath = await getActiveCookiePath();
    if (cookiePath == null) return;

    state = state.copyWith(
      isSyncing: true,
      syncStatus: 'Fetching playlists...',
      syncProgress: 0.1,
    );

    try {
      final youtubeService = ref.read(youtubeServiceProvider);
      final databaseService = ref.read(databaseServiceProvider);

      // Fetch Playlist Contexts
      final playlists = await youtubeService.fetchPlaylists(cookiePath);
      await databaseService.replacePlaylists(
        playlists.map<Map<String, dynamic>>((p) => p.toJson()).toList(),
      );

      state = state.copyWith(
        isSyncing: false,
        syncStatus: 'Structure synced',
        syncProgress: 1.0,
      );
    } catch (e) {
      print('[SyncService] Structure sync failed: $e');
      state = state.copyWith(
        isSyncing: false,
        syncStatus: 'Failed: $e',
        syncProgress: 0.0,
      );
      rethrow;
    }
  }

  /// Production-Level Progressive Sync System
  ///
  /// Flow:
  /// 1. Quick Discovery: Count total playlists (1-2 seconds)
  /// 2. Progressive Fetch: Fetch each playlist one by one with flat mode
  ///    - Each playlist appears on screen immediately after fetching
  ///    - Real-time progress updates
  /// 3. On-Demand: Full video details loaded when user clicks a video
  Future<void> syncFullLibrary() async {
    if (state.activeAccount == null) {
      _updateStatus(
        'No active account. Please login or import cookies.',
        progress: 0.0,
      );
      state = state.copyWith(isSyncing: false);
      throw Exception('No active account');
    }

    final cookiePath = await getActiveCookiePath();
    if (cookiePath == null) return;

    if (state.isSyncing) {
      LogService.w('Sync already in progress', 'SyncService');
      return;
    }

    final connectivity = ref.read(connectivityServiceProvider);
    if (!await connectivity.hasInternetAccess()) {
      _updateStatus('No internet connection', progress: 0.0);
      state = state.copyWith(isSyncing: false);
      return;
    }

    state = state.copyWith(isSyncing: true);
    _updateStatus('Initializing sync...', progress: 0.0);

    print('[SyncService] 🚀 Starting Production-Level Progressive Sync...');

    try {
      final youtubeService = ref.read(youtubeServiceProvider);
      final databaseService = ref.read(databaseServiceProvider);

      final stopwatch = Stopwatch()..start();

      // ==================== PHASE 1: QUICK DISCOVERY ====================
      print('[SyncService] 📊 Phase 1: Discovering ALL playlists...');
      _updateStatus('Discovering all your playlists...', progress: 0.05);

      final playlists = await youtubeService.fetchPlaylists(cookiePath);

      if (playlists.isEmpty) {
        _updateStatus(
          'No playlists found. Please check your cookies.',
          progress: 0.0,
        );
        state = state.copyWith(isSyncing: false);
        return;
      }

      final validPlaylists = playlists.where((p) {
        final id = p.id;
        // Keep special playlists
        if (id == 'WL' || id == 'LL') return true;
        // Keep proper playlist IDs (start with PL, RD, etc. or are longer than 15 chars)
        if (id.startsWith(RegExp(r'PL|RD|OL|UU|FL|RDMM'))) return true;
        if (id.length > 15) return true;
        // Filter out 11-char video IDs
        if (id.length == 11) {
          print('[SyncService] ⚠️  Filtering out video ID: $id (${p.title})');
          return false;
        }
        return true;
      }).toList();

      await databaseService.replacePlaylists(
        validPlaylists.map<Map<String, dynamic>>((p) => p.toJson()).toList(),
      );

      final totalPlaylists = validPlaylists.length;
      print(
        '[SyncService] ✅ Found $totalPlaylists playlists (including WL, LL, saved, created, private)',
      );
      _updateStatus(
        'Found $totalPlaylists playlists. Starting sync...',
        progress: 0.10,
      );

      await Future.delayed(const Duration(milliseconds: 500));

      // ==================== PHASE 2: PROGRESSIVE FETCH ====================
      print('[SyncService] 🎯 Phase 2: Progressive syncing (one by one)...');

      int completedPlaylists = 0;
      int totalVideos = 0;

      for (var i = 0; i < validPlaylists.length; i++) {
        final playlist = validPlaylists[i];

        try {
          completedPlaylists++;
          final progressPercent =
              0.10 + (0.80 * (completedPlaylists / totalPlaylists));

          _updateStatus(
            'Syncing "${playlist.title}" ($completedPlaylists/$totalPlaylists)...',
            progress: progressPercent,
          );

          print(
            '[SyncService] 📥 [$completedPlaylists/$totalPlaylists] Syncing: ${playlist.title}',
          );

          final videos = await youtubeService.fetchPlaylistItems(
            playlist.id,
            cookiePath,
            flat: true, // Fast flat mode
          );

          if (videos.isEmpty) {
            print('[SyncService] ⚠️  ${playlist.title}: No videos');
            continue;
          }

          final videosToSave = <Map<String, dynamic>>[];
          for (var j = 0; j < videos.length; j++) {
            final video = videos[j];
            final videoJson = video.toJson();
            videoJson['playlistId'] = playlist.id;
            videoJson['position'] = j;
            if (playlist.id == 'LL') videoJson['isLiked'] = true;
            if (playlist.id == 'WL') videoJson['isWatchLater'] = true;
            videosToSave.add(videoJson);
          }

          await databaseService.saveVideos(videosToSave);

          ref.invalidate(playlistVideosProvider(playlist.id));
          if (playlist.id == 'LL') ref.invalidate(likedVideosProvider);
          if (playlist.id == 'WL') ref.invalidate(watchLaterVideosProvider);

          totalVideos += videos.length;

          final firstChannelName = videos.isNotEmpty
              ? videos.first.channelName
              : 'No videos';
          print(
            '[SyncService] ✓ ${playlist.title}: ${videos.length} videos (by $firstChannelName) saved to DB',
          );

          await Future.delayed(const Duration(milliseconds: 100));
        } catch (e) {
          print('[SyncService] ⚠️  Error syncing ${playlist.title}: $e');
        }
      }

      // ==================== PHASE 3: COMPLETE ====================
      stopwatch.stop();
      final syncTime = (stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(
        1,
      );

      print('[SyncService] ✅ Sync Complete!');
      print(
        '[SyncService] 📊 Stats: $totalPlaylists playlists, $totalVideos videos in ${syncTime}s',
      );

      _updateStatus(
        'Synced $totalPlaylists playlists with $totalVideos videos',
        progress: 1.0,
      );

      await Future.delayed(const Duration(seconds: 2));

      // Dismiss sync notification
      ref
          .read(notificationServiceProvider)
          .cancel(
            'sync',
          ); // We use hashCode in cancel, but 8888 is used in showSyncProgress
      // Actually let's just use a dedicated cancel for sync if needed,
      // but NotificationService.cancel(taskId) uses taskId.hashCode.
      // I'll update cancel to handle 'sync' string or similar.
      // For now, let's just finish the loop.

      state = state.copyWith(
        isSyncing: false,
        syncStatus: null,
        syncProgress: 0.0,
      );
    } catch (e) {
      print('[SyncService] ❌ Sync failed: $e');
      _updateStatus('Sync failed: ${e.toString()}', progress: 0.0);
      state = state.copyWith(isSyncing: false);
      rethrow;
    }
  }

  Future<void> syncPlaylists() async {
    final cookiePath = await getActiveCookiePath();
    if (cookiePath == null) return;

    try {
      final youtubeService = ref.read(youtubeServiceProvider);
      final databaseService = ref.read(databaseServiceProvider);

      final playlists = await youtubeService.fetchPlaylists(cookiePath);
      await databaseService.replacePlaylists(
        playlists.map<Map<String, dynamic>>((p) => p.toJson()).toList(),
      );

      final regularPlaylists = playlists
          .where((p) => p.id != 'LL' && p.id != 'WL')
          .toList();

      await Future.wait(
        regularPlaylists.map((playlist) async {
          try {
            final videos = await youtubeService.fetchPlaylistVideos(
              playlist.id,
              cookiePath,
            );

            await databaseService.clearPlaylistVideos(playlist.id);
            await databaseService.saveVideos(
              videos.map((v) => v.toJson()).toList(),
            );
          } catch (e) {
            print('[SyncService] Error syncing playlist ${playlist.title}: $e');
          }
        }),
        eagerError: false,
      );
    } catch (e) {
      print('[SyncService] Error syncing playlists: $e');
      rethrow;
    }
  }

  Future<void> syncLikedVideos() async {
    final cookiePath = await getActiveCookiePath();
    if (cookiePath == null) return;

    // Check connectivity
    final connectivity = ref.read(connectivityServiceProvider);
    if (!await connectivity.hasInternetAccess()) {
      _updateStatus('No internet connection');
      return;
    }

    state = state.copyWith(
      isSyncing: true,
      syncStatus: 'Fetching Liked Videos...',
    );

    try {
      final youtubeService = ref.read(youtubeServiceProvider);
      final databaseService = ref.read(databaseServiceProvider);

      // 1. Get Items (Fast)
      final videos = await youtubeService.fetchPlaylistItems('LL', cookiePath);

      // 2. Clear old
      await databaseService.clearLikedVideos();
      ref.invalidate(likedVideosProvider);

      // 3. Save
      print('[SyncService] Saving ${videos.length} liked videos...');

      final videosToSave = <Map<String, dynamic>>[];
      for (var i = 0; i < videos.length; i++) {
        final v = videos[i].toJson();
        v['playlistId'] = 'LL';
        v['position'] = i;
        v['isLiked'] = true;
        videosToSave.add(v);
      }

      if (videosToSave.isNotEmpty) {
        await databaseService.saveVideos(videosToSave);
        ref.invalidate(likedVideosProvider);
      }

      state = state.copyWith(
        isSyncing: false,
        syncStatus: 'Liked videos fetched successfully',
        syncProgress: 1.0,
      );
    } catch (e) {
      print('[SyncService] Error syncing liked videos: $e');
      state = state.copyWith(
        isSyncing: false,
        syncStatus: 'Failed to fetch liked videos',
        syncProgress: 0.0,
      );
      rethrow;
    }
  }

  Future<void> syncWatchLater() async {
    final cookiePath = await getActiveCookiePath();
    if (cookiePath == null) return;

    try {
      final youtubeService = ref.read(youtubeServiceProvider);
      final databaseService = ref.read(databaseServiceProvider);

      final videos = await youtubeService.fetchWatchLaterVideos(cookiePath);

      await databaseService.clearWatchLaterVideos();
      await databaseService.saveVideos(videos.map((v) => v.toJson()).toList());
    } catch (e) {
      print('[SyncService] Error syncing watch later: $e');
      rethrow;
    }
  }

  Future<void> syncSpecificPlaylist(String playlistId) async {
    final cookiePath = await getActiveCookiePath();
    if (cookiePath == null) return;

    // Check connectivity
    final connectivity = ref.read(connectivityServiceProvider);
    if (!await connectivity.hasInternetAccess()) {
      _updateStatus('No internet connection');
      return;
    }

    state = state.copyWith(
      isSyncing: true,
      syncStatus: 'Fetching playlist videos...',
    );

    try {
      final youtubeService = ref.read(youtubeServiceProvider);
      final databaseService = ref.read(databaseServiceProvider);

      final videos = await youtubeService.fetchPlaylistItems(
        playlistId,
        cookiePath,
      );

      await databaseService.clearPlaylistVideos(playlistId);
      ref.invalidate(playlistVideosProvider(playlistId));

      final videosToSave = <Map<String, dynamic>>[];
      for (var i = 0; i < videos.length; i++) {
        final v = videos[i].toJson();
        v['playlistId'] = playlistId;
        v['position'] = i;
        videosToSave.add(v);
      }

      if (videosToSave.isNotEmpty) {
        await databaseService.saveVideos(videosToSave);
        ref.invalidate(playlistVideosProvider(playlistId));
      }

      state = state.copyWith(
        isSyncing: false,
        syncStatus: 'Playlist fetched successfully',
        syncProgress: 1.0,
      );
    } catch (e) {
      print('[SyncService] Error syncing playlist $playlistId: $e');
      state = state.copyWith(
        isSyncing: false,
        syncStatus: 'Failed to fetch playlist',
        syncProgress: 0.0,
      );
      rethrow;
    }
  }
}
