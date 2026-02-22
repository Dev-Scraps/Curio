import 'dart:async';
import 'dart:io' as io;
import 'package:async/async.dart';
import 'package:curio/core/services/system/logger.dart';
import 'package:curio/core/services/yt_dlp/ytdlp.dart';
import 'package:curio/domain/entities/playlist.dart';
import 'package:curio/domain/entities/video.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

part 'youtube.g.dart';

@Riverpod(keepAlive: true)
YoutubeService youtubeService(Ref ref) => YoutubeService(ref);

class YoutubeService {
  final Ref _ref;
  late final YtDlpService _ytDlp = _ref.read(ytDlpServiceProvider);
  static const _tag = 'YoutubeService';

  // Memoization
  final AsyncMemoizer<List<Playlist>> _playlistMemoizer =
      AsyncMemoizer<List<Playlist>>();
  final Map<String, AsyncMemoizer<List<Video>>> _playlistVideoMemoizer = {};

  // Concurrency control
  static const int _maxConcurrentRequests = 5;
  int _currentConcurrentRequests = 0;
  final List<Completer<void>> _requestQueue = [];

  Future<void> _acquireSlot() async {
    while (_currentConcurrentRequests >= _maxConcurrentRequests) {
      final completer = Completer<void>();
      _requestQueue.add(completer);
      await completer.future;
    }
    _currentConcurrentRequests++;
  }

  void _releaseSlot() {
    _currentConcurrentRequests--;
    if (_requestQueue.isNotEmpty) {
      final completer = _requestQueue.removeAt(0);
      completer.complete();
    }
  }

  YoutubeService(this._ref);
  // Updated youtube_service.dart - Key methods with enhanced metadata handling

  /// Fetch user's playlists from YouTube via yt-dlp
  Future<List<Playlist>> fetchPlaylists(String cookiePath) async {
    return _playlistMemoizer.runOnce(() async {
      final List<Playlist> out = [];

      try {
        LogService.d('Fetching playlists via yt-dlp', _tag);

        String? cookieString;
        try {
          cookieString = await io.File(cookiePath).readAsString();
        } catch (e) {
          LogService.w('Could not read cookies: $e', _tag);
        }

        if (cookieString != null && cookieString.isNotEmpty) {
          final ytdlpPlaylists = await _ytDlp.getUserPlaylists(
            cookies: cookieString,
          );

          LogService.d(
            'yt-dlp returned ${ytdlpPlaylists.length} playlists',
            _tag,
          );

          for (final playlistData in ytdlpPlaylists) {
            final id = playlistData['id'] as String?;
            final title = playlistData['title'] as String?;

            if (id != null && title != null) {
              // Parse modified date if available
              DateTime? lastUpdated;
              final modifiedDateStr = playlistData['modified_date'] as String?;
              if (modifiedDateStr != null && modifiedDateStr.length == 8) {
                try {
                  final year = modifiedDateStr.substring(0, 4);
                  final month = modifiedDateStr.substring(4, 6);
                  final day = modifiedDateStr.substring(6, 8);
                  lastUpdated = DateTime.parse('$year-$month-$day');
                } catch (e) {
                  LogService.w(
                    'Failed to parse modified_date: $modifiedDateStr',
                    _tag,
                  );
                }
              }

              // Create playlist with complete metadata
              out.add(
                Playlist(
                  id: id,
                  title: title,
                  videoCount: playlistData['playlist_count'] as int? ?? 0,
                  thumbnailUrl: playlistData['thumbnail'] as String?,
                  uploader:
                      playlistData['uploader'] as String? ??
                      playlistData['channel'] as String? ??
                      'You',
                  uploaderUrl:
                      playlistData['channel_url'] as String? ??
                      playlistData['uploader_url'] as String?,
                  description: playlistData['description'] as String?,
                  lastUpdated: lastUpdated,
                  isLiked: id == 'LL',
                  isWatchLater: id == 'WL',
                  // New fields
                  channel: playlistData['channel'] as String?,
                  channelId: playlistData['channel_id'] as String?,
                  channelUrl: playlistData['channel_url'] as String?,
                  availability: playlistData['availability'] as String?,
                  modifiedDate: modifiedDateStr,
                  viewCount: playlistData['view_count'] as int?,
                ),
              );

              final availability = playlistData['availability'] ?? 'unknown';
              LogService.d(
                'Parsed: $title (${playlistData["playlist_count"]} videos, $availability)',
                _tag,
              );
            }
          }
        }

        // Fallback to web scraping only if yt-dlp returns nothing
        if (out.isEmpty) {
          LogService.d(
            'yt-dlp returned no playlists, trying web scraping fallback',
            _tag,
          );
          final scrapedPlaylists = await _scrapePlaylists(cookiePath);
          out.addAll(scrapedPlaylists);
        }

        LogService.d('Found ${out.length} playlists total', _tag);
      } catch (e, stackTrace) {
        LogService.e('Error fetching playlists: $e\n$stackTrace', _tag);
      }

      return out;
    });
  }

