import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../components/components.dart';
import '../../core/theme/theme.dart';
import '../../l10n/app_localizations.dart';
import '../scan/qr_camera.dart';
import '../scan/viewfinder.dart';

/// A camera page that reads one QR code and returns its text (the card desk's "hand out an online card"). The
/// camera is released as soon as the page closes. Android and iPhone alike.
class QrCaptureScreen extends StatefulWidget {
  const QrCaptureScreen({super.key, required this.title, this.cameraFactory = MobileScannerQrCamera.new});

  final String title;
  final QrCameraFactory cameraFactory;

  @override
  State<QrCaptureScreen> createState() => _QrCaptureScreenState();
}

class _QrCaptureScreenState extends State<QrCaptureScreen> {
  late final QrCamera _camera = widget.cameraFactory(torch: false);
  StreamSubscription<QrDetection>? _detections;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _detections = _camera.detections.listen((QrDetection d) {
      if (_done || d.raw.trim().isEmpty || !mounted) return;
      _done = true;
      final NavigatorState navigator = Navigator.of(context);
      unawaited(_camera.pause());
      navigator.pop(d.raw);
    });
    _camera.addListener(_changed);
    unawaited(_camera.start());
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _camera.removeListener(_changed);
    unawaited(_detections?.cancel());
    _camera.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final WaiterColors c = context.colors;
    final WaiterLayout layout = context.layout;
    final double side = layout.widthClass.isTablet ? 320 : 256;
    return ColoredBox(
      color: const Color(0xFF000000),
      child: Column(
        children: <Widget>[
          TopBar.task(onClose: () => Navigator.of(context).pop(), title: widget.title),
          Expanded(
            child: switch (_camera.status) {
              QrCameraStatus.denied || QrCameraStatus.unavailable => Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: layout.margin),
                  child: StatusBanner(
                    tone: BannerTone.warning,
                    title: _camera.status == QrCameraStatus.denied ? l10n.cameraDeniedTitle : l10n.cameraUnavailableTitle,
                    body: _camera.status == QrCameraStatus.denied ? l10n.cameraDeniedBody : l10n.cameraUnavailableBody,
                  ),
                ),
              ),
              _ => LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final Size size = constraints.biggest;
                  final Rect window = Rect.fromCenter(center: size.center(Offset.zero), width: side, height: side);
                  return Stack(
                    children: <Widget>[
                      Positioned.fill(child: _camera.buildPreview(context)),
                      Positioned.fill(
                        child: CustomPaint(
                          painter: ViewfinderPainter(window: window, brackets: window, scrim: c.scrim, bracketColor: c.accentSaffron),
                        ),
                      ),
                      if (_camera.status == QrCameraStatus.starting) const Center(child: Spinner()),
                    ],
                  );
                },
              ),
            },
          ),
        ],
      ),
    );
  }
}
