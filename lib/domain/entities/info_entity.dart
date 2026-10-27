class AboutValueEntity {
  final String title;
  final String description;
  final String? imageUrl;

  const AboutValueEntity({
    required this.title,
    required this.description,
    this.imageUrl,
  });
}

/// "Sobre nosotros".
class AboutEntity {
  final String name;
  final String? description;
  final String? imageUrl;
  final List<AboutValueEntity> values;

  const AboutEntity({
    required this.name,
    this.description,
    this.imageUrl,
    this.values = const [],
  });
}

class ShippingStepEntity {
  final int order;
  final String title;
  final String? description;
  final String? imageUrl;

  const ShippingStepEntity({
    required this.order,
    required this.title,
    this.description,
    this.imageUrl,
  });
}

/// Mensaje del formulario "Contáctanos".
class ContactMessage {
  final String name;
  final String email;
  final String? phone;
  final String subject;
  final String message;

  const ContactMessage({
    required this.name,
    required this.email,
    required this.subject,
    required this.message,
    this.phone,
  });
}

/// Datos del Libro de Reclamaciones. Los nombres siguen la hoja oficial:
/// consumidor, bien contratado, detalle y pedido del consumidor.
class ClaimDraft {
  // Consumidor
  final String consumerName;

  /// "DNI", "RUC", "Carné de extranjería" o "Pasaporte".
  final String documentType;
  final String documentNumber;
  final String address;
  final String phone;
  final String email;

  // Menor de edad: lo representa un apoderado
  final bool isMinor;
  final String? guardianName;
  final String? guardianDocument;
  final String? guardianAddress;
  final String? guardianPhone;
  final String? guardianEmail;

  // Bien contratado
  /// 'producto' o 'servicio'.
  final String goodType;
  final double amount;
  final String goodDescription;

  // Compra (opcional)
  final String? voucherType;
  final String? voucherNumber;
  final DateTime? purchaseDate;
  final String? orderCode;
  final String? productName;
  final String? brand;
  final String? model;

  // Detalle
  /// 'reclamo' o 'queja'.
  final String requestType;
  final String detail;
  final String consumerRequest;
  final String? expectedSolution;
  final String? otherSolution;

  const ClaimDraft({
    required this.consumerName,
    required this.documentType,
    required this.documentNumber,
    required this.address,
    required this.phone,
    required this.email,
    required this.goodType,
    required this.amount,
    required this.goodDescription,
    required this.requestType,
    required this.detail,
    required this.consumerRequest,
    this.isMinor = false,
    this.guardianName,
    this.guardianDocument,
    this.guardianAddress,
    this.guardianPhone,
    this.guardianEmail,
    this.voucherType,
    this.voucherNumber,
    this.purchaseDate,
    this.orderCode,
    this.productName,
    this.brand,
    this.model,
    this.expectedSolution,
    this.otherSolution,
  });
}

/// Constancia al registrar un reclamo.
class ClaimReceipt {
  final String number;

  /// Fecha límite de respuesta (15 días hábiles).
  final DateTime? deadline;

  const ClaimReceipt({required this.number, this.deadline});
}

/// Estado de un reclamo ya registrado.
class ClaimStatus {
  final String number;
  final String status;
  final String? requestType;
  final DateTime? deadline;
  final String? response;
  final DateTime? responseDate;
  final DateTime? createdAt;

  const ClaimStatus({
    required this.number,
    required this.status,
    this.requestType,
    this.deadline,
    this.response,
    this.responseDate,
    this.createdAt,
  });
}