  /// Fetch all videos in a playlist via yt-dlp
  ///
  /// [flat] = true: Quick basic info only (ID, title, thumbnail)
  /// [flat] = false: Full details (duration, views, upload date, etc.)
  Future<List<Video>> fetchPlaylistItems(
    String playlistId,
    String cookiePath, {
    bool flat = true,
  }) async {
    try {
      LogService.d('Fetching playlist $playlistId (flat=$flat)', _tag);

      final meta = await _ytDlp.fetchMetadata(
        'https://www.youtube.com/playlist?list=$playlistId',
        cookiePath: cookiePath,
        flat: flat,
      );

      final entries = meta['entries'] as List? ?? [];
      final videos = <Video>[];

      for (final e in entries) {
        if (e is! Map<String, dynamic>) continue;

        // Enhanced metadata extraction
        final videoId = e['id'] as String? ?? '';
        final title = e['title'] as String? ?? '';

        if (videoId.isEmpty || title.isEmpty) continue;

        // Extract channel name with comprehensive fallbacks
        String channelName = '';
        if (e['channel'] != null && (e['channel'] as String).isNotEmpty) {
          channelName = e['channel'] as String;
        } else if (e['uploader'] != null &&
            (e['uploader'] as String).isNotEmpty) {
          channelName = e['uploader'] as String;
        } else if (e['channel_id'] != null &&
            (e['channel_id'] as String).isNotEmpty) {
          channelName = e['channel_id'] as String;
        } else if (e['uploader_id'] != null &&
            (e['uploader_id'] as String).isNotEmpty) {
          channelName = e['uploader_id'] as String;
        } else if (e['author'] != null && (e['author'] as String).isNotEmpty) {
          channelName = e['author'] as String;
        } else if (e['creator'] != null &&
            (e['creator'] as String).isNotEmpty) {
          channelName = e['creator'] as String;
        } else if (e['artist'] != null && (e['artist'] as String).isNotEmpty) {
          channelName = e['artist'] as String;
        }

        // Extract upload date with comprehensive fallbacks
        String uploadDate = '';
        final rawUploadDate = e['upload_date'];
        final rawReleaseDate = e['release_date'];
        final rawTimestamp = e['timestamp'];
        final rawReleaseTimestamp = e['release_timestamp'];

        if (rawUploadDate != null && rawUploadDate.toString().isNotEmpty) {
          uploadDate = rawUploadDate.toString();
        } else if (rawReleaseDate != null &&
            rawReleaseDate.toString().isNotEmpty) {
          uploadDate = rawReleaseDate.toString();
        } else if (rawTimestamp != null) {
          // Convert Unix timestamp to YYYYMMDD format
          try {
            final dateTime = DateTime.fromMillisecondsSinceEpoch(
              (rawTimestamp is int
                      ? rawTimestamp
                      : int.parse(rawTimestamp.toString())) *
                  1000,
            );
            uploadDate =
                '${dateTime.year}${dateTime.month.toString().padLeft(2, '0')}${dateTime.day.toString().padLeft(2, '0')}';
          } catch (e) {
            uploadDate = rawTimestamp.toString();
          }
        } else if (rawReleaseTimestamp != null) {
          try {
            final dateTime = DateTime.fromMillisecondsSinceEpoch(
              (rawReleaseTimestamp is int
                      ? rawReleaseTimestamp
                      : int.parse(rawReleaseTimestamp.toString())) *
                  1000,
            );
            uploadDate =
                '${dateTime.year}${dateTime.month.toString().padLeft(2, '0')}${dateTime.day.toString().padLeft(2, '0')}';
          } catch (e) {
            uploadDate = rawReleaseTimestamp.toString();
          }
        }

        // Extract view count with proper handling
        String viewCount = '';
        final rawViewCount = e['view_count'] ?? e['viewCount'];
        if (rawViewCount != null) {
          if (rawViewCount is int) {
            viewCount = rawViewCount.toString();
          } else if (rawViewCount is double) {
            viewCount = rawViewCount.toInt().toString();
          } else if (rawViewCount is String && rawViewCount.isNotEmpty) {
            viewCount = rawViewCount;
          }
        }

        // Extract duration with proper formatting
        String duration = '';
        final rawDuration = e['duration'];
        if (rawDuration != null) {
          if (rawDuration is int || rawDuration is double) {
            // Convert seconds to HH:MM:SS or MM:SS format
            final totalSeconds = rawDuration is int
                ? rawDuration
                : (rawDuration as double).toInt();
            if (totalSeconds > 0) {
              final hours = totalSeconds ~/ 3600;
              final minutes = (totalSeconds % 3600) ~/ 60;
              final seconds = totalSeconds % 60;

              if (hours > 0) {
                duration =
                    '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
              } else {
                duration =
                    '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
              }
            }
          } else if (rawDuration is String && rawDuration.isNotEmpty) {
            duration = rawDuration;
          }
        }

        // Get thumbnail URL with fallbacks
        String thumbnailUrl = '';
        final thumbnails = e['thumbnails'] as List?;
        if (thumbnails != null && thumbnails.isNotEmpty) {
          // Try to get the highest quality thumbnail
          for (final thumbnail in thumbnails.reversed) {
            if (thumbnail is Map<String, dynamic> && thumbnail['url'] != null) {
              final url = thumbnail['url'] as String;
              if (url.isNotEmpty) {
                thumbnailUrl = url;
                break;
              }
            }
          }
        }

        // Fallback to default YouTube thumbnail if none found
        if (thumbnailUrl.isEmpty && videoId.isNotEmpty) {
          thumbnailUrl = 'https://i.ytimg.com/vi/$videoId/mqdefault.jpg';
        }

        // Extract channel ID
        String channelId = '';
        if (e['channel_id'] != null && (e['channel_id'] as String).isNotEmpty) {
          channelId = e['channel_id'] as String;
        } else if (e['uploader_id'] != null &&
            (e['uploader_id'] as String).isNotEmpty) {
          channelId = e['uploader_id'] as String;
        }

        // Create video with all extracted metadata
        final video = Video(
          id: videoId,
          title: title,
          channelName: channelName,
          uploadDate: uploadDate,
          viewCount: viewCount,
          duration: duration,
          thumbnailUrl: thumbnailUrl,
          playlistId: playlistId,
          isLiked: playlistId == 'LL',
          isWatchLater: playlistId == 'WL',
          addedDate: DateTime.now(),
          channelId: channelId,
        );

        videos.add(video);
      }

      LogService.d(
        'Fetched ${videos.length} videos from playlist $playlistId',
        _tag,
      );
      return videos;
    } catch (e, stackTrace) {
      LogService.e(
        'Error fetching playlist $playlistId: $e\n$stackTrace',
        _tag,
      );
      return [];
    }
  }

