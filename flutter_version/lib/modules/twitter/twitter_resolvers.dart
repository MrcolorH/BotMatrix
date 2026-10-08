import 'dart:convert';
import 'package:dio/dio.dart';
import '../../core/models/video_parse_result.dart';

class TwitterResolvers {
  static final RegExp twitterRegex = RegExp(
    r'https?://(?:www\.)?(?:twitter|x)\.com/[a-zA-Z0-9_]+/status/(\d+)',
    caseSensitive: false,
  );

  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 12),
    receiveTimeout: const Duration(seconds: 15),
    headers: {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    },
  ));

  /// 格式化字节大小
  static String formatBytes(int bytes) {
    if (bytes <= 0) return '未知大小';
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    } else if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
  }

  /// 通过 HEAD 请求探测远程视频文件大小（毫秒级，不下载主体）
  static Future<String> getRemoteFileSize(String url) async {
    try {
      final res = await _dio.head(
        url,
        options: Options(
          followRedirects: true,
          validateStatus: (status) => status != null && status < 400,
        ),
      );
      final lenStr = res.headers.value('content-length');
      if (lenStr != null) {
        final bytes = int.tryParse(lenStr);
        if (bytes != null && bytes > 0) {
          return formatBytes(bytes);
        }
      }
    } catch (_) {}
    return '未知大小';
  }

  /// 规范化生成中文下载文件名
  static String generateCustomFilename(String rawAuthor, String rawTitle) {
    String cleanTitle = rawTitle.replaceAll(RegExp(r'https?://\S+'), '');
    cleanTitle = cleanTitle.replaceAll(RegExp(r'[@#]\S+'), '');
    cleanTitle = cleanTitle.replaceAll(RegExp(r'[^\w\u4e00-\u9fa5\s_-]+'), '').trim();
    cleanTitle = cleanTitle.replaceAll(RegExp(r'\s+'), '_');
    if (cleanTitle.length > 40) {
      cleanTitle = cleanTitle.substring(0, 40);
    }
    if (cleanTitle.isEmpty) {
      cleanTitle = 'twitter_video';
    }
    return '${rawAuthor}_$cleanTitle.mp4';
  }

  /// 引擎 1：FixTweet API (高效、免 Key、最高画质提取)
  static Future<VideoParseResult> resolveViaFxTwitter(String statusId) async {
    final url = 'https://api.fxtwitter.com/status/$statusId';
    final res = await _dio.get(url);
    if (res.statusCode != 200 || res.data == null) {
      throw Exception('FixTweet 响应异常 (HTTP ${res.statusCode})');
    }

    final data = res.data is String ? jsonDecode(res.data) : res.data;
    final tweet = data['tweet'];
    if (tweet == null) throw Exception('FixTweet 未返回推文数据');

    final media = tweet['media'];
    final videos = media?['videos'] as List?;
    if (videos == null || videos.isEmpty) {
      throw Exception('推文中未检测到视频媒体');
    }

    final v = videos[0] as Map<String, dynamic>;
    final formats = (v['formats'] as List?) ?? [];
    final mp4Formats = formats.where((f) {
      final container = f['container']?.toString() ?? '';
      final fUrl = f['url']?.toString() ?? '';
      return container == 'mp4' || fUrl.contains('.mp4');
    }).toList();

    String bestUrl;
    if (mp4Formats.isNotEmpty) {
      mp4Formats.sort((a, b) {
        final bitA = (a['bitrate'] as num?)?.toInt() ?? 0;
        final bitB = (b['bitrate'] as num?)?.toInt() ?? 0;
        return bitB.compareTo(bitA);
      });
      bestUrl = mp4Formats.first['url']?.toString() ?? '';
    } else {
      bestUrl = v['url']?.toString() ?? '';
    }

    if (bestUrl.isEmpty) {
      throw Exception('未找到有效的视频直链');
    }

    String resolution = '最高画质';
    final resMatch = RegExp(r'(\d+)x(\d+)').firstMatch(bestUrl);
    if (resMatch != null) {
      resolution = '${resMatch.group(2)}p';
    } else if (v['height'] != null) {
      resolution = '${v['height']}p';
    }

    final authorName = tweet['author']?['name']?.toString() ?? 'Twitter 用户';
    final text = tweet['text']?.toString() ?? '';
    final thumbnail = v['thumbnail_url']?.toString();

    return VideoParseResult(
      url: bestUrl,
      resolution: resolution,
      author: authorName,
      title: text.length > 150 ? text.substring(0, 150) : text,
      thumbnail: thumbnail,
    );
  }

  /// 引擎 2：TwitterDown 官方接口
  static Future<VideoParseResult> resolveViaTwitterDown(
    String tweetUrl,
    String apiKey,
  ) async {
    if (apiKey.trim().isEmpty) {
      throw Exception('未配置 TWITTERDOWN_API_KEY');
    }

    const apiUrl = 'https://twitterdown.com/api/v1/twitter';
    final res = await _dio.post(
      apiUrl,
      data: {'url': tweetUrl},
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
      ),
    );

    final data = res.data is String ? jsonDecode(res.data) : res.data;
    if (data['code'] != 0 || data['data'] == null) {
      throw Exception(data['message']?.toString() ?? 'TwitterDown 接口返回异常');
    }

    final resData = data['data'] as Map<String, dynamic>;
    final videos = (resData['videos'] as List?) ?? [];
    if (videos.isEmpty) throw Exception('TwitterDown 未获取到视频列表');

    int getResNum(dynamic item) {
      final str = item['resolution']?.toString() ?? '';
      final m = RegExp(r'(\d+)').firstMatch(str);
      return m != null ? int.tryParse(m.group(1)!) ?? 0 : 0;
    }

    videos.sort((a, b) => getResNum(b).compareTo(getResNum(a)));
    final best = videos.first as Map<String, dynamic>;

    return VideoParseResult(
      url: best['url']?.toString() ?? '',
      resolution: best['resolution']?.toString() ?? 'HD',
      author: resData['username']?.toString() ?? '未知',
      title: resData['text']?.toString() ?? '',
      thumbnail: resData['thumbnail']?.toString(),
    );
  }

  /// 引擎 3：VxTwitter / Cobalt 开放线路兜底
  static Future<VideoParseResult> resolveViaVxTwitter(String statusId) async {
    final url = 'https://api.vxtwitter.com/Twitter/status/$statusId';
    final res = await _dio.get(url);
    if (res.statusCode != 200 || res.data == null) {
      throw Exception('VxTwitter 响应异常');
    }

    final data = res.data is String ? jsonDecode(res.data) : res.data;
    final mediaUrls = (data['mediaURLs'] as List?) ?? [];
    final videoUrls = mediaUrls.where((u) => u.toString().contains('.mp4')).toList();

    if (videoUrls.isEmpty) {
      throw Exception('VxTwitter 未找到视频直链');
    }

    final videoUrl = videoUrls.first.toString();
    String resStr = '最高画质';
    final m = RegExp(r'(\d+)x(\d+)').firstMatch(videoUrl);
    if (m != null) {
      resStr = '${m.group(2)}p';
    }

    return VideoParseResult(
      url: videoUrl,
      resolution: resStr,
      author: data['user_name']?.toString() ?? 'Twitter 用户',
      title: data['text']?.toString() ?? '',
      thumbnail: null,
    );
  }
}
