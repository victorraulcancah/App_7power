import '../../domain/entities/banner_entity.dart';

/// Elemento de `GET /banners/publicos`.
class BannerModel extends BannerEntity {
  const BannerModel({
    required super.id,
    required super.imageUrl,
    super.title,
    super.subtitle,
    super.buttonText,
    super.linkUrl,
  });

  factory BannerModel.fromJson(Map<String, dynamic> json) => BannerModel(
        id: (json['id'] as num).toInt(),
        imageUrl: json['imagen_url'].toString(),
        title: json['titulo']?.toString(),
        subtitle: json['subtitulo']?.toString(),
        buttonText: json['texto_boton']?.toString(),
        linkUrl: json['enlace_url']?.toString(),
      );
}