  /// Convenience wrapper for fetching all videos in a playlist
  Future<List<Video>> fetchPlaylistVideos(
    String playlistId,
    String cookiePath,
  ) async {
    if (!_playlistVideoMemoizer.containsKey(playlistId)) {
      _playlistVideoMemoizer[playlistId] = AsyncMemoizer<List<Video>>();
    }

    return _playlistVideoMemoizer[playlistId]!.runOnce(() async {
      final videos = await fetchPlaylistItems(playlistId, cookiePath);

      return videos
          .map(
            (v) => v.copyWith(
              playlistId: playlistId,
              isLiked: playlistId == 'LL',
              isWatchLater: playlistId == 'WL',
            ),
          )
          .toList();
    });
  }

  Future<List<Video>> fetchLikedVideos(String cookiePath) =>
      fetchPlaylistVideos('LL', cookiePath);

  Future<List<Video>> fetchWatchLaterVideos(String cookiePath) =>
      fetchPlaylistVideos('WL', cookiePath);

  Future<Video?> fetchVideoMetadata(
    String videoId, {
    String? cookiePath,
  }) async {
    try {
      final meta = await _ytDlp.fetchMetadata(
        'https://www.youtube.com/watch?v=$videoId',
        cookiePath: cookiePath,
      );
      return Video.fromJson(meta);
    } catch (e) {
      LogService.e('Error fetching video $videoId: $e', _tag);
      return null;
    }
  }

