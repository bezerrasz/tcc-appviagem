import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:test_tcc/core/theme/app_colors.dart';
import 'package:test_tcc/core/theme/app_spacing.dart';
import 'package:test_tcc/presentation/controllers/auth_controller.dart';
import 'package:test_tcc/presentation/pages/auth/register_page.dart';
import 'package:test_tcc/presentation/widgets/app_text_field.dart';
import 'package:test_tcc/presentation/widgets/auth_hero.dart';
import 'package:test_tcc/presentation/widgets/error_banner.dart';
import 'package:test_tcc/presentation/widgets/primary_button.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AuthController>().clearError();
    });
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _submitting = false);
    setState(() => _submitting = true);
    await context.read<AuthController>().login(
      identifier: _identifierController.text,
      password: _senhaController.text,
    );
    if (mounted) setState(() => _submitting = false);
  }

  Future<void> _abrirCadastro() async {
    final criado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const RegisterPage()),
    );
    if (!mounted || criado != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Conta criada com sucesso! Faça login.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final erro = context.watch<AuthController>().error;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const AuthHero(
              icon: Icons.directions_car_filled,
              title: 'Share a Ride',
              subtitle: 'Conecte-se e economize nas suas viagens',
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppTextField(
                      label: 'E-mail ou nome de usuário',
                      controller: _identifierController,
                      icon: Icons.person_outline,
                      textInputAction: TextInputAction.next,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Informe seu e-mail ou nome de usuário.'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      label: 'Senha',
                      controller: _senhaController,
                      icon: Icons.lock_outline,
                      isPassword: true,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _handleLogin(),
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Informe sua senha.'
                          : null,
                    ),
                    if (erro != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      ErrorBanner(message: erro),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    PrimaryButton(
                      label: 'Entrar',
                      loading: _submitting,
                      onPressed: _handleLogin,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                          ),
                          child: Text(
                            'Novo por aqui?',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SecondaryButton(
                      label: 'Criar nova conta',
                      icon: Icons.person_add_alt,
                      onPressed: _submitting ? null : _abrirCadastro,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
