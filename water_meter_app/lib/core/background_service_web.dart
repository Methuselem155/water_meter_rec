import 'background_service.dart';

class BackgroundServiceWeb implements BackgroundService {
  @override
  void initialize(Function callbackDispatcher) {}

  @override
  void registerOneOffTask(String uniqueName, String taskName, {Map<String, dynamic>? inputData}) {}
}

BackgroundService getBackgroundService() => BackgroundServiceWeb();