  Future<String> getStreamUrl(
    String videoId,
    String cookiePath, {
    String? formatId,
    bool audioOnly = false,
    String? qualitySetting,
  }) async {
    if (audioOnly && formatId == null) {
      return _ytDlp.getAudioStreamUrl(
        'https://www.youtube.com/watch?v=$videoId',
        cookiePath: cookiePath,
        qualitySetting: qualitySetting,
      );
    }
    return _ytDlp.getStreamUrl(
      'https://www.youtube.com/watch?v=$videoId',
      cookiePath: cookiePath,
      formatId: formatId,
      qualitySetting: qualitySetting,
    );
  }

  /// Get both video and audio URLs for dual-source playback (1080p+ formats)
  Future<
    ({
      String videoUrl,
      String? audioUrl,
      List<Map<String, String>> audioTracks,
      Map<String, String> headers,
    })
  >
  getVideoAndAudioUrls(
    String videoId,
    String cookiePath, {
    String? formatId,
    String? qualitySetting,
  }) async {
    return _ytDlp.getVideoAndAudioUrls(
      'https://www.youtube.com/watch?v=$videoId',
      cookiePath: cookiePath,
      formatId: formatId,
      qualitySetting: qualitySetting,
    );
  }

  Future<Map<String, Video>> fetchMultipleVideos(
    List<String> videoIds,
    String cookiePath,
  ) async {
    final results = <String, Video>{};

    final futures = videoIds.map((id) async {
      await _acquireSlot();
      try {
        final video = await fetchVideoMetadata(id, cookiePath: cookiePath);
        if (video != null) {
          results[id] = video;
        }
      } finally {
        _releaseSlot();
      }
    }).toList();

    await Future.wait(futures, eagerError: false);
    return results;
  }

