import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:test_tcc/core/theme/app_colors.dart';
import 'package:test_tcc/core/theme/app_spacing.dart';
import 'package:test_tcc/core/theme/app_typography.dart';
import 'package:test_tcc/core/utils/formatters.dart';
import 'package:test_tcc/core/utils/greeting.dart';
import 'package:test_tcc/domain/entities/user.dart';
import 'package:test_tcc/presentation/controllers/auth_controller.dart';
import 'package:test_tcc/presentation/controllers/grupo_controller.dart';
import 'package:test_tcc/presentation/pages/grupos/criar_grupo_page.dart';
import 'package:test_tcc/presentation/widgets/app_card.dart';
import 'package:test_tcc/presentation/widgets/section_header.dart';
import 'package:test_tcc/presentation/widgets/status_badge.dart';

class InicioTab extends StatelessWidget {
  final VoidCallback onVerGrupos;

  const InicioTab({super.key, required this.onVerGrupos});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().currentUser;
    final totalGrupos = context.watch<GrupoController>().grupos.length;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Saudacao(user: user),
            const SizedBox(height: AppSpacing.xl),
            if (user != null) ...[
              _CardSaldo(user: user),
              const SizedBox(height: AppSpacing.xl),
            ],
            const SectionHeader(title: 'Ações rápidas'),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CriarGrupoPage()),
              ),
              child: const _AcaoTile(
                icon: Icons.add_circle_outline,
                titulo: 'Criar grupo',
                subtitulo: 'Organize caronas com seus colegas',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              onTap: onVerGrupos,
              child: _AcaoTile(
                icon: Icons.groups_outlined,
                titulo: 'Meus grupos',
                subtitulo: totalGrupos == 0
                    ? 'Você ainda não participa de nenhum'
                    : '$totalGrupos grupo(s) ativo(s)',
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const _CardConvite(),
          ],
        ),
      ),
    );
  }
}

class _Saudacao extends StatelessWidget {
  final User? user;

  const _Saudacao({required this.user});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: AppColors.primarySoft,
          child: const Icon(Icons.person, color: AppColors.primary, size: 28),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(getGreeting(), style: AppTypography.caption),
              const SizedBox(height: 2),
              Text(
                user?.name ?? 'Bem-vindo',
                style: AppTypography.headline,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (user != null)
          StatusBadge(label: user!.tipo.label, icon: Icons.verified_user),
      ],
    );
  }
}

/// Indicador do saldo do usuário. Somente leitura (atualizado via Pix pelo backend).
class _CardSaldo extends StatelessWidget {
  final User user;

  const _CardSaldo({required this.user});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Meu saldo', style: AppTypography.caption),
                const SizedBox(height: 2),
                Text(
                  formatMoeda(user.valor),
                  style: AppTypography.headline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AcaoTile extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final String subtitulo;

  const _AcaoTile({
    required this.icon,
    required this.titulo,
    required this.subtitulo,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(icon, color: AppColors.primary),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: AppTypography.label),
              const SizedBox(height: 2),
              Text(subtitulo, style: AppTypography.caption),
            ],
          ),
        ),
        const Icon(Icons.chevron_right, color: AppColors.textMuted),
      ],
    );
  }
}

class _CardConvite extends StatelessWidget {
  const _CardConvite();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.eco, color: Colors.white, size: 28),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Caronas que conectam',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Divida trajetos, economize e reduza o trânsito junto com a sua comunidade.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
          ),
        ],
      ),
    );
  }
}
