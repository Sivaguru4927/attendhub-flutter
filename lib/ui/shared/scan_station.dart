import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/laser_scanner_overlay.dart';
import '../../data/models/scan_event.dart';
import 'scan_result_card.dart';

/// Sends a confirmed roll number to the server and returns the outcome.
typedef ScanSubmit = Future<ScanResult> Function(String payload, String method);

/// Camera scanner used by BOTH the volunteer page and the admin page.
///
/// Flow:  camera sees code -> must stay in view for [hold time] (progress bar)
///        -> roll number is shown with Confirm (Enter) / Cancel (Esc)
///        -> on confirm it is saved and the student's details (or
///           "Scanned student" + roll no + date/time) are shown.
class ScanStation extends StatefulWidget {
  const ScanStation({
    super.key,
    required this.title,
    required this.onSubmit,
    required this.onExit,
    this.onSessionEnded,
  });

  final String title;
  final ScanSubmit onSubmit;
  final VoidCallback onExit;
  final VoidCallback? onSessionEnded;

  @override
  State<ScanStation> createState() => _ScanStationState();
}

class _ScanStationState extends State<ScanStation> with WidgetsBindingObserver {
  late final MobileScannerController _scanner;
  final FocusNode _focus = FocusNode();
  final ValueNotifier<double> _progress = ValueNotifier<double>(0);
  Timer? _tick;
  Timer? _resultTimer;

  double _holdSeconds = AppConstants.defaultHoldSeconds;

  // hold-to-confirm tracking
  String? _candidate;
  DateTime _candStart = DateTime.now();
  DateTime _candSeen = DateTime.now();

  // pending confirmation
  String? _pending;
  String _pendingMethod = 'QR Camera';
  DateTime? _pendingReadAt;
  bool _submitting = false;

  ScanResult? _result;
  int _okCount = 0;

  String? _cooldownCode;
  DateTime _cooldownUntil = DateTime.fromMillisecondsSinceEpoch(0);

