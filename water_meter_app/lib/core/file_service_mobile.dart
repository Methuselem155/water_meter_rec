import 'dart:io' as io;
import 'file_service.dart';

class MobileFileService implements FileService {
  @override
  void deleteFile(String path) {
    final file = io.File(path);
    if (file.existsSync()) {
      file.deleteSync();
    }
  }
}

FileService getFileService() => MobileFileService();
