part of 'app_repository.dart';

extension AppRepositoryHttp on AppRepository {
  Future<List<T>> _list<T>(String path, T Function(JsonMap) decode) async {
    final data = await _requestRaw(path);
    return (data as List)
        .map((value) => decode(JsonMap.from(value as Map)))
        .toList(growable: false);
  }

  Future<JsonMap> _request(
    String path, {
    String method = 'GET',
    JsonMap? body,
    String? idempotencyKey,
  }) async => JsonMap.from(
    await _requestRaw(
          path,
          method: method,
          body: body,
          idempotencyKey: idempotencyKey,
        )
        as Map,
  );

  Future<Object?> _requestRaw(
    String path, {
    String method = 'GET',
    JsonMap? body,
    String? idempotencyKey,
    bool retried = false,
  }) async {
    final request = http.Request(
      method,
      Uri.parse('${AppRepository._apiBase}$path'),
    );
    request.headers.addAll(_headers(idempotencyKey));
    if (body != null) request.body = jsonEncode(body);
    final streamed = await _client
        .send(request)
        .timeout(const Duration(seconds: 10));
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 401 && !retried && await _refreshSession()) {
      return _requestRaw(
        path,
        method: method,
        body: body,
        idempotencyKey: idempotencyKey,
        retried: true,
      );
    }
    final decoded = jsonDecode(response.body) as Map<String, Object?>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      // 401 仅在「已登录会话失效」时触发过期回调；auth 端点（登录/注册/
      // 验证码等）的 401 是凭证错误，走表单内联错误展示，不能切页。
      if (response.statusCode == 401 &&
          !retried &&
          !path.startsWith('/api/v1/auth/')) {
        onSessionExpired?.call();
      }
      final error = JsonMap.from(decoded['error']! as Map);
      final fieldErrors = _parseFieldErrors(error['fieldErrors']);
      throw ApiException(
        error['code']! as String,
        _specificErrorMessage(error['message']! as String, fieldErrors),
        response.statusCode,
        fieldErrors: fieldErrors,
      );
    }
    return decoded['data'];
  }

  Map<String, List<String>> _parseFieldErrors(Object? value) {
    if (value is! Map) return const {};
    return value.map((key, messages) {
      final list = messages is List
          ? messages.whereType<String>().toList(growable: false)
          : const <String>[];
      return MapEntry(key.toString(), list);
    });
  }

  String _specificErrorMessage(
    String fallback,
    Map<String, List<String>> fieldErrors,
  ) {
    final messages = fieldErrors.values.expand((value) => value).toSet();
    return messages.isEmpty ? fallback : messages.join('；');
  }

  Future<bool> _refreshSession() {
    _refreshInFlight ??= _performRefresh();
    return _refreshInFlight!.whenComplete(() => _refreshInFlight = null);
  }

  Future<bool> _performRefresh() async {
    final refreshToken =
        await _secure.read(key: AppRepository._refreshTokenKey) ?? '';
    if (refreshToken.isEmpty) return false;
    try {
      final request = http.Request(
        'POST',
        Uri.parse('${AppRepository._apiBase}/api/v1/auth/refresh'),
      );
      request.headers.addAll(_headers(null));
      request.body = jsonEncode({'refreshToken': refreshToken});
      final streamed = await _client
          .send(request)
          .timeout(const Duration(seconds: 10));
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode < 200 || response.statusCode >= 300) return false;
      final decoded = jsonDecode(response.body) as Map<String, Object?>;
      final data = JsonMap.from(decoded['data']! as Map);
      final token = data['token']! as String;
      final refresh = data['refreshToken']! as String;
      _token = token;
      await _secure.write(key: AppRepository._tokenKey, value: token);
      await _secure.write(key: AppRepository._refreshTokenKey, value: refresh);
      return true;
    } catch (_) {
      return false;
    }
  }

  Map<String, String> _headers(String? idempotencyKey) {
    final headers = <String, String>{
      'content-type': 'application/json',
      'accept-language': _acceptLanguage,
      'x-app-id': AppRepository._appId,
      'x-app-environment': AppRepository._appEnvironment,
      'x-platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      'x-app-version': '1.0.0',
    };
    if (_token.isNotEmpty) headers['authorization'] = 'Bearer $_token';
    if (idempotencyKey != null) headers['idempotency-key'] = idempotencyKey;
    return headers;
  }
}
