import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/color_utils.dart';
import '../components/splash_screen.dart';
import '../providers/company_provider.dart';
import '../providers/home_provider.dart';
import 'main_shell.dart';

/// Pantalla de carga al abrir el app, como la de la web: tapa la tienda hasta
/// que ya se sabe el color de la empresa y llegó la portada (banners y
/// productos), en lugar de mostrar la tienda a medio cargar.
///
/// La tienda se construye debajo desde el principio, así que empieza a pedir sus
/// datos mientras se ve el splash. No espera más de [limit]: si la red está muy
/// lenta se entra igual y las imágenes van apareciendo.
class StartupGate extends StatefulWidget {
  static const Duration limit = Duration(seconds: 8);
  static const Duration fade = Duration(milliseconds: 250);

  const StartupGate({super.key});

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  Timer? _limit;
  bool _timedOut = false;

  /// Una vez que se quita el splash no vuelve, aunque la portada se recargue
  /// (por ejemplo al iniciar sesión).
  bool _dismissed = false;
  bool _removed = false;

  @override
  void initState() {
    super.initState();
    _limit = Timer(StartupGate.limit, () {
      if (mounted) setState(() => _timedOut = true);
    });
  }

  @override
  void dispose() {
    _limit?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final company = context.watch<CompanyProvider>();
    final home = context.watch<HomeProvider>();

    final ready = company.isLoaded &&
        (home.status == HomeStatus.loaded || _timedOut);
    if (ready && !_dismissed) {
      _dismissed = true;
      _limit?.cancel();
    }

    final info = company.info;
    final splash = SplashScreen(
      background:
          ColorUtils.parseHex(info?.splashColor) ?? SplashScreen.defaultBackground,
      logoUrl: info?.logoUrl,
      text: info?.splashText ?? SplashScreen.defaultText,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        if (company.isLoaded) const MainShell(),
        if (!_removed)
          IgnorePointer(
            ignoring: _dismissed,
            child: AnimatedOpacity(
              opacity: _dismissed ? 0 : 1,
              duration: StartupGate.fade,
              onEnd: () {
                if (_dismissed && mounted) setState(() => _removed = true);
              },
              child: splash,
            ),
          ),
      ],
    );
  }
}
