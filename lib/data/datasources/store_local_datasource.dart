import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/company_info_model.dart';

abstract class StoreLocalDataSource {
  /// Los últimos datos de la empresa que respondió el backend, o null.
  Future<CompanyInfoModel?> readCompany();

  Future<void> writeCompany(CompanyInfoModel company);
}

/// Guarda los datos de la empresa en el dispositivo. Con ellos el app arranca
/// ya con el color y el logo de la empresa, sin esperar a la red.
class StoreLocalDataSourceImpl implements StoreLocalDataSource {
  static const _key = 'company_info_v1';

  @override
  Future<CompanyInfoModel?> readCompany() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      if (raw == null) return null;
      return CompanyInfoModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Dato dañado o sin almacenamiento: se trata como si no hubiera caché.
      return null;
    }
  }

  @override
  Future<void> writeCompany(CompanyInfoModel company) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(company.toJson()));
    } catch (_) {
      // Guardar es una mejora: si falla, la app sigue igual.
    }
  }
}
