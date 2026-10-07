/// Minimal stub so `dart:io` symbols used behind `kIsWeb` guards still
/// compile for the web target without pulling in the real dart:io library.
class File {
  File(this.path);
  final String path;

  bool existsSync() => false;

  Future<File> copy(String newPath) async => File(newPath);
}
