import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hugeicons/hugeicons.dart';
import '../viewmodels/viewmodel.dart';
import '../handlers/download_handler.dart';

class CompactSettingsSheet extends ConsumerStatefulWidget {
  const CompactSettingsSheet({super.key});

  @override
  ConsumerState<CompactSettingsSheet> createState() =>
      _CompactSettingsSheetState();
}

enum _SettingsPage { main, quality, captions, audio, speed, sleep }

class _CompactSettingsSheetState extends ConsumerState<CompactSettingsSheet> {
  _SettingsPage _page = _SettingsPage.main;

  void _navigateTo(_SettingsPage page) => setState(() => _page = page);
  void _goBack() => setState(() => _page = _SettingsPage.main);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playerViewModelProvider);
    final viewModel = ref.read(playerViewModelProvider.notifier);

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        constraints: const BoxConstraints(maxHeight: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  if (_page != _SettingsPage.main)
                    GestureDetector(
                      onTap: _goBack,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        margin: const EdgeInsets.only(right: 12),
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedArrowLeft01,
                          color: Theme.of(context).colorScheme.onSurface,
                          size: 16,
                        ),
                      ),
                    ),
                  Text(
                    _getHeaderTitle(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: Navigator.of(context).pop,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedCancel01,
                        color: Theme.of(context).colorScheme.onSurface,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 30),
                child: _buildBody(context, state, viewModel),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getHeaderTitle() {
    switch (_page) {
      case _SettingsPage.quality:
        return 'Quality';
      case _SettingsPage.captions:
        return 'Captions';
      case _SettingsPage.audio:
        return 'Audio Track';
      case _SettingsPage.speed:
        return 'Playback Speed';
      case _SettingsPage.sleep:
        return 'Sleep Timer';
      case _SettingsPage.main:
        return 'Settings';
    }
  }

  Widget _buildBody(
    BuildContext context,
    PlayerState state,
    PlayerViewModel viewModel,
  ) {
    switch (_page) {
      case _SettingsPage.main:
        return Column(
          children: [
            // Video Options Section
            _buildSectionHeader('Video Options'),
            _buildMenuItem(
              icon: HugeIcons.strokeRoundedSettings02,
              title: 'Quality',
              value: state.selectedQuality == 'auto'
                  ? 'Auto'
                  : state.selectedQuality,
              onTap: () => _navigateTo(_SettingsPage.quality),
            ),
            _buildMenuItem(
              icon: HugeIcons.strokeRoundedSubtitle,
              title: 'Captions',
              value: state.selectedCaption ?? 'Off',
              onTap: () => _navigateTo(_SettingsPage.captions),
            ),
            _buildMenuItem(
              icon: HugeIcons.strokeRoundedMusicNote02,
              title: 'Audio Track',
              value: state.selectedAudioTrack != null
                  ? state.availableAudioTracks
                        .firstWhere(
                          (t) => t.id == state.selectedAudioTrack,
                          orElse: () => state.availableAudioTracks.first,
                        )
                        .label
                  : 'Default',
              onTap: () => _navigateTo(_SettingsPage.audio),
            ),
            _buildMenuItem(
              icon: HugeIcons.strokeRoundedDashboardSpeed02,
              title: 'Playback Speed',
              value: '${state.playbackSpeed}x',
              onTap: () => _navigateTo(_SettingsPage.speed),
            ),

            // Actions Section
            _buildSectionHeader('Actions'),
            _buildMenuItem(
              icon: HugeIcons.strokeRoundedDownload01,
              title: 'Download Video',
              value: '',
              onTap: () {
                Navigator.of(context).pop();
                PlayerDownloadHandler.handleDownload(context, ref, state);
              },
            ),
            _buildMenuItem(
              icon: HugeIcons.strokeRoundedShare01,
              title: 'Share Video',
              value: '',
              onTap: () => _shareVideo(context, state),
            ),
            _buildMenuItem(
              icon: HugeIcons.strokeRoundedLink01,
              title: 'Open in Browser',
              value: '',
              onTap: () => _openInBrowser(state),
            ),

            // Playback Section
            _buildSectionHeader('Playback'),
            _buildMenuItem(
              icon: HugeIcons.strokeRoundedClock01,
              title: 'Sleep Timer',
              value: state.sleepTimerMinutes != null
                  ? '${state.sleepTimerMinutes} min'
                  : 'Off',
              onTap: () => _navigateTo(_SettingsPage.sleep),
            ),
          ],
        );
      case _SettingsPage.quality:
        return Column(
          children: [
            _buildSelectOption(
              title: 'Auto',
              selected: state.selectedQuality == 'auto',
              onTap: () {
                viewModel.selectQuality('auto');
                _goBack();
              },
            ),
            ...state.availableQualities.map((q) {
              // Build detailed subtitle with codec, FPS, bitrate info
              List<String> details = [];

              // Add codec
              if (q.codec.isNotEmpty) {
                details.add(q.codec);
              }

              // Add FPS for video
              if (q.fps != null && q.vcodec != 'none') {
                details.add('${q.fps}fps');
              }

              // Add bitrate info
              if (q.vbr != null && q.vcodec != 'none') {
                details.add('${q.vbr!.round()}kbps');
              } else if (q.abr != null && q.vcodec == 'none') {
                details.add('${q.abr!.round()}kbps');
              } else if (q.tbr != null) {
                details.add('${q.tbr!.round()}kbps');
              }

              // Add filesize if available
              String? subtitle;
              if (details.isNotEmpty) {
                subtitle = details.join(' • ');
                if (q.filesize != null) {
                  subtitle +=
                      ' • ${(q.filesize! / 1024 / 1024).toStringAsFixed(1)} MB';
                }
              } else if (q.filesize != null) {
                subtitle =
                    '${(q.filesize! / 1024 / 1024).toStringAsFixed(1)} MB';
              }

              return _buildSelectOption(
                title: q.resolution,
                subtitle: subtitle,
                selected: state.selectedQuality == q.formatId,
                onTap: () {
                  viewModel.selectQuality(q.formatId);
                  _goBack();
                },
              );
            }),
          ],
        );
      case _SettingsPage.captions:
        final captions = state.metadata?.availableCaptions ?? [];
        return Column(
          children: [
            _buildSelectOption(
              title: 'Off',
              selected: state.selectedCaption == null,
              onTap: () {
                viewModel.disableCaptions();
                _goBack();
              },
            ),
            if (captions.isEmpty)
              Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'No captions available',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Captions may not be available for this video',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant.withOpacity(0.7),
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ...captions.map(
                (c) => _buildSelectOption(
                  title: c.name,
                  subtitle: '${c.lang} • ${c.type.toUpperCase()}',
                  selected: state.selectedCaption == c.lang,
                  onTap: () {
                    viewModel.selectCaption(c.lang);
                    _goBack();
                  },
                ),
              ),
          ],
        );
      case _SettingsPage.audio:
        final audioTracks = state.availableAudioTracks;
        return Column(
          children: [
            if (audioTracks.isEmpty)
              Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedMusicNote02,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 48,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'No audio tracks available',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'This video may only have one audio track',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant.withOpacity(0.7),
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ...audioTracks.map(
                (t) => _buildSelectOption(
                  title: t.label,
                  subtitle: t.language,
                  selected: state.selectedAudioTrack == t.id,
                  onTap: () {
                    viewModel.selectAudioTrack(t.id);
                    _goBack();
                  },
                ),
              ),
          ],
        );
      case _SettingsPage.speed:
        final speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
        return Column(
          children: speeds
              .map(
                (s) => _buildSelectOption(
                  title: '${s}x',
                  selected: state.playbackSpeed == s,
                  onTap: () {
                    viewModel.setPlaybackSpeed(s);
                    _goBack();
                  },
                ),
              )
              .toList(),
        );
      case _SettingsPage.sleep:
        final times = [null, 15, 30, 45, 60, 90, 120];
        return Column(
          children: times
              .map(
                (t) => _buildSelectOption(
                  title: t == null ? 'Off' : '$t minutes',
                  selected: state.sleepTimerMinutes == t,
                  onTap: () {
                    viewModel.setSleepTimer(t);
                    _goBack();
                  },
                ),
              )
              .toList(),
        );
    }
  }

  Widget _buildMenuItem({
    required dynamic icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            HugeIcon(
              icon: icon,
              color: Theme.of(context).colorScheme.onSurface,
              size: 20,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 8),
            HugeIcon(
              icon: HugeIcons.strokeRoundedArrowRight01,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchItem({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.onSurface, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.red,
            activeTrackColor: Colors.red.withOpacity(0.3),
            inactiveTrackColor: Colors.grey.withOpacity(0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectOption({
    required String title,
    String? subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: selected ? Colors.white.withOpacity(0.05) : Colors.transparent,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurface,
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: selected
                            ? Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.7)
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            if (selected)
              HugeIcon(
                icon: HugeIcons.strokeRoundedFavourite,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  void _shareVideo(BuildContext context, PlayerState state) {
    final videoUrl =
        state.metadata?.rawData['webpage_url'] ??
        'https://www.youtube.com/watch?v=${state.metadata?.videoId}';
    final title = state.metadata?.title ?? 'Check out this video!';

    Share.share('$title\n$videoUrl', subject: title);
  }

  void _openInBrowser(PlayerState state) async {
    final videoUrl =
        state.metadata?.rawData['webpage_url'] ??
        'https://www.youtube.com/watch?v=${state.metadata?.videoId}';
    final uri = Uri.parse(videoUrl);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
