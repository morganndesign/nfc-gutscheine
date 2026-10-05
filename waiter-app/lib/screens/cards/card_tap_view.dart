import 'package:flutter/widgets.dart';

import '../../components/components.dart';
import '../../core/cards/card_presenter.dart';
import '../../core/theme/theme.dart';
import '../../l10n/app_localizations.dart';

/// The "hold the card to the phone" view of card desk steps (sale, delivery, replacement): the NFC mark, the
/// instruction, and "checking" once the card is on the phone. On iPhone the system sheet covers it.
class CardTapView extends StatelessWidget {
  const CardTapView({required this.instruction, required this.checking, super.key});

  final String instruction;
  final bool checking;

  @override
  Widget build(BuildContext context) {
    final WaiterColors c = context.colors;
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: context.layout.margin),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: LayoutTokens.maxForm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ExcludeSemantics(
                child: WaiterIconView.mark(
                  WaiterIcon.nfcArcs,
                  dimension: 96,
                  strokeWidth: 4,
                  color: checking ? c.info : c.fgSecondary,
                ),
              ),
              const SizedBox(height: Space.s6),
              Semantics(
                liveRegion: true,
                child: checking
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Spinner(color: c.fgPrimary),
                          const SizedBox(width: Space.s2),
                          Flexible(child: ScaledText(l10n.cardChecking, type: TypeTokens.bodyM)),
                        ],
                      )
                    : ScaledText(instruction, type: TypeTokens.bodyL, textAlign: TextAlign.center, maxLines: 3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Title and body for a card that could not be presented.
({ProblemFamily family, String title, String body}) cardFailureTexts(
  AppLocalizations l10n,
  CardPresentException e, {
  required String notUsableTitle,
  required String notUsableBody,
}) => switch (e.failure) {
  CardPresentFailure.notUsable => (family: ProblemFamily.verification, title: notUsableTitle, body: notUsableBody),
  CardPresentFailure.moved || CardPresentFailure.cancelled => (
    family: ProblemFamily.verification,
    title: l10n.problemCardMovedTitle,
    body: l10n.problemCardMovedBody,
  ),
  CardPresentFailure.notRecognized => (
    family: ProblemFamily.notFound,
    title: l10n.problemCardNotRecognizedTitle,
    body: l10n.problemCardNotRecognizedBody,
  ),
  CardPresentFailure.unverified => (
    family: ProblemFamily.verification,
    title: l10n.problemCardUnverifiedTitle,
    body: l10n.problemCardUnverifiedBody,
  ),
  CardPresentFailure.nfcOff => (
    family: ProblemFamily.account,
    title: l10n.problemNfcOffTitle,
    body: l10n.problemNfcOffBody,
  ),
  CardPresentFailure.unsupported => (
    family: ProblemFamily.account,
    title: l10n.problemNfcUnsupportedTitle,
    body: l10n.problemNfcUnsupportedBody,
  ),
  CardPresentFailure.network => (family: ProblemFamily.network, title: l10n.offlineTitle, body: l10n.offlineBody),
  CardPresentFailure.throttled ||
  CardPresentFailure.server ||
  CardPresentFailure.forbidden => (family: ProblemFamily.server, title: notUsableTitle, body: l10n.cardsFailed),
};
