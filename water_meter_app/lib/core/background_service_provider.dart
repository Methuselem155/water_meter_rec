import 'background_service_stub.dart'
    if (dart.library.io) 'background_service_mobile.dart'
    if (dart.library.html) 'background_service_web.dart';

final backgroundService = getBackgroundService();
