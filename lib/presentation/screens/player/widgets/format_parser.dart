import 'dart:math';

// This function runs in an isolate via `compute` and returns a JSON-serializable
// list of parsed format maps. Keep it simple and free of complex types.
List<Map<String, dynamic>> parseFormatsIsolate(List<dynamic> formatsList) {
  final allFormats = <Map<String, dynamic>>[];

  for (var format in formatsList) {
    if (format is! Map) continue;

    final vcodec = (format['vcodec']?.toString() ?? 'none');
    final acodec = (format['acodec']?.toString() ?? 'none');

    // Skip formats with no video and no audio codecs
    if (vcodec == 'none' && acodec == 'none') continue;

    final formatId = format['format_id']?.toString() ?? '';
    final height = format['height'] is int ? format['height'] as int : null;

    int? fps;
    final fpsValue = format['fps'];
    if (fpsValue is int) fps = fpsValue;
    if (fpsValue is double) fps = fpsValue.toInt();

    final filesize = format['filesize'] is int
        ? format['filesize'] as int
        : null;
    final ext = format['ext']?.toString() ?? '';
    final abr = format['abr'] is num ? format['abr'] as num : null;

    String label;
    String type;

    if (vcodec != 'none' && acodec == 'none') {
      // Video-only format
      if (height == null || height == 0) continue;
      label = '${height}p Video Only';
      type = 'video';
    } else if (vcodec == 'none' && acodec != 'none') {
      // Audio-only format
      label = 'Audio ${abr != null ? '${abr.round()}kbps' : ext.toUpperCase()}';
      type = 'audio';
    } else {
      // Video+audio format
      if (height == null || height == 0) continue;
      label = '${height}p';
      type = 'combined';
    }

    allFormats.add({
      'formatId': formatId,
      'resolution': label,
      'codec': ext.toUpperCase(),
      'filesize': filesize,
      'fps': fps?.toString(),
      'height': height,
      'type': type,
      'vcodec': vcodec,
      'acodec': acodec,
      'abr': abr?.toString(),
    });
  }

  // Sort: combined formats first, then video-only, then audio-only
  // Within each type, sort by quality (height for video, bitrate for audio)
  allFormats.sort((a, b) {
    final typeCompare = _getTypePriority(
      a['type'],
    ).compareTo(_getTypePriority(b['type']));
    if (typeCompare != 0) return typeCompare;

    if (a['type'] == 'audio') {
      // Sort audio by bitrate
      final aAbr = num.tryParse(a['abr'] ?? '0') ?? 0;
      final bAbr = num.tryParse(b['abr'] ?? '0') ?? 0;
      return bAbr.compareTo(aAbr);
    } else {
      // Sort video by height
      final aHeight = a['height'] as int? ?? 0;
      final bHeight = b['height'] as int? ?? 0;
      return bHeight.compareTo(aHeight);
    }
  });

  return allFormats;
}

int _getTypePriority(String? type) {
  switch (type) {
    case 'combined':
      return 0;
    case 'video':
      return 1;
    case 'audio':
      return 2;
    default:
      return 3;
  }
}
