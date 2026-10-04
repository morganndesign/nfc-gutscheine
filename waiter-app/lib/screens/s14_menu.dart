import 'dart:async';

import 'package:flutter/material.dart' show MaterialPageRoute;
import 'package:flutter/widgets.dart';

import '../app/app_scope.dart';
import '../components/components.dart';
import '../components/support/text_emphasis.dart';
import '../core/api/api_failure.dart';
import '../core/api/models.dart';
import '../core/state/session_state.dart';
import '../core/storage/settings_store.dart';
import '../core/theme/theme.dart';
import '../l10n/app_localizations.dart';
import 'cards/s22_receive_delivery.dart';
import 'cards/s25_order_cards.dart';
import 'cards/s23_card_lookup.dart';
import 'scan/sheet_rows.dart';

/// Gap between the account header and the text column (Avatar → name).
const double _headerGap = Space.s4;

/// Minimum height of the account header (03a §9).
const double _headerHeight = 72;

/// S14 · Menu (03a §9): account, restaurant, device, cards (managers and
/// owners: confirm a delivery, find a card), appearance, sounds, haptics,
/// keep screen on, sign out and version.
Future<void> showMenuSheet(BuildContext context) => showWaiterSheet<void>(
  context: context,
  title: AppLocalizations.of(context).menuAccount,
  edgeToEdge: true,
  barrierLabel: AppLocalizations.of(context).menuClose,
  builder: (BuildContext sheetContext) => const _MenuBody(),
);

class _MenuBody extends StatefulWidget {
  const _MenuBody();

  @override
  State<_MenuBody> createState() => _MenuBodyState();
}

