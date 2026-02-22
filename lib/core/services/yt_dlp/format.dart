import 'dart:async';
import 'dart:convert';

import 'package:curio/core/services/system/logger.dart';
import 'package:curio/core/services/yt_dlp/metadata_platform.dart';
import 'package:curio/core/services/yt_dlp/metadata_service.dart';

class YtDlpFormatService {
  final YtDlpMetadataPlatformService _platform = YtDlpMetadataPlatformService();
  final YtDlpMetadataService _metadataService;
  static const _tag = 'YtDlpFormatService';

  YtDlpFormatService(this._metadataService);

  /// Get stream URL for a video with quality settings
  Future<String> getStreamUrl(
    String url, {
    String? cookiePath,
    String? cookies,
    String? formatId,
    String? qualitySetting,
  }) async {
    try {
      LogService.d(
        'Fetching stream URL for $url with quality: ${qualitySetting ?? "auto"}',
        _tag,
      );

      final metadata = await _metadataService.fetchMetadata(
        url,
        cookiePath: cookiePath,
        cookies: cookies,
      );

      final formats = metadata['formats'] as List?;
      if (formats == null || formats.isEmpty) {
        throw Exception('No formats available');
      }

      Map<String, dynamic>? selectedFormat;

      if (formatId != null) {
        selectedFormat = formats.firstWhere(
          (f) => f['format_id'] == formatId,
          orElse: () => null,
        );

        // If selected format is video-only, merge with best audio
        if (selectedFormat != null) {
          final vcodec = selectedFormat['vcodec'] as String? ?? 'none';
          final acodec = selectedFormat['acodec'] as String? ?? 'none';

          if (vcodec != 'none' && acodec == 'none') {
            // Find best audio format
            final audioFormats = formats.where((f) {
              final avcodec = f['vcodec'] as String? ?? 'none';
              final aacodec = f['acodec'] as String? ?? 'none';
              return avcodec == 'none' && aacodec != 'none';
            }).toList();

            if (audioFormats.isNotEmpty) {
              audioFormats.sort((a, b) {
                final aAbr = a['abr'] as num? ?? 0;
                final bAbr = b['abr'] as num? ?? 0;
                return bAbr.compareTo(aAbr);
              });
              final bestAudioFormat = audioFormats.first;
              final mergedFormatId =
                  '${selectedFormat['format_id']}+${bestAudioFormat['format_id']}';

              // Check if this merged format already exists in the list
              final existingMerged = formats.firstWhere(
                (f) => f['format_id'] == mergedFormatId,
                orElse: () => null,
              );

              if (existingMerged != null) {
                selectedFormat = existingMerged;
              } else {
                // Create a synthetic merged format
                selectedFormat = Map<String, dynamic>.from(selectedFormat);
                selectedFormat['format_id'] = mergedFormatId;
                selectedFormat['is_merged'] = true;
                selectedFormat['acodec'] = bestAudioFormat['acodec'];
                selectedFormat['abr'] = bestAudioFormat['abr'];
              }
            }
          }
        }
      }

      selectedFormat ??= qualitySetting != null
          ? _selectFormatByQuality(formats, qualitySetting)
          : null;

      if (selectedFormat == null) {
        selectedFormat = formats.firstWhere((f) {
          final vcodec = f['vcodec'] as String? ?? 'none';
          final acodec = f['acodec'] as String? ?? 'none';
          return vcodec != 'none' && acodec != 'none';
        }, orElse: () => formats.first);
      }

      final streamUrl = selectedFormat!['url'] as String?;
      if (streamUrl == null || streamUrl.isEmpty) {
        throw Exception('No stream URL in selected format');
      }

      LogService.d(
        'Stream URL obtained successfully for quality: ${selectedFormat['format_note'] ?? "unknown"}',
        _tag,
      );
      return streamUrl;
    } catch (e) {
      LogService.e('Error getting stream URL: $e', _tag);
      rethrow;
    }
  }