  static final _timeFmt = DateFormat('hh:mm:ss a');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scanner = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      detectionTimeoutMs: 150,
      facing: CameraFacing.back,
    );
    _tick = Timer.periodic(const Duration(milliseconds: 50), _onTick);
    _loadHold();
  }

  Future<void> _loadHold() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getDouble(AppConstants.holdSecondsKey);
      if (v != null && mounted) setState(() => _holdSeconds = v);
    } catch (_) {}
  }

  Future<void> _saveHold(double v) async {
    setState(() => _holdSeconds = v);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(AppConstants.holdSecondsKey, v);
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    _resultTimer?.cancel();
    _progress.dispose();
    _focus.dispose();
    _scanner.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scanner.start().catchError((_) {});
    } else if (state == AppLifecycleState.paused) {
      _scanner.stop().catchError((_) {});
    }
  }

  // -------------------------------------------------------------------------
  // Detection + hold timer
  // -------------------------------------------------------------------------
  void _onDetect(BarcodeCapture capture) {
    if (_pending != null || _submitting || _result != null) return;
    String? raw;
    for (final b in capture.barcodes) {
      final v = b.rawValue;
      if (v != null && v.trim().isNotEmpty) {
        raw = v;
        break;
      }
    }
    if (raw == null) return;
    final code = raw.trim().toUpperCase();
    final now = DateTime.now();
    if (code == _cooldownCode && now.isBefore(_cooldownUntil)) return;

    if (_holdSeconds <= 0.05) {
      _setPending(code, 'QR Camera');
      return;
    }
    if (_candidate == code) {
      _candSeen = now;
    } else {
      _candidate = code;
      _candStart = now;
      _candSeen = now;
      _progress.value = 0.02;
    }
  }

  void _onTick(Timer _) {
    final code = _candidate;
    if (code == null) return;
    final now = DateTime.now();
    // Code left the camera view -> start over.
    if (now.difference(_candSeen).inMilliseconds > 900) {
      _candidate = null;
      _progress.value = 0;
      return;
    }
    final need = _holdSeconds * 1000;
    final p = (now.difference(_candStart).inMilliseconds / need).clamp(0.0, 1.0);
    _progress.value = p;
    if (p >= 1.0) {
      _candidate = null;
      _progress.value = 0;
      _setPending(code, 'QR Camera');
    }
  }

  void _setPending(String code, String method) {
    HapticFeedback.mediumImpact();
    setState(() {
      _pending = code;
      _pendingMethod = method;
      _pendingReadAt = DateTime.now();
    });
    _focus.requestFocus();
  }

  // -------------------------------------------------------------------------
  // Confirm / cancel / result
  // -------------------------------------------------------------------------
  Future<void> _confirm() async {
    final code = _pending;
    if (code == null || _submitting) return;
    setState(() => _submitting = true);
    ScanResult res;
    try {
      res = await widget.onSubmit(code, _pendingMethod);
    } catch (e) {
      res = ScanResult.error('Could not reach the server. Check your internet.\n$e');
    }
    if (!mounted) return;
    if (res.status == ScanResultStatus.sessionEnded) {
      widget.onSessionEnded?.call();
    }
    if (res.isSuccess) {
      HapticFeedback.heavyImpact();
      _okCount++;
    } else {
      HapticFeedback.vibrate();
    }
    setState(() {
      _submitting = false;
      _pending = null;
      _result = res;
      _cooldownCode = code;
      _cooldownUntil = DateTime.now().add(const Duration(milliseconds: 2500));
    });
    _resultTimer?.cancel();
    _resultTimer = Timer(
        const Duration(milliseconds: AppConstants.resultDisplayMs), _dismissResult);
  }

  void _cancel() {
    if (_pending == null || _submitting) return;
    setState(() {
      _cooldownCode = _pending;
      _cooldownUntil = DateTime.now().add(const Duration(milliseconds: 1500));
      _pending = null;
    });
    _progress.value = 0;
  }

  void _dismissResult() {
    _resultTimer?.cancel();
    if (!mounted || _result == null) return;
    setState(() => _result = null);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter) {
      if (_pending != null) {
        _confirm();
        return KeyEventResult.handled;
      }
      if (_result != null) {
        _dismissResult();
        return KeyEventResult.handled;
      }
    }
    if (k == LogicalKeyboardKey.escape) {
      if (_pending != null) {
        _cancel();
        return KeyEventResult.handled;
      }
      if (_result != null) {
        _dismissResult();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  // -------------------------------------------------------------------------
  // Toolbar actions
  // -------------------------------------------------------------------------
  Future<void> _toggleTorch(bool unavailable) async {
    if (unavailable) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Flashlight is not available on this camera / browser. '
            'It works on most Android phones (Chrome) and in the Android app.'),
      ));
      return;
    }
    try {
      await _scanner.toggleTorch();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Flashlight failed: $e')));
    }
  }

  Future<void> _switchCamera() async {
    try {
      await _scanner.switchCamera();
    } catch (_) {}
  }

  Future<void> _manualEntry() async {
    final ctrl = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Type roll number'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: 'e.g. 25BMA127'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(ctrl.text),
              child: const Text('Next')),
        ],
      ),
    );
    final code = value?.trim().toUpperCase() ?? '';
    if (code.isNotEmpty && mounted) _setPending(code, 'Manual');
  }

  void _openHoldSettings() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Scan hold time',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text(
                  'How long the code must stay in front of the camera before '
                  'the roll number is shown. Longer = fewer accidental scans '
                  'while moving the camera between people.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in const [0.0, 0.5, 1.0, 1.5, 2.0, 3.0])
                      ChoiceChip(
                        label: Text(s == 0 ? 'Instant' : '${s}s'),
                        selected: _holdSeconds == s,
                        onSelected: (_) {
                          _saveHold(s);
                          setSheet(() {});
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // UI
  // -------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: SafeArea(
          child: Stack(
            children: [
              MobileScanner(controller: _scanner, onDetect: _onDetect),
              const LaserScannerOverlay(),
              Positioned(top: 0, left: 0, right: 0, child: _header()),
              Positioned(
                left: 16,
                right: 16,
                bottom: 12,
                child: _bottom(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.success,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('$_okCount',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _scanner,
            builder: (context, state, _) {
              final unavailable = state.torchState == TorchState.unavailable;
              final on = state.torchState == TorchState.on;
              return IconButton(
                tooltip: unavailable ? 'Flashlight not available' : 'Flashlight',
                onPressed: () => _toggleTorch(unavailable),
                icon: Icon(
                  on ? Icons.flash_on : Icons.flash_off,
                  color: unavailable
                      ? Colors.white24
                      : (on ? Colors.yellow : Colors.white),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Switch camera',
            onPressed: _switchCamera,
            icon: const Icon(Icons.cameraswitch_outlined, color: Colors.white),
          ),
          IconButton(
            tooltip: 'Scan hold time',
            onPressed: _openHoldSettings,
            icon: const Icon(Icons.timer_outlined, color: Colors.white),
          ),
          IconButton(
            tooltip: 'Type roll number',
            onPressed: _manualEntry,
            icon: const Icon(Icons.keyboard_alt_outlined, color: Colors.white),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: widget.onExit,
            icon: const Icon(Icons.close_rounded, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _bottom() {
    if (_result != null) {
      return ScanResultCard(result: _result!, onNext: _dismissResult);
    }
    if (_pending != null) return _pendingPanel();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ValueListenableBuilder<double>(
          valueListenable: _progress,
          builder: (context, p, _) {
            if (p <= 0) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: p,
                  minHeight: 10,
                  backgroundColor: Colors.white24,
                  color: AppColors.accent,
                ),
              ),
            );
          },
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _holdSeconds <= 0.05
                ? 'Point the camera at the barcode / QR'
                : 'Hold the code steady for ${_holdSeconds}s',
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _pendingPanel() {
    final readAt = _pendingReadAt;
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _pendingMethod == 'Manual' ? 'Typed roll number' : 'Scanned roll number',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              _pending!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
                color: AppColors.textPrimary,
              ),
            ),
            if (readAt != null)
              Text(
                'Read at ${_timeFmt.format(readAt)}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _submitting ? null : _cancel,
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48)),
                    child: const Text('Cancel  (Esc)'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _submitting ? null : _confirm,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white),
                          )
                        : const Text('Confirm  (Enter)',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
