import 'dart:async';
import 'dart:io';
import 'package:curio/core/services/yt_dlp/ytdlp.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:curio/presentation/common/shimmer_loading.dart';
import 'package:flutter_animate/flutter_animate.dart';

// Video metadata provider
final videoMetadataProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, url) async {
      return ref.watch(ytDlpServiceProvider).fetchMetadata(url, flat: false);
    });

class DownloadConfigureModal extends ConsumerStatefulWidget {
  final String videoUrl;
  final Map<String, dynamic>? preFetchedMetadata;
  final ScrollController? scrollController;

  const DownloadConfigureModal({
    super.key,
    required this.videoUrl,
    this.preFetchedMetadata,
    this.scrollController,
  });

  @override
  ConsumerState<DownloadConfigureModal> createState() =>
      _DownloadConfigureModalState();
}

class _DownloadConfigureModalState
    extends ConsumerState<DownloadConfigureModal> {
  String? _selectedCombinedFormatId;
  String? _selectedVideoOnlyFormatId;
  List<String> _selectedAudioOnlyFormatIds = [];
  bool _useSuggestedFormat = true;
  final Set<String> _expandedCategories = <String>{};
  Map<String, Map<String, dynamic>> _formatDetailsById = {};
  String? _defaultAudioFormatId;

  @override
  Widget build(BuildContext context) {
    final metadataAsync = widget.preFetchedMetadata != null
        ? AsyncValue.data(widget.preFetchedMetadata!)
        : ref.watch(videoMetadataProvider(widget.videoUrl));

    return Column(
      children: [
        // 1. Custom App Bar / Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedCancel01,
                  color: Colors.grey,
                  size: 20,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              Text(
                'Format selection',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              TextButton(
                onPressed: _hasSelectedFormat() ? _startDownload : null,
                child: Text(
                  'Download',
                  style: TextStyle(
                    color: _hasSelectedFormat()
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).disabledColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: metadataAsync.when(
            data: (metadata) {
              final rawFormats =
                  (metadata['formats'] as List<dynamic>? ?? <dynamic>[])
                      .whereType<Map<String, dynamic>>()
                      .map((f) => Map<String, dynamic>.from(f))
                      .toList();

              List<Map<String, dynamic>> sortedVideoAudioFormats() {
                final list = rawFormats
                    .where((f) {
                      final vcodec = f['vcodec'] as String? ?? 'none';
                      final acodec = f['acodec'] as String? ?? 'none';
                      return vcodec != 'none' && acodec != 'none';
                    })
                    .map((f) => Map<String, dynamic>.from(f))
                    .toList();
                list.sort(_compareVideoFormats);
                return list;
              }

              List<Map<String, dynamic>> sortedVideoOnlyFormats() {
                final list = rawFormats
                    .where((f) {
                      final vcodec = f['vcodec'] as String? ?? 'none';
                      final acodec = f['acodec'] as String? ?? 'none';
                      return vcodec != 'none' && acodec == 'none';
                    })
                    .map((f) => Map<String, dynamic>.from(f))
                    .toList();
                list.sort(_compareVideoFormats);
                return list;
              }

              List<Map<String, dynamic>> sortedAudioFormats() {
                final list = rawFormats
                    .where((f) {
                      final vcodec = f['vcodec'] as String? ?? 'none';
                      final acodec = f['acodec'] as String? ?? 'none';
                      return vcodec == 'none' && acodec != 'none';
                    })
                    .map((f) => Map<String, dynamic>.from(f))
                    .toList();
                list.sort((a, b) {
                  final aAbr = (a['abr'] as num?)?.toDouble() ?? 0;
                  final bAbr = (b['abr'] as num?)?.toDouble() ?? 0;
                  return bAbr.compareTo(aAbr);
                });
                return list;
              }

              final combinedFormats = sortedVideoAudioFormats();
              final videoFormats = sortedVideoOnlyFormats();
              final audioFormats = sortedAudioFormats();

              _defaultAudioFormatId = audioFormats.isNotEmpty
                  ? audioFormats.first['format_id'] as String?
                  : null;

              final syntheticCombinedFormats =
                  _generateSyntheticCombinedFormats(videoFormats, audioFormats);

              if (syntheticCombinedFormats.isNotEmpty) {
                combinedFormats
                  ..addAll(syntheticCombinedFormats)
                  ..sort(_compareVideoFormats);
              }

              _formatDetailsById = {
                for (final format in rawFormats)
                  if (format['format_id'] != null)
                    format['format_id'] as String: Map<String, dynamic>.from(
                      format,
                    ),
              };

              for (final syntheticFormat in syntheticCombinedFormats) {
                final syntheticId = syntheticFormat['format_id'] as String?;
                if (syntheticId != null && syntheticId.isNotEmpty) {
                  _formatDetailsById[syntheticId] = Map<String, dynamic>.from(
                    syntheticFormat,
                  );
                }
              }

              final subtitlesRaw =
                  (metadata['subtitles'] as Map<String, dynamic>? ?? {});
              final autoCaptionsRaw =
                  (metadata['automatic_captions'] as Map<String, dynamic>? ??
                  {});

              Map<String, List<Map<String, dynamic>>> normalizeSubtitleMap(
                Map<String, dynamic> source,
              ) {
                return source.map(
                  (key, value) => MapEntry(
                    key,
                    (value as List<dynamic>? ?? [])
                        .whereType<Map<String, dynamic>>()
                        .map((entry) => Map<String, dynamic>.from(entry))
                        .toList(),
                  ),
                );
              }

              final subtitleMap = normalizeSubtitleMap(subtitlesRaw);
              final autoCaptionMap = normalizeSubtitleMap(autoCaptionsRaw);

              final suggestedSubtitleMap = subtitleMap.isNotEmpty
                  ? subtitleMap
                  : autoCaptionMap.map((key, value) => MapEntry(key, value));
              final otherSubtitleMap = {
                ...subtitleMap,
                ...autoCaptionMap,
              }..removeWhere((key, _) => suggestedSubtitleMap.containsKey(key));

              print('Debug: Combined formats count: ${combinedFormats.length}');
              print('Debug: Video-only formats count: ${videoFormats.length}');

              return ListView(
                controller: widget.scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                children: [
                  _buildRichMetadataSection(metadata),
                  const Gap(24),

                  // Combined Formats (Video + Audio)
                  if (combinedFormats.isNotEmpty) ...[
                    _buildSectionHeader(
                      'Video (Combined)',
                      combinedFormats,
                      'combined',
                    ),
                    const Gap(12),
                    _buildFormatGrid(combinedFormats, 'combined'),
                    if (combinedFormats.length == 1) ...[
                      const Gap(8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          'Only 1 combined format available. Consider video-only formats with auto-merge for more options.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                fontStyle: FontStyle.italic,
                              ),
                        ),
                      ),
                    ],
                    const Gap(24),
                  ],

                  // Video Only Formats (Need Audio Merge)
                  if (videoFormats.isNotEmpty) ...[
                    _buildSectionHeader(
                      'Video Only (Audio will be added)',
                      videoFormats,
                      'video',
                    ),
                    const Gap(12),
                    _buildFormatGrid(videoFormats, 'video'),
                    const Gap(24),
                  ],

                  if (audioFormats.isNotEmpty) ...[
                    _buildSectionHeader('Audio Only', audioFormats, 'audio'),
                    const Gap(12),
                    _buildFormatGrid(audioFormats, 'audio'),
                    const Gap(24),
                  ],

                  //Subtitle selection UI will use suggestedSubtitleMap & otherSubtitleMap
                  _buildInfoFooter(),
                  const Gap(32),
                ],
              );
            },
            loading: _buildLoadingState,
            error: (error, _) => _buildErrorState(error),
          ),
        ),
      ],
    );
  }

  Widget _buildRichMetadataSection(Map<String, dynamic> metadata) {
    return Container(
      padding: const EdgeInsets.all(0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail
          Container(
            width: 120,
            height: 68,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: metadata['thumbnail']?.isNotEmpty == true
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      metadata['thumbnail'],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const HugeIcon(
                            icon: HugeIcons.strokeRoundedCancel01,
                            color: Colors.grey,
                            size: 24,
                          ),
                    ),
                  )
                : const HugeIcon(
                    icon: HugeIcons.strokeRoundedPlay,
                    color: Colors.grey,
                    size: 24,
                  ),
          ),
          const Gap(16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metadata['title'] ?? 'Unknown Title',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const Gap(6),
                Text(
                  metadata['uploader'] ?? 'Unknown Channel',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const Gap(4),
                Row(
                  children: [
                    if (metadata['duration'] != null)
                      _buildBadge(metadata['duration'].toString()),
                    const Gap(8),
                    if (metadata['view_count'] != null)
                      _buildBadge(_formatViewCount(metadata['view_count'])),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontSize: 10,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    List<Map<String, dynamic>> formats,
    String category,
  ) {
    final isExpanded = _expandedCategories.contains(category);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
          ),
        ),
        if (formats.length > 4)
          GestureDetector(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedCategories.remove(category);
                } else {
                  _expandedCategories.add(category);
                }
              });
            },
            child: Text(
              isExpanded ? 'Show less' : 'Show all ${formats.length} items',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFormatGrid(List<Map<String, dynamic>> formats, String category) {
    final isExpanded = _expandedCategories.contains(category);
    final displayFormats = isExpanded ? formats : formats.take(4).toList();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.6, // Taller cards to prevent overflow
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: displayFormats.length,
      itemBuilder: (context, index) {
        return _buildFormatCard(displayFormats[index], category);
      },
    );
  }

  Widget _buildFormatCard(Map<String, dynamic> format, String category) {
    final formatId = format['format_id'] as String;
    final isSelected = _isFormatSelected(formatId, category);
    final ext = format['ext'] as String? ?? '';
    final vcodec = format['vcodec'] as String? ?? 'none';
    final acodec = format['acodec'] as String? ?? 'none';
    final height = format['height'] as int?;
    final width = format['width'] as int?;
    final isSynthetic = format['is_synthetic'] == true;
    final fileSizeValue =
        (format['filesize'] ?? format['filesize_approx']) as num?;
    final tbr = format['tbr'] as num?;

    // Determine format type
    final bool isCombined = vcodec != 'none' && acodec != 'none';
    final bool isVideoOnly = vcodec != 'none' && acodec == 'none';
    final bool isAudioOnly = vcodec == 'none' && acodec != 'none';

    // Resolution string
    String resolution = 'Unknown';
    if (height != null) {
      resolution = '${width}x$height'; // e.g. 1920x1080
      // Add quality label if standard
      if (height >= 2160)
        resolution += ' (4K)';
      else if (height >= 1440)
        resolution += ' (2K)';
      else if (height >= 1080)
        resolution += ' (1080p)';
      else if (height >= 720)
        resolution += ' (720p)';
      else if (height >= 480)
        resolution += ' (480p)';
      else if (height >= 360)
        resolution += ' (360p)';
    } else if (isAudioOnly) {
      final abr = format['abr'] as num?;
      resolution = abr != null ? '${abr.round()} kbps' : 'Audio Only';
    }

    // Size string
    String sizeStr = 'N/A';
    if (fileSizeValue != null && fileSizeValue > 0) {
      final fileSize = fileSizeValue.toDouble();
      if (fileSize > 1024 * 1024 * 1024) {
        sizeStr = '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
      } else if (fileSize > 1024 * 1024) {
        sizeStr = '${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB';
      } else {
        sizeStr = '${(fileSize / 1024).toStringAsFixed(2)} KB';
      }
    }

    // Bitrate string
    String bitrate = '';
    if (tbr != null && tbr > 0) {
      bitrate = '${tbr.round()} Kbps';
    } else {
      final abr = (format['abr'] as num?)?.toDouble();
      if (abr != null && abr > 0) {
        bitrate = '${abr.round()} Kbps';
      }
    }

    // Codec/Container string
    String containerCodec = ext.toUpperCase();
    String codecs = '';
    if (vcodec != 'none' && vcodec != 'images') codecs += vcodec.split('.')[0];
    if (acodec != 'none') {
      if (codecs.isNotEmpty) codecs += ' ';
      codecs += acodec.split('.')[0];
    }
    if (codecs.isNotEmpty) containerCodec += ' ($codecs)';

    return GestureDetector(
      onTap: () => _selectFormatByCategory(formatId, category),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.08)
              : Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.white.withOpacity(0.1),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top: Format type indicator and ID - Resolution
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$formatId  •  $resolution',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),

            const Gap(4),

            // Middle: Size Bitrate
            Text(
              '$sizeStr  $bitrate',
              style: TextStyle(
                fontSize: 9,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const Gap(2),

            // Codec/Container
            Text(
              containerCodec,
              style: TextStyle(
                fontSize: 8,
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            // Bottom: Icons and merge indicator
            Expanded(
              child: Align(
                alignment: Alignment.bottomRight,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Merge indicator for video-only formats
                    if (isVideoOnly)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 3,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(
                          '+Audio',
                          style: TextStyle(
                            fontSize: 7,
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    if (isSynthetic)
                      Container(
                        margin: const EdgeInsets.only(top: 1),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 3,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(
                          'Auto mix',
                          style: TextStyle(
                            fontSize: 7,
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const Gap(1),
                    // Media icons
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isVideoOnly || isCombined) ...[
                          Icon(
                            Icons.videocam,
                            size: 12,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const Gap(2),
                        ],
                        if (isAudioOnly || isCombined)
                          Icon(
                            Icons.music_note,
                            size: 12,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 20,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Format Guide:',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const Gap(4),
                Text(
                  '• COMPLETE: Video + Audio (single file)\n• VIDEO ONLY: Video only (Audio will be merged)\n• AUDIO: Audio only file',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactSuggestedFormatSection(Map<String, dynamic> metadata) {
    final requestedFormats =
        metadata['requested_formats'] as List<dynamic>? ?? [];
    if (requestedFormats.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.recommend,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          const Gap(8),
          Expanded(
            child: Text(
              _formatSuggestedFormatDescription(requestedFormats),
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Gap(8),
          SizedBox(
            height: 32,
            child: ElevatedButton.icon(
              onPressed: _selectSuggestedFormat,
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedFavourite,
                color: Colors.white,
                size: 16,
              ),
              label: const Text('Use'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatSuggestedFormatDescription(List<dynamic> formats) {
    if (formats.isEmpty) return 'No format information available';

    final descriptions = <String>[];
    for (final format in formats) {
      if (format is Map<String, dynamic>) {
        final formatMap = format;
        descriptions.add(formatMap['format'] ?? 'Unknown');
      } else {
        descriptions.add(format.toString());
      }
    }

    return descriptions.join(' + ');
  }

  String _formatViewCount(int viewCount) {
    if (viewCount >= 1000000) {
      return '${(viewCount / 1000000).toStringAsFixed(1)}M';
    } else if (viewCount >= 1000) {
      return '${(viewCount / 1000).toStringAsFixed(1)}K';
    }
    return viewCount.toString();
  }

  void _selectCombinedFormat(String formatId) {
    setState(() {
      _useSuggestedFormat = false;
      _selectedCombinedFormatId = formatId;
      _selectedVideoOnlyFormatId = null;
      _selectedAudioOnlyFormatIds.clear();
    });
  }

  void _selectVideoOnlyFormat(String formatId) {
    setState(() {
      _useSuggestedFormat = false;
      _selectedCombinedFormatId = null;
      _selectedVideoOnlyFormatId = formatId;
      _selectedAudioOnlyFormatIds.clear();
    });
  }

  void _selectAudioOnlyFormat(String formatId) {
    setState(() {
      _useSuggestedFormat = false;
      _selectedCombinedFormatId = null;
      _selectedVideoOnlyFormatId = null;
      _selectedAudioOnlyFormatIds = [formatId];
    });
  }

  void _selectSuggestedFormat() {
    setState(() {
      _useSuggestedFormat = true;
      _selectedCombinedFormatId = null;
      _selectedVideoOnlyFormatId = null;
      _selectedAudioOnlyFormatIds.clear();
    });
  }

  List<String> _getSelectedFormatIds() {
    if (_useSuggestedFormat) {
      return ['best'];
    }

    final formatIds = <String>[];

    // Handle Combined Format (already has audio)
    if (_selectedCombinedFormatId != null) {
      formatIds.add(_selectedCombinedFormatId!);
    }

    // Handle Video Only Format with proper fallbacks
    if (_selectedVideoOnlyFormatId != null) {
      String videoFormatId = _selectedVideoOnlyFormatId!;

      // If explicit audio formats are selected, create fallback combinations
      if (_selectedAudioOnlyFormatIds.isNotEmpty) {
        // Create format combinations with fallbacks: video+audio1/video+audio2/video+audio3
        final fallbackCombinations = _selectedAudioOnlyFormatIds
            .map((audioId) => '$videoFormatId+$audioId')
            .join('/');
        formatIds.add(fallbackCombinations);
        print('Debug: Created fallback combinations: $fallbackCombinations');
      } else {
        // Auto-merge with default audio
        final selectedFormat = _formatDetailsById[_selectedVideoOnlyFormatId!];
        if (selectedFormat != null) {
          final acodec = selectedFormat['acodec'] as String? ?? 'none';
          if (acodec == 'none') {
            final fallbackAudioId = _defaultAudioFormatId;
            if (fallbackAudioId != null && fallbackAudioId.isNotEmpty) {
              videoFormatId = '$videoFormatId+$fallbackAudioId';
            } else {
              videoFormatId = '$videoFormatId+bestaudio';
            }
            print('Debug: Auto-merging audio. New formatId: $videoFormatId');
          }
        }
        formatIds.add(videoFormatId);
      }
    }

    // Add explicit audio formats only if no video format is selected (Audio Only mode)
    if (_selectedVideoOnlyFormatId == null &&
        _selectedAudioOnlyFormatIds.isNotEmpty) {
      // Create fallback combinations for audio-only: audio1/audio2/audio3
      final audioFallbacks = _selectedAudioOnlyFormatIds.join('/');
      formatIds.add(audioFallbacks);
      print('Debug: Created audio fallbacks: $audioFallbacks');
    }

    return formatIds;
  }

  bool _hasSelectedFormat() {
    return _useSuggestedFormat ||
        _selectedCombinedFormatId != null ||
        _selectedVideoOnlyFormatId != null ||
        _selectedAudioOnlyFormatIds.isNotEmpty;
  }

  List<Map<String, dynamic>> _generateSyntheticCombinedFormats(
    List<Map<String, dynamic>> videoFormats,
    List<Map<String, dynamic>> audioFormats,
  ) {
    if (videoFormats.isEmpty || audioFormats.isEmpty) {
      return const [];
    }

    final syntheticFormats = <Map<String, dynamic>>[];
    final audioCandidates = audioFormats.take(4).toList();
    final seenIds = <String>{};

    for (final video in videoFormats) {
      final videoId = video['format_id'] as String?;
      if (videoId == null || videoId.isEmpty) continue;

      final audio = _selectPreferredAudioForVideo(video, audioCandidates);
      if (audio == null) continue;

      final audioId = audio['format_id'] as String?;
      if (audioId == null || audioId.isEmpty) continue;

      final syntheticId = '$videoId+$audioId';
      if (seenIds.contains(syntheticId)) continue;
      seenIds.add(syntheticId);

      final combined = Map<String, dynamic>.from(video);
      combined['format_id'] = syntheticId;
      combined['ext'] = video['ext'] ?? audio['ext'] ?? 'mp4';
      combined['acodec'] = (audio['acodec'] as String?) ?? 'synthetic_audio';
      combined['abr'] = audio['abr'] ?? combined['abr'];
      combined['is_synthetic'] = true;
      combined['source_video_id'] = videoId;
      combined['source_audio_id'] = audioId;
      combined['audio_ext'] = audio['ext'];
      combined['audio_format_id'] = audioId;
      combined['components'] = {'video': videoId, 'audio': audioId};

      combined['format'] = _buildSyntheticFormatLabel(video, audio);
      combined['format_note'] = _buildSyntheticFormatNote(video, audio);
      combined['is_downloadable'] = true;
      combined['is_streamable'] = true;
      combined['requires_merge'] = true;

      final bitrate = _calculateCombinedBitrate(video, audio);
      if (bitrate != null && bitrate > 0) {
        combined['tbr'] = bitrate;
      }

      final totalFileSize = _calculateCombinedFilesize(video, audio);
      if (totalFileSize != null && totalFileSize > 0) {
        combined['filesize'] = null;
        combined['filesize_approx'] = totalFileSize.round();
      }

      syntheticFormats.add(combined);
    }

    return syntheticFormats;
  }

  Map<String, dynamic>? _selectPreferredAudioForVideo(
    Map<String, dynamic> video,
    List<Map<String, dynamic>> audioCandidates,
  ) {
    if (audioCandidates.isEmpty) return null;

    Map<String, dynamic>? bestCandidate;
    var bestScore = double.negativeInfinity;

    for (final candidate in audioCandidates) {
      final score = _scoreAudioForVideo(video, candidate);
      if (score > bestScore) {
        bestScore = score;
        bestCandidate = candidate;
      }
    }

    return bestCandidate ?? audioCandidates.first;
  }

  double _scoreAudioForVideo(
    Map<String, dynamic> video,
    Map<String, dynamic> audio,
  ) {
    final videoExt = (video['ext'] as String?)?.toLowerCase() ?? '';
    final audioExt = (audio['ext'] as String?)?.toLowerCase() ?? '';
    final vcodec = (video['vcodec'] as String?)?.toLowerCase() ?? '';
    final acodec = (audio['acodec'] as String?)?.toLowerCase() ?? '';

    double score = 0;

    final prefersMp4 =
        videoExt == 'mp4' || videoExt == 'm4v' || vcodec.contains('avc');
    final prefersWebm =
        videoExt == 'webm' || vcodec.contains('vp9') || vcodec.contains('av1');

    if (prefersMp4 && (audioExt == 'm4a' || acodec.contains('aac'))) {
      score += 4;
    }

    if (prefersWebm && (audioExt == 'webm' || acodec.contains('opus'))) {
      score += 4;
    }

    if (videoExt.isNotEmpty && audioExt == videoExt) {
      score += 2;
    }

    final abr = _asDouble(audio['abr']) ?? _asDouble(audio['tbr']) ?? 0;
    if (abr > 0) {
      final num abrScore = (abr / 128).clamp(0, 4);
      score += abrScore.toDouble();
    }

    return score;
  }

  String _buildSyntheticFormatLabel(
    Map<String, dynamic> video,
    Map<String, dynamic> audio,
  ) {
    final videoLabel =
        (video['format'] as String?) ??
        (video['format_note'] as String?) ??
        _videoResolutionLabel(video);
    final audioLabel =
        (audio['format'] as String?) ??
        (audio['format_note'] as String?) ??
        _audioDescriptor(audio);
    return '$videoLabel + $audioLabel';
  }

  String _buildSyntheticFormatNote(
    Map<String, dynamic> video,
    Map<String, dynamic> audio,
  ) {
    return '${_videoResolutionLabel(video)} + ${_audioDescriptor(audio)}';
  }

  String _videoResolutionLabel(Map<String, dynamic> video) {
    final formatNote = video['format_note'];
    if (formatNote is String && formatNote.isNotEmpty) return formatNote;

    final height = (video['height'] as num?)?.toInt();
    if (height != null && height > 0) {
      final fps = (video['fps'] as num?)?.toInt();
      if (fps != null && fps >= 48) {
        return '${height}p$fps';
      }
      return '${height}p';
    }

    final resolution = video['resolution'];
    if (resolution is String && resolution.isNotEmpty) return resolution;

    return 'Video';
  }

  String _audioDescriptor(Map<String, dynamic> audio) {
    final abr = (audio['abr'] as num?)?.round();
    if (abr != null && abr > 0) {
      return '${abr}kbps';
    }

    final formatNote = audio['format_note'];
    if (formatNote is String && formatNote.isNotEmpty) return formatNote;

    final ext = audio['ext'];
    if (ext is String && ext.isNotEmpty) return ext.toUpperCase();

    return 'Audio';
  }

  double? _calculateCombinedBitrate(
    Map<String, dynamic> video,
    Map<String, dynamic> audio,
  ) {
    final videoBitrate = _asDouble(video['tbr']) ?? _asDouble(video['vbr']);
    final audioBitrate =
        _asDouble(audio['tbr']) ??
        _asDouble(audio['abr']) ??
        _asDouble(audio['abr']);

    if ((videoBitrate ?? 0) <= 0 && (audioBitrate ?? 0) <= 0) return null;

    return (videoBitrate ?? 0) + (audioBitrate ?? 0);
  }

  double? _calculateCombinedFilesize(
    Map<String, dynamic> video,
    Map<String, dynamic> audio,
  ) {
    final videoSize =
        _asDouble(video['filesize']) ?? _asDouble(video['filesize_approx']);
    final audioSize =
        _asDouble(audio['filesize']) ?? _asDouble(audio['filesize_approx']);

    if ((videoSize ?? 0) <= 0 && (audioSize ?? 0) <= 0) return null;

    return (videoSize ?? 0) + (audioSize ?? 0);
  }

  double? _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return null;
  }

  void _startDownload() {
    final formatIds = _getSelectedFormatIds();
    print(
      'DownloadConfigureModal._startDownload called with formatIds: $formatIds',
    );

    // Return the first selected format ID to maintain compatibility
    // with existing screens that expect a single formatId
    final formatId = formatIds.isNotEmpty ? formatIds.first : null;

    Navigator.pop(context, {
      'formatId': formatId,
      'formatIds': formatIds, // Keep the full list for future use
    });
  }

  Widget _buildLoadingState() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        // 1. Metadata Section Skeleton
        Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail
                const ShimmerBox(
                  width: 120,
                  height: 68,
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                const Gap(16),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBox(
                        height: 16,
                        width: double.infinity,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const Gap(8),
                      ShimmerBox(
                        height: 14,
                        width: 120,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const Gap(8),
                      Row(
                        children: [
                          ShimmerBox(
                            height: 14,
                            width: 40,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          const Gap(8),
                          ShimmerBox(
                            height: 14,
                            width: 60,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            )
            .animate()
            .fadeIn(duration: 400.ms)
            .slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad),
        const Gap(24),

        // 2. Section Header Skeleton
        const ShimmerBox(
              height: 20,
              width: 150,
              borderRadius: BorderRadius.all(Radius.circular(4)),
            )
            .animate()
            .fadeIn(duration: 400.ms, delay: 100.ms)
            .slideY(begin: 0.2, end: 0, curve: Curves.easeOutQuad),
        const Gap(12),

        // 3. Format Grid Skeleton (Combined)
        GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.6,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: 4,
              itemBuilder: (context, index) =>
                  ShimmerBox(borderRadius: BorderRadius.circular(12)),
            )
            .animate()
            .fadeIn(duration: 500.ms, delay: 200.ms)
            .slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad),
        const Gap(24),

        // 4. Another Section Header Skeleton
        const ShimmerBox(
              height: 20,
              width: 180,
              borderRadius: BorderRadius.all(Radius.circular(4)),
            )
            .animate()
            .fadeIn(duration: 400.ms, delay: 300.ms)
            .slideY(begin: 0.2, end: 0, curve: Curves.easeOutQuad),
        const Gap(12),

        // 5. Another Grid Skeleton (Video Only)
        GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.6,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: 2,
              itemBuilder: (context, index) =>
                  ShimmerBox(borderRadius: BorderRadius.circular(12)),
            )
            .animate()
            .fadeIn(duration: 500.ms, delay: 400.ms)
            .slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad),
      ],
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildErrorState(Object error) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const Gap(16),
          Text(
            'Error loading formats',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Gap(8),
          Text(
            error.toString(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const Gap(16),
          ElevatedButton.icon(
            onPressed: () => setState(() {}),
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedRefresh,
              color: Colors.white,
              size: 18,
            ),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }

  bool _isFormatSelected(String formatId, String category) {
    switch (category) {
      case 'combined':
        return _selectedCombinedFormatId == formatId;
      case 'video':
        return _selectedVideoOnlyFormatId == formatId;
      case 'audio':
        return _selectedAudioOnlyFormatIds.contains(formatId);
      default:
        return false;
    }
  }

  void _selectFormatByCategory(String formatId, String category) {
    switch (category) {
      case 'combined':
        _selectCombinedFormat(formatId);
        break;
      case 'video':
        _selectVideoOnlyFormat(formatId);
        break;
      case 'audio':
        _selectAudioOnlyFormat(formatId);
        break;
    }
  }

  int _compareVideoFormats(Map<String, dynamic> a, Map<String, dynamic> b) {
    final aHeight = (a['height'] as num?)?.toInt() ?? 0;
    final bHeight = (b['height'] as num?)?.toInt() ?? 0;
    if (aHeight != bHeight) return bHeight.compareTo(aHeight);

    final aTbr = (a['tbr'] as num?)?.toDouble() ?? 0;
    final bTbr = (b['tbr'] as num?)?.toDouble() ?? 0;
    if (aTbr != bTbr) return bTbr.compareTo(aTbr);

    final aFps = (a['fps'] as num?)?.toDouble() ?? 0;
    final bFps = (b['fps'] as num?)?.toDouble() ?? 0;
    return bFps.compareTo(aFps);
  }
}
