import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:test_tcc/core/config/app_constants.dart';
import 'package:test_tcc/core/theme/app_colors.dart';
import 'package:test_tcc/core/theme/app_spacing.dart';
import 'package:test_tcc/core/theme/app_typography.dart';
import 'package:test_tcc/core/utils/formatters.dart';
import 'package:test_tcc/domain/entities/carona_detalhe.dart';
import 'package:test_tcc/domain/entities/carona_resumo.dart';
import 'package:test_tcc/presentation/controllers/carona_detalhe_controller.dart';
import 'package:test_tcc/presentation/widgets/app_card.dart';
import 'package:test_tcc/presentation/widgets/carona_status_badge.dart';
import 'package:test_tcc/presentation/widgets/state_views.dart';
import 'package:test_tcc/presentation/widgets/status_badge.dart';

/// Detalhe de uma carona: motorista + carro + custos/Pix reais + passageiros.
class CaronaDetalhePage extends StatefulWidget {
  const CaronaDetalhePage({super.key});

  @override
  State<CaronaDetalhePage> createState() => _CaronaDetalhePageState();
}

class _CaronaDetalhePageState extends State<CaronaDetalhePage> {
  bool _comprovanteEnviado = false;
  String? _chavePixSalva;
  final Set<int> _passageirosPixConfirmado = {};