  /// Get both video and audio stream URLs for dual-source playback
  /// Returns a record with videoUrl, audioUrl, audioTracks, and HTTP headers required for playback
  Future<
    ({
      String videoUrl,
      String? audioUrl,
      List<Map<String, String>> audioTracks,
      Map<String, String> headers,
    })
  >
  getVideoAndAudioUrls(
    String url, {
    String? cookiePath,
    String? cookies,
    String? formatId,
    String? qualitySetting,
  }) async {
    try {
      LogService.d(
        'Fetching dual-source URLs for $url with format: ${formatId ?? "auto"}',
        _tag,
      );

      final metadata = await _metadataService.fetchMetadata(
        url,
        cookiePath: cookiePath,
        cookies: cookies,
      );

      final formats = metadata['formats'] as List?;
      if (formats == null || formats.isEmpty) {
        throw Exception('No formats available');
      }

      Map<String, dynamic>? selectedFormat;
      String? audioUrl;

      if (formatId != null) {
        // Check if this is a merged format ID (e.g., "313+251")
        if (formatId.contains('+')) {
          final parts = formatId.split('+');
          final videoFormatId = parts[0];
          final audioFormatId = parts[1];

          // Get video format
          selectedFormat = formats.firstWhere(
            (f) => f['format_id'] == videoFormatId,
            orElse: () => null,
          );

          // Get audio format
          final audioFormat = formats.firstWhere(
            (f) => f['format_id'] == audioFormatId,
            orElse: () => null,
          );

          if (audioFormat != null) {
            audioUrl = audioFormat['url'] as String?;
          }
        } else {
          selectedFormat = formats.firstWhere(
            (f) => f['format_id'] == formatId,
            orElse: () => null,
          );
        }
      }

      // If we have a video-only format, find the best audio
      if (selectedFormat != null && audioUrl == null) {
        final vcodec = selectedFormat['vcodec'] as String? ?? 'none';
        final acodec = selectedFormat['acodec'] as String? ?? 'none';

        if (vcodec != 'none' && acodec == 'none') {
          // Find best audio format
          final audioFormats = formats.where((f) {
            final avcodec = f['vcodec'] as String? ?? 'none';
            final aacodec = f['acodec'] as String? ?? 'none';
            return avcodec == 'none' && aacodec != 'none';
          }).toList();

          if (audioFormats.isNotEmpty) {
            audioFormats.sort((a, b) {
              final aAbr = a['abr'] as num? ?? 0;
              final bAbr = b['abr'] as num? ?? 0;
              return bAbr.compareTo(aAbr);
            });
            audioUrl = audioFormats.first['url'] as String?;
            LogService.d(
              'Found audio track: ${audioFormats.first['format_id']}',
              _tag,
            );
          }
        }
      }

      // Fallback to quality-based selection
      selectedFormat ??= qualitySetting != null
          ? _selectFormatByQuality(formats, qualitySetting)
          : null;

      // Final fallback to combined format
      if (selectedFormat == null) {
        selectedFormat = formats.firstWhere((f) {
          final vcodec = f['vcodec'] as String? ?? 'none';
          final acodec = f['acodec'] as String? ?? 'none';
          return vcodec != 'none' && acodec != 'none';
        }, orElse: () => formats.first);
      }

      final videoUrl = selectedFormat!['url'] as String?;
      if (videoUrl == null || videoUrl.isEmpty) {
        throw Exception('No video stream URL in selected format');
      }

      // Extract HTTP headers
      final Map<String, String> headers = {};
      final rawHeaders =
          selectedFormat['http_headers'] as Map? ??
          metadata['http_headers'] as Map?;

      if (rawHeaders != null) {
        rawHeaders.forEach((key, value) {
          if (key != null && value != null) {
            headers[key.toString()] = value.toString();
          }
        });
      }

      // Collect all valid audio tracks
      final List<Map<String, String>> audioTracks = [];

      // If we found audio formats during search
      // (Re-scan because previous logic might have filtered too aggressively for 'best')
      final allFormats = formats.cast<Map<String, dynamic>>();
      final potentialAudioFormats = allFormats.where((f) {
        final vcodec = f['vcodec'] as String? ?? 'none';
        final acodec = f['acodec'] as String? ?? 'none';
        return vcodec == 'none' && acodec != 'none';
      }).toList();

      for (var f in potentialAudioFormats) {
        final url = f['url'] as String?;
        if (url != null) {
          final lang = f['language'] as String? ?? 'und';
          final label = f['format_note'] as String? ?? lang;
          audioTracks.add({
            'url': url,
            'language': lang,
            'label': label,
            'id': f['format_id'] as String? ?? '',
          });
        }
      }

      LogService.d(
        'Dual-source URLs obtained: video=${selectedFormat['format_id']}, audioTracks=${audioTracks.length}, headers=${headers.keys}',
        _tag,
      );

      return (
        videoUrl: videoUrl,
        audioUrl: audioUrl,
        audioTracks: audioTracks,
        headers: headers,
      );
    } catch (e) {
      LogService.e('Error getting dual-source URLs: $e', _tag);
      rethrow;
    }
  }

