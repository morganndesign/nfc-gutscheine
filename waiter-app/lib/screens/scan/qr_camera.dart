import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// What the S12 camera can do right now (03a §8, S16 §11.3, 12 P03–P05).
enum QrCameraStatus {
  /// Starting (black preview; spinner after 500 ms).
  starting,

  /// Live preview, decoding continuously on-device.
  running,

  /// Permission denied or restricted (P03 / P04).
  denied,

  /// No usable camera, or in use by another app (P05).
  unavailable,
}

/// One decoded QR code with its corners in camera-image coordinates.
@immutable
class QrDetection {
  /// Creates a detection.
  const QrDetection({
    required this.raw,
    this.corners = const <Offset>[],
    this.imageSize = Size.zero,
    this.landscape = false,
  });

  /// The decoded text.
  final String raw;

  /// Corner points in the camera image.
  final List<Offset> corners;

  /// Size of the camera image the corners refer to.
  final Size imageSize;

  /// Whether the device was in landscape (the image is rotated).
  final bool landscape;

  /// The code's bounds in a preview of [view] size filled with
  /// `BoxFit.cover`; `null` when the camera reported no geometry.
  Rect? boundsIn(Size view) {
    if (corners.length < 4 || imageSize.isEmpty || view.isEmpty) return null;
    final Size image = landscape ? imageSize.flipped : imageSize;
    final double ratio = math.max(
      view.width / image.width,
      view.height / image.height,
    );
    final double dx = (image.width * ratio - view.width) / 2;
    final double dy = (image.height * ratio - view.height) / 2;
    double left = double.infinity;
    double top = double.infinity;
    double right = -double.infinity;
    double bottom = -double.infinity;
    for (final Offset corner in corners) {
      final Offset p = Offset(corner.dx * ratio - dx, corner.dy * ratio - dy);
      left = math.min(left, p.dx);
      top = math.min(top, p.dy);
      right = math.max(right, p.dx);
      bottom = math.max(bottom, p.dy);
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }
}

/// The camera behind S12. The screen owns one instance and disposes it when
/// it leaves (03a §8: the camera is released immediately).
abstract class QrCamera implements Listenable {
  /// Current status.
  QrCameraStatus get status;

  /// Whether the device has a torch for the active camera.
  bool get torchAvailable;

  /// Whether the torch is on.
  bool get torchOn;

  /// Decoded QR codes.
  Stream<QrDetection> get detections;

  /// The live preview, filling its box (aspect-fill).
  Widget buildPreview(BuildContext context);

  /// Starts or resumes the camera (also after returning from Settings).
  Future<void> start();

  /// Freezes the preview and stops decoding (one detection = one request).
  Future<void> pause();

  /// Switches the torch.
  Future<void> toggleTorch();

  /// Focus and exposure at [point] (0–1 in both axes of the preview).
  Future<void> focusAt(Offset point);

  /// Releases the camera.
  void dispose();
}

/// Creates the camera of S12; [torch] restores the torch state remembered
/// for the session (03a §8).
typedef QrCameraFactory = QrCamera Function({required bool torch});

/// Production [QrCamera] on `mobile_scanner` 7: QR codes only, back camera,
/// lifecycle pause/resume handled by the scanner widget.
class MobileScannerQrCamera extends ChangeNotifier implements QrCamera {
  /// Creates the camera.
  MobileScannerQrCamera({required bool torch})
    : _controller = MobileScannerController(
        formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
        torchEnabled: torch,
      ) {
    _controller.addListener(notifyListeners);
  }

  final MobileScannerController _controller;

  @override
  QrCameraStatus get status {
    final MobileScannerState value = _controller.value;
    final MobileScannerException? error = value.error;
    if (error != null) {
      return error.errorCode == MobileScannerErrorCode.permissionDenied
          ? QrCameraStatus.denied
          : QrCameraStatus.unavailable;
    }
    return value.isRunning ? QrCameraStatus.running : QrCameraStatus.starting;
  }

  @override
  bool get torchAvailable =>
      _controller.value.torchState != TorchState.unavailable;

  @override
  bool get torchOn => _controller.value.torchState == TorchState.on;

  @override
  Stream<QrDetection> get detections =>
      _controller.barcodes.expand(_detectionsOf);

  Iterable<QrDetection> _detectionsOf(BarcodeCapture capture) sync* {
    final DeviceOrientation orientation = _controller.value.deviceOrientation;
    for (final Barcode barcode in capture.barcodes) {
      final String? raw = barcode.rawValue;
      if (raw == null) continue;
      yield QrDetection(
        raw: raw,
        corners: barcode.corners,
        imageSize: capture.size,
        landscape:
            orientation == DeviceOrientation.landscapeLeft ||
            orientation == DeviceOrientation.landscapeRight,
      );
    }
  }

  @override
  Widget buildPreview(BuildContext context) => MobileScanner(
    controller: _controller,
    placeholderBuilder: (BuildContext context) => const SizedBox.expand(),
    errorBuilder: (BuildContext context, MobileScannerException error) =>
        const SizedBox.expand(),
  );

  @override
  Future<void> start() async {
    try {
      await _controller.start();
    } on MobileScannerException {
      // Reflected in [status] through the controller value.
    }
  }

  @override
  Future<void> pause() => _controller.pause();

  @override
  Future<void> toggleTorch() => _controller.toggleTorch();

  @override
  Future<void> focusAt(Offset point) async {
    if (!_controller.value.isRunning) return;
    await _controller.setFocusPoint(point);
  }

  @override
  void dispose() {
    _controller.removeListener(notifyListeners);
    unawaited(_controller.dispose());
    super.dispose();
  }
}
