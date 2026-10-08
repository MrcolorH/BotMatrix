class VideoParseResult {
  final String url;
  final String resolution;
  final String? filesize;
  final String author;
  final String title;
  final String? thumbnail;

  VideoParseResult({
    required this.url,
    required this.resolution,
    this.filesize,
    required this.author,
    required this.title,
    this.thumbnail,
  });
}

class CachedVideoItem {
  final String url;
  final String filename;
  final String author;
  final String title;
  final String resolution;
  final String size;
  final DateTime cachedAt;

  CachedVideoItem({
    required this.url,
    required this.filename,
    required this.author,
    required this.title,
    required this.resolution,
    required this.size,
    DateTime? cachedAt,
  }) : cachedAt = cachedAt ?? DateTime.now();
}
