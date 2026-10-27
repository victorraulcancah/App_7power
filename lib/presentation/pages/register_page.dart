import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/validators.dart';
import '../../domain/entities/register_entity.dart';
import '../../domain/usecases/registration_usecases.dart';
import '../components/components.dart';
import '../providers/registration_provider.dart';
import '../widgets/captcha_puzzle.dart';

/// Crear una cuenta de cliente. Antes de enviar hay que resolver el
/// rompecabezas, igual que en la web.
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  /// Devuelve el correo registrado, o null si se cerró sin crear la cuenta.
  static Future<String?> open(BuildContext context) =>
      Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const RegisterPage()),
      );

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _names = TextEditingController();
  final _lastNames = TextEditingController();
  final _email = TextEditingController();
  final _document = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  int? _typeId;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<RegistrationProvider>().loadDocumentTypes();
    });
  }

  @override
  void dispose() {
    for (final c in [
      _names,
      _lastNames,
      _email,
      _document,
      _phone,
      _password,
      _confirm,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final draft = RegisterDraft(
      firstNames: _names.text,
      lastNames: _lastNames.text,
      email: _email.text,
      password: _password.text,
      passwordConfirmation: _confirm.text,
      phone: _phone.text,
      documentTypeId: _typeId!,
      documentNumber: _document.text,
    );

    final token = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _CaptchaDialog(),
    );
    if (token == null || !mounted) return;

    setState(() => _sending = true);
    final result =
        await context.read<RegistrationProvider>().register(draft, token);
    if (!mounted) return;
    setState(() => _sending = false);

    if (result.error != null) {
      AppSnackbar.error(context, result.error!);
      return;
    }
    AppSnackbar.success(context, result.message!);
    Navigator.of(context).pop(draft.email.trim());
  }

  @override
  Widget build(BuildContext context) {
    final types = context.watch<RegistrationProvider>().documentTypes;
    final gap = const SizedBox(height: 16);

    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppConstants.defaultPadding * 1.5),
          children: [
            AppTextField(
              label: 'Nombres',
              controller: _names,
              textInputAction: TextInputAction.next,
              prefixIcon: Icons.person_outline,
              validator: (v) => Validators.required(v, 'tus nombres'),
            ),
            gap,
            AppTextField(
              label: 'Apellidos',
              controller: _lastNames,
              textInputAction: TextInputAction.next,
              prefixIcon: Icons.person_outline,
              validator: (v) => Validators.required(v, 'tus apellidos'),
            ),
            gap,
            AppTextField(
              label: 'Correo electrónico',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              prefixIcon: Icons.mail_outline,
              validator: Validators.email,
            ),
            gap,
            DropdownButtonFormField<int>(
              key: const Key('register-document-type'),
              initialValue: _typeId,
              decoration: InputDecoration(
                labelText: 'Tipo de documento',
                prefixIcon: const Icon(Icons.badge_outlined),
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppConstants.defaultBorderRadius),
                ),
              ),
              items: [
                for (final t in types)
                  DropdownMenuItem(value: t.id, child: Text(t.name)),
              ],
              onChanged: (v) => setState(() => _typeId = v),
              validator: (v) => v == null ? 'Elige el tipo de documento' : null,
            ),
            gap,
            AppTextField(
              label: 'Número de documento',
              controller: _document,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.next,
              prefixIcon: Icons.numbers,
              validator: (v) =>
                  validateRegisterDocument(_typeId ?? 0, v ?? ''),
            ),
            gap,
            AppTextField(
              label: 'Celular (opcional)',
              controller: _phone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              prefixIcon: Icons.phone_outlined,
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.isEmpty || RegExp(r'^9\d{8}$').hasMatch(t)) return null;
                return 'Debe tener 9 dígitos y empezar con 9';
              },
            ),
            gap,
            AppTextField(
              label: 'Contraseña',
              controller: _password,
              isPassword: true,
              textInputAction: TextInputAction.next,
              prefixIcon: Icons.lock_outline,
              validator: (v) => (v ?? '').length < 8
                  ? 'Debe tener al menos 8 caracteres'
                  : null,
            ),
            gap,
            AppTextField(
              label: 'Confirmar contraseña',
              controller: _confirm,
              isPassword: true,
              textInputAction: TextInputAction.done,
              prefixIcon: Icons.lock_outline,
              validator: (v) =>
                  v != _password.text ? 'Las contraseñas no coinciden' : null,
            ),
            const SizedBox(height: 24),
            AppButton(
              label: 'Continuar',
              isLoading: _sending,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

/// Pide un desafío, deja resolverlo y lo verifica. Cierra con el token
/// verificado, o null si se cancela.
class _CaptchaDialog extends StatefulWidget {
  const _CaptchaDialog();

  @override
  State<_CaptchaDialog> createState() => _CaptchaDialogState();
}

class _CaptchaDialogState extends State<_CaptchaDialog> {
  CaptchaChallenge? _challenge;
  List<int>? _order;
  String? _error;
  bool _loading = true;
  bool _verifying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _challenge = null;
    });
    final result = await context.read<RegistrationProvider>().newCaptcha();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _challenge = result.challenge;
      _order = result.challenge?.order;
      _error = result.error;
    });
  }

  Future<void> _confirm() async {
    final challenge = _challenge!;
    setState(() {
      _verifying = true;
      _error = null;
    });
    final error = await context
        .read<RegistrationProvider>()
        .verifyCaptcha(challenge.token, _order ?? challenge.order);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(challenge.token);
      return;
    }
    // Un desafío fallado o vencido no se reutiliza.
    setState(() => _verifying = false);
    await _load();
    if (mounted) setState(() => _error = error);
  }

  @override
  Widget build(BuildContext context) {
    final challenge = _challenge;
    return AlertDialog(
      title: const Text('Verificación'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Toca dos piezas para intercambiarlas y arma la imagen.',
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (challenge != null)
              CaptchaPuzzle(
                key: ValueKey(challenge.token),
                challenge: challenge,
                onChanged: (order) => _order = order,
              ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        if (challenge == null && !_loading)
          TextButton(onPressed: _load, child: const Text('Reintentar'))
        else
          FilledButton(
            onPressed: challenge == null || _verifying ? null : _confirm,
            child: _verifying
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Confirmar'),
          ),
      ],
    );
  }
}

