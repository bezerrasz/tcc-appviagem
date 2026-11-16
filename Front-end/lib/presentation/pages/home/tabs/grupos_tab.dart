import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:test_tcc/core/theme/app_colors.dart';
import 'package:test_tcc/core/theme/app_spacing.dart';
import 'package:test_tcc/core/theme/app_typography.dart';
import 'package:test_tcc/domain/entities/grupo.dart';
import 'package:test_tcc/domain/repositories/chat_repository.dart';
import 'package:test_tcc/presentation/controllers/auth_controller.dart';
import 'package:test_tcc/presentation/controllers/grupo_controller.dart';
import 'package:test_tcc/presentation/controllers/grupo_detalhe_controller.dart';
import 'package:test_tcc/presentation/pages/grupos/criar_grupo_page.dart';
import 'package:test_tcc/presentation/pages/grupos/grupo_detalhe_page.dart';
import 'package:test_tcc/presentation/widgets/app_card.dart';
import 'package:test_tcc/presentation/widgets/state_views.dart';
import 'package:test_tcc/presentation/widgets/status_badge.dart';

class GruposTab extends StatelessWidget {
  const GruposTab({super.key});

  Future<void> _criarGrupo(BuildContext context) async {
    final grupo = await Navigator.push<Grupo>(
      context,
      MaterialPageRoute(builder: (_) => const CriarGrupoPage()),
    );
    if (grupo == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Grupo "${grupo.nome}" criado!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GrupoController>();

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.md,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Meus grupos', style: AppTypography.headline),
                FilledButton.tonalIcon(
                  onPressed: () => _criarGrupo(context),
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('Criar'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primarySoft,
                    foregroundColor: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: controller.carregar,
              child: _buildLista(context, controller),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLista(BuildContext context, GrupoController controller) {
    if (controller.loading && !controller.carregouUmaVez) {
      return ListView(children: const [LoadingView()]);
    }
    if (controller.error != null) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        children: [
          ErrorView(message: controller.error!, onRetry: controller.carregar),
        ],
      );
    }
    if (controller.grupos.isEmpty) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        children: [
          EmptyState(
            icon: Icons.groups_outlined,
            title: 'Nenhum grupo ainda',
            message: 'Crie seu primeiro grupo para começar a organizar caronas.',
            actionLabel: 'Criar grupo',
            onAction: () => _criarGrupo(context),
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      itemCount: controller.grupos.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (_, i) => _GrupoCard(grupo: controller.grupos[i]),
    );
  }
}

class _GrupoCard extends StatelessWidget {
  final Grupo grupo;

  const _GrupoCard({required this.grupo});

  void _abrir(BuildContext context) {
    // Captura as dependências do escopo autenticado antes de empurrar a rota.
    final repo = context.read<ChatRepository>();
    final userId = context.read<AuthController>().currentUser?.idUsuario;
    if (userId == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        // Controller com escopo da tela: descartado (e socket desconectado)
        // automaticamente ao sair, pelo ChangeNotifierProvider.
        builder: (_) => ChangeNotifierProvider(
          create: (_) => GrupoDetalheController(
            repo: repo,
            idGrupo: grupo.idGrupo,
            currentUserId: userId,
          )..iniciar(),
          child: GrupoDetalhePage(grupo: grupo),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => _abrir(context),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(
              Icons.groups_outlined,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              grupo.nome,
              style: AppTypography.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (grupo.isAdm)
            const StatusBadge(label: 'Admin', icon: Icons.shield_outlined),
        ],
      ),
    );
  }
}
