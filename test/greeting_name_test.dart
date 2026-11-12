import 'package:flutter_test/flutter_test.dart';

import 'package:appecommerce/domain/entities/user_entity.dart';

UserEntity _user({
  String fullName = 'Ana Pérez',
  String? firstNames,
  String? lastNames,
  String? document,
  String? holderName,
  String? holderDocument,
}) => UserEntity(
  id: 1,
  fullName: fullName,
  email: 'a@b.com',
  firstNames: firstNames,
  lastNames: lastNames,
  documentNumber: document,
  erpCode: holderName == null ? null : 'CLI1',
  holderName: holderName,
  holderDocument: holderDocument,
);

void main() {
  group('Nombre del saludo', () {
    test('RUC 20: la razón social sin SAC ni EIRL', () {
      expect(
        _user(holderName: 'GRUPO GM IMPORTACIONES SAC', holderDocument: '20512345678')
            .greetingName,
        'Grupo GM Importaciones',
      );
      expect(
        _user(holderName: '7POWER AUDIO E.I.R.L.', holderDocument: '20512345678')
            .greetingName,
        '7power Audio',
      );
      expect(
        _user(holderName: 'DISTRIBUIDORA LIMA S.A.C.', holderDocument: '20512345678')
            .greetingName,
        'Distribuidora Lima',
      );
    });

    test('persona: un nombre y un apellido', () {
      expect(
        _user(fullName: 'Anthony Kener Gustavo Miranda', firstNames: 'Anthony Kener', lastNames: 'Gustavo Miranda')
            .greetingName,
        'Anthony Gustavo',
      );
    });

    test('persona sin nombres separados: usa el nombre completo', () {
      expect(_user(fullName: 'ANTHONY KENER GUSTAVO MIRANDA PUN').greetingName,
          'Anthony Miranda');
      expect(_user(fullName: 'Ana Pérez').greetingName, 'Ana Pérez');
      expect(_user(fullName: 'Ana').greetingName, 'Ana');
    });

    test('con la cuenta vinculada manda el nombre del ERP, no el del registro', () {
      // Registrada en la tienda con nombres que no son los del cliente.
      expect(
        _user(
          fullName: 'Grupo Importaciones',
          firstNames: 'Grupo',
          lastNames: 'Importaciones',
          holderName: 'ANTHONY KENER GUSTAVO MIRANDA PUN',
          holderDocument: '70830096',
        ).greetingName,
        'Anthony Miranda',
      );
    });

    test('RUC 10 (persona con negocio) sale como persona', () {
      expect(
        _user(
          fullName: 'Juan Quispe',
          firstNames: 'Juan',
          lastNames: 'Quispe Rojas',
          holderName: 'JUAN QUISPE ROJAS',
          holderDocument: '10412345678',
        ).greetingName,
        'Juan Quispe',
      );
    });
  });
}
