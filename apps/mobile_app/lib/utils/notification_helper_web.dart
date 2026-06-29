import 'dart:js' as js;

void showWebNotification(String title, String body) {
  try {
    if (js.context['showPanggilInNotification'] == null) {
      js.context.callMethod('eval', [
        """
        window.showPanggilInNotification = function(title, body) {
          if (!('Notification' in window)) return;
          if (Notification.permission === 'granted') {
            new Notification(title, { body: body });
          } else if (Notification.permission !== 'denied') {
            Notification.requestPermission().then(function(permission) {
              if (permission === 'granted') {
                new Notification(title, { body: body });
              }
            }).catch(function(err) {
              // Fallback for older callback style if Promise fails
              try {
                Notification.requestPermission(function(permission) {
                  if (permission === 'granted') {
                    new Notification(title, { body: body });
                  }
                });
              } catch(e) {}
            });
          }
        };
      """,
      ]);
    }
    js.context.callMethod('showPanggilInNotification', [title, body]);
  } catch (e) {
    print('Failed to trigger web notification: $e');
  }
}
