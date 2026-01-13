// Stub implementation for Web platform (dart:io is not available on web)

class Platform {
  static bool get isIOS => false;
  static bool get isAndroid => false;
  static bool get isMacOS => false;
  static bool get isWindows => false;
  static bool get isLinux => false;
  static bool get isFuchsia => false;
}

// Stub for File class (not used on Web but needed for compilation)
class File {
  File(String path);

  Future<bool> exists() async => false;
  Future<List<int>> readAsBytes() async => throw UnsupportedError('File operations not supported on web');
}
