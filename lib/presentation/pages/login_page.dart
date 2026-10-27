import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/validators.dart';
import '../components/components.dart';
import '../providers/auth_provider.dart';
import '../providers/company_provider.dart';

/// Formulario de inicio de sesión. Se usa dentro de la pestaña Cuenta y, como
/// pantalla aparte, desde el carrito.
class LoginForm extends StatefulWidget {
  /// Se llama cuando el inicio de sesión fue correcto.
  final VoidCallback? onSuccess;

  const LoginForm({super.key, this.onSuccess});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final auth = context.read<AuthProvider>();
    final ok = await auth.login(_email.text, _password.text);

    if (!mounted) return;
    if (ok) {
      widget.onSuccess?.call();
    } else {
      AppSnackbar.error(context, auth.errorMessage);
    }
  }

  /// Registro y recuperación de contraseña se hacen en la web de la tienda
  /// (el registro exige resolver un captcha).
  Future<void> _openWeb(String path) async {
    final website = context.read<CompanyProvider>().info?.website;
    if (website == null) return;
    final base = website.endsWith('/') ? website : '$website/';
    await launchUrl(Uri.parse('$base$path'), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final hasWebsite =
        context.select<CompanyProvider, bool>((c) => c.info?.website != null);

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(AppConstants.defaultPadding * 1.5),
        children: [
          Icon(Icons.account_circle_outlined,
              size: 72, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text('Inicia sesión',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),
          AppTextField(
            label: 'Correo electrónico',
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            prefixIcon: Icons.mail_outline,
            validator: Validators.email,
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Contraseña',
            controller: _password,
            isPassword: true,
            textInputAction: TextInputAction.done,
            prefixIcon: Icons.lock_outline,
            validator: (v) => Validators.required(v, 'tu contraseña'),
          ),
          const SizedBox(height: 24),
          AppButton(
            label: 'Ingresar',
            isLoading: auth.isLoading,
            onPressed: _submit,
          ),
          if (hasWebsite) ...[
            const SizedBox(height: 8),
            AppButton(
              label: '¿Olvidaste tu contraseña?',
              variant: AppButtonVariant.text,
              onPressed: () => _openWeb('forgot-password'),
            ),
            AppButton(
              label: 'Crear una cuenta',
              variant: AppButtonVariant.outline,
              onPressed: () => _openWeb('register'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Pantalla de inicio de sesión para abrir encima de otra (carrito, etc.).
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  /// La cierra sola cuando el usuario inicia sesión.
  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Iniciar sesión')),
      body: LoginForm(onSuccess: () => Navigator.of(context).pop()),
    );
  }
}