  /// Get audio-only stream URL for background playback
  Future<String> getAudioStreamUrl(
    String url, {
    String? cookiePath,
    String? cookies,
    String? qualitySetting,
  }) async {
    try {
      LogService.d('Fetching audio-only stream URL for $url', _tag);

      final metadata = await _metadataService.fetchMetadata(
        url,
        cookiePath: cookiePath,
        cookies: cookies,
      );

      final formats = metadata['formats'] as List?;
      if (formats == null || formats.isEmpty) {
        throw Exception('No formats available');
      }

      // Find best audio-only format
      final audioFormats = formats.where((f) {
        final vcodec = f['vcodec'] as String? ?? 'none';
        final acodec = f['acodec'] as String? ?? 'none';
        return vcodec == 'none' && acodec != 'none';
      }).toList();

      Map<String, dynamic>? selectedFormat;

      if (qualitySetting != null && qualitySetting.toLowerCase() == 'best') {
        if (audioFormats.isNotEmpty) {
          audioFormats.sort((a, b) {
            final aAbr = a['abr'] as num? ?? 0;
            final bAbr = b['abr'] as num? ?? 0;
            return bAbr.compareTo(aAbr);
          });
          selectedFormat = audioFormats.first;
        }
      } else if (audioFormats.isNotEmpty) {
        selectedFormat = audioFormats.first;
      }

      selectedFormat ??= formats.firstWhere((f) {
        final acodec = f['acodec'] as String? ?? 'none';
        return acodec != 'none';
      }, orElse: () => formats.first);

      final streamUrl = selectedFormat!['url'] as String?;
      if (streamUrl == null || streamUrl.isEmpty) {
        throw Exception('No audio stream URL available');
      }

      LogService.d('Audio stream URL obtained successfully', _tag);
      return streamUrl;
    } catch (e) {
      LogService.e('Error getting audio stream URL: $e', _tag);
      rethrow;
    }
  }

