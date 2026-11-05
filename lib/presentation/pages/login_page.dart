import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/constants/api_constants.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/validators.dart';
import '../components/components.dart';
import '../providers/auth_provider.dart';
import 'register_page.dart';

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

  Future<void> _google() async {
    FocusScope.of(context).unfocus();

    final auth = context.read<AuthProvider>();
    final ok = await auth.loginWithGoogle();

    if (!mounted) return;
    if (ok) {
      widget.onSuccess?.call();
    } else if (auth.errorMessage.isNotEmpty) {
      // Si el cliente solo canceló, no hay nada que avisar.
      AppSnackbar.error(context, auth.errorMessage);
    }
  }

  /// Tras crear la cuenta se deja escrito el correo para iniciar sesión.
  Future<void> _register() async {
    final email = await RegisterPage.open(context);
    if (email != null && mounted) _email.text = email;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

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
          if (ApiConstants.googleLoginEnabled) ...[
            const SizedBox(height: 16),
            const _OrDivider(),
            const SizedBox(height: 16),
            _GoogleButton(onPressed: auth.isLoading ? null : _google),
          ],
          const SizedBox(height: 8),
          AppButton(
            label: '¿Olvidaste tu contraseña?',
            variant: AppButtonVariant.text,
            onPressed: () =>
                ForgotPasswordPage.open(context, email: _email.text),
          ),
          AppButton(
            label: 'Crear una cuenta',
            variant: AppButtonVariant.outline,
            onPressed: _register,
          ),
        ],
      ),
    );
  }
}

/// "o" entre dos líneas, para separar el correo de las otras formas de entrar.
class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;

    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('o', style: TextStyle(color: outline)),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

/// "Continuar con Google", con la "G" de colores.
class _GoogleButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const _GoogleButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF3C4043),
        side: const BorderSide(color: Color(0xFFDADCE0)),
      ),
      icon: const FaIcon(FontAwesomeIcons.google, size: 18, color: Color(0xFFEA4335)),
      label: const Text('Continuar con Google'),
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
