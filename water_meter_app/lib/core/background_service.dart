abstract class BackgroundService {
  void initialize(Function callbackDispatcher);
  void registerOneOffTask(String uniqueName, String taskName, {Map<String, dynamic>? inputData});
}
