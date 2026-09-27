import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';
import 'feedback_service.dart';

/// Gives components access to the [FeedbackService] (09 §2.5: components name
/// a token, they never call platform haptics). Without a scope (isolated
/// widget tests) feedback is silently skipped.
class FeedbackScope extends InheritedWidget {
  const FeedbackScope({required this.service, required super.child, super.key});

  final FeedbackService service;

  static FeedbackService? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<FeedbackScope>()?.service;

  @override
  bool updateShouldNotify(FeedbackScope oldWidget) => !identical(service, oldWidget.service);
}

extension FeedbackContext on BuildContext {
  void haptic(HapticToken token, {int step = 0}) => FeedbackScope.maybeOf(this)?.haptic(token, step: step);

  void sound(SoundToken token) => FeedbackScope.maybeOf(this)?.sound(token);
}
