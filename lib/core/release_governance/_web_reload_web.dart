// Web implementation of the page reload used by the UpdateGate's "Reload"
// action for the web-prod distribution. We use the same dart:html surface
// the rest of the codebase uses (auth_broadcast_web, web_push_service_web)
// rather than mixing dart:html and package:web in the same project.

// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

void reloadWebPage() {
  html.window.location.reload();
}
