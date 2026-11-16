import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:test_tcc/core/theme/app_spacing.dart';
import 'package:test_tcc/core/theme/app_typography.dart';
import 'package:test_tcc/domain/entities/grupo.dart';
import 'package:test_tcc/domain/failures/grupo_failure.dart';
import 'package:test_tcc/presentation/controllers/grupo_controller.dart';
import 'package:test_tcc/presentation/widgets/app_text_field.dart';
import 'package:test_tcc/presentation/widgets/error_banner.dart';
import 'package:test_tcc/presentation/widgets/primary_button.dart';

class CriarGrupoPage extends StatefulWidget {
  const CriarGrupoPage({super.key});

  @override
  State<CriarGrupoPage> createState() => _CriarGrupoPageState();
}

class _CriarGrupoPageState extends State<CriarGrupoPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  bool _submitting = false;
  String? _erro;

  @override
  void dispose() {
    _nomeController.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _erro = null;
    });
    try {
      final grupo = await context.read<GrupoController>().criar(
            nome: _nomeController.text,
          );
      if (!mounted) return;
      Navigator.pop<Grupo>(context, grupo);
    } on GrupoFailure catch (f) {
      if (!mounted) return;
      setState(() {
        _erro = f.message;
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Criar grupo')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Crie um grupo para organizar as caronas com seus colegas.',
                style: AppTypography.body,
              ),
              const SizedBox(height: AppSpacing.xl),
              AppTextField(
                label: 'Nome do grupo',
                controller: _nomeController,
                icon: Icons.groups_outlined,
                hint: 'Ex: Unoesc Noturno - Eng. Computação',
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _confirmar(),
                validator: (v) => (v == null || v.trim().length < 3)
                    ? 'O nome deve ter ao menos 3 caracteres.'
                    : null,
              ),
              if (_erro != null) ...[
                const SizedBox(height: AppSpacing.lg),
                ErrorBanner(message: _erro!),
              ],
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                label: 'Criar grupo',
                loading: _submitting,
                onPressed: _confirmar,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
