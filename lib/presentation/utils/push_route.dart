import 'package:flutter/widgets.dart';

import '../../core/push/push_messaging.dart';
import '../pages/account/purchases_page.dart';
import '../pages/account/quotes_page.dart';
import '../pages/promotions/offers_page.dart';

/// A qué pantalla lleva una notificación. El servidor manda `tipo` en sus datos.
class PushRoute {
  /// La pantalla de [message], o null si no se sabe a dónde llevar (el aviso se
  /// muestra igual, solo que tocarlo no abre nada).
  static Widget? pageFor(PushMessage message) => switch (message.type) {
        'compra' => const PurchasesPage(),
        'cotizacion' => const QuotesPage(),
        'oferta' => const OffersPage(),
        _ => null,
      };
}