  /// Fetch user profile info by scraping YouTube
  Future<Map<String, String>> fetchSelfProfile(String cookiePath) async {
    await _acquireSlot();
    try {
      LogService.d('Fetching user profile', _tag);

      // Read cookies to send correct headers
      String? cookieString;
      try {
        cookieString = await io.File(cookiePath).readAsString();
      } catch (e) {
        LogService.w('Could not read cookies: $e', _tag);
      }

      final cookieHeader = cookieString != null
          ? _convertNetscapeCookiesToHeader(cookieString)
          : '';

      final response = await http.get(
        Uri.parse('https://www.youtube.com/'),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36',
          'Accept-Language': 'en-US,en;q=0.9',
          'Cookie': cookieHeader,
        },
      );

      if (response.statusCode != 200) {
        throw io.HttpException(
          'Failed to fetch profile: ${response.statusCode}',
        );
      }

      String name = '';
      String avatar = '';
      String email = '';

      try {
        final html = response.body;

        // Try to find ytInitialData
        final dataMatch = RegExp(
          r'var ytInitialData = ({.+?});',
          dotAll: true,
        ).firstMatch(html);

        if (dataMatch != null) {
          final jsonStr = dataMatch.group(1)!;
          final data = jsonDecode(jsonStr) as Map<String, dynamic>;

          // Traverse to find activeAccountHeaderRenderer
          // Structure: topbar -> desktopTopbarRenderer -> topbarButtons -> [last] -> topbarMenuButtonRenderer -> menuRenderer -> multiPageMenuRenderer -> header -> activeAccountHeaderRenderer
          // Or sometimes simpler paths depending on A/B tests.
          // Easier: Convert to string and regex the specific renderer JSON if traversal is too deep/variable.
          // Yet, let's try a direct regex on the JSON string for the renderer which is distinct.

          final accountHeaderMatch = RegExp(
            r'"activeAccountHeaderRenderer":\s*({[^}]+})',
          ).firstMatch(jsonStr);

          if (accountHeaderMatch != null) {
            // We successfully isolated the account header json
            // It looks like: {"accountName":{"simpleText":"Name"},"accountPhoto":{"thumbnails":[{"url":"..."}]},"email":{"simpleText":"email@gmail.com"}}
            // NOTE: The JSON might be nested. Regex on valid JSON is risky if it contains nested braces.
            // A safer bet is to parse the whole string, but it's huge.
            // Let's refine the regex to be greedy until the logical end or use a finding loop.

            // Actually, looking at the full data structure is safer if we can find the path.
            // Let's recursively search for 'activeAccountHeaderRenderer' in the map.
            final header = _findKey(data, 'activeAccountHeaderRenderer');

            if (header != null && header is Map) {
              // Extract Name
              final nameObj = header['accountName'] as Map?;
              name = nameObj?['simpleText'] as String? ?? '';

              // Extract Email
              final emailObj = header['email'] as Map?;
              email = emailObj?['simpleText'] as String? ?? '';

              // Extract Avatar
              final photoObj = header['accountPhoto'] as Map?;
              final thumbnails = photoObj?['thumbnails'] as List?;
              if (thumbnails != null && thumbnails.isNotEmpty) {
                avatar = thumbnails.last['url'] as String? ?? '';
              }
            }
          }
        }

        // Fallbacks if structured parse failed
        if (email.isEmpty) {
          final emailMatch = RegExp(
            r'"email":{"simpleText":"([^"]+)"}',
          ).firstMatch(html);
          if (emailMatch != null) {
            email = emailMatch.group(1) ?? '';
          }
        }
      } catch (e) {
        LogService.e('Error parsing profile HTML: $e', _tag);
      }

      // Final Fallbacks
      if (name.isEmpty) name = 'User';
      if (email.isEmpty) email = 'No Email ID';

      LogService.d(
        'Profile fetched: Name=$name, Avatar=${avatar.isNotEmpty}, Email=$email',
        _tag,
      );

      return {'name': name, 'avatar': avatar, 'email': email};
    } catch (e) {
      LogService.e('Error fetching profile: $e', _tag);
      return {'name': 'Unknown', 'avatar': '', 'email': 'Unknown ID'};
    } finally {
      _releaseSlot();
    }
  }

  /// Helper to recursively find a key in a nested map/list
  dynamic _findKey(dynamic data, String targetKey) {
    if (data is Map) {
      if (data.containsKey(targetKey)) return data[targetKey];
      for (final value in data.values) {
        final result = _findKey(value, targetKey);
        if (result != null) return result;
      }
    } else if (data is List) {
      for (final item in data) {
        final result = _findKey(item, targetKey);
        if (result != null) return result;
      }
    }
    return null;
  }

  void clearCache() {
    _playlistVideoMemoizer.clear();
    LogService.d('Cache cleared', _tag);
  }

  Future<List<Playlist>> _scrapePlaylists(String cookiePath) async {
    final playlists = <Playlist>[];

    try {
      // Read cookies from file
      String? cookieString;
      try {
        cookieString = await io.File(cookiePath).readAsString();
      } catch (e) {
        LogService.w('Could not read cookies: $e', _tag);
        return playlists;
      }

      // Convert Netscape cookies to HTTP cookie header
      final cookieHeader = _convertNetscapeCookiesToHeader(cookieString);

      // Fetch YouTube library page
      final response = await http.get(
        Uri.parse('https://www.youtube.com/feed/playlists'),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept-Language': 'en-US,en;q=0.9',
          'Cookie': cookieHeader,
        },
      );

      if (response.statusCode != 200) {
        LogService.w(
          'Failed to fetch playlists page: ${response.statusCode}',
          _tag,
        );
        return playlists;
      }

      final html = response.body;

      // Extract playlists from YouTube's JSON data in the page
      // YouTube embeds data in ytInitialData variable
      final dataMatch = RegExp(
        r'var ytInitialData = ({.+?});',
        dotAll: true,
      ).firstMatch(html);

      if (dataMatch != null) {
        try {
          final jsonStr = dataMatch.group(1)!;
          final data = jsonDecode(jsonStr) as Map<String, dynamic>;

          // Navigate through YouTube's data structure to find playlists
          final contents = data['contents'] as Map?;
          final twoColumnBrowseResultsRenderer =
              contents?['twoColumnBrowseResultsRenderer'] as Map?;
          final tabs = twoColumnBrowseResultsRenderer?['tabs'] as List?;

          if (tabs != null) {
            for (final tab in tabs) {
              final tabRenderer = tab['tabRenderer'] as Map?;
              final content = tabRenderer?['content'] as Map?;
              final sectionListRenderer =
                  content?['sectionListRenderer'] as Map?;
              final sectionContents = sectionListRenderer?['contents'] as List?;

              if (sectionContents != null) {
                for (final section in sectionContents) {
                  final itemSectionRenderer =
                      section['itemSectionRenderer'] as Map?;
                  final items = itemSectionRenderer?['contents'] as List?;

                  if (items != null) {
                    for (final item in items) {
                      final gridRenderer = item['gridRenderer'] as Map?;
                      final gridItems = gridRenderer?['items'] as List?;

                      if (gridItems != null) {
                        for (final gridItem in gridItems) {
                          final playlistRenderer =
                              gridItem['gridPlaylistRenderer'] as Map?;
                          if (playlistRenderer != null) {
                            final playlistId =
                                playlistRenderer['playlistId'] as String?;
                            final titleRuns =
                                (playlistRenderer['title'] as Map?)?['runs']
                                    as List?;
                            final title = titleRuns?.first['text'] as String?;

                            // Extract video count
                            final videoCountText =
                                playlistRenderer['videoCountText'] as Map?;
                            final videoCountRuns =
                                videoCountText?['runs'] as List?;
                            int videoCount = 0;
                            if (videoCountRuns != null &&
                                videoCountRuns.isNotEmpty) {
                              final countStr =
                                  videoCountRuns.first['text'] as String?;
                              videoCount =
                                  int.tryParse(
                                    countStr?.replaceAll(
                                          RegExp(r'[^\d]'),
                                          '',
                                        ) ??
                                        '0',
                                  ) ??
                                  0;
                            }

                            // Extract thumbnail
                            final thumbnail =
                                (playlistRenderer['thumbnail']
                                        as Map?)?['thumbnails']
                                    as List?;
                            String? thumbnailUrl;
                            if (thumbnail != null && thumbnail.isNotEmpty) {
                              thumbnailUrl = thumbnail.last['url'] as String?;
                            }

                            if (playlistId != null && title != null) {
                              playlists.add(
                                Playlist(
                                  id: playlistId,
                                  title: title,
                                  videoCount: videoCount,
                                  thumbnailUrl: thumbnailUrl,
                                  uploader: 'You',
                                ),
                              );
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        } catch (e) {
          LogService.e('Error parsing playlists JSON: $e', _tag);
        }
      }

      LogService.d('Scraped ${playlists.length} playlists', _tag);
    } catch (e) {
      LogService.e('Error scraping playlists: $e', _tag);
    }

    return playlists;
  }

  String _convertNetscapeCookiesToHeader(String netscapeCookies) {
    final cookies = <String>[];

    for (final line in netscapeCookies.split('\n')) {
      final trimmed = line.trim();
      // Skip comments and empty lines
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

      // Netscape format: domain, flag, path, secure, expiration, name, value
      final parts = trimmed.split('\t');
      if (parts.length >= 7) {
        final name = parts[5];
        final value = parts[6];
        cookies.add('$name=$value');
      }
    }

    return cookies.join('; ');
  }
}
