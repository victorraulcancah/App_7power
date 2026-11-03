import 'package:flutter/material.dart';

import '../../core/utils/color_utils.dart';
import '../../domain/entities/company_info_entity.dart';
import '../../domain/usecases/get_company_info_usecase.dart';
import '../../theme/app_theme.dart';

/// Datos de la empresa y tema derivado de ellos. Si el backend no responde la
/// app sigue funcionando con el tema por defecto.
class CompanyProvider extends ChangeNotifier {
  /// Cuánto se espera al backend en el primer arranque (sin datos guardados)
  /// antes de mostrar la tienda con el tema por defecto. Si llega después, el
  /// tema se actualiza solo.
  static const Duration firstLoadLimit = Duration(seconds: 4);

  final GetCompanyInfoUseCase getCompanyInfoUseCase;
  final GetCachedCompanyInfoUseCase? getCachedCompanyInfoUseCase;

  CompanyProvider({
    required this.getCompanyInfoUseCase,
    this.getCachedCompanyInfoUseCase,
  });

  CompanyInfoEntity? _info;
  bool _loaded = false;

  CompanyInfoEntity? get info => _info;

  /// Ya se sabe qué color y logo usar (guardados o recién llegados), o se
  /// dejó de esperar. Hasta entonces la app muestra una pantalla de carga en
  /// lugar de pintarse con un color que enseguida cambia.
  bool get isLoaded => _loaded;

  /// Color del navbar y footer configurado en el backend, o el de marca.
  Color get brandColor =>
      ColorUtils.parseHex(_info?.navbarColor) ?? AppTheme.primary;

  ThemeData get theme => AppTheme.build(ColorUtils.parseHex(_info?.navbarColor));

  Future<void> load() async {
    // Lo guardado en el equipo se usa de inmediato; el backend lo refresca.
    final cached = await getCachedCompanyInfoUseCase?.call();
    if (cached != null && _info == null) {
      _info = cached;
      _loaded = true;
      notifyListeners();
    }

    final fresh = getCompanyInfoUseCase().then((result) {
      result.fold((_) {}, (info) => _info = info);
      _loaded = true;
      notifyListeners();
    });

    // Sin datos guardados no se espera más de [firstLoadLimit]; la respuesta
    // que llegue después igual se aplica.
    await fresh.timeout(firstLoadLimit, onTimeout: () {
      if (!_loaded) {
        _loaded = true;
        notifyListeners();
      }
    });
  }
}
