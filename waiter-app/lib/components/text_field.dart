import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/theme.dart';
import '../l10n/app_localizations.dart';
import 'icon_button.dart';
import 'support/announce.dart';
import 'support/field_parts.dart';
import 'support/shake.dart';

/// Content kinds of [WaiterTextField] (05 §2.4 behaviour).
enum TextFieldKind {
  /// E-mail keyboard, no autocorrect or capitalisation, whitespace removed,
  /// autofill "username"/"email", Return = Next, max 254.
  email,

  /// Secure entry with a visibility toggle, autofill "password", Return =
  /// done (the screen signs in), max 128.
  password,

  /// Server address (development and staging builds only): URL keyboard,
  /// no autocorrect, whitespace removed, Return = done, max 512.
  url,
}

/// E-mail and password entry (05 §2.4). Named `WaiterTextField` because
/// Material's `TextField` would collide in screens.
///
/// Label above (never floating), 56-pt container, `radius.s`, `bg.surface`,
/// 1 pt `color.border.control` (13 · R06), focused 2 pt `color.focus.ring`
/// inner stroke (13 · R17), error 2 pt `color.danger` with an icon + text
/// line below. Validation is the screen's job (on submit only); when
/// [errorText] appears it is announced assertively. [shakeController]
/// runs the field error shake (240 ms, ±6 pt, 2 cycles — 13 · R18); the
/// label, container and message move as one unit.
class WaiterTextField extends StatefulWidget {
  /// Creates a field.
  const WaiterTextField({
    required this.kind,
    required this.label,
    required this.controller,
    super.key,
    this.focusNode,
    this.placeholder,
    this.errorText,
    this.helperText,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
    this.shakeController,
  });

  /// Content kind.
  final TextFieldKind kind;

  /// Visible label (`signIn.emailLabel`, `signIn.passwordLabel`).
  final String label;

  /// Text controller.
  final TextEditingController controller;

  /// Focus node.
  final FocusNode? focusNode;

  /// Placeholder in `fg.tertiary` (never repeats the label).
  final String? placeholder;

  /// Error text; `null` = no error.
  final String? errorText;

  /// Helper text.
  final String? helperText;

  /// `false` renders the disabled look (`bg.key`, no border).
  final bool enabled;

  /// Not editable but not greyed — S02 while signing in (03a §2 "fields
  /// read-only (not greyed)"). Keeps the resting look.
  final bool readOnly;

  /// Whether the field takes focus on first build.
  final bool autofocus;

  /// Every edit (the screen clears the error here).
  final ValueChanged<String>? onChanged;

  /// Return key.
  final ValueChanged<String>? onSubmitted;

  /// Field error shake trigger.
  final ShakeController? shakeController;

  @override
  State<WaiterTextField> createState() => _WaiterTextFieldState();
}

class _WaiterTextFieldState extends State<WaiterTextField> {
  FocusNode? _ownFocus;
  bool _obscured = true;

  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  /// 05 §2.4 max lengths.
  static const int _maxEmail = 254;
  static const int _maxUrl = 512;
  static const int _maxPassword = 128;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(WaiterTextField old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      (old.focusNode ?? _ownFocus)?.removeListener(_onFocus);
      _focus.addListener(_onFocus);
    }
    final String? error = widget.errorText;
    if (error != null && error != old.errorText) {
      announce(context, error, assertive: true);
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _ownFocus?.dispose();
    super.dispose();
  }

  void _onFocus() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final WaiterColors c = context.colors;
    final WaiterTextStyles styles = context.textStyles;
    final bool password = widget.kind == TextFieldKind.password;
    final bool focused = _focus.hasFocus;
    final FieldTone tone = !widget.enabled
        ? FieldTone.disabled
        : widget.errorText != null
        ? FieldTone.error
        : focused && !widget.readOnly
        ? FieldTone.focused
        : FieldTone.rest;
    final Color labelColor = !widget.enabled
        ? c.fgTertiary
        : focused && widget.errorText == null
        ? c.fgPrimary
        : c.fgSecondary;

    final Widget input = Material(
      type: MaterialType.transparency,
      child: Semantics(
        label: widget.label,
        child: TextField(
          controller: widget.controller,
          focusNode: _focus,
          enabled: widget.enabled,
          readOnly: widget.readOnly,
          autofocus: widget.autofocus,
          obscureText: password && _obscured,
          keyboardType: switch (widget.kind) {
            TextFieldKind.password => TextInputType.visiblePassword,
            TextFieldKind.email => TextInputType.emailAddress,
            TextFieldKind.url => TextInputType.url,
          },
          textInputAction: widget.kind == TextFieldKind.email
              ? TextInputAction.next
              : TextInputAction.done,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.none,
          autofillHints: switch (widget.kind) {
            TextFieldKind.password => const <String>[AutofillHints.password],
            TextFieldKind.email => const <String>[AutofillHints.username, AutofillHints.email],
            TextFieldKind.url => const <String>[AutofillHints.url],
          },
          inputFormatters: <TextInputFormatter>[
            if (!password) FilteringTextInputFormatter.deny(RegExp(r'\s')),
            LengthLimitingTextInputFormatter(
              switch (widget.kind) {
                TextFieldKind.password => _maxPassword,
                TextFieldKind.email => _maxEmail,
                TextFieldKind.url => _maxUrl,
              },
            ),
          ],
          style: styles.bodyL.copyWith(
            color: widget.enabled ? c.fgPrimary : c.fgTertiary,
          ),
          cursorColor: c.fgPrimary,
          keyboardAppearance: Theme.of(context).brightness,
          decoration: InputDecoration.collapsed(
            hintText: widget.placeholder,
            hintStyle: styles.bodyL.copyWith(color: c.fgTertiary),
          ),
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
        ),
      ),
    );

    return Shake(
      controller: widget.shakeController,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ExcludeSemantics(child: FieldLabel(widget.label, color: labelColor)),
          const SizedBox(height: TextFieldTokens.labelGap),
          FieldContainer(
            tone: tone,
            height: TextFieldTokens.height,
            child: Padding(
              padding: EdgeInsetsDirectional.only(
                start: TextFieldTokens.paddingHorizontal,
                end: password ? 0 : TextFieldTokens.paddingHorizontal,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(child: input),
                  if (password)
                    WaiterIconButton(
                      icon: WaiterIcon.eye,
                      toggledIcon: WaiterIcon.eyeOff,
                      toggled: !_obscured,
                      // "Show password, off/on" (05 §2.4): one label,
                      // the toggle state carries on/off.
                      semanticLabel: l10n.signInPasswordShow,
                      onPressed: widget.enabled
                          ? () => setState(() => _obscured = !_obscured)
                          : null,
                    ),
                ],
              ),
            ),
          ),
          FieldMessage(error: widget.errorText, helper: widget.helperText),
        ],
      ),
    );
  }
}
