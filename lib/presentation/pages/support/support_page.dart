import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../providers/company_provider.dart';
import '../../utils/whatsapp_support.dart';
import '../account/purchases_page.dart';
import '../account/quotes_page.dart';
import '../more/claim_book_page.dart';
import '../more/shipping_steps_page.dart';

/// El verde de WhatsApp.
const Color whatsappGreen = Color(0xFF25D366);

/// Una pregunta frecuente con su respuesta y, si ayuda, un botón que lleva a la
/// pantalla donde se resuelve.
class FaqItem {
  final String question;
  final String answer;
  final String? actionLabel;
  final Widget Function()? actionPage;

  const FaqItem(this.question, this.answer, {this.actionLabel, this.actionPage});
}

/// Ayuda: hablar con un asesor por WhatsApp y las preguntas más comunes.
class SupportPage extends StatelessWidget {
  const SupportPage({super.key});

  /// Las respuestas dicen lo que el app hace de verdad y mandan a la pantalla
  /// correspondiente; lo que depende de la empresa (métodos de pago) sale de lo
  /// que ella configuró. [paymentMethods] son sus nombres.
  static List<FaqItem> faq(List<String> paymentMethods) => [
        const FaqItem(
          '¿Cómo hago un pedido?',
          'Agrega los productos al carrito, toca Comprar, elige tu dirección de '
              'entrega y paga. También puedes pedir una cotización y comprarla '
              'después, cuando te convenga.',
        ),
        FaqItem(
          '¿Qué métodos de pago hay?',
          paymentMethods.isEmpty
              ? 'Los métodos de pago se muestran al pagar. Si tienes dudas, '
                  'escríbenos por WhatsApp.'
              : 'Aceptamos: ${paymentMethods.join(', ')}. Los ves también al '
                  'momento de pagar.',
        ),
        FaqItem(
          '¿Hacen envíos?',
          'Revisa cómo funciona el envío: los pasos, las zonas y los tiempos.',
          actionLabel: 'Ver cómo funciona el envío',
          actionPage: () => const ShippingStepsPage(),
        ),
        FaqItem(
          '¿Los productos tienen garantía?',
          'Cada producto indica su garantía en su ficha, en la sección '
              '"Garantía". Si tuviste un problema con una compra, puedes '
              'registrarlo en el Libro de reclamaciones.',
          actionLabel: 'Ir al Libro de reclamaciones',
          actionPage: () => const ClaimBookPage(),
        ),
        FaqItem(
          '¿Cómo sigo el estado de mi pedido?',
          'En Cuenta → Compras ves cada compra con su seguimiento paso a paso.',
          actionLabel: 'Ver mis compras',
          actionPage: () => const PurchasesPage(),
        ),
        FaqItem(
          '¿Dónde veo mis cotizaciones?',
          'En Cuenta → Cotizaciones. Desde ahí puedes comprarlas, editarlas o '
              'cancelarlas.',
          actionLabel: 'Ver mis cotizaciones',
          actionPage: () => const QuotesPage(),
        ),
        const FaqItem(
          'Olvidé mi contraseña',
          'En la pantalla de iniciar sesión toca "¿Olvidaste tu contraseña?" y te '
              'enviaremos un enlace al correo de tu cuenta.',
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final company = context.watch<CompanyProvider>().info;
    final items = faq([for (final m in company?.paymentMethods ?? const []) m.name]);

    return Scaffold(
      appBar: AppBar(title: const Text('Ayuda')),
      body: ListView(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        children: [
          const _WhatsAppCard(),
          const SizedBox(height: 20),
          Text('Preguntas frecuentes',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          for (final item in items) _FaqTile(item: item),
        ],
      ),
    );
  }
}

class _WhatsAppCard extends StatelessWidget {
  const _WhatsAppCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppConstants.defaultPadding * 1.25),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF128C7E), whatsappGreen],
        ),
        boxShadow: [
          BoxShadow(
            color: whatsappGreen.withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              FaIcon(FontAwesomeIcons.whatsapp, color: Colors.white, size: 30),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  '¿Necesitas ayuda?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Escríbenos y un asesor de 7Power te atiende por WhatsApp.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => WhatsAppSupport.open(context),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF128C7E),
            ),
            icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 18),
            label: const Text('Hablar con un asesor'),
          ),
        ],
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  final FaqItem item;

  const _FaqTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Theme(
          // Sin las líneas que Material pone arriba y abajo al abrir.
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            title: Text(
              item.question,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            iconColor: theme.colorScheme.primary,
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            children: [
              Text(item.answer, style: theme.textTheme.bodyMedium),
              if (item.actionPage != null) ...[
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => item.actionPage!()),
                  ),
                  child: Text(item.actionLabel ?? 'Ver'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Ícono de WhatsApp para la barra superior: lleva a la pantalla de ayuda.
class SupportAction extends StatelessWidget {
  const SupportAction({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Ayuda',
      icon: const FaIcon(FontAwesomeIcons.whatsapp, color: whatsappGreen, size: 26),
      onPressed: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const SupportPage())),
    );
  }
}
