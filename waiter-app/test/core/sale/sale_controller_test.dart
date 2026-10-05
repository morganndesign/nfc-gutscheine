import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/core/api/models.dart';
import 'package:giftcard_waiter/core/sale/sale_controller.dart';

import '../../support/app_harness.dart';

/// Selling a printed voucher when the owner took Loyalty away while the form was open (audit L4): the waiter is told
/// exactly that, the permissions are read again, and the entry comes back with a paid method (Android and iPhone).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }
  }

  Map<String, Object?> manager({required bool loyalty}) {
    final Map<String, Object?> user = Payloads.manager();
    return <String, Object?>{
      ...user,
      'permissions': <String>[
        ...(user['permissions']! as List<String>),
        if (loyalty) Permissions.sellComplimentary,
      ],
    };
  }

  testWidgets('Loyalty refused at the sale: its own message, permissions reloaded, back with cash', (
    WidgetTester tester,
  ) async {
    final TestApp app = await TestApp.create(user: manager(loyalty: true));
    unawaited(app.session.start());
    await settle(tester);
    app.backend
      ..on('POST', '/vouchers', FakeReply(403, Payloads.error('COMPLIMENTARY_NOT_ALLOWED')))
      ..on('GET', '/auth/me', FakeReply(200, <String, Object?>{'data': manager(loyalty: false)}));
    final SaleController c = SaleController(api: app.services.api, session: app.session, printer: app.printer);
    expect(c.methods, contains(PaymentMethod.complimentary));
    c
      ..digit(2)
      ..digit(0)
      ..digit(0)
      ..digit(0)
      ..continueToDetails()
      ..chooseMethod(PaymentMethod.complimentary)
      ..setReason('Stammgast');
    unawaited(c.sell());
    await settle(tester);

    expect((c.state as SaleProblem).kind, SaleProblemKind.loyaltyNotAllowed);
    expect(app.backend.to('GET', '/auth/me'), isNotEmpty);
    expect(c.methods, isNot(contains(PaymentMethod.complimentary)));
    c.backToDetails();
    expect((c.state as SaleDetails).method, PaymentMethod.cash);
    c.dispose();
    app.dispose();
    await tester.pump(const Duration(minutes: 2));
  });
}
