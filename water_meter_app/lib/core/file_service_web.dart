import 'file_service.dart';

class WebFileService implements FileService {
  @override
  void deleteFile(String path) {}
}

FileService getFileService() => WebFileService();
