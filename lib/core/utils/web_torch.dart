// Flashlight helper for the WEB build.
//
// On Android Chrome the camera "torch" is switched on the live camera track.
// The scanner library sometimes reports "flashlight unavailable" even when the
// phone supports it, so on web we talk to the camera track directly
// (see the script in web/index.html).
export 'web_torch_stub.dart' if (dart.library.js_interop) 'web_torch_web.dart';
