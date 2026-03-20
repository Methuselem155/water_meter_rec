import 'file_service_stub.dart'
    if (dart.library.io) 'file_service_mobile.dart'
    if (dart.library.html) 'file_service_web.dart';

final fileService = getFileService();
