// Utility functions for formatting video metadata like duration, view counts, etc.

import 'package:intl/intl.dart';

/// Formats duration in seconds to YouTube-like format (MM:SS or HH:MM:SS)
String formatDuration(String? durationString) {
  if (durationString == null || durationString.isEmpty) return '0:00';

  // Try to parse as seconds
  final seconds = int.tryParse(durationString);
  if (seconds != null) {
    return formatDurationFromSeconds(seconds);
  }

  // Try to parse existing format (HH:MM:SS or MM:SS)
  final parts = durationString.split(':');
  if (parts.length == 2) {
    // MM:SS format
    final minutes = int.tryParse(parts[0]) ?? 0;
    final secs = int.tryParse(parts[1]) ?? 0;
    return formatDurationFromSeconds(minutes * 60 + secs);
  } else if (parts.length == 3) {
    // HH:MM:SS format
    final hours = int.tryParse(parts[0]) ?? 0;
    final minutes = int.tryParse(parts[1]) ?? 0;
    final secs = int.tryParse(parts[2]) ?? 0;
    return formatDurationFromSeconds(hours * 3600 + minutes * 60 + secs);
  }

  // Return as-is if can't parse
  return durationString;
}

/// Formats duration from total seconds to YouTube-like format (MM:SS or HH:MM:SS)
String formatDurationFromSeconds(int totalSeconds) {
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;

  if (hours > 0) {
    return '${hours.toString()}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  } else {
    return '${minutes.toString()}:${seconds.toString().padLeft(2, '0')}';
  }
}

/// Formats view count to YouTube-like format (1.2K, 5.3M, etc.)
String formatViewCount(String? viewCount) {
  if (viewCount == null || viewCount.isEmpty || viewCount == '0')
    return '0 Views';

  // Remove commas, "views", "Views" and any whitespace
  String cleaned = viewCount
      .replaceAll(',', '')
      .replaceAll('views', '')
      .replaceAll('Views', '')
      .trim();

  final count = int.tryParse(cleaned);
  if (count == null)
    return '$viewCount Views'; // Return with suffix if can't parse

  if (count >= 1000000000) {
    // Billions
    final billions = count / 1000000000;
    return '${billions.toStringAsFixed(billions >= 10 ? 0 : 1)}B Views';
  } else if (count >= 1000000) {
    // Millions
    final millions = count / 1000000;
    return '${millions.toStringAsFixed(millions >= 10 ? 0 : 1)}M Views';
  } else if (count >= 1000) {
    // Thousands
    final thousands = count / 1000;
    return '${thousands.toStringAsFixed(thousands >= 10 ? 0 : 1)}K Views';
  } else {
    return '$count Views';
  }
}

/// Formats video count for playlists (for metadata text)
String formatVideoCount(int count) {
  if (count == 0) return 'No videos';
  if (count == 1) return '1 video';
  return '$count videos';
}

/// Formats video count for badges (abbreviated format)
String formatVideoCountBadge(int count) {
  if (count >= 1000000) {
    return '${(count / 1000000).toStringAsFixed(1)}M';
  } else if (count >= 1000) {
    return '${(count / 1000).toStringAsFixed(1)}K';
  } else {
    return count.toString();
  }
}

/// Formats upload date to absolute date (e.g., "Jan 1, 2023")
String formatUploadDate(String? uploadDate) {
  if (uploadDate == null || uploadDate.isEmpty) return '';

  try {
    DateTime? date;

    // First, try parsing as unix timestamp (number as string)
    final timestamp = int.tryParse(uploadDate);
    if (timestamp != null) {
      // Check if it's a reasonable unix timestamp (after 2000)
      if (timestamp > 946684800) {
        // 2000-01-01
        date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
      }
    }

    // If not a unix timestamp, try parsing YYYYMMDD format (from yt-dlp)
    if (date == null &&
        uploadDate.length == 8 &&
        int.tryParse(uploadDate) != null) {
      final year = int.parse(uploadDate.substring(0, 4));
      final month = int.parse(uploadDate.substring(4, 6));
      final day = int.parse(uploadDate.substring(6, 8));
      date = DateTime(year, month, day);
    }

    // If still not parsed, try parsing ISO8601 format
    date ??= DateTime.tryParse(uploadDate);

    if (date == null) return uploadDate;

    // Format as absolute date
    return DateFormat('MMM d, yyyy').format(date);
  } catch (e) {
    return uploadDate; // Return original if parsing fails
  }
}

/// Formats bytes into human-readable file size (B, KB, MB, GB, TB)
String formatFileSize(int bytes) {
  if (bytes <= 0) return '0 B';
  const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
  var i = 0;
  double size = bytes.toDouble();
  while (size >= 1024 && i < suffixes.length - 1) {
    size /= 1024;
    i++;
  }
  return '${size.toStringAsFixed(size < 10 && i > 0 ? 1 : 0)} ${suffixes[i]}';
}
