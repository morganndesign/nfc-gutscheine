import 'package:flutter/widgets.dart';

/// Moves focus to [node] after the current frame (07 §5.7: focus is set
/// after the transition's first frame, never waiting for the motion).
void focusAfterFrame(FocusNode node) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (node.context != null && node.canRequestFocus) node.requestFocus();
  });
}

/// Moves focus to the first focusable control inside the `Focus` that owns
/// [scope] — e.g. a button whose own focus node is internal to the
/// component — after the current frame.
void focusFirstIn(FocusNode scope) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (scope.context == null) return;
    for (final FocusNode node in scope.descendants) {
      if (node.canRequestFocus && !node.skipTraversal) {
        node.requestFocus();
        return;
      }
    }
  });
}
