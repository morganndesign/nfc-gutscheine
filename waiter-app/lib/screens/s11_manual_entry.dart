import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../app/app_scope.dart';
import '../components/components.dart';
import '../components/support/announce.dart';
import '../core/api/waiter_api.dart';
import '../core/format/format.dart';
import '../core/state/loop_controller.dart';
import '../core/state/loop_state.dart';
import '../core/theme/theme.dart';
import '../l10n/app_localizations.dart';

/// How long the paste error stays (03a §7 States).
const Duration _pasteErrorLifetime = Duration(seconds: 3);

/// Two-pane S11 on tablets in landscape from this window width (08 §4.3).
const double _twoPaneMinWidth = 856;

/// Gutter between the two panes (08 §4.2).
const double _paneGutter = 32;

/// S11 · Manual entry (03a §7): the 16-digit card number via the app keypad
/// only — the OS keyboard never appears. Hardware keyboards: digits,
/// Backspace, Enter (= submit at 16) and Cmd/Ctrl + V (08 §7).
///
/// The typed digits are transient UI state; the lookup itself is the loop's
/// `LookingUpState(method: manual)`, during which the button shows the
/// spinner and the keypad ignores input at full colour.
class ManualEntryScreen extends StatefulWidget {
  /// Creates the screen.
  const ManualEntryScreen({super.key});

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  CardNumberEntry? _entry;
  String? _pasteError;
  Timer? _pasteTimer;
  final ShakeController _shake = ShakeController();
  LoopController? _listened;
  LoopState? _previous;

