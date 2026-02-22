import 'package:curio/presentation/common/progress_indicators.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../domain/entities/playlist.dart';
import '../../../domain/entities/video.dart';
import '../../common/empty_state.dart';
import '../../common/video_card.dart';
import '../../providers/playlists_provider.dart';
import '../../providers/videos_provider.dart';
import '../player/player_screen.dart';
import '../playlist/playlist_screen.dart';

class SearchResultsScreen extends ConsumerStatefulWidget {
  final String initialQuery;

  const SearchResultsScreen({super.key, this.initialQuery = ''});

  @override
  ConsumerState<SearchResultsScreen> createState() =>
      _SearchResultsScreenState();
}

class _SearchResultsScreenState extends ConsumerState<SearchResultsScreen> {
  late TextEditingController _searchController;
  String _searchQuery = '';
  List<Video> _filteredVideos = [];
  List<Playlist> _filteredPlaylists = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
    _searchQuery = widget.initialQuery;
    _performSearch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    setState(() => _isLoading = true);

    try {
      // Get all videos and playlists
      final likedVideos = await ref.read(likedVideosProvider.future);
      final watchLaterVideos = await ref.read(watchLaterVideosProvider.future);
      final playlists = await ref.read(playlistsProvider.future);

      // Combine all videos (remove duplicates by id)
      final allVideos = <String, Video>{};
      for (var video in [...likedVideos, ...watchLaterVideos]) {
        allVideos[video.id] = video;
      }

      if (_searchQuery.isEmpty) {
        setState(() {
          _filteredVideos = [];
          _filteredPlaylists = [];
          _isLoading = false;
        });
        return;
      }

      final query = _searchQuery.toLowerCase();

      // Filter videos
      _filteredVideos = allVideos.values.where((video) {
        return video.title.toLowerCase().contains(query) ||
            video.channelName.toLowerCase().contains(query) ||
            (video.description?.toLowerCase().contains(query) ?? false);
      }).toList();

      // Filter playlists (exclude special playlists LL and WL)
      _filteredPlaylists = playlists.where((playlist) {
        if (playlist.id == 'LL' || playlist.id == 'WL') return false;
        return playlist.title.toLowerCase().contains(query) ||
            (playlist.description?.toLowerCase().contains(query) ?? false) ||
            playlist.uploader.toLowerCase().contains(query);
      }).toList();

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error searching: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalResults = _filteredVideos.length + _filteredPlaylists.length;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: Theme.of(context).textTheme.titleMedium,
          decoration: InputDecoration(
            hintText: 'Search videos and playlists...',
            border: InputBorder.none,
            hintStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          onChanged: (value) {
            setState(() => _searchQuery = value);
            // Debounce search for better performance
            Future.delayed(const Duration(milliseconds: 300), () {
              if (_searchQuery == value) {
                _performSearch();
              }
            });
          },
          onSubmitted: (_) => _performSearch(),
        ),
        actions: [
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedCancel01,
                color: Colors.grey,
                size: 20,
              ),
              onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
                _performSearch();
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: M3CircularProgressIndicator())
          : _searchQuery.isEmpty
          ? _buildEmptyQueryState()
          : totalResults == 0
          ? _buildNoResultsState()
          : _buildResults(),
    );
  }

  Widget _buildEmptyQueryState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 80,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
          const Gap(16),
          Text(
            'Search your library',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const Gap(8),
          Text(
            'Find videos and playlists by title,\nchannel, or description',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
          const Gap(16),
          Text(
            'No results found',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const Gap(8),
          Text(
            'Try different keywords or check your spelling',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Results summary
        Text(
          'Found ${_filteredVideos.length} video${_filteredVideos.length != 1 ? 's' : ''} and ${_filteredPlaylists.length} playlist${_filteredPlaylists.length != 1 ? 's' : ''}',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const Gap(16),

        // Playlists section
        if (_filteredPlaylists.isNotEmpty) ...[
          Text(
            'Playlists',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const Gap(12),
          ..._filteredPlaylists.map((playlist) => _buildPlaylistCard(playlist)),
          const Gap(24),
        ],

        // Videos section
        if (_filteredVideos.isNotEmpty) ...[
          Text(
            'Videos',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const Gap(12),
          ..._filteredVideos.map(
            (video) => VideoCard(
              video: video,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => PlayerScreen(video: video)),
                );
              },
              onMenuTap: () {},
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPlaylistCard(Playlist playlist) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: playlist.thumbnailUrl == null
                ? LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.secondary,
                    ],
                  )
                : null,
            image: playlist.thumbnailUrl != null
                ? DecorationImage(
                    image: NetworkImage(playlist.thumbnailUrl!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: playlist.thumbnailUrl == null
              ? const HugeIcon(
                  icon: HugeIcons.strokeRoundedHome02,
                  color: Colors.white,
                  size: 24,
                )
              : null,
        ),
        title: Text(
          playlist.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${playlist.videoCount} videos'),
            if (playlist.description != null &&
                playlist.description!.isNotEmpty)
              Text(
                playlist.description!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        trailing: const HugeIcon(
          icon: HugeIcons.strokeRoundedArrowRight01,
          color: Colors.grey,
          size: 20,
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PlaylistScreen(playlist: playlist),
            ),
          );
        },
      ),
    );
  }
}
