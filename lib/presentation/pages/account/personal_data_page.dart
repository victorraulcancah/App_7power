import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../components/components.dart';
import '../../providers/auth_provider.dart';
import 'change_password_page.dart';

/// "Datos personales": solo lectura, salvo el celular (como en la web, el
/// cliente no puede cambiar su nombre ni su documento).
class PersonalDataPage extends StatefulWidget {
  const PersonalDataPage({super.key});

  @override
  State<PersonalDataPage> createState() => _PersonalDataPageState();
}

class _PersonalDataPageState extends State<PersonalDataPage> {
  @override
  void initState() {
    super.initState();
    // Se refrescan los datos por si cambiaron en otro dispositivo o en la web.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().refreshProfile();
    });
  }

  Future<void> _editPhone() async {
    final auth = context.read<AuthProvider>();

    final phone = await showDialog<String>(
      context: context,
      builder: (_) => _PhoneDialog(initial: auth.user?.phone ?? ''),
    );
    if (phone == null) return;

    final error = await auth.updatePhone(phone);
    if (!mounted) return;
    if (error != null) {
      AppSnackbar.error(context, error);
    } else {
      AppSnackbar.success(context, 'Celular actualizado');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      appBar: AppBar(title: const Text('Datos personales')),
      body: user == null
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.all(AppConstants.defaultPadding),
              children: [
                _Field(
                  icon: Icons.tag,
                  label: 'Código de cliente',
                  value: '#${user.id}',
                ),
                _Field(
                  icon: Icons.person_outline,
                  label: 'Nombre o razón social',
                  value: user.fullName,
                ),
                _Field(
                  icon: Icons.badge_outlined,
                  label: user.documentType ?? 'Documento',
                  value: user.documentNumber ?? '—',
                ),
                _Field(
                  icon: Icons.mail_outline,
                  label: 'Correo',
                  value: user.email,
                ),
                _Field(
                  icon: Icons.phone_outlined,
                  label: 'Celular',
                  value: user.phone ?? 'Sin registrar',
                  onEdit: _editPhone,
                ),
                const Divider(height: 32),
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('Cambiar contraseña'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ChangePasswordPage(),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Diálogo para cambiar el celular. Es un widget propio para que el
/// controlador se libere junto con el diálogo, no antes de que termine de
/// cerrarse.
class _PhoneDialog extends StatefulWidget {
  final String initial;

  const _PhoneDialog({required this.initial});

  @override
  State<_PhoneDialog> createState() => _PhoneDialogState();
}

class _PhoneDialogState extends State<_PhoneDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Celular'),
      content: Form(
        key: _formKey,
        child: AppTextField(
          label: 'Celular',
          hint: '9XXXXXXXX',
          controller: _controller,
          keyboardType: TextInputType.phone,
          prefixIcon: Icons.phone_outlined,
          validator: (v) => RegExp(r'^9[0-9]{8}$').hasMatch((v ?? '').trim())
              ? null
              : 'Ingresa un celular peruano válido (9 dígitos, empieza con 9).',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, _controller.text.trim());
            }
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onEdit;

  const _Field({
    required this.icon,
    required this.label,
    required this.value,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(value),
      trailing: onEdit == null
          ? null
          : IconButton(
              tooltip: 'Editar',
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEdit,
            ),
    );
  }
}
