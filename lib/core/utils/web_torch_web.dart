import 'dart:js_interop';

@JS('attendTorch')
external JSPromise _attendTorch(JSBoolean on);

/// Turns the camera flashlight on/off in the browser.
/// Returns: 'on', 'off', 'unsupported', 'no-camera' or 'error: ...'.
Future<String> webTorchSet(bool on) async {
  try {
    final result = await _attendTorch(on.toJS).toDart;
    if (result is JSString) return result.toDart;
    return 'error: unexpected result';
  } catch (e) {
    return 'error: $e';
  }
}
