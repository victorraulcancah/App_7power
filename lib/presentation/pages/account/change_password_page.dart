import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../domain/usecases/auth_usecases.dart';
import '../../components/components.dart';
import '../../providers/auth_provider.dart';

/// Cambiar la contraseña desde "Datos personales". La sesión sigue abierta.
class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() => _saving = true);
    final error = await context.read<AuthProvider>().changePassword(
          current: _current.text,
          next: _next.text,
          confirmation: _confirm.text,
        );
    if (!mounted) return;
    setState(() => _saving = false);

    if (error != null) {
      AppSnackbar.error(context, error);
      return;
    }
    AppSnackbar.success(context, 'Contraseña actualizada');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 16);

    return Scaffold(
      appBar: AppBar(title: const Text('Cambiar contraseña')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppConstants.defaultPadding * 1.5),
          children: [
            AppTextField(
              label: 'Contraseña actual',
              controller: _current,
              isPassword: true,
              textInputAction: TextInputAction.next,
              prefixIcon: Icons.lock_outline,
              validator: (v) =>
                  (v ?? '').isEmpty ? 'Ingresa tu contraseña actual' : null,
            ),
            gap,
            AppTextField(
              label: 'Contraseña nueva',
              controller: _next,
              isPassword: true,
              textInputAction: TextInputAction.next,
              prefixIcon: Icons.lock_reset,
              onChanged: (_) => setState(() {}),
              validator: (v) => validateNewPassword(v ?? ''),
            ),
            const SizedBox(height: 8),
            _Requirements(password: _next.text),
            gap,
            AppTextField(
              label: 'Confirmar contraseña nueva',
              controller: _confirm,
              isPassword: true,
              textInputAction: TextInputAction.done,
              prefixIcon: Icons.lock_reset,
              validator: (v) =>
                  v != _next.text ? 'Las contraseñas no coinciden' : null,
            ),
            const SizedBox(height: 24),
            AppButton(
              label: 'Guardar contraseña',
              isLoading: _saving,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

/// Lista de requisitos que se marcan a medida que se escribe.
class _Requirements extends StatelessWidget {
  final String password;

  const _Requirements({required this.password});

  @override
  Widget build(BuildContext context) {
    final checks = <(String, bool)>[
      ('Mínimo 8 caracteres', password.length >= 8),
      ('Una mayúscula', RegExp(r'[A-Z]').hasMatch(password)),
      ('Una minúscula', RegExp(r'[a-z]').hasMatch(password)),
      ('Un número', RegExp(r'\d').hasMatch(password)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (label, ok) in checks)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Icon(
                  ok ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 18,
                  color: ok ? Colors.green.shade700 : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: ok ? Colors.green.shade700 : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
