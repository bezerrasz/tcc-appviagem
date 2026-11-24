import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:test_tcc/core/theme/app_colors.dart';
import 'package:test_tcc/core/theme/app_spacing.dart';
import 'package:test_tcc/core/theme/app_typography.dart';
import 'package:test_tcc/data/datasources/session_socket_service.dart';
import 'package:test_tcc/domain/entities/carona_item.dart';
import 'package:test_tcc/domain/entities/carona_resumo.dart';
import 'package:test_tcc/domain/repositories/carona_repository.dart';
import 'package:test_tcc/presentation/controllers/auth_controller.dart';
import 'package:test_tcc/presentation/controllers/carona_controller.dart';
import 'package:test_tcc/presentation/controllers/carona_detalhe_controller.dart';
import 'package:test_tcc/presentation/pages/caronas/carona_detalhe_page.dart';
import 'package:test_tcc/presentation/widgets/app_card.dart';
import 'package:test_tcc/presentation/widgets/carona_status_badge.dart';
import 'package:test_tcc/presentation/widgets/state_views.dart';

/// Aba "Caronas" (só para motorista/ambos): relação das viagens do usuário
/// com seus status. O GET é disparado pelo HomeShell sempre que a aba é aberta.
class CaronasTab extends StatelessWidget {
  const CaronasTab({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CaronaController>();

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.md,
            ),
            child: Text('Minhas caronas', style: AppTypography.headline),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: controller.carregar,
              child: _buildLista(controller),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLista(CaronaController controller) {
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
    if (controller.caronas.isEmpty) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        children: const [
          EmptyState(
            icon: Icons.directions_car_outlined,
            title: 'Nenhuma carona ainda',
            message:
                'Quando você pedir ou aceitar uma carona, ela aparece aqui.',
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
      itemCount: controller.caronas.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (_, i) => _CaronaItemCard(item: controller.caronas[i]),
    );
  }
}

class _CaronaItemCard extends StatelessWidget {
  final CaronaItem item;

  const _CaronaItemCard({required this.item});

  String get _data {
    final d = item.data;
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$dd/$mm • $hh:$min';
  }

  String get _subtitulo {
    if (item.papel == PapelCarona.motorista) {
      final vagas =
          item.lugares == null ? '' : ' • ${item.ocupadas}/${item.lugares} vagas';
      return 'Você é o motorista$vagas';
    }
    final status = item.meuStatus;
    final label = status == null ? '—' : status.label;
    return 'Passageiro • pedido: $label';
  }

  Future<void> _abrir(BuildContext context) async {
    final repo = context.read<CaronaRepository>();
    final sessionSocket = context.read<SessionSocketService>();
    final userId = context.read<AuthController>().currentUser?.idUsuario;
    final lista = context.read<CaronaController>();
    if (userId == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => CaronaDetalheController(
            repo: repo,
            idCarona: item.idCarona,
            currentUserId: userId,
            sessionSocket: sessionSocket,
          )..iniciar(),
          child: const CaronaDetalhePage(),
        ),
      ),
    );
    // Status pode ter mudado no detalhe (concluir/cancelar): atualiza a lista.
    await lista.carregar();
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
            child: const Icon(Icons.directions_car, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.grupoNome,
                  style: AppTypography.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.destino != null && item.destino!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    '→ ${item.destino}',
                    style: AppTypography.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  _subtitulo,
                  style: AppTypography.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(_data, style: AppTypography.caption),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          CaronaStatusBadge(status: item.status),
        ],
      ),
    );
  }
}