  String _data(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year} • $hh:$min';
  }

  String? _obterChavePix(CaronaDetalhe detalhe) {
    if (_chavePixSalva != null && _chavePixSalva!.trim().isNotEmpty) {
      return _chavePixSalva!.trim();
    }
    try {
      final dyn = detalhe as dynamic;
      final p = dyn.motoristaPix ?? dyn.chavePix;
      if (p is String && p.trim().isNotEmpty) return p.trim();
    } catch (_) {}
    return detalhe.motoristaNome;
  }

  Future<void> _pedir(CaronaDetalheController c) async {
    final ok = await c.pedir();
    _feedback(c, ok, 'Pedido enviado. Aguarde o motorista aprovar.');
  }

  Future<void> _cancelarPedido(CaronaDetalheController c) async {
    final ok = await c.cancelarPedido();
    _feedback(c, ok, 'Pedido cancelado.');
  }

  Future<void> _decidir(
    CaronaDetalheController c,
    PassageiroCarona p,
    bool aprovar,
  ) async {
    final ok = await c.decidir(idPassageiro: p.idUsuario, aprovar: aprovar);
    if (!mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(c.error ?? 'Não foi possível decidir o pedido.')),
    );
  }

  Future<void> _editarCustos(CaronaDetalheController c) async {
    final detalhe = c.detalhe;
    final custos = detalhe?.custos;
    final kmController = TextEditingController(
      text: _decimal(custos?.kmRodados),
    );
    final litroController = TextEditingController(
      text: _decimal(custos?.valorLitro),
    );
    final pixController = TextEditingController(
      text: detalhe != null ? (_obterChavePix(detalhe) ?? '') : '',
    );

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Custos da viagem e Chave Pix'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Informe a distância (km), o valor do litro do combustível e '
                'sua chave Pix para receber dos passageiros.',
                style: AppTypography.caption,
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: kmController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Km rodados',
                  suffixText: 'km',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: litroController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Valor do litro',
                  prefixText: 'R\$ ',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: pixController,
                decoration: const InputDecoration(
                  labelText: 'Sua Chave Pix',
                  hintText: 'CPF, celular, e-mail ou chave aleatória',
                  prefixIcon: Icon(Icons.pix, size: 18),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (confirmou != true || !mounted) return;

    final km = parseMoeda(kmController.text);
    final litro = parseMoeda(litroController.text);
    final novaChavePix = pixController.text.trim();

    if (km == null ||
        km < AppConstants.caronaKmMin ||
        km > AppConstants.caronaKmMax) {
      _aviso(
        'Informe os km rodados (até ${AppConstants.caronaKmMax.toInt()} km).',
      );
      return;
    }
    if (litro == null ||
        litro < AppConstants.caronaValorLitroMin ||
        litro > AppConstants.caronaValorLitroMax) {
      _aviso(
        'Informe o valor do litro (até '
        '${formatMoeda(AppConstants.caronaValorLitroMax)}).',
      );
      return;
    }

    if (novaChavePix.isNotEmpty) {
      setState(() => _chavePixSalva = novaChavePix);
    }

    final ok = await c.atualizarCustos(kmRodados: km, valorLitro: litro);
    _feedback(c, ok, 'Custos e Chave Pix atualizados.');
  }

  String _decimal(double? valor) =>
      valor == null ? '' : valor.toStringAsFixed(2).replaceAll('.', ',');

  void _aviso(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensagem)));
  }

  Future<void> _concluir(CaronaDetalheController c) async {
    final ok = await _confirmar(
      titulo: 'Concluir carona?',
      mensagem:
          'Marcar esta carona como concluída e transferir o saldo pendente?',
      acao: 'Concluir',
    );
    if (ok != true) return;
    final feito = await c.concluir();
    _feedback(c, feito, 'Carona concluída e saldo atualizado!');
  }

  Future<void> _cancelar(CaronaDetalheController c) async {
    final ok = await _confirmar(
      titulo: 'Cancelar carona?',
      mensagem: 'Esta ação não pode ser desfeita.',
      acao: 'Cancelar carona',
      destrutivo: true,
    );
    if (ok != true) return;
    final feito = await c.cancelar();
    _feedback(c, feito, 'Carona cancelada.');
  }

  Future<bool?> _confirmar({
    required String titulo,
    required String mensagem,
    required String acao,
    bool destrutivo = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: Text(mensagem),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: destrutivo
                ? FilledButton.styleFrom(backgroundColor: AppColors.error)
                : null,
            child: Text(acao),
          ),
        ],
      ),
    );
  }

  void _feedback(CaronaDetalheController c, bool ok, String sucesso) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? sucesso : (c.error ?? 'Não foi possível concluir a ação.'),
        ),
      ),
    );
  }

  void _copiarChavePix(String? chave) {
    if (chave == null || chave.isEmpty) {
      _aviso('O motorista não cadastrou uma chave Pix.');
      return;
    }
    Clipboard.setData(ClipboardData(text: chave));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Chave Pix "$chave" copiada para a área de transferência!',
        ),
      ),
    );
  }

  void _passageiroAvisarPix() {
    setState(() => _comprovanteEnviado = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Aviso de Pix enviado! O motorista irá confirmar o recebimento.',
        ),
      ),
    );
  }

  Future<void> _motoristaConfirmarPixPassageiro(
    CaronaDetalheController c,
    PassageiroCarona p,
  ) async {
    setState(() => _passageirosPixConfirmado.add(p.idUsuario));
    try {
      final dyn = c as dynamic;
      await dyn.confirmarPagamentoPix(p.idUsuario);
    } catch (_) {
      // Se o método ainda não existir no controller do Flutter, o concluir() transfere o saldo no banco
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Pix de ${p.nome} confirmado pelo motorista!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CaronaDetalheController>();
    final detalhe = c.detalhe;

    return Scaffold(
      appBar: AppBar(title: const Text('Carona')),
      body: c.loading
          ? const LoadingView()
          : detalhe == null
          ? ErrorView(
              message: c.error ?? 'Não foi possível carregar a carona.',
              onRetry: c.iniciar,
            )
          : Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: c.iniciar,
                    child: _Conteudo(
                      controller: c,
                      detalhe: detalhe,
                      dataLabel: _data(detalhe.data),
                      chavePixMotorista: _obterChavePix(detalhe),
                      comprovanteEnviado: _comprovanteEnviado,
                      passageirosPixConfirmado: _passageirosPixConfirmado,
                      onDecidir: (p, aprovar) => _decidir(c, p, aprovar),
                      onEditarCustos: () => _editarCustos(c),
                      onCopiarPix: _copiarChavePix,
                      onPassageiroAvisarPix: _passageiroAvisarPix,
                      onMotoristaConfirmarPix: (p) =>
                          _motoristaConfirmarPixPassageiro(c, p),
                    ),
                  ),
                ),
                _AcoesBar(
                  controller: c,
                  onPedir: () => _pedir(c),
                  onCancelarPedido: () => _cancelarPedido(c),
                  onConcluir: () => _concluir(c),
                  onCancelar: () => _cancelar(c),
                ),
              ],
            ),
    );
  }
}

class _AcoesBar extends StatelessWidget {
  final CaronaDetalheController controller;
  final VoidCallback onPedir;
  final VoidCallback onCancelarPedido;
  final VoidCallback onConcluir;
  final VoidCallback onCancelar;

