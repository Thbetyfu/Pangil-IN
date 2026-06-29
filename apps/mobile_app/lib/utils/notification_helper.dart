import 'notification_helper_stub.dart'
    if (dart.library.js_util) 'notification_helper_web.dart'
    if (dart.library.js) 'notification_helper_web.dart';

void triggerSystemNotification(String title, String body) {
  showWebNotification(title, body);
}
