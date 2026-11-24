import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:test_tcc/core/theme/app_colors.dart';
import 'package:test_tcc/core/theme/app_spacing.dart';
import 'package:test_tcc/core/theme/app_typography.dart';
import 'package:test_tcc/core/utils/formatters.dart';
import 'package:test_tcc/domain/entities/user.dart';
import 'package:test_tcc/presentation/controllers/auth_controller.dart';
import 'package:test_tcc/presentation/controllers/carro_controller.dart';
import 'package:test_tcc/presentation/pages/perfil/carros_page.dart';
import 'package:test_tcc/presentation/widgets/app_card.dart';
import 'package:test_tcc/presentation/widgets/status_badge.dart';
import 'package:test_tcc/presentation/widgets/user_avatar.dart';

class PerfilTab extends StatefulWidget {
  const PerfilTab({super.key});

  @override
  State<PerfilTab> createState() => _PerfilTabState();
}

class _PerfilTabState extends State<PerfilTab> {
  // O GET dos carros (para exibir o carro ativo) é disparado pelo HomeShell
  // sempre que a aba Perfil é aberta.

  bool _enviandoFoto = false;

  /// Abre a galeria (no navegador, o seletor de arquivos) e envia a imagem.
  /// A imagem é reduzida para no máximo 1024px antes do upload.
  Future<void> _trocarFoto() async {
    if (_enviandoFoto) return;
    final XFile? arquivo;
    try {
      arquivo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
    } catch (_) {
      _feedback(false, '', 'Não foi possível abrir a galeria.');
      return;
    }
    if (arquivo == null || !mounted) return;

    final auth = context.read<AuthController>();
    setState(() => _enviandoFoto = true);
    try {
      final bytes = await arquivo.readAsBytes();
      final ok = await auth.atualizarFoto(bytes);
      _feedback(ok, 'Foto de perfil atualizada.', auth.error);
    } catch (_) {
      _feedback(false, '', 'Não foi possível ler a imagem escolhida.');
    } finally {
      if (mounted) setState(() => _enviandoFoto = false);
    }
  }

  Future<void> _editarEmail(User user) async {
    final controller = TextEditingController(text: user.email);
    final novo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar e-mail'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'E-mail'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (novo == null || novo.isEmpty || novo == user.email || !mounted) return;
    final auth = context.read<AuthController>();
    final ok = await auth.atualizarPerfil(email: novo);
    _feedback(ok, 'E-mail atualizado.', auth.error);
  }

  Future<void> _editarDataNascimento(User user) async {
    final hoje = DateTime.now();
    final escolhida = await showDatePicker(
      context: context,
      initialDate: user.dataNascimento,
      firstDate: DateTime(1900),
      // Mínimo de 18 anos (o backend revalida).
      lastDate: DateTime(hoje.year - 18, hoje.month, hoje.day),
      helpText: 'Data de nascimento',
    );
    if (escolhida == null || !mounted) return;
    final auth = context.read<AuthController>();
    final ok = await auth.atualizarPerfil(dataNascimento: escolhida);
    _feedback(ok, 'Data de nascimento atualizada.', auth.error);
  }

  void _feedback(bool ok, String sucesso, String? erro) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? sucesso : (erro ?? 'Não foi possível salvar.'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().currentUser;
    final carroAtivo = context.watch<CarroController>().carroAtivo;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.lg),
            _AvatarEditavel(
              fotoPerfil: user?.fotoPerfil,
              enviando: _enviandoFoto,
              onTap: user == null ? null : _trocarFoto,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              user?.name ?? 'Usuário',
              style: AppTypography.headline,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(user?.email ?? '', style: AppTypography.body),
            const SizedBox(height: AppSpacing.md),
            if (user != null) StatusBadge(label: user.tipo.label),
            const SizedBox(height: AppSpacing.xl),
            if (user != null)
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _InfoRow(
                      icon: Icons.badge_outlined,
                      label: 'Tipo de conta',
                      value: user.tipo.label,
                    ),
                    const Divider(height: 1),
                    _InfoRow(
                      icon: Icons.cake_outlined,
                      label: 'Data de nascimento',
                      value: formatData(user.dataNascimento),
                      onEdit: () => _editarDataNascimento(user),
                    ),
                    const Divider(height: 1),
                    _InfoRow(
                      icon: Icons.mail_outline,
                      label: 'E-mail',
                      value: user.email,
                      onEdit: () => _editarEmail(user),
                    ),
                    const Divider(height: 1),
                    _InfoRow(
                      icon: Icons.directions_car_outlined,
                      label: 'Carro',
                      value: carroAtivo != null
                          ? '${carroAtivo.descricao} • ${carroAtivo.placa}'
                          : 'Nenhum carro ativo',
                      onEdit: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CarrosPage()),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.xl),
            OutlinedButton.icon(
              onPressed: () => context.read<AuthController>().logout(),
              icon: const Icon(Icons.logout, size: 20),
              label: const Text('Sair da conta'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Avatar da tela de perfil com o selo de câmera para trocar a foto.
class _AvatarEditavel extends StatelessWidget {
  final String? fotoPerfil;
  final bool enviando;
  final VoidCallback? onTap;

  const _AvatarEditavel({
    required this.fotoPerfil,
    required this.enviando,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Alterar foto de perfil',
      child: GestureDetector(
        onTap: enviando ? null : onTap,
        child: Stack(
          alignment: Alignment.center,
          children: [
            UserAvatar(fotoPerfil: fotoPerfil),
            if (enviando)
              const SizedBox(
                width: 88,
                height: 88,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.photo_camera_outlined,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onEdit;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textMuted, size: 20),
          const SizedBox(width: AppSpacing.md),
          Text(label, style: AppTypography.body),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: AppTypography.label,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onEdit != null)
            IconButton(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 18),
              color: AppColors.primary,
              tooltip: 'Editar',
              visualDensity: VisualDensity.compact,
            )
          else
            const SizedBox(width: AppSpacing.md),
        ],
      ),
    );
  }
}
