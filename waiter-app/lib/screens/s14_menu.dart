import 'dart:async';

import 'package:flutter/widgets.dart';

import '../app/app_scope.dart';
import '../components/components.dart';
import '../components/support/text_emphasis.dart';
import '../core/api/models.dart';
import '../core/storage/settings_store.dart';
import '../core/theme/theme.dart';
import '../l10n/app_localizations.dart';
import 'scan/sheet_rows.dart';

/// Gap between the account header and the text column (Avatar → name).
const double _headerGap = Space.s4;

/// Minimum height of the account header (03a §9).
const double _headerHeight = 72;

/// S14 · Menu (03a §9): account, restaurant, device, appearance, sounds,
/// haptics, keep screen on, sign out and version. Deliberately short —
/// nothing here affects cards or money. Android reader mode is paused while
/// it is open (09 §5).
Future<void> showMenuSheet(BuildContext context) async {
  final AppServices services = context.services;
  services.loop.setSheetOpen(true);
  try {
    await showWaiterSheet<void>(
      context: context,
      title: AppLocalizations.of(context).menuAccount,
      edgeToEdge: true,
      barrierLabel: AppLocalizations.of(context).menuClose,
      builder: (BuildContext sheetContext) => const _MenuBody(),
    );
  } finally {
    services.loop.setSheetOpen(false);
  }
}

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

  Future<void> _chooseTheme() => showWaiterSheet<void>(
    context: context,
    title: AppLocalizations.of(context).menuTheme,
    edgeToEdge: true,
    builder: (BuildContext sheetContext) => const _ThemeChoice(),
  );

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
