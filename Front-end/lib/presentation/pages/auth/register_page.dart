import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:test_tcc/core/theme/app_colors.dart';
import 'package:test_tcc/core/theme/app_spacing.dart';
import 'package:test_tcc/core/utils/email_validator.dart';
import 'package:test_tcc/domain/entities/user.dart';
import 'package:test_tcc/presentation/controllers/auth_controller.dart';
import 'package:test_tcc/presentation/widgets/app_text_field.dart';
import 'package:test_tcc/presentation/widgets/auth_hero.dart';
import 'package:test_tcc/presentation/widgets/error_banner.dart';
import 'package:test_tcc/presentation/widgets/primary_button.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _cpfController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarController = TextEditingController();

  DateTime? _dataNascimento;
  TipoUsuario _tipo = TipoUsuario.passageiro;
  bool _submitting = false;
  bool _tentouEnviar = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AuthController>().clearError();
    });
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _cpfController.dispose();
    _senhaController.dispose();
    _confirmarController.dispose();
    super.dispose();
  }

  Future<void> _selecionarData() async {
    final hoje = DateTime.now();
    final escolhida = await showDatePicker(
      context: context,
      initialDate:
          _dataNascimento ?? DateTime(hoje.year - 18, hoje.month, hoje.day),
      firstDate: DateTime(1900),
      lastDate: hoje,
      helpText: 'Data de nascimento',
    );
    if (escolhida != null) setState(() => _dataNascimento = escolhida);
  }

  Future<void> _handleSubmit() async {
    setState(() => _tentouEnviar = true);
    final formOk = _formKey.currentState!.validate();
    // Data não é um TextFormField; valida à parte.
    if (!formOk || _dataNascimento == null) return;

    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    final user = await context.read<AuthController>().register(
      name: _nomeController.text,
      email: _emailController.text,
      password: _senhaController.text,
      confirmPassword: _confirmarController.text,
      cpf: _cpfController.text,
      dataNascimento: _dataNascimento,
      tipo: _tipo,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (user != null) Navigator.pop<bool>(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final erro = context.watch<AuthController>().error;
    final dataFaltando = _tentouEnviar && _dataNascimento == null;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            const AuthHero(
              icon: Icons.person_add_alt_1,
              title: 'Crie sua conta',
              subtitle: 'Junte-se à comunidade de caronas',
              showBack: true,
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppTextField(
                      label: 'Nome completo',
                      controller: _nomeController,
                      icon: Icons.person_outline,
                      textInputAction: TextInputAction.next,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Informe seu nome.'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      label: 'E-mail',
                      controller: _emailController,
                      icon: Icons.mail_outline,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Informe seu e-mail.';
                        }
                        if (!isValidEmail(v)) return 'E-mail inválido.';
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      label: 'CPF (somente números)',
                      controller: _cpfController,
                      icon: Icons.badge_outlined,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(11),
                      ],
                      validator: (v) => (v == null || v.length != 11)
                          ? 'CPF deve ter 11 dígitos.'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _DateField(
                      data: _dataNascimento,
                      hasError: dataFaltando,
                      onTap: _selecionarData,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      label: 'Senha',
                      controller: _senhaController,
                      icon: Icons.lock_outline,
                      isPassword: true,
                      validator: (v) => (v == null || v.length < 8)
                          ? 'A senha deve ter ao menos 8 caracteres.'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      label: 'Confirmar senha',
                      controller: _confirmarController,
                      icon: Icons.lock_outline,
                      isPassword: true,
                      validator: (v) => (v != _senhaController.text)
                          ? 'As senhas não coincidem.'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _TipoSelector(
                      selecionado: _tipo,
                      onChanged: (t) => setState(() => _tipo = t),
                    ),
                    if (dataFaltando) ...[
                      const SizedBox(height: AppSpacing.lg),
                      const ErrorBanner(
                        message: 'Selecione sua data de nascimento.',
                      ),
                    ],
                    if (erro != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      ErrorBanner(message: erro),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    PrimaryButton(
                      label: 'Criar conta',
                      loading: _submitting,
                      onPressed: _handleSubmit,
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

class _DateField extends StatelessWidget {
  final DateTime? data;
  final bool hasError;
  final VoidCallback onTap;

  const _DateField({
    required this.data,
    required this.hasError,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final texto = data == null
        ? 'Data de nascimento'
        : '${data!.day.toString().padLeft(2, '0')}/${data!.month.toString().padLeft(2, '0')}/${data!.year}';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InputDecorator(
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.calendar_today_outlined),
          enabledBorder: hasError
              ? OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: const BorderSide(color: AppColors.error),
                )
              : null,
        ),
        child: Text(
          texto,
          style: TextStyle(
            fontSize: 16,
            color: data == null ? AppColors.textMuted : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _TipoSelector extends StatelessWidget {
  final TipoUsuario selecionado;
  final ValueChanged<TipoUsuario> onChanged;

  const _TipoSelector({required this.selecionado, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tipo de perfil', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            _opcao(TipoUsuario.passageiro, 'Passageiro', Icons.person),
            const SizedBox(width: AppSpacing.sm),
            _opcao(TipoUsuario.motorista, 'Motorista', Icons.drive_eta),
            const SizedBox(width: AppSpacing.sm),
            _opcao(TipoUsuario.ambos, 'Ambos', Icons.swap_horiz),
          ],
        ),
      ],
    );
  }

  Widget _opcao(TipoUsuario tipo, String label, IconData icon) {
    final ativo = selecionado == tipo;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(tipo),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          decoration: BoxDecoration(
            color: ativo ? AppColors.primarySoft : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: ativo ? AppColors.primary : AppColors.border,
              width: ativo ? 1.6 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: ativo ? AppColors.primary : AppColors.textMuted,
                size: 22,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: ativo ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