  const _AcoesBar({
    required this.controller,
    required this.onPedir,
    required this.onCancelarPedido,
    required this.onConcluir,
    required this.onCancelar,
  });

  @override
  Widget build(BuildContext context) {
    final podePedir = controller.podePedir;
    final podeCancelarPedido = controller.podeCancelarPedido;
    final podeConcluir = controller.podeConcluir;
    final podeCancelar = controller.podeCancelar;
    if (!podePedir && !podeCancelarPedido && !podeConcluir && !podeCancelar) {
      return const SizedBox.shrink();
    }

    final agindo = controller.agindo;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (podePedir)
              Expanded(
                child: FilledButton.icon(
                  onPressed: agindo ? null : onPedir,
                  icon: const Icon(Icons.front_hand_outlined, size: 18),
                  label: const Text('Pedir carona'),
                ),
              ),
            if (podeCancelarPedido)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: agindo ? null : onCancelarPedido,
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Cancelar meu pedido'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                ),
              ),
            if (podeCancelar)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: agindo ? null : onCancelar,
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Cancelar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                ),
              ),
            if (podeCancelar && podeConcluir)
              const SizedBox(width: AppSpacing.md),
            if (podeConcluir)
              Expanded(
                child: FilledButton.icon(
                  onPressed: agindo ? null : onConcluir,
                  icon: agindo
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.onPrimary,
                          ),
                        )
                      : const Icon(Icons.check, size: 18),
                  label: const Text('Concluir'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Conteudo extends StatelessWidget {
  final CaronaDetalheController controller;
  final CaronaDetalhe detalhe;
  final String dataLabel;
  final String? chavePixMotorista;
  final bool comprovanteEnviado;
  final Set<int> passageirosPixConfirmado;
  final void Function(PassageiroCarona, bool aprovar) onDecidir;
  final VoidCallback onEditarCustos;
  final ValueChanged<String?> onCopiarPix;
  final VoidCallback onPassageiroAvisarPix;
  final ValueChanged<PassageiroCarona> onMotoristaConfirmarPix;

  const _Conteudo({
    required this.controller,
    required this.detalhe,
    required this.dataLabel,
    required this.chavePixMotorista,
    required this.comprovanteEnviado,
    required this.passageirosPixConfirmado,
    required this.onDecidir,
    required this.onEditarCustos,
    required this.onCopiarPix,
    required this.onPassageiroAvisarPix,
    required this.onMotoristaConfirmarPix,
  });

  @override
  Widget build(BuildContext context) {
    final passageiros = detalhe.passageiros;
    final souMotorista = controller.souMotorista;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                detalhe.grupoNome,
                style: AppTypography.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            CaronaStatusBadge(status: detalhe.status),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(dataLabel, style: AppTypography.caption),
        if (detalhe.destino != null && detalhe.destino!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const Icon(
                Icons.place_outlined,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(detalhe.destino!, style: AppTypography.label),
              ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.xl),

        Text('Motorista', style: AppTypography.label),
        const SizedBox(height: AppSpacing.sm),
        _PessoaCard(
          nome: detalhe.motoristaNome ?? 'Motorista',
          icone: Icons.drive_eta,
        ),
        const SizedBox(height: AppSpacing.xl),

        if (detalhe.carro != null) ...[
          Text('Carro', style: AppTypography.label),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Icon(
                    Icons.directions_car,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        detalhe.carro!.descricao,
                        style: AppTypography.label,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${detalhe.carro!.detalhe} • ${detalhe.carro!.placa}',
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],

        Text('Custos da viagem e Pix', style: AppTypography.label),
        const SizedBox(height: AppSpacing.sm),
        _CustosCard(
          custos: detalhe.custos,
          souMotorista: souMotorista,
          podeEditar: controller.podeEditarCustos,
          comprovanteEnviado: comprovanteEnviado,
          motoristaNome: detalhe.motoristaNome ?? 'Motorista',
          motoristaPix: chavePixMotorista,
          onEditar: onEditarCustos,
          onCopiarPix: onCopiarPix,
          onPassageiroAvisarPix: onPassageiroAvisarPix,
        ),
        const SizedBox(height: AppSpacing.xl),

        Row(
          children: [
            Expanded(child: Text('Passageiros', style: AppTypography.label)),
            if (detalhe.lugares != null)
              Text(
                '${detalhe.ocupadas} de ${detalhe.lugares} vagas',
                style: AppTypography.caption,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (passageiros.isEmpty)
          Text('Nenhum pedido ainda.', style: AppTypography.caption)
        else
          ...passageiros.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _PassageiroCard(
                passageiro: p,
                souMotorista: souMotorista,
                temCustosDefinidos: detalhe.custos != null,
                pixConfirmado:
                    passageirosPixConfirmado.contains(p.idUsuario) ||
                    detalhe.status == StatusCarona.concluida,
                podeDecidir:
                    souMotorista &&
                    detalhe.status == StatusCarona.aberta &&
                    p.status == StatusPassageiro.pendente,
                decidindo: controller.estaDecidindo(p.idUsuario),
                onAprovar: () => onDecidir(p, true),
                onRecusar: () => onDecidir(p, false),
                onConfirmarPix: () => onMotoristaConfirmarPix(p),
              ),
            ),
          ),
      ],
    );
  }
}

class _CustosCard extends StatelessWidget {
  final CustosCarona? custos;
  final bool souMotorista;
  final bool podeEditar;
  final bool comprovanteEnviado;
  final String motoristaNome;
  final String? motoristaPix;
  final VoidCallback onEditar;
  final ValueChanged<String?> onCopiarPix;
  final VoidCallback onPassageiroAvisarPix;

  const _CustosCard({
    required this.custos,
    required this.souMotorista,
    required this.podeEditar,
    required this.comprovanteEnviado,
    required this.motoristaNome,
    required this.motoristaPix,
    required this.onEditar,
    required this.onCopiarPix,
    required this.onPassageiroAvisarPix,
  });

  @override
  Widget build(BuildContext context) {
    final c = custos;

    if (c == null) {
      return AppCard(
        onTap: podeEditar ? onEditar : null,
        child: Row(
          children: [
            const Icon(
              Icons.local_gas_station_outlined,
              color: AppColors.textMuted,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                podeEditar
                    ? 'Informe os km rodados, valor do litro e sua Chave Pix.'
                    : 'O motorista ainda não informou os custos da viagem.',
                style: AppTypography.caption,
              ),
            ),
            if (podeEditar)
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      );
    }

    final porPassageiro = c.valorPorPassageiro;
    final saldoMotorista = porPassageiro != null
        ? porPassageiro * c.passageiros
        : 0.0;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Total da viagem', style: AppTypography.caption),
              ),
              Text(formatMoeda(c.total), style: AppTypography.title),
              if (podeEditar)
                IconButton(
                  onPressed: onEditar,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  color: AppColors.primary,
                  tooltip: 'Editar custos e Chave Pix',
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _LinhaCusto(label: 'Distância', valor: '${_numero(c.kmRodados)} km'),
          _LinhaCusto(
            label:
                'Combustível (${_numero(c.litros)} L a ${formatMoeda(c.valorLitro)})',
            valor: formatMoeda(c.combustivel),
          ),
          _LinhaCusto(
            label: 'Taxa (${formatMoeda(c.taxaPorKm)}/km)',
            valor: formatMoeda(c.taxa),
          ),
          if (motoristaPix != null && motoristaPix!.isNotEmpty)
            _LinhaCusto(label: 'Chave Pix', valor: motoristaPix!),
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: porPassageiro == null
                ? Text(
                    'Sem passageiros aprovados: o total ainda não tem como ser dividido.',
                    style: AppTypography.caption,
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Por passageiro (${c.passageiros})',
                              style: AppTypography.label,
                            ),
                          ),
                          Text(
                            formatMoeda(porPassageiro),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      if (souMotorista) ...[
                        const Divider(height: AppSpacing.lg),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Saldo total a receber',
                                style: AppTypography.caption,
                              ),
                            ),
                            Text(
                              formatMoeda(saldoMotorista),
                              style: const TextStyle(
                                color: AppColors.success,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Consumo médio considerado: ${_numero(c.consumoMedio)} km/L.',
            style: AppTypography.caption,
          ),
          if (souMotorista && podeEditar) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onEditar,
                icon: const Icon(Icons.pix, size: 18),
                label: Text(
                  motoristaPix == null || motoristaPix!.isEmpty
                      ? 'Adicionar Chave Pix'
                      : 'Alterar Custos / Chave Pix',
                ),
              ),
            ),
          ],
          if (!souMotorista && porPassageiro != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.pix, color: AppColors.primary, size: 20),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Pix para $motoristaNome',
                          style: AppTypography.label,
                        ),
                      ),
                      if (comprovanteEnviado)
                        const StatusBadge(
                          label: 'Enviado',
                          color: AppColors.success,
                          icon: Icons.check_circle_outline,
                        ),
                    ],
                  ),
                  if (motoristaPix != null && motoristaPix!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('Chave: $motoristaPix', style: AppTypography.caption),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => onCopiarPix(motoristaPix),
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Text('Copiar Chave Pix'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: comprovanteEnviado
                              ? null
                              : onPassageiroAvisarPix,
                          icon: Icon(
                            comprovanteEnviado
                                ? Icons.check
                                : Icons.send_outlined,
                            size: 16,
                          ),
                          label: Text(
                            comprovanteEnviado ? 'Avisado' : 'Já fiz o Pix',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _numero(double valor) {
    final texto = valor.toStringAsFixed(2);
    return texto
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '')
        .replaceAll('.', ',');
  }
}

class _LinhaCusto extends StatelessWidget {
  final String label;
  final String valor;

  const _LinhaCusto({required this.label, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTypography.caption)),
          Text(valor, style: AppTypography.caption),
        ],
      ),
    );
  }
}

