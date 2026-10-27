import '../../core/errors/failures.dart';
import '../../core/utils/either.dart';
import '../entities/info_entity.dart';
import '../repositories/info_repository.dart';

class GetAboutUseCase {
  final InfoRepository repository;
  GetAboutUseCase(this.repository);

  Future<Either<Failure, AboutEntity>> call() => repository.getAbout();
}

class GetShippingStepsUseCase {
  final InfoRepository repository;
  GetShippingStepsUseCase(this.repository);

  Future<Either<Failure, List<ShippingStepEntity>>> call() =>
      repository.getShippingSteps();
}

final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Primer problema del mensaje de contacto, o null si está bien.
String? validateContact(ContactMessage m) {
  if (m.name.trim().isEmpty) return 'Ingresa tu nombre';
  if (!_emailRegex.hasMatch(m.email.trim())) return 'Ingresa un correo válido';
  if (m.subject.trim().isEmpty) return 'Ingresa el asunto';
  if (m.message.trim().isEmpty) return 'Escribe tu mensaje';
  if (m.message.length > 2000) return 'El mensaje no puede pasar de 2000 letras';
  return null;
}

class SendContactUseCase {
  final InfoRepository repository;
  SendContactUseCase(this.repository);

  Future<Either<Failure, void>> call(ContactMessage message) {
    final error = validateContact(message);
    if (error != null) {
      return Future.value(Either.left(ValidationFailure(error)));
    }
    return repository.sendContact(message);
  }
}

/// Formato del documento según su tipo, igual que el formulario y el backend.
String? validateDocument(String type, String value) {
  final v = value.trim();
  return switch (type) {
    'RUC' => RegExp(r'^(10|15|17|20)\d{9}$').hasMatch(v)
        ? null
        : 'El RUC debe tener 11 dígitos y empezar con 10, 15, 17 o 20',
    'Carné de extranjería' => RegExp(r'^[A-Za-z0-9]{9,12}$').hasMatch(v)
        ? null
        : 'El carné de extranjería debe tener entre 9 y 12 caracteres',
    'Pasaporte' => RegExp(r'^[A-Za-z0-9]{6,12}$').hasMatch(v)
        ? null
        : 'El pasaporte debe tener entre 6 y 12 caracteres',
    _ => RegExp(r'^\d{8}$').hasMatch(v) ? null : 'El DNI debe tener 8 dígitos',
  };
}

/// Primer problema del reclamo, o null si se puede enviar. Repite las reglas
/// del backend para avisar antes de enviar.
String? validateClaim(ClaimDraft c, {DateTime? today}) {
  final now = today ?? DateTime.now();

  if (c.consumerName.trim().length < 2) return 'Ingresa tu nombre completo';
  final document = validateDocument(c.documentType, c.documentNumber);
  if (document != null) return document;
  if (c.address.trim().length < 10) {
    return 'La dirección debe tener al menos 10 caracteres';
  }
  if (!RegExp(r'^\d{9}$').hasMatch(c.phone.trim())) {
    return 'El teléfono debe tener exactamente 9 dígitos';
  }
  if (!_emailRegex.hasMatch(c.email.trim())) {
    return 'El correo no tiene un formato válido';
  }

  if (c.isMinor) {
    if ((c.guardianName ?? '').trim().length < 2) {
      return 'Ingresa el nombre del apoderado';
    }
    if (!RegExp(r'^\d{8}$').hasMatch((c.guardianDocument ?? '').trim())) {
      return 'El DNI del apoderado debe tener 8 dígitos';
    }
    if ((c.guardianAddress ?? '').trim().length < 10) {
      return 'La dirección del apoderado debe tener al menos 10 caracteres';
    }
    if (!RegExp(r'^\d{9}$').hasMatch((c.guardianPhone ?? '').trim())) {
      return 'El teléfono del apoderado debe tener 9 dígitos';
    }
    if (!_emailRegex.hasMatch((c.guardianEmail ?? '').trim())) {
      return 'El correo del apoderado no es válido';
    }
  }

  if (c.amount <= 0) return 'El monto reclamado debe ser mayor a 0';
  if (c.goodDescription.trim().length < 10) {
    return 'La descripción del bien debe tener al menos 10 caracteres';
  }
  if (c.purchaseDate != null && c.purchaseDate!.isAfter(now)) {
    return 'La fecha de compra no puede ser futura';
  }
  if (c.detail.trim().length < 20) {
    return 'El detalle del reclamo debe tener al menos 20 caracteres';
  }
  if (c.consumerRequest.trim().length < 10) {
    return 'Tu pedido debe tener al menos 10 caracteres';
  }
  if (c.expectedSolution == 'Otro' && (c.otherSolution ?? '').trim().isEmpty) {
    return 'Escribe la solución que esperas';
  }
  return null;
}

class SubmitClaimUseCase {
  final InfoRepository repository;
  SubmitClaimUseCase(this.repository);

  Future<Either<Failure, ClaimReceipt>> call(ClaimDraft claim) {
    final error = validateClaim(claim);
    if (error != null) {
      return Future.value(Either.left(ValidationFailure(error)));
    }
    return repository.submitClaim(claim);
  }
}

class FindClaimUseCase {
  final InfoRepository repository;
  FindClaimUseCase(this.repository);

  Future<Either<Failure, ClaimStatus>> call(String number) {
    if (number.trim().isEmpty) {
      return Future.value(Either.left(
        const ValidationFailure('Ingresa el número de reclamo'),
      ));
    }
    return repository.findClaim(number.trim());
  }
}