/// Pide el correo y manda el enlace para cambiar la contraseña.
class ForgotPasswordPage extends StatefulWidget {
  final String? initialEmail;

  const ForgotPasswordPage({super.key, this.initialEmail});

  static Future<void> open(BuildContext context, {String? email}) =>
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ForgotPasswordPage(initialEmail: email),
        ),
      );

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail);
  bool _sending = false;
  String? _sent;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _sending = true);
    final result =
        await context.read<RegistrationProvider>().forgotPassword(_email.text);
    if (!mounted) return;
    setState(() {
      _sending = false;
      _sent = result.message;
    });
    if (result.error != null) AppSnackbar.error(context, result.error!);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar contraseña')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppConstants.defaultPadding * 1.5),
          children: [
            Icon(Icons.lock_reset, size: 64, color: scheme.primary),
            const SizedBox(height: 12),
            const Text(
              'Escribe el correo de tu cuenta y te enviaremos un enlace para '
              'elegir una contraseña nueva.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            AppTextField(
              label: 'Correo electrónico',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              prefixIcon: Icons.mail_outline,
              validator: Validators.email,
            ),
            const SizedBox(height: 24),
            AppButton(
              label: 'Enviar enlace',
              isLoading: _sending,
              onPressed: _submit,
            ),
            if (_sent != null) ...[
              const SizedBox(height: 16),
              Text(
                _sent!,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.primary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
