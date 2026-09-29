import 'package:flutter/widgets.dart';

import '../app/app_scope.dart';
import '../components/components.dart';
import '../core/state/loop_controller.dart';
import '../core/state/loop_state.dart';
import '../core/theme/theme.dart';
import '../l10n/app_localizations.dart';

/// S11 · Tap card: the guest's card is held to the phone. On Android this
/// screen is the whole prompt; on iPhone the system sheet covers it and this
/// screen shows what happens underneath. The phone only relays: the server
/// challenges the card.
class CardTapScreen extends StatelessWidget {
  const CardTapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final LoopController loop = context.services.loop;
    final AppLocalizations l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: loop,
      builder: (BuildContext context, _) {
        final LoopState state = loop.state;
        final CardTapState tap = state is CardTapState ? state : const CardTapState();
        final WaiterColors c = context.colors;
        final WaiterLayout layout = context.layout;
        final bool checking = tap.phase == CardTapPhase.checking;
        return ColoredBox(
          color: c.bgCanvas,
          child: Column(
            children: <Widget>[
              TopBar.task(onClose: loop.back, title: l10n.cardTitle),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: layout.margin),
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
                            child: AnimatedSwitcher(
                              duration: Motion.durationFast,
                              child: checking
                                  ? Row(
                                      key: ValueKey<bool>(tap.slow),
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        Spinner(color: c.fgPrimary),
                                        const SizedBox(width: Space.s2),
                                        Flexible(
                                          child: ScaledText(
                                            tap.slow ? l10n.cardSlow : l10n.cardChecking,
                                            type: TypeTokens.bodyM,
                                          ),
                                        ),
                                      ],
                                    )
                                  : ScaledText(
                                      l10n.cardWaiting,
                                      key: const ValueKey<String>('waiting'),
                                      type: TypeTokens.bodyL,
                                      textAlign: TextAlign.center,
                                      maxLines: 3,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
