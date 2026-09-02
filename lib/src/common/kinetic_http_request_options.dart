/// Custom HTTP request headers and User-Agent for media loading.
///
/// Pass via [CommonVideoController.setHttpRequestOptions] or
/// `creationParams['userAgent']` / `creationParams['headers']`.
/// Applied on the next source load / [CommonVideoController.switchVideoSource].
///
/// On Web, progressive MP4 cannot carry custom headers; HLS/DASH xhr may.
/// Browsers typically forbid overriding `User-Agent`.
class KineticHttpRequestOptions {
  const KineticHttpRequestOptions({
    this.userAgent,
    this.headers,
  });

  /// HTTP User-Agent string. Null clears a previously set value when passed
  /// through [toMethodChannelArgs] with [clear] semantics via null options.
  final String? userAgent;

  /// Extra request headers (e.g. `Authorization`, `Referer`).
  final Map<String, String>? headers;

  bool get isEmpty =>
      (userAgent == null || userAgent!.isEmpty) &&
      (headers == null || headers!.isEmpty);

  Map<String, dynamic> toMethodChannelArgs() => <String, dynamic>{
        if (userAgent != null) 'userAgent': userAgent,
        if (headers != null) 'headers': headers,
      };

  factory KineticHttpRequestOptions.fromMap(Map<Object?, Object?>? map) {
    if (map == null) {
      return const KineticHttpRequestOptions();
    }
    final rawHeaders = map['headers'];
    Map<String, String>? headers;
    if (rawHeaders is Map) {
      headers = <String, String>{
        for (final entry in rawHeaders.entries)
          if (entry.key != null && entry.value != null)
            entry.key.toString(): entry.value.toString(),
      };
      if (headers.isEmpty) headers = null;
    }
    final ua = map['userAgent'] as String?;
    return KineticHttpRequestOptions(
      userAgent: ua != null && ua.isNotEmpty ? ua : null,
      headers: headers,
    );
  }

  /// Reads top-level `userAgent` / `headers` from view [creationParams].
  factory KineticHttpRequestOptions.fromCreationParams(
    Map<String, dynamic>? params,
  ) {
    if (params == null) return const KineticHttpRequestOptions();
    return KineticHttpRequestOptions.fromMap(params);
  }
}