class _MenuBodyState extends State<_MenuBody> {
  /// The device name as registered by the backend, loaded once per opening.
  Future<String?>? _deviceName;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _deviceName ??= context.services.session.currentDeviceName();
  }

  AppServices get _services => context.services;

  /// E61–E63: `haptic.select` on every toggle; turning Sounds on plays the
  /// `sound.cardDetected` sample, turning Haptics on the select preview,
  /// turning Haptics off nothing (11 §3.6).
  void _toggleSound(bool on) {
    _services.settings.sound = on;
    _services.feedback.haptic(HapticToken.select);
    if (on) _services.feedback.sound(SoundToken.cardDetected);
  }

  void _toggleHaptics(bool on) {
    _services.settings.haptics = on;
    if (on) _services.feedback.haptic(HapticToken.select);
  }

  void _toggleKeepScreenOn(bool on) {
    _services.settings.keepScreenOn = on;
    _services.feedback.haptic(HapticToken.select);
  }

  Future<void> _chooseLanguage() => showWaiterSheet<void>(
    context: context,
    title: AppLocalizations.of(context).menuLanguage,
    edgeToEdge: true,
    builder: (BuildContext sheetContext) => const _LanguageChoice(),
  );

  Future<void> _chooseTheme() => showWaiterSheet<void>(
    context: context,
    title: AppLocalizations.of(context).menuTheme,
    edgeToEdge: true,
    builder: (BuildContext sheetContext) => const _ThemeChoice(),
  );

  /// Closes the menu and opens a card desk screen above S05.
  void _open(Widget screen) {
    final NavigatorState navigator = Navigator.of(context);
    navigator.pop();
    unawaited(navigator.push<void>(MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => screen)));
  }

  /// Sign out always asks (03a §9); confirm clears token, Recent and pending
  /// links, online or offline, and lands on S02.
  Future<void> _signOut() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final DialogChoice choice = await showWaiterDialog(
      context: context,
      title: l10n.menuSignOutConfirmTitle,
      body: l10n.menuSignOutConfirmBody,
      confirmLabel: l10n.menuSignOutConfirmAction,
      cancelLabel: l10n.commonCancel,
      destructive: true,
    );
    if (choice != DialogChoice.confirm || !mounted) return;
    final AppServices services = _services;
    Navigator.of(context).pop();
    await services.session.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final WaiterColors c = context.colors;
    final double margin = context.layout.margin;
    final AppServices services = _services;
    final SessionUser? user = services.session.user;
    final SettingsStore settings = services.settings;

    return ListenableBuilder(
      listenable: settings,
      builder: (BuildContext context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _AccountHeader(name: user?.name ?? '', email: user?.email ?? ''),
          const SizedBox(height: Space.s2),
          SheetRow(
            label: l10n.menuRestaurant,
            value: user?.restaurant?.name ?? '',
          ),
          FutureBuilder<String?>(
            future: _deviceName,
            builder: (BuildContext context, AsyncSnapshot<String?> snapshot) {
              final String? device = snapshot.data;
              if (device == null) return const SizedBox.shrink();
              return SheetRow(
                label: l10n.menuDevice,
                value: device,
                showDivider: false,
              );
            },
          ),
          if ((user?.canReceiveCards ?? false) || (user?.canManageCards ?? false)) ...<Widget>[
            const SizedBox(height: Space.s6),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: margin),
              child: Semantics(
                header: true,
                child: ScaledText(l10n.menuCards, type: TypeTokens.overline, color: c.fgTertiary),
              ),
            ),
            const SizedBox(height: Space.s2),
            if (user?.canReceiveCards ?? false) ...<Widget>[
              // Whoever confirms deliveries orders them too (decision 2026-10-04).
              SheetRow(
                label: l10n.menuCardsOrder,
                trailing: WaiterIconView(WaiterIcon.chevronRight, size: IconSize.s16, color: c.fgTertiary),
                onPressed: () => _open(const OrderCardsScreen()),
              ),
              SheetRow(
                label: l10n.menuCardsReceive,
                trailing: WaiterIconView(WaiterIcon.chevronRight, size: IconSize.s16, color: c.fgTertiary),
                onPressed: () => _open(const ReceiveDeliveryScreen()),
                showDivider: user?.canManageCards ?? false,
              ),
            ],
            if (user?.canManageCards ?? false)
              SheetRow(
                label: l10n.menuCardsFind,
                trailing: WaiterIconView(WaiterIcon.chevronRight, size: IconSize.s16, color: c.fgTertiary),
                onPressed: () => _open(const CardLookupScreen()),
                showDivider: false,
              ),
          ],
          const SizedBox(height: Space.s6),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: margin),
            child: Semantics(
              header: true,
              child: ScaledText(
                l10n.menuSectionSettings,
                type: TypeTokens.overline,
                color: c.fgTertiary,
              ),
            ),
          ),
          const SizedBox(height: Space.s2),
          SheetRow(
            label: l10n.menuLanguage,
            value: languageName(Localizations.localeOf(context).languageCode),
            trailing: WaiterIconView(WaiterIcon.chevronRight, size: IconSize.s16, color: c.fgTertiary),
            onPressed: () => unawaited(_chooseLanguage()),
          ),
          SheetRow(
            label: l10n.menuTheme,
            value: _themeLabel(l10n, settings.theme),
            trailing: WaiterIconView(
              WaiterIcon.chevronRight,
              size: IconSize.s16,
              color: c.fgTertiary,
            ),
            onPressed: () => unawaited(_chooseTheme()),
          ),
          SheetRow(
            label: l10n.menuSound,
            toggled: settings.sound,
            trailing: SheetSwitch(value: settings.sound),
            onPressed: () => _toggleSound(!settings.sound),
          ),
          SheetRow(
            label: l10n.menuHaptics,
            toggled: settings.haptics,
            trailing: SheetSwitch(value: settings.haptics),
            onPressed: () => _toggleHaptics(!settings.haptics),
          ),
          SheetRow(
            label: l10n.menuKeepScreenOn,
            caption: l10n.menuKeepScreenOnCaption,
            toggled: settings.keepScreenOn,
            trailing: SheetSwitch(value: settings.keepScreenOn),
            onPressed: () => _toggleKeepScreenOn(!settings.keepScreenOn),
            showDivider: false,
          ),
          const SizedBox(height: Space.s2),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: margin),
            child: ScaledText(
              l10n.menuSunlightTip,
              type: TypeTokens.caption,
              color: c.fgTertiary,
            ),
          ),
          const SizedBox(height: Space.s6),
          SheetRow(
            label: l10n.menuSignOut,
            labelColor: c.danger,
            emphasised: true,
            onPressed: () => unawaited(_signOut()),
            showDivider: false,
          ),
          const SizedBox(height: Space.s4),
          ScaledText(
            l10n.menuVersion(
              '${services.appVersion} (${services.buildNumber})',
            ),
            type: TypeTokens.caption,
            color: c.fgTertiary,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

String _themeLabel(AppLocalizations l10n, ThemePreference theme) =>
    switch (theme) {
      ThemePreference.system => l10n.menuThemeSystem,
      ThemePreference.light => l10n.menuThemeLight,
      ThemePreference.dark => l10n.menuThemeDark,
    };

/// Who is signed in (03a §9): Avatar, name `type.body.l` 600 and e-mail
/// `type.body.m` `fg.secondary`, each up to 2 lines (04 §3).
class _AccountHeader extends StatelessWidget {
  const _AccountHeader({required this.name, required this.email});

  final String name;
  final String email;

  @override
  Widget build(BuildContext context) {
    final WaiterTheme theme = context.waiter;
    return MergeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _headerHeight),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: context.layout.margin),
          child: Row(
            children: <Widget>[
              Avatar(name: name, size: AvatarSize.large),
              const SizedBox(width: _headerGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    ScaledText.rich(
                      (ScaledStyles s) => TextSpan(
                        text: name,
                        style: s(
                          TypeTokens.bodyL,
                        ).semiBold(boldText: theme.boldText),
                      ),
                      type: TypeTokens.bodyL,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    ScaledText(
                      email,
                      type: TypeTokens.bodyM,
                      color: theme.colors.fgSecondary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Nested appearance sheet (03a §9): Match system · Light · Dark; the
/// choice applies live (the theme scope cross-fades) and closes the sheet.
class _ThemeChoice extends StatelessWidget {
  const _ThemeChoice();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppServices services = context.services;
    final ThemePreference current = services.settings.theme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final ThemePreference option in ThemePreference.values)
          SheetRow(
            label: _themeLabel(l10n, option),
            toggled: option == current,
            trailing: option == current
                ? WaiterIconView(WaiterIcon.check)
                : null,
            showDivider: option != ThemePreference.values.last,
            onPressed: () {
              services.settings.theme = option;
              services.feedback.haptic(HapticToken.select);
              Navigator.of(context).pop();
            },
          ),
      ],
    );
  }
}

/// The account languages, each in its own language (never translated).
const List<(String, String)> accountLanguages = <(String, String)>[
  ('de', 'Deutsch'),
  ('en', 'English'),
  ('bs', 'Bosanski · Hrvatski · Srpski'),
];

/// The endonym of a language code (`hr`/`sr` count as `bs`).
String languageName(String code) {
  final String key = code == 'hr' || code == 'sr' ? 'bs' : code;
  return accountLanguages.firstWhere(((String, String) l) => l.$1 == key, orElse: () => accountLanguages.first).$2;
}

/// Nested language sheet: saves the account's language (the dashboard follows), the app switches at once.
class _LanguageChoice extends StatefulWidget {
  const _LanguageChoice();

  @override
  State<_LanguageChoice> createState() => _LanguageChoiceState();
}

class _LanguageChoiceState extends State<_LanguageChoice> {
  String? _saving;

  Future<void> _choose(String code) async {
    final AppServices services = context.services;
    final SnackbarController? snackbar = SnackbarHost.maybeOf(context);
    final String failed = AppLocalizations.of(context).menuLanguageFailed;
    setState(() => _saving = code);
    services.feedback.haptic(HapticToken.select);
    try {
      await services.api.setLanguage(code);
      await services.session.refreshUser();
      if (mounted) Navigator.of(context).pop();
    } on ApiFailure catch (e) {
      // Signed out elsewhere, device revoked, restaurant suspended: the session sheet or S15, like every request.
      if (services.session.handleFailure(e, SessionContext.lookup)) {
        if (mounted) setState(() => _saving = null);
        return;
      }
      snackbar?.show(SnackbarData(message: failed));
      if (mounted) setState(() => _saving = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String current = Localizations.localeOf(context).languageCode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final (String code, String name) in accountLanguages)
          SheetRow(
            label: name,
            toggled: languageName(current) == name,
            trailing: _saving == code
                ? const Spinner()
                : languageName(current) == name
                ? WaiterIconView(WaiterIcon.check)
                : null,
            showDivider: code != accountLanguages.last.$1,
            onPressed: _saving == null ? () => unawaited(_choose(code)) : null,
          ),
      ],
    );
  }
}