  /// 422 on the lookup (E19): `manual.error.invalid` until the next edit.
  bool _invalid = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Restored digits after L02 "Edit number" (03a §7).
    _entry ??= switch (context.services.loop.state) {
      ManualEntryState(:final String prefill) => CardNumberEntry.of(prefill),
      LookingUpState(:final ScanRequest request) => CardNumberEntry.of(
        request.cardNumber ?? '',
      ),
      _ => CardNumberEntry.empty,
    };
    if (_listened == null) {
      final LoopController loop = context.services.loop;
      _listened = loop;
      _previous = loop.state;
      loop.addListener(_onLoop);
    }
  }

  /// The number was rejected (422): red field, error shake, digits kept;
  /// the loop plays `haptic.error` (03a §7, 11 E19).
  void _onLoop() {
    final LoopState state = _listened!.state;
    final LoopState? previous = _previous;
    _previous = state;
    if (state is ManualEntryState &&
        state.invalid &&
        previous is LookingUpState) {
      setState(() => _invalid = true);
      _shake.shake();
      announce(
        context,
        AppLocalizations.of(context).manualErrorInvalid,
        assertive: true,
      );
    }
  }

  @override
  void dispose() {
    _listened?.removeListener(_onLoop);
    _pasteTimer?.cancel();
    _shake.dispose();
    super.dispose();
  }

  LoopController get _loop => context.services.loop;

  bool get _lookingUp => switch (_loop.state) {
    LookingUpState(:final LookupOrigin origin) => origin == LookupOrigin.manual,
    _ => false,
  };

  // ------------------------------------------------------------------ input

  EntryOutcome _apply(EntryChange<CardNumberEntry> change) {
    if (_lookingUp) return EntryOutcome.ignored;
    switch (change.outcome) {
      case EntryOutcome.rejectedAtLimit:
        // 17th digit: ±3-pt limit nudge (13 · R18); the keypad plays the warning.
        _shake.nudge();
      case EntryOutcome.accepted ||
          EntryOutcome.deleted ||
          EntryOutcome.cleared:
        final bool completes = !_entry!.isComplete && change.value.isComplete;
        setState(() {
          _entry = change.value;
          _clearPasteError();
          _invalid = false;
        });
        // E18: `haptic.select` on the 16th digit (outranks the key tick).
        if (completes) context.services.feedback.haptic(HapticToken.select);
      case EntryOutcome.ignored || EntryOutcome.pasteRejected:
        break;
    }
    return change.outcome;
  }

  EntryOutcome _digit(int digit) => _apply(_entry!.digit(digit));

  EntryOutcome _backspace() => _apply(_entry!.backspace());

  EntryOutcome _clear() => _apply(_entry!.clear());

  /// Paste rule (03a §7): exactly 16 digits after stripping, else the field
  /// stays unchanged and `manual.error.paste` shows for 3 s.
  void _paste(String text) {
    if (_lookingUp) return;
    final EntryChange<CardNumberEntry> change = _entry!.paste(text);
    if (change.outcome == EntryOutcome.pasteRejected) {
      _pasteTimer?.cancel();
      setState(
        () => _pasteError = AppLocalizations.of(context).manualErrorPaste,
      );
      _pasteTimer = Timer(_pasteErrorLifetime, () {
        if (mounted) setState(_clearPasteError);
      });
      return;
    }
    _apply(change);
  }

  Future<void> _pasteFromClipboard() async {
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    final String? text = data?.text;
    if (text != null && mounted) _paste(text);
  }

  void _clearPasteError() {
    _pasteTimer?.cancel();
    _pasteTimer = null;
    _pasteError = null;
  }

  void _submit() {
    final CardNumberEntry entry = _entry!;
    if (!entry.isComplete || !_loop.isOnline || _lookingUp) return;
    _loop.submitManual(entry.digits);
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final LoopController loop = _loop;
    return ListenableBuilder(
      listenable: loop,
      builder: (BuildContext context, _) {
        final LoopState state = loop.state;
        final bool lookingUp = _lookingUp;
        final bool slow = lookingUp && state is LookingUpState && state.slow;
        final bool online = loop.isOnline;
        final CardNumberEntry entry = _entry!;
        final AppLocalizations l10n = AppLocalizations.of(context);
        final WaiterLayout layout = context.layout;

        final Widget field = _FieldBlock(
          entry: entry,
          error: _pasteError ?? (_invalid ? l10n.manualErrorInvalid : null),
          loading: lookingUp,
          slow: slow,
          online: online,
          shake: _shake,
          onPaste: _paste,
          onCancel: loop.back,
        );
        final Widget keypad = Keypad(
          variant: KeypadVariant.cardNumber,
          autofocus: true,
          onDigit: _digit,
          onBackspace: _backspace,
          onClear: _clear,
        );
        final Widget submit = PrimaryButton(
          label: l10n.manualSubmit,
          semanticLabel: lookingUp ? l10n.scanLookingUp : null,
          status: lookingUp ? ButtonStatus.loading : ButtonStatus.idle,
          onPressed: entry.isComplete && online ? _submit : null,
          disabledReason: online
              ? l10n.manualCounter(entry.count)
              : l10n.offlineTitle,
        );

        final bool tablet = layout.widthClass.isTablet;
        final bool twoPane =
            tablet &&
            layout.size.width >= _twoPaneMinWidth &&
            layout.size.width > layout.size.height;
        final EdgeInsets padding = EdgeInsets.fromLTRB(
          layout.margin,
          0,
          layout.margin,
          layout.viewPadding.bottom + layout.ctaBottomPadding,
        );

        final Widget body;
        if (twoPane) {
          body = Padding(
            padding: padding,
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Center(child: SingleChildScrollView(child: field)),
                ),
                const SizedBox(width: _paneGutter),
                SizedBox(
                  width: LayoutTokens.maxKeypad,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      keypad,
                      const SizedBox(height: Space.s4),
                      submit,
                    ],
                  ),
                ),
              ],
            ),
          );
        } else if (tablet) {
          // 03a §7: centred 400-pt column, button directly below the keypad.
          body = Center(
            child: SingleChildScrollView(
              padding: padding,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: LayoutTokens.maxForm,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    field,
                    const SizedBox(height: Space.s10),
                    keypad,
                    const SizedBox(height: Space.s4),
                    submit,
                  ],
                ),
              ),
            ),
          );
        } else {
          // Phones: the informational region scrolls, keypad and button stay
          // pinned in the thumb zone (07 §6.2).
          body = Padding(
            padding: padding,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: LayoutTokens.maxForm,
                ),
                child: Column(
                  children: <Widget>[
                    Expanded(child: SingleChildScrollView(child: field)),
                    const SizedBox(height: Space.s4),
                    keypad,
                    const SizedBox(height: Space.s4),
                    submit,
                  ],
                ),
              ),
            ),
          );
        }

        return CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            const SingleActivator(LogicalKeyboardKey.enter): _submit,
            const SingleActivator(LogicalKeyboardKey.numpadEnter): _submit,
            const SingleActivator(LogicalKeyboardKey.keyV, control: true): () =>
                unawaited(_pasteFromClipboard()),
            const SingleActivator(LogicalKeyboardKey.keyV, meta: true): () =>
                unawaited(_pasteFromClipboard()),
          },
          child: ColoredBox(
            color: context.colors.bgCanvas,
            child: Column(
              children: <Widget>[
                TopBar.task(onClose: loop.back, title: l10n.manualTitle),
                Expanded(child: body),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Helper, CardNumberField and the counter / status row (03a §7).
class _FieldBlock extends StatelessWidget {
  const _FieldBlock({
    required this.entry,
    required this.error,
    required this.loading,
    required this.slow,
    required this.online,
    required this.shake,
    required this.onPaste,
    required this.onCancel,
  });

  final CardNumberEntry entry;

  /// Paste or 422 error; replaces the counter row.
  final String? error;
  final bool loading;
  final bool slow;
  final bool online;
  final ShakeController shake;
  final ValueChanged<String> onPaste;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final WaiterColors c = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: Space.s6),
        ScaledText(
          l10n.manualHelper,
          type: TypeTokens.caption,
          color: c.fgSecondary,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Space.s2),
        CardNumberField(
          digits: entry.digits,
          errorText: error,
          loading: loading,
          onPaste: onPaste,
          shakeController: shake,
        ),
        AnimatedSwitcher(
          duration: Motion.durationFast,
          switchInCurve: Motion.easeStandard,
          switchOutCurve: Motion.easeStandard,
          child: KeyedSubtree(
            key: ValueKey<String>(
              slow
                  ? 'slow'
                  : error != null
                  ? 'error'
                  : !online
                  ? 'offline'
                  : entry.isComplete
                  ? 'complete'
                  : 'counter',
            ),
            child: _statusRow(context, l10n, c),
          ),
        ),
      ],
    );
  }

  Widget _statusRow(
    BuildContext context,
    AppLocalizations l10n,
    WaiterColors c,
  ) {
    if (error != null && !slow) return const SizedBox.shrink();
    if (slow) {
      // > 3 s: `scan.slow` under the field; Cancel replaces the counter row.
      return Row(
        children: <Widget>[
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: ScaledText(
                l10n.scanSlow,
                type: TypeTokens.caption,
                color: c.fgSecondary,
              ),
            ),
          ),
          TertiaryButton(label: l10n.commonCancel, onPressed: onCancel),
        ],
      );
    }
    if (!online) {
      return Padding(
        padding: const EdgeInsets.only(top: Space.s2),
        child: Semantics(
          liveRegion: true,
          child: Row(
            children: <Widget>[
              WaiterIconView(
                WaiterIcon.info,
                size: IconSize.s16,
                color: c.info,
              ),
              const SizedBox(width: Space.s1),
              Flexible(
                child: ScaledText(
                  l10n.offlineTitle,
                  type: TypeTokens.caption,
                  color: c.info,
                ),
              ),
            ],
          ),
        ),
      );
    }
    final bool complete = entry.isComplete;
    final Color color = complete ? c.success : c.fgTertiary;
    return Padding(
      padding: const EdgeInsets.only(top: Space.s2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          if (complete) ...<Widget>[
            WaiterIconView(WaiterIcon.check, size: IconSize.s16, color: color),
            const SizedBox(width: Space.s1),
          ],
          ScaledText(
            l10n.manualCounter(entry.count),
            type: TypeTokens.caption,
            color: color,
          ),
        ],
      ),
    );
  }
}
