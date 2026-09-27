import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../app/app_scope.dart';
import '../app/money.dart';
import '../components/components.dart';
import '../components/support/text_emphasis.dart';
import '../core/format/format.dart';
import '../core/state/loop_controller.dart';
import '../core/storage/recent_store.dart';
import '../core/theme/theme.dart';
import '../l10n/app_localizations.dart';
import 'scan/sheet_rows.dart';

/// Height of an hour header in the list (03b §6.3).
const double _hourHeaderHeight = 32;

/// Characters of the transaction id shown in the detail (12 §5.15).
const int _transactionIdChars = 6;

/// S13 · Recent (03b §6): the shift history of this device and waiter since
/// 04:00, newest first, grouped by clock hour in the restaurant time zone.
/// Opens at the medium detent from the S05 TopBar; Android reader mode is
/// paused while it is open (09 §5).
Future<void> showRecentSheet(BuildContext context) async {
  final LoopController loop = context.services.loop;
  loop.setSheetOpen(true);
  try {
    await showWaiterScrollSheet<void>(
      context: context,
      title: AppLocalizations.of(context).recentTitle,
      builder: (BuildContext sheetContext, ScrollController controller) =>
          _RecentBody(controller: controller),
    );
  } finally {
    loop.setSheetOpen(false);
  }
}

class _RecentBody extends StatelessWidget {
  const _RecentBody({required this.controller});

  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final RecentStore recent = context.services.recent;
    return ListenableBuilder(
      listenable: recent,
      builder: (BuildContext context, _) {
        final List<RecentEntry> entries = recent.entries;
        // 03b §6.4: a 04:00 clear while open fades the rows into the empty state.
        return AnimatedSwitcher(
          duration: Motion.durationBase,
          child: entries.isEmpty
              ? KeyedSubtree(
                  key: const ValueKey<String>('empty'),
                  child: _Empty(controller: controller),
                )
              : KeyedSubtree(
                  key: const ValueKey<String>('rows'),
                  child: _Rows(
                    controller: controller,
                    entries: entries,
                    total: recent.total,
                  ),
                ),
        );
      },
    );
  }
}

/// EmptyState (03b §6.4): also shown when the store could not be read.
class _Empty extends StatelessWidget {
  const _Empty({required this.controller});

  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return CustomScrollView(
      controller: controller,
      slivers: <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.layout.margin,
              vertical: Space.s6,
            ),
            child: EmptyState(
              illustration: WaiterIllustration.recentEmpty,
              title: l10n.recentEmptyTitle,
              body: l10n.recentEmptyBody,
              knockoutColor: context.colors.bgSurface,
            ),
          ),
        ),
      ],
    );
  }
}

/// HistoryCard (sticky, 08 §3.8) over the hour-grouped TransactionRows and
/// the footer.
class _Rows extends StatelessWidget {
  const _Rows({
    required this.controller,
    required this.entries,
    required this.total,
  });