  Map<String, dynamic>? _selectFormatByQuality(
    List<dynamic> formats,
    String quality,
  ) {
    int? targetHeight;
    bool preferBest = false;
    bool preferWorst = false;

    switch (quality) {
      case 'Best':
        preferBest = true;
        break;
      case 'Worst':
        preferWorst = true;
        break;
      case '1080p':
        targetHeight = 1080;
        break;
      case '720p':
        targetHeight = 720;
        break;
      case '480p':
        targetHeight = 480;
        break;
      case '360p':
        targetHeight = 360;
        break;
    }

    // First try to find combined formats (video + audio in one stream)
    final combinedFormats = formats.where((f) {
      final vcodec = f['vcodec'] as String? ?? 'none';
      final acodec = f['acodec'] as String? ?? 'none';
      return vcodec != 'none' && acodec != 'none';
    }).toList();

    // Find best audio format for merging
    final audioFormats = formats.where((f) {
      final vcodec = f['vcodec'] as String? ?? 'none';
      final acodec = f['acodec'] as String? ?? 'none';
      return vcodec == 'none' && acodec != 'none';
    }).toList();

    String? bestAudioFormatId;
    if (audioFormats.isNotEmpty) {
      audioFormats.sort((a, b) {
        final aAbr = a['abr'] as num? ?? 0;
        final bAbr = b['abr'] as num? ?? 0;
        return bAbr.compareTo(aAbr);
      });
      bestAudioFormatId = audioFormats.first['format_id'] as String?;
    }

    Map<String, dynamic>? selectedFormat;

    if (preferBest) {
      // Try combined formats first
      if (combinedFormats.isNotEmpty) {
        combinedFormats.sort((a, b) {
          final aHeight = a['height'] as int? ?? 0;
          final bHeight = b['height'] as int? ?? 0;
          if (aHeight != bHeight) return bHeight.compareTo(aHeight);
          final aTbr = a['tbr'] as num? ?? 0;
          final bTbr = b['tbr'] as num? ?? 0;
          return bTbr.compareTo(aTbr);
        });
        selectedFormat = combinedFormats.first;
      } else if (bestAudioFormatId != null) {
        // Fall back to video-only + audio
        final videoFormats = formats.where((f) {
          final vcodec = f['vcodec'] as String? ?? 'none';
          final acodec = f['acodec'] as String? ?? 'none';
          return vcodec != 'none' && acodec == 'none';
        }).toList();

        if (videoFormats.isNotEmpty) {
          videoFormats.sort((a, b) {
            final aHeight = a['height'] as int? ?? 0;
            final bHeight = b['height'] as int? ?? 0;
            if (aHeight != bHeight) return bHeight.compareTo(aHeight);
            final aTbr = a['tbr'] as num? ?? 0;
            final bTbr = b['tbr'] as num? ?? 0;
            return bTbr.compareTo(aTbr);
          });
          final bestVideoFormat = videoFormats.first;
          selectedFormat = Map<String, dynamic>.from(bestVideoFormat);
          selectedFormat['format_id'] =
              '${bestVideoFormat['format_id']}+$bestAudioFormatId';
          selectedFormat['is_merged'] = true;
        }
      }
    } else if (preferWorst) {
      if (combinedFormats.isNotEmpty) {
        combinedFormats.sort((a, b) {
          final aHeight = a['height'] as int? ?? 999999;
          final bHeight = b['height'] as int? ?? 999999;
          return aHeight.compareTo(bHeight);
        });
        selectedFormat = combinedFormats.first;
      }
    } else if (targetHeight != null) {
      // Find closest combined format
      Map<String, dynamic>? closestCombined;
      int minCombinedDiff = 999999;
      for (final format in combinedFormats) {
        final height = format['height'] as int? ?? 0;
        final diff = (height - targetHeight).abs();
        if (diff < minCombinedDiff) {
          minCombinedDiff = diff;
          closestCombined = format;
        }
      }
      selectedFormat = closestCombined;

      // If no combined format close enough, try video-only + audio
      if (selectedFormat == null && bestAudioFormatId != null) {
        final videoFormats = formats.where((f) {
          final vcodec = f['vcodec'] as String? ?? 'none';
          final acodec = f['acodec'] as String? ?? 'none';
          return vcodec != 'none' && acodec == 'none';
        }).toList();

        Map<String, dynamic>? closestVideo;
        int minVideoDiff = 999999;
        for (final format in videoFormats) {
          final height = format['height'] as int? ?? 0;
          final diff = (height - targetHeight).abs();
          if (diff < minVideoDiff) {
            minVideoDiff = diff;
            closestVideo = format;
          }
        }

        if (closestVideo != null) {
          selectedFormat = Map<String, dynamic>.from(closestVideo);
          selectedFormat['format_id'] =
              '${closestVideo['format_id']}+$bestAudioFormatId';
          selectedFormat['is_merged'] = true;
        }
      }
    }

    return selectedFormat;
  }

  Future<List<Map<String, dynamic>>> getFormats(
    String url, {
    String? cookiePath,
    String? cookies,
  }) async {
    try {
      final metadata = await _metadataService.fetchMetadata(
        url,
        cookiePath: cookiePath,
        cookies: cookies,
        flat: false,
      );

      final formats = metadata['formats'] as List?;
      if (formats == null) return [];

      final result = <Map<String, dynamic>>[];
      for (final format in formats) {
        if (format is Map<String, dynamic>) {
          result.add(_parseFormat(format));
        }
      }

      result.sort((a, b) {
        final aHeight = a['height'] as int? ?? 0;
        final bHeight = b['height'] as int? ?? 0;
        if (aHeight != bHeight) return bHeight.compareTo(aHeight);
        final aTbr = a['tbr'] as num? ?? 0;
        final bTbr = b['tbr'] as num? ?? 0;
        return bTbr.compareTo(aTbr);
      });

      return result;
    } catch (e) {
      LogService.e('Error fetching formats: $e', _tag);
      return [];
    }
  }

