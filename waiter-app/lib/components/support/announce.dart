import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

/// Posts a screen-reader announcement (07 §5.6). [assertive] interrupts
/// (problems, success, over balance); otherwise the message is queued.
void announce(BuildContext context, String message, {bool assertive = false}) {
  if (message.isEmpty) return;
  unawaited(
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
      assertiveness: assertive ? Assertiveness.assertive : Assertiveness.polite,
    ),
  );
}
