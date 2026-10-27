import 'package:flutter/material.dart';

import '../../core/utils/color_utils.dart';
import '../../domain/entities/company_info_entity.dart';
import '../../domain/usecases/get_company_info_usecase.dart';
import '../../theme/app_theme.dart';

/// Datos de la empresa y tema derivado de ellos. Si el backend no responde la
/// app sigue funcionando con el tema por defecto.
class CompanyProvider extends ChangeNotifier {
  final GetCompanyInfoUseCase getCompanyInfoUseCase;

  CompanyProvider({required this.getCompanyInfoUseCase});

  CompanyInfoEntity? _info;
  bool _loaded = false;

  CompanyInfoEntity? get info => _info;
  bool get isLoaded => _loaded;

  /// Color del navbar y footer configurado en el backend, o el de marca.
  Color get brandColor =>
      ColorUtils.parseHex(_info?.navbarColor) ?? AppTheme.primary;

  ThemeData get theme => AppTheme.build(ColorUtils.parseHex(_info?.navbarColor));

  Future<void> load() async {
    final result = await getCompanyInfoUseCase();
    result.fold((_) {}, (info) => _info = info);
    _loaded = true;
    notifyListeners();
  }
}
