/// Minimal [File] shim so the example compiles on Flutter Web.
/// Android-only demo helpers that write VTT/XML are never called when [kIsWeb].
class File {
  File(this.path);

  final String path;

  Future<File> writeAsString(String contents) async {
    throw UnsupportedError('Local file write is not used on web demo');
  }

  Uri get uri => Uri.parse(path);
}