class _PessoaCard extends StatelessWidget {
  final String nome;
  final IconData icone;

  const _PessoaCard({required this.nome, required this.icone});

  @override
  Widget build(BuildContext context) {
    final inicial = nome.trim().isEmpty
        ? '?'
        : nome.trim().characters.first.toUpperCase();
    return AppCard(
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primarySoft,
            child: Text(
              inicial,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              nome,
              style: AppTypography.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(icone, color: AppColors.textMuted, size: 20),
        ],
      ),
    );
  }
}

class _PassageiroCard extends StatelessWidget {
  final PassageiroCarona passageiro;
  final bool souMotorista;
  final bool temCustosDefinidos;
  final bool pixConfirmado;
  final bool podeDecidir;
  final bool decidindo;
  final VoidCallback onAprovar;
  final VoidCallback onRecusar;
  final VoidCallback onConfirmarPix;

  const _PassageiroCard({
    required this.passageiro,
    required this.souMotorista,
    required this.temCustosDefinidos,
    required this.pixConfirmado,
    required this.podeDecidir,
    required this.decidindo,
    required this.onAprovar,
    required this.onRecusar,
    required this.onConfirmarPix,
  });

  ({Color cor, IconData icone}) get _visual => switch (passageiro.status) {
    StatusPassageiro.pendente => (
      cor: AppColors.warning,
      icone: Icons.schedule,
    ),
    StatusPassageiro.aprovado => (
      cor: AppColors.success,
      icone: Icons.check_circle_outline,
    ),
    StatusPassageiro.recusado => (
      cor: AppColors.error,
      icone: Icons.cancel_outlined,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final inicial = passageiro.nome.trim().isEmpty
        ? '?'
        : passageiro.nome.trim().characters.first.toUpperCase();
    final v = _visual;

    return AppCard(
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primarySoft,
                child: Text(
                  inicial,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  passageiro.nome,
                  style: AppTypography.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              StatusBadge(
                label: passageiro.status.label,
                color: v.cor,
                icon: v.icone,
              ),
            ],
          ),
          if (podeDecidir) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: decidindo ? null : onRecusar,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                    child: const Text('Recusar'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: FilledButton(
                    onPressed: decidindo ? null : onAprovar,
                    child: decidindo
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.onPrimary,
                            ),
                          )
                        : const Text('Aprovar'),
                  ),
                ),
              ],
            ),
          ],
          if (souMotorista &&
              passageiro.status == StatusPassageiro.aprovado &&
              temCustosDefinidos) ...[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: pixConfirmado ? null : onConfirmarPix,
                icon: Icon(
                  pixConfirmado ? Icons.check_circle_outline : Icons.pix,
                  size: 16,
                ),
                label: Text(
                  pixConfirmado
                      ? 'Pix Confirmado (Saldo Transferido)'
                      : 'Confirmar Recebimento Pix',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
