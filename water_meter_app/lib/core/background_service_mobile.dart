import 'package:workmanager/workmanager.dart';
import 'background_service.dart';

class BackgroundServiceMobile implements BackgroundService {
  @override
  void initialize(Function callbackDispatcher) {
    Workmanager().initialize(callbackDispatcher);
  }

  @override
  void registerOneOffTask(String uniqueName, String taskName, {Map<String, dynamic>? inputData}) {
    Workmanager().registerOneOffTask(
      uniqueName,
      taskName,
      inputData: inputData,
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }
}

BackgroundService getBackgroundService() => BackgroundServiceMobile();