  final ScrollController controller;
  final List<RecentEntry> entries;
  final int total;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final WaiterLayout layout = context.layout;
    final List<Widget> items = _items(context);
    return Column(
      children: <Widget>[
        Padding(
          padding: EdgeInsets.fromLTRB(
            layout.margin,
            0,
            layout.margin,
            Space.s4,
          ),
          child: HistoryCard(
            count: entries.length,
            totalCents: total,
            money: context.money,
            limitReached: entries.length >= RecentStore.maxRows,
          ),
        ),
        Expanded(
          child: ListView(
            controller: controller,
            padding: EdgeInsets.only(
              bottom: layout.viewPadding.bottom + Space.s4,
            ),
            children: <Widget>[
              ...items,
              Padding(
                padding: EdgeInsets.fromLTRB(
                  layout.margin,
                  Space.s3,
                  layout.margin,
                  0,
                ),
                child: ScaledText(
                  l10n.recentFooter,
                  type: TypeTokens.caption,
                  color: context.colors.fgTertiary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _items(BuildContext context) {
    final List<Widget> items = <Widget>[];
    final String zone = _zoneOf(context);
    int? hour;
    for (int i = 0; i < entries.length; i++) {
      final RecentEntry entry = entries[i];
      final WallTime time = _wallTime(context, zone, entry.createdAt);
      final bool lastOfHour =
          i == entries.length - 1 ||
          _wallTime(context, zone, entries[i + 1].createdAt).hour != time.hour;
      if (time.hour != hour) {
        hour = time.hour;
        items.add(
          _HourHeader(hour: time.hour, money: context.moneyFor(entry.currency)),
        );
      }
      items.add(
        TransactionRow(
          time: time,
          last4: entry.last4,
          amountCents: entry.amount,
          remainingCents: entry.balanceAfter,
          money: context.moneyFor(entry.currency),
          showDivider: !lastOfHour,
          onPressed: () => _showDetail(context, entry, time),
        ),
      );
    }
    return items;
  }
}

String _zoneOf(BuildContext context) =>
    context.services.session.user?.restaurant?.timezone ?? 'Europe/Vienna';

/// Wall-clock time of [instant] in the restaurant zone (09 §4.5).
WallTime _wallTime(BuildContext context, String zone, DateTime instant) {
  final DateTime local = context.services.session.calendar.local(zone, instant);
  return WallTime(local.hour, local.minute);
}

/// Clock-hour group header: `type.overline`, `fg.tertiary`, 32 pt, heading.
class _HourHeader extends StatelessWidget {
  const _HourHeader({required this.hour, required this.money});

  final int hour;
  final MoneyContext money;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _hourHeaderHeight),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: context.layout.margin),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: ScaledText(
              money.time(WallTime(hour, 0)),
              type: TypeTokens.overline,
              color: context.colors.fgTertiary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Recent detail (03b §6.5): a sheet on the Recent sheet with the facts of
/// one redemption and the reversal hint; read-only, no actions besides ✕.
void _showDetail(BuildContext context, RecentEntry entry, WallTime time) {
  unawaited(
    showWaiterSheet<void>(
      context: context,
      title: AppLocalizations.of(context).recentDetailTitle,
      builder: (BuildContext sheetContext) =>
          _RecentDetail(entry: entry, time: time),
    ),
  );
}

class _RecentDetail extends StatelessWidget {
  const _RecentDetail({required this.entry, required this.time});

  final RecentEntry entry;
  final WallTime time;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final WaiterColors c = context.colors;
    final MoneyContext money = context.moneyFor(entry.currency);
    final String transaction = _shortId(entry.transactionId);
    // 12 §2.5: last 6 characters of the X-Request-Id; long press copies it.
    final String? supportCode =
        entry.requestId.replaceAll('-', '').length < SupportCode.length
        ? null
        : SupportCode.fromRequestId(entry.requestId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: Space.s2),
        Semantics(
          label: money.spoken(entry.amount),
          excludeSemantics: true,
          child: ScaledText.rich(
            (ScaledStyles s) => TextSpan(
              text: money.format(entry.amount),
              style: s(TypeTokens.amountL).tabular,
            ),
            type: TypeTokens.amountL,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: Space.s6),
        FactRow(label: l10n.recentDetailTime, value: money.time(time)),
        FactRow(
          label: l10n.recentDetailCard,
          value: CardNumber.masked(entry.last4),
          spokenValue: Spoken.characters(entry.last4),
        ),
        FactRow(
          label: l10n.recentDetailAmount,
          value: money.format(entry.amount),
          spokenValue: money.spoken(entry.amount),
        ),
        FactRow(
          label: l10n.recentDetailRemaining,
          value: entry.balanceAfter == 0
              ? l10n.recentRowEmpty
              : money.format(entry.balanceAfter),
          spokenValue: entry.balanceAfter == 0
              ? null
              : money.spoken(entry.balanceAfter),
        ),
        FactRow(
          label: l10n.recentDetailTransaction,
          value: transaction,
          spokenValue: Spoken.characters(transaction),
          showDivider: supportCode != null,
          onLongPress: () => _copy(context, entry.transactionId),
        ),
        if (supportCode != null)
          FactRow(
            label: l10n.recentDetailSupportCode,
            value: supportCode,
            spokenValue: SupportCode.spoken(supportCode),
            showDivider: false,
            onLongPress: () => _copy(context, entry.requestId),
          ),
        const SizedBox(height: Space.s6),
        ScaledText(
          l10n.recentDetailReverseHint,
          type: TypeTokens.bodyM,
          color: c.fgSecondary,
        ),
      ],
    );
  }

  /// Long press copies the full id; `common.copied` confirms (12 §2.5).
  static void _copy(BuildContext context, String text) {
    final SnackbarController? snackbar = SnackbarHost.maybeOf(context);
    final String copied = AppLocalizations.of(context).commonCopied;
    unawaited(
      Clipboard.setData(
        ClipboardData(text: text),
      ).then((_) => snackbar?.show(SnackbarData(message: copied))),
    );
  }

  /// Last six characters of the transaction id, upper case (12 §5.15).
  static String _shortId(String id) {
    final String compact = id.replaceAll('-', '').toUpperCase();
    return compact.length <= _transactionIdChars
        ? compact
        : compact.substring(compact.length - _transactionIdChars);
  }
}