  Map<String, dynamic> _parseFormat(Map<String, dynamic> format) {
    final formatId = format['format_id'] ?? '';
    final vcodec = format['vcodec'] as String? ?? 'none';
    final acodec = format['acodec'] as String? ?? 'none';
    final ext = format['ext'] ?? '';
    final height = format['height'] as int?;

    String qualityTier = 'Unknown';
    if (height != null) {
      if (height >= 2160)
        qualityTier = '4K';
      else if (height >= 1440)
        qualityTier = '1440p';
      else if (height >= 1080)
        qualityTier = '1080p';
      else if (height >= 720)
        qualityTier = '720p';
      else if (height >= 480)
        qualityTier = '480p';
      else if (height >= 360)
        qualityTier = '360p';
      else
        qualityTier = '${height}p';
    } else if (acodec != 'none' && vcodec == 'none') {
      final abr = format['abr'] as num?;
      qualityTier = abr != null ? '${abr.round()}kbps' : 'Audio';
    }

    String formatType = 'unknown';
    if (vcodec != 'none' && acodec != 'none')
      formatType = 'video+audio';
    else if (vcodec != 'none')
      formatType = 'video';
    else if (acodec != 'none')
      formatType = 'audio';

    return {
      'format_id': formatId,
      'ext': ext,
      'format_note':
          format['format_note'] ?? format['resolution'] ?? qualityTier,
      'format_type': formatType,
      'quality_tier': qualityTier,
      'vcodec': vcodec,
      'acodec': acodec,
      'filesize': format['filesize'] as int?,
      'filesize_approx': format['filesize_approx'] as int?,
      'tbr': format['tbr'] as num?,
      'vbr': format['vbr'] as num?,
      'abr': format['abr'] as num?,
      'fps': format['fps'] as num?,
      'width': format['width'] as int?,
      'height': height,
      'aspect_ratio': format['aspect_ratio'] as num?,
      'is_downloadable': formatType != 'unknown',
      'is_streamable': vcodec != 'none' && acodec != 'none',
    };
  }

  Future<Map<String, dynamic>> getFormatsCategorized(
    String url, {
    String? cookies,
  }) async {
    try {
      final result = await _platform.callMethod('get_formats_categorized', {
        'url': url,
        'cookies': cookies ?? '',
      });

      final formatsData = jsonDecode(result) as Map<String, dynamic>;
      if (formatsData.containsKey('error'))
        throw Exception(formatsData['message']);

      // Process formats
      final categorizedFormats = <String, dynamic>{};

      // Handle format arrays
      for (final key in ['combined', 'video', 'audio']) {
        if (formatsData.containsKey(key)) {
          final formatsList = (formatsData[key] as List<dynamic>)
              .cast<Map<String, dynamic>>();

          // Sort descending by quality
          formatsList.sort((a, b) {
            // 1. By Height/Resolution
            final aHeight = a['height'] as int? ?? 0;
            final bHeight = b['height'] as int? ?? 0;
            if (aHeight != bHeight) return bHeight.compareTo(aHeight);

            // 2. By Bitrate (tbr or filesize)
            final aTbr = a['tbr'] as num? ?? a['filesize'] as num? ?? 0;
            final bTbr = b['tbr'] as num? ?? b['filesize'] as num? ?? 0;
            return bTbr.compareTo(aTbr);
          });

          categorizedFormats[key] = formatsList;
        }
      }

      // Handle subtitle information
      if (formatsData.containsKey('subtitles')) {
        categorizedFormats['subtitles'] = Map<String, dynamic>.from(
          formatsData['subtitles'] as Map,
        );
      }
      if (formatsData.containsKey('automatic_captions')) {
        categorizedFormats['automatic_captions'] = Map<String, dynamic>.from(
          formatsData['automatic_captions'] as Map,
        );
      }

      return categorizedFormats;
    } catch (e) {
      LogService.e('Error getting categorized formats: $e', _tag);
      return {
        'combined': [],
        'video': [],
        'audio': [],
        'subtitles': {},
        'automatic_captions': {},
      };
    }
  }
}
