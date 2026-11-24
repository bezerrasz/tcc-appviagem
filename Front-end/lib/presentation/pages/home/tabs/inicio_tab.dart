import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:test_tcc/core/theme/app_colors.dart';
import 'package:test_tcc/core/theme/app_spacing.dart';
import 'package:test_tcc/core/theme/app_typography.dart';
import 'package:test_tcc/core/utils/formatters.dart';
import 'package:test_tcc/core/utils/greeting.dart';
import 'package:test_tcc/domain/entities/user.dart';
import 'package:test_tcc/domain/entities/resumo_financeiro.dart';
import 'package:test_tcc/presentation/controllers/auth_controller.dart';
import 'package:test_tcc/presentation/controllers/financeiro_controller.dart';
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
              _Saldos(user: user),
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

/// Saldos do usuário conforme o tipo: passageiro vê o total pago; motorista
/// vê o total recebido e o que ainda tem a receber (por passageiro e carona);
/// "ambos" vê tudo. Somente leitura: os valores só mudam quando um
/// comprovante Pix é importado.
class _Saldos extends StatelessWidget {
  final User user;

  const _Saldos({required this.user});

  @override
  Widget build(BuildContext context) {
    final fin = context.watch<FinanceiroController>();
    final resumo = fin.resumo;
    // Enquanto o resumo não chega, usa os saldos que vieram no login.
    final saldoPago = resumo?.saldoPago ?? user.saldoPago;
    final saldoRecebido = resumo?.saldoRecebido ?? user.saldoRecebido;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (fin.error != null && resumo == null) ...[
          AppCard(
            onTap: fin.carregar,
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: AppColors.error),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    '${fin.error} Toque para tentar de novo.',
                    style: AppTypography.caption,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (user.pagaCaronas) ...[
          _CardValor(
            icone: Icons.north_east,
            titulo: 'Total pago em caronas',
            valor: saldoPago,
          ),
          if (user.recebeCaronas) const SizedBox(height: AppSpacing.md),
        ],
        if (user.recebeCaronas) ...[
          _CardValor(
            icone: Icons.south_west,
            titulo: 'Total recebido em caronas',
            valor: saldoRecebido,
            cor: AppColors.success,
          ),
          const SizedBox(height: AppSpacing.md),
          _CardAReceber(
            resumo: resumo,
            carregando: fin.loading && resumo == null,
          ),
        ],
      ],
    );
  }
}

class _CardValor extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final double valor;
  final Color cor;

  const _CardValor({
    required this.icone,
    required this.titulo,
    required this.valor,
    this.cor = AppColors.primary,
  });

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
            child: Icon(icone, color: cor),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: AppTypography.caption),
                const SizedBox(height: 2),
                Text(
                  formatMoeda(valor),
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

/// Pagamentos pendentes das caronas concluídas que o usuário conduziu: uma
/// linha por passageiro e carona, o total pendente e o total geral
/// (recebido + a receber).
class _CardAReceber extends StatelessWidget {
  final ResumoFinanceiro? resumo;
  final bool carregando;

  const _CardAReceber({required this.resumo, required this.carregando});

  String _data(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final r = resumo;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule, color: AppColors.warning, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text('A receber', style: AppTypography.label),
              ),
              if (r != null && r.aReceber.isNotEmpty)
                Text(
                  '${r.aReceber.length} pendente(s)',
                  style: AppTypography.caption,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (carregando)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (r == null)
            Text('Não foi possível carregar.', style: AppTypography.caption)
          else ...[
            if (r.aReceber.isEmpty)
              Text(
                'Nenhum pagamento pendente.',
                style: AppTypography.caption,
              )
            else
              ...r.aReceber.map(
                (i) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              i.passageiroNome,
                              style: AppTypography.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              [
                                _data(i.data),
                                if (i.destino != null && i.destino!.isNotEmpty)
                                  i.destino!,
                                if (i.grupoNome != null) i.grupoNome!,
                              ].join(' • '),
                              style: AppTypography.caption,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(formatMoeda(i.valor), style: AppTypography.label),
                    ],
                  ),
                ),
              ),
            const Divider(height: AppSpacing.xl),
            _LinhaTotal(rotulo: 'Total pendente', valor: r.totalAReceber),
            const SizedBox(height: AppSpacing.xs),
            _LinhaTotal(
              rotulo: 'Recebido + a receber',
              valor: r.totalGeral,
              destaque: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _LinhaTotal extends StatelessWidget {
  final String rotulo;
  final double valor;
  final bool destaque;

  const _LinhaTotal({
    required this.rotulo,
    required this.valor,
    this.destaque = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            rotulo,
            style: destaque ? AppTypography.label : AppTypography.caption,
          ),
        ),
        Text(
          formatMoeda(valor),
          style: destaque
              ? const TextStyle(
                  color: AppColors.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                )
              : AppTypography.label,
        ),
      ],
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
