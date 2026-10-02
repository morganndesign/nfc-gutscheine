import 'package:flutter/widgets.dart';

import '../app/app_scope.dart';
import '../components/components.dart';
import '../core/api/models.dart';
import '../core/state/session_state.dart';
import '../core/station/station_controller.dart';
import '../core/theme/theme.dart';
import '../l10n/app_localizations.dart';
import 'scan/sheet_rows.dart';

/// S21 · Personalisation station (internal; platform staff with a station token, Android). Choose a batch, then
/// hold blank cards to the phone one after the other: the server keys and checks each card through the phone.
class StationScreen extends StatefulWidget {
  const StationScreen({super.key});

  @override
  State<StationScreen> createState() => _StationScreenState();
}

class _StationScreenState extends State<StationScreen> {
  StationController? _station;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_station != null) return;
    final AppServices services = context.services;
    final AppLocalizations l10n = AppLocalizations.of(context);
    _station = StationController(
      api: services.api,
      nfc: services.nfc,
      prompt: () => l10n.stationWaiting,
      onAuthFailure: (failure) => services.session.handleFailure(failure, SessionContext.lookup),
    )..load();
  }

  @override
  void dispose() {
    _station?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final StationController station = _station!;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final WaiterColors c = context.colors;
    return ListenableBuilder(
      listenable: station,
      builder: (BuildContext context, _) {
        final StationBatch? batch = station.batch;
        return ColoredBox(
          color: c.bgCanvas,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TopBar.task(onClose: batch != null ? station.finish : null, title: batch?.batchCode ?? l10n.stationTitle),
              if (station.last case final StationOutcome last) _OutcomeBanner(outcome: last),
              Expanded(
                child: batch == null ? _BatchList(station: station) : _Run(station: station),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BatchList extends StatelessWidget {
  const _BatchList({required this.station});

  final StationController station;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final WaiterLayout layout = context.layout;
    final List<StationBatch>? batches = station.batches;
    final StationFailure? failure = station.loadFailure;
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: Space.s4),
      children: <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(horizontal: layout.margin),
          child: ScaledText(l10n.stationChoose, type: TypeTokens.titleM),
        ),
        const SizedBox(height: Space.s2),
        if (station.loading && batches == null)
          const Padding(
            padding: EdgeInsets.all(Space.s6),
            child: Center(child: Spinner()),
          )
        else if (failure != null)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: layout.margin),
            child: StatusBanner(
              tone: BannerTone.warning,
              title: failure == StationFailure.offline ? l10n.offlineTitle : l10n.stationFailed,
              actionLabel: l10n.commonTryAgain,
              onAction: station.load,
            ),
          )
        else if (batches != null && batches.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: layout.margin, vertical: Space.s4),
            child: ScaledText(l10n.stationEmpty, type: TypeTokens.bodyM, color: context.colors.fgSecondary),
          )
        else
          for (final StationBatch b in batches ?? const <StationBatch>[])
            SheetRow(
              label: b.restaurant,
              caption: b.batchCode,
              value: l10n.stationBatch(b.qaPassed),
              showDivider: b != batches!.last,
              onPressed: () => station.choose(b),
            ),
        const SizedBox(height: Space.s6),
        Center(
          child: TertiaryButton(label: l10n.menuSignOut, onPressed: context.services.session.signOut),
        ),
      ],
    );
  }
}

class _Run extends StatelessWidget {
  const _Run({required this.station});

  final StationController station;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final WaiterColors c = context.colors;
    final bool working = station.phase == StationPhase.working;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.layout.margin),
      child: Column(
        children: <Widget>[
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  ExcludeSemantics(
                    child: WaiterIconView.mark(
                      WaiterIcon.nfcArcs,
                      dimension: 96,
                      strokeWidth: 4,
                      color: working ? c.info : c.fgSecondary,
                    ),
                  ),
                  const SizedBox(height: Space.s6),
                  Semantics(
                    liveRegion: true,
                    child: working
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Spinner(color: c.fgPrimary),
                              const SizedBox(width: Space.s2),
                              Flexible(child: ScaledText(l10n.stationWorking, type: TypeTokens.bodyM)),
                            ],
                          )
                        : ScaledText(l10n.stationWaiting, type: TypeTokens.bodyL, textAlign: TextAlign.center),
                  ),
                  const SizedBox(height: Space.s4),
                  ScaledText(l10n.stationBatch(station.finished), type: TypeTokens.bodyM, color: c.fgSecondary),
                ],
              ),
            ),
          ),
          SecondaryButton(label: l10n.stationFinish, onPressed: station.finish),
          const SizedBox(height: Space.s6),
        ],
      ),
    );
  }
}

class _OutcomeBanner extends StatelessWidget {
  const _OutcomeBanner({required this.outcome});

  final StationOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String? number = outcome.cardNumber;
    final String? code = outcome.detail == null ? null : 'Code: ${outcome.detail}';
    if (number != null) {
      return StatusBanner(tone: BannerTone.success, title: l10n.stationDone(number));
    }
    return switch (outcome.failure!) {
      StationFailure.rejected => StatusBanner(tone: BannerTone.danger, title: l10n.stationRejected, body: code),
      StationFailure.unknownChip => StatusBanner(tone: BannerTone.danger, title: l10n.stationUnknownChip, body: code),
      StationFailure.nfcOff => StatusBanner(
        tone: BannerTone.warning,
        title: l10n.problemNfcOffTitle,
        body: l10n.problemNfcOffBody,
      ),
      StationFailure.nfcUnsupported => StatusBanner(
        tone: BannerTone.warning,
        title: l10n.problemNfcUnsupportedTitle,
        body: l10n.problemNfcUnsupportedBody,
      ),
      StationFailure.offline => StatusBanner(
        tone: BannerTone.warning,
        title: l10n.offlineTitle,
        body: l10n.stationFailed,
      ),
      StationFailure.tagLost ||
      StationFailure.refused ||
      StationFailure.server => StatusBanner(tone: BannerTone.warning, title: l10n.stationFailed, body: code),
    };
  }
}
