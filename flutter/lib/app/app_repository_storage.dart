part of 'app_repository.dart';

/// AppRepository 的对象存储（BaaS）方法——part 拆分服从 CI 350 行硬上限，
/// 私有成员经 library 级隐私共享。
extension AppRepositoryStorage on AppRepository {
  // ── S3 storage (BaaS) ──────────────────────────────────────────────────
  /// 申请对象存储上传：server 按 app_id + environment 选 bucket/key，返回
  /// presigned PUT URL 与对象访问 URL。avatar 等文件直传 OSS，不再 base64。
  Future<({String uploadUrl, String url, String objectKey})> signUpload(
    String path,
    String contentType,
  ) async {
    final data = await _request(
      '/api/v1/storage/uploads',
      method: 'POST',
      body: {'path': path, 'contentType': contentType},
    );
    return (
      uploadUrl: data['uploadUrl']! as String,
      url: data['url']! as String,
      objectKey: data['objectKey']! as String,
    );
  }

  /// objectKey → 短时效 presigned GET URL（私有 bucket；24h 有效）。
  /// 通用资产（avatar/视频/音频…）显示前换取。
  Future<String?> resolveObjectUrl(String objectKey) async {
    try {
      final data = await _request(
        '/api/v1/storage/urls?key=${Uri.encodeComponent(objectKey)}',
      );
      return data['url'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// 二进制直传到 presigned URL（不经 API base；PUT 一次成功即返回）。
  Future<void> uploadToS3(
    String uploadUrl,
    Uint8List bytes,
    String contentType,
  ) async {
    final request = http.Request('PUT', Uri.parse(uploadUrl));
    request.headers['content-type'] = contentType;
    request.bodyBytes = bytes;
    final streamed = await _client
        .send(request)
        .timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'UPLOAD_FAILED',
        '对象存储上传失败 ${response.statusCode}',
        response.statusCode,
      );
    }
  }
}
