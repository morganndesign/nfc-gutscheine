import 'package:flutter/widgets.dart';

import '../core/api/models.dart';
import '../core/theme/theme.dart';
import '../l10n/app_localizations.dart';
import 'scan/sheet_rows.dart';

/// How the guest paid (sale and top-up).
String paymentMethodLabel(AppLocalizations l10n, PaymentMethod m) => switch (m) {
  PaymentMethod.cash => l10n.salePaymentCash,
  PaymentMethod.cardTerminal => l10n.salePaymentCardTerminal,
  PaymentMethod.bankTransfer => l10n.salePaymentBankTransfer,
  PaymentMethod.complimentary => l10n.salePaymentComplimentary,
};

/// One payment method: a full-width row with a check mark when chosen, read as
/// a radio button.
class PaymentMethodRow extends StatelessWidget {
  const PaymentMethodRow({
    super.key,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final WaiterColors c = context.colors;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      child: SheetRow(
        label: label,
        emphasised: selected,
        trailing: selected ? WaiterIconView(WaiterIcon.check, size: IconSize.s20, color: c.fgPrimary) : null,
        onPressed: enabled ? onSelected : null,
      ),
    );
  }
}
