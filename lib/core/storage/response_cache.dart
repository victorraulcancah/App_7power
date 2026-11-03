import 'package:shared_preferences/shared_preferences.dart';

/// Guarda en el dispositivo la última respuesta de ciertos pedidos al servidor
/// (banners, categorías, marcas, productos de la portada). Así, al abrir el app,
/// la portada se arma al instante con lo de la vez anterior y se actualiza
/// cuando llega lo nuevo.
///
/// Lo que depende del cliente con sesión (los precios) se guarda con una clave
/// distinta por cliente (ver [ownerFor]): lo de un cliente, o de un invitado,
/// nunca se muestra a otro.
class ResponseCache {
  static const _prefix = 'response_cache_v1_';

  /// Pasado este tiempo lo guardado ya no se usa: mejor la pantalla de carga que
  /// banners o precios de hace semanas.
  static const Duration maxAge = Duration(days: 14);

  final DateTime Function() _now;

  ResponseCache({DateTime Function()? now}) : _now = now ?? DateTime.now;

  /// El texto guardado en [key], o null si no hay o está vencido.
  Future<String?> read(String key) async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString('$_prefix$key');
      if (raw == null) return null;

      // "milisegundos|contenido"
      final separator = raw.indexOf('|');
      final savedAt = separator < 0 ? null : int.tryParse(raw.substring(0, separator));
      if (savedAt == null ||
          _now().difference(DateTime.fromMillisecondsSinceEpoch(savedAt)) > maxAge) {
        return null;
      }
      return raw.substring(separator + 1);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String key, String body) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_prefix$key', '${_now().millisecondsSinceEpoch}|$body');
    } catch (_) {
      // Guardar es una mejora: si falla, la app sigue igual.
    }
  }

  /// Borra las entradas que empiezan con [keyPrefix], salvo las de [keep]. Cada
  /// inicio de sesión genera un dueño nuevo; así no se acumulan los viejos.
  Future<void> prune(String keyPrefix, {required Set<String> keep}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final stored in prefs.getKeys().toList()) {
        if (!stored.startsWith('$_prefix$keyPrefix')) continue;
        if (keep.contains(stored.substring(_prefix.length))) continue;
        await prefs.remove(stored);
      }
    } catch (_) {
      // No es importante.
    }
  }

  /// Identifica al cliente con sesión sin guardar el token tal cual: un hash
  /// sencillo basta, solo sirve para distinguir un dueño de otro.
  static String ownerFor(String? authToken) {
    if (authToken == null || authToken.isEmpty) return 'guest';
    var hash = 5381;
    for (final unit in authToken.codeUnits) {
      hash = ((hash << 5) + hash + unit) & 0x7fffffff;
    }
    return 'u$hash';
  }
}
