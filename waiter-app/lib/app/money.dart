import 'package:flutter/widgets.dart';

import '../components/money_context.dart';
import '../core/api/models.dart';
import '../core/format/format.dart';
import 'app_scope.dart';

/// Money and date formatting for the signed-in restaurant in the current UI
/// language (12 §1.4: restaurant locale for numbers, UI language for words).
extension MoneyOfContext on BuildContext {
  MoneyContext get money {
    final Restaurant? restaurant = services.session.user?.restaurant;
    return MoneyContext(
      currency: restaurant?.currency ?? 'EUR',
      language: UiLanguage.fromLanguageCode(Localizations.localeOf(this).languageCode),
      restaurantLocale: RestaurantLocale.parse(restaurant?.locale ?? 'de_AT'),
    );
  }

  /// Same, for a card whose currency may differ from the default.
  MoneyContext moneyFor(String currency) {
    final MoneyContext base = money;
    return MoneyContext(currency: currency, language: base.language, restaurantLocale: base.restaurantLocale);
  }
}
