import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:test_tcc/core/config/app_constants.dart';
import 'package:test_tcc/core/theme/app_colors.dart';
import 'package:test_tcc/core/theme/app_spacing.dart';
import 'package:test_tcc/core/theme/app_typography.dart';
import 'package:test_tcc/core/utils/abrir_arquivo.dart';
import 'package:test_tcc/core/utils/formatters.dart';
import 'package:test_tcc/domain/entities/carona_detalhe.dart';
import 'package:test_tcc/domain/entities/carona_resumo.dart';
import 'package:test_tcc/presentation/controllers/auth_controller.dart';
import 'package:test_tcc/presentation/controllers/carona_detalhe_controller.dart';
import 'package:test_tcc/presentation/widgets/app_card.dart';
import 'package:test_tcc/presentation/widgets/carona_status_badge.dart';
import 'package:test_tcc/presentation/widgets/state_views.dart';
import 'package:test_tcc/presentation/widgets/status_badge.dart';

/// Detalhe de uma carona: motorista + carro + custos + passageiros e, depois
/// de concluída, o pagamento via Pix (feito por fora do app, com o comprovante
/// importado aqui).
class CaronaDetalhePage extends StatefulWidget {
  const CaronaDetalhePage({super.key});

  @override
  State<CaronaDetalhePage> createState() => _CaronaDetalhePageState();
}

class _CaronaDetalhePageState extends State<CaronaDetalhePage> {
  bool _enviandoComprovante = false;
  int? _abrindoComprovanteDe;

  String _data(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year} • $hh:$min';
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

  /// Custos da viagem (da carona) e chave Pix (do perfil do motorista, vale
  /// para todas as caronas dele) no mesmo diálogo.
  Future<void> _editarCustos(CaronaDetalheController c) async {
    final auth = context.read<AuthController>();
    final custos = c.detalhe?.custos;
    final chaveAtual = auth.currentUser?.chavePix ?? '';

    final resultado = await showDialog<
        ({String km, String litro, String chavePix})>(
      context: context,
      builder: (_) => _DialogoCustos(
        kmInicial: _decimal(custos?.kmRodados),
        litroInicial: _decimal(custos?.valorLitro),
        chavePixInicial: chaveAtual,
      ),
    );
    if (resultado == null || !mounted) return;

    final km = parseMoeda(resultado.km);
    final litro = parseMoeda(resultado.litro);
    final novaChave = resultado.chavePix;

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

    if (novaChave != chaveAtual) {
      final salvou = await auth.atualizarPerfil(chavePix: novaChave);
      if (!salvou) {
        _aviso(auth.error ?? 'Não foi possível salvar a chave Pix.');
        return;
      }
    }

    final ok = await c.atualizarCustos(kmRodados: km, valorLitro: litro);
    _feedback(c, ok, 'Custos e chave Pix atualizados.');
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
    if (c.detalhe?.custos == null) {
      _aviso('Informe os km rodados e o valor do litro antes de concluir.');
      return;
    }
    final semChave =
        (context.read<AuthController>().currentUser?.chavePix ?? '').isEmpty;
    final semPassageiros = (c.detalhe?.ocupadas ?? 0) == 0;
    final ok = await _confirmar(
      titulo: 'Concluir carona?',
      mensagem: 'O valor de cada passageiro aprovado será fixado e eles '
          'poderão pagar via Pix e enviar o comprovante.'
          '${semPassageiros ? '\n\nAtenção: nenhum passageiro foi aprovado '
              'nesta carona. Se a viagem não ocorreu com caroneiros, '
              'considere cancelar em vez de concluir.' : ''}'
          '${semChave ? '\n\nVocê ainda não cadastrou sua chave Pix: '
              'informe-a em "Custos e chave Pix" ou no seu perfil.' : ''}',
      acao: 'Concluir',
    );
    if (ok != true) return;
    final feito = await c.concluir();
    _feedback(c, feito, 'Carona concluída. Pagamentos liberados.');
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

  void _copiarChavePix(String chave, {String rotulo = 'Chave Pix'}) {
    Clipboard.setData(ClipboardData(text: chave));
    _aviso('$rotulo copiada. Faça o Pix no app do seu banco.');
  }

  /// Passageiro escolhe o comprovante (imagem ou PDF) e envia.
  Future<void> _importarComprovante(CaronaDetalheController c) async {
    if (_enviandoComprovante) return;
    final PlatformFile? arquivo;
    try {
      arquivo = await FilePicker.pickFile(
        dialogTitle: 'Comprovante do Pix',
        type: FileType.custom,
        allowedExtensions: AppConstants.comprovanteExtensoes,
      );
    } catch (_) {
      _aviso('Não foi possível abrir a seleção de arquivos.');
      return;
    }
    if (arquivo == null || !mounted) return;

    setState(() => _enviandoComprovante = true);
    try {
      final bytes = await arquivo.readAsBytes();
      final ok = await c.enviarComprovante(bytes);
      _feedback(
        c,
        ok,
        'Comprovante enviado! Aguarde a confirmação do motorista.',
      );
    } catch (_) {
      _aviso('Não foi possível ler o arquivo escolhido.');
    } finally {
      if (mounted) setState(() => _enviandoComprovante = false);
    }
  }

  Future<void> _confirmarPagamento(
    CaronaDetalheController c,
    PassageiroCarona p,
  ) async {
    final confirmar = await _confirmar(
      titulo: 'Confirmar Pix de ${p.nome}?',
      mensagem:
          'Confirme apenas após conferir o recebimento do valor na sua conta '
          'ou verificar o comprovante enviado.',
      acao: 'Confirmar Pix',
    );
    if (confirmar != true) return;
    final ok = await c.confirmarPagamento(p.idUsuario);
    _feedback(c, ok, 'Pagamento de ${p.nome} confirmado e saldos atualizados!');
  }

  Future<void> _recusarComprovante(
    CaronaDetalheController c,
    PassageiroCarona p,
  ) async {
    final confirmar = await _confirmar(
      titulo: 'Recusar comprovante de ${p.nome}?',
      mensagem:
          'O arquivo enviado será removido para que o passageiro possa '
          'importar um novo comprovante Pix.',
      acao: 'Recusar comprovante',
      destrutivo: true,
    );
    if (confirmar != true) return;
    final ok = await c.recusarComprovante(p.idUsuario);
    _feedback(c, ok, 'Comprovante recusado. Novo envio liberado para ${p.nome}.');
  }

  Future<void> _removerPassageiro(
    CaronaDetalheController c,
    PassageiroCarona p,
  ) async {
    final confirmar = await _confirmar(
      titulo: 'Remover ${p.nome} da carona?',
      mensagem:
          'A vaga voltará a ficar disponível para outros colegas e o rateio '
          'será recalculado.',
      acao: 'Remover',
      destrutivo: true,
    );
    if (confirmar != true) return;
    final ok = await c.decidir(idPassageiro: p.idUsuario, aprovar: false);
    _feedback(c, ok, '${p.nome} removido da carona.');
  }

  /// Motorista (ou o próprio passageiro) abre o comprovante: imagem aparece
  /// num diálogo; PDF abre numa nova aba do navegador.
  Future<void> _verComprovante(
    CaronaDetalheController c,
    PassageiroCarona p,
  ) async {
    if (_abrindoComprovanteDe != null) return;
    setState(() => _abrindoComprovanteDe = p.idUsuario);
    final arquivo = await (() async {
      try {
        return await c.baixarComprovante(p.idUsuario);
      } finally {
        if (mounted) setState(() => _abrindoComprovanteDe = null);
      }
    })();
    if (!mounted) return;
    if (arquivo == null) {
      _aviso(c.error ?? 'Não foi possível abrir o comprovante.');
      return;
    }

    if (arquivo.contentType.startsWith('image/')) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Comprovante de ${p.nome}'),
          content: InteractiveViewer(
            child: Image.memory(arquivo.bytes, fit: BoxFit.contain),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fechar'),
            ),
          ],
        ),
      );
      return;
    }

    final abriu = abrirArquivo(
      arquivo.bytes,
      arquivo.contentType,
      'comprovante-${p.nome}.pdf',
    );
    if (!abriu) {
      _aviso('Para ver comprovantes em PDF, use a versão web do app.');
    }
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
                      enviandoComprovante: _enviandoComprovante,
                      abrindoComprovanteDe: _abrindoComprovanteDe,
                      onDecidir: (p, aprovar) => _decidir(c, p, aprovar),
                      onEditarCustos: () => _editarCustos(c),
                      onCopiarPix: _copiarChavePix,
                      onCopiarPixApp: (chave) =>
                          _copiarChavePix(chave, rotulo: 'Chave Pix do app'),
                      onImportarComprovante: () => _importarComprovante(c),
                      onVerComprovante: (p) => _verComprovante(c, p),
                      onConfirmarPagamento: (p) => _confirmarPagamento(c, p),
                      onRecusarComprovante: (p) => _recusarComprovante(c, p),
                      onRemoverPassageiro: (p) => _removerPassageiro(c, p),
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
  final bool enviandoComprovante;
  final int? abrindoComprovanteDe;
  final void Function(PassageiroCarona, bool aprovar) onDecidir;
  final VoidCallback onEditarCustos;
  final ValueChanged<String> onCopiarPix;
  final ValueChanged<String> onCopiarPixApp;
  final VoidCallback onImportarComprovante;
  final ValueChanged<PassageiroCarona> onVerComprovante;
  final ValueChanged<PassageiroCarona> onConfirmarPagamento;
  final ValueChanged<PassageiroCarona> onRecusarComprovante;
  final ValueChanged<PassageiroCarona> onRemoverPassageiro;

  const _Conteudo({
    required this.controller,
    required this.detalhe,
    required this.dataLabel,
    required this.enviandoComprovante,
    required this.abrindoComprovanteDe,
    required this.onDecidir,
    required this.onEditarCustos,
    required this.onCopiarPix,
    required this.onCopiarPixApp,
    required this.onImportarComprovante,
    required this.onVerComprovante,
    required this.onConfirmarPagamento,
    required this.onRecusarComprovante,
    required this.onRemoverPassageiro,
  });

  @override
  Widget build(BuildContext context) {
    final passageiros = detalhe.passageiros;
    final souMotorista = controller.souMotorista;
    final meuVinculo = controller.meuVinculo;
    final meuPagamento = meuVinculo?.pagamento;
    final custos = detalhe.custos;

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

        // Passageiro aprovado de carona concluída: o que pagar e como.
        if (!souMotorista && meuPagamento != null) ...[
          Text('Seu pagamento', style: AppTypography.label),
          const SizedBox(height: AppSpacing.sm),
          _MeuPagamentoCard(
            pagamento: meuPagamento,
            motoristaNome: detalhe.motoristaNome ?? 'o motorista',
            chavePix: detalhe.chavePixMotorista,
            podeEnviar: controller.podeEnviarComprovante,
            enviando: enviandoComprovante,
            abrindo: abrindoComprovanteDe == meuVinculo?.idUsuario,
            onCopiarPix: onCopiarPix,
            onImportar: onImportarComprovante,
            onVerComprovante: meuVinculo == null
                ? null
                : () => onVerComprovante(meuVinculo),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],

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

        Text('Custos da viagem', style: AppTypography.label),
        const SizedBox(height: AppSpacing.sm),
        _CustosCard(
          custos: custos,
          souMotorista: souMotorista,
          podeEditar: controller.podeEditarCustos,
          chavePixMotorista: detalhe.chavePixMotorista,
          onEditar: onEditarCustos,
          onCopiarPix: onCopiarPix,
        ),
        const SizedBox(height: AppSpacing.xl),

        // Repasse da taxa de serviço da plataforma (visível ao motorista após
        // concluir uma viagem com passageiros aprovados).
        if (souMotorista &&
            detalhe.status == StatusCarona.concluida &&
            detalhe.ocupadas > 0 &&
            custos != null &&
            custos.taxaApp > 0) ...[
          Text('Taxa da plataforma', style: AppTypography.label),
          const SizedBox(height: AppSpacing.sm),
          _TaxaAppCard(
            taxaApp: custos.taxaApp,
            chavePixApp: custos.chavePixApp,
            recebedorApp: custos.recebedorApp,
            onCopiarPixApp: onCopiarPixApp,
          ),
          const SizedBox(height: AppSpacing.xl),
        ],

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
                // Só o motorista vê o pagamento de cada passageiro na lista
                // (o passageiro vê o próprio no card "Seu pagamento").
                pagamento: souMotorista ? p.pagamento : null,
                podeDecidir:
                    souMotorista &&
                    detalhe.status == StatusCarona.aberta &&
                    p.status == StatusPassageiro.pendente,
                podeRemover:
                    souMotorista &&
                    detalhe.status == StatusCarona.aberta &&
                    p.status == StatusPassageiro.aprovado,
                decidindo: controller.estaDecidindo(p.idUsuario),
                confirmandoPagamento:
                    controller.estaConfirmandoPagamento(p.idUsuario),
                recusandoComprovante:
                    controller.estaRecusandoComprovante(p.idUsuario),
                abrindoComprovante: abrindoComprovanteDe == p.idUsuario,
                onAprovar: () => onDecidir(p, true),
                onRecusar: () => onDecidir(p, false),
                onRemover: () => onRemoverPassageiro(p),
                onVerComprovante: () => onVerComprovante(p),
                onConfirmarPagamento: () => onConfirmarPagamento(p),
                onRecusarComprovante: () => onRecusarComprovante(p),
              ),
            ),
          ),
      ],
    );
  }
}

/// Card do passageiro com o valor a pagar, a chave Pix do motorista e a
/// importação do comprovante (aguardando confirmação do motorista até quitar).
class _MeuPagamentoCard extends StatelessWidget {
  final PagamentoPassageiro pagamento;
  final String motoristaNome;
  final String? chavePix;
  final bool podeEnviar;
  final bool enviando;
  final bool abrindo;
  final ValueChanged<String> onCopiarPix;
  final VoidCallback onImportar;
  final VoidCallback? onVerComprovante;

  const _MeuPagamentoCard({
    required this.pagamento,
    required this.motoristaNome,
    required this.chavePix,
    required this.podeEnviar,
    required this.enviando,
    required this.abrindo,
    required this.onCopiarPix,
    required this.onImportar,
    required this.onVerComprovante,
  });

  @override
  Widget build(BuildContext context) {
    final chave = chavePix;
    final temChave = chave != null && chave.isNotEmpty;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  pagamento.pago ? 'Você pagou' : 'Valor a pagar',
                  style: AppTypography.caption,
                ),
              ),
              Text(
                formatMoeda(pagamento.valor),
                style: TextStyle(
                  color: pagamento.pago ? AppColors.success : AppColors.primary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (pagamento.pago) ...[
            Row(
              children: [
                const StatusBadge(
                  label: 'Pago',
                  color: AppColors.success,
                  icon: Icons.check_circle_outline,
                ),
                const SizedBox(width: AppSpacing.sm),
                if (pagamento.dataPagamento != null)
                  Expanded(
                    child: Text(
                      'Confirmado em ${formatData(pagamento.dataPagamento!)}',
                      style: AppTypography.caption,
                    ),
                  ),
              ],
            ),
            if (pagamento.temComprovante && onVerComprovante != null) ...[
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: abrindo ? null : onVerComprovante,
                icon: const Icon(Icons.receipt_long_outlined, size: 16),
                label: const Text('Ver meu comprovante'),
              ),
            ],
          ] else if (pagamento.aguardandoConfirmacao) ...[
            const Align(
              alignment: Alignment.centerLeft,
              child: StatusBadge(
                label: 'Aguardando confirmação',
                color: AppColors.warning,
                icon: Icons.hourglass_top_rounded,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Comprovante enviado! Aguarde $motoristaNome conferir e '
              'confirmar o recebimento para atualizar seu saldo.',
              style: AppTypography.caption,
            ),
            if (onVerComprovante != null) ...[
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: abrindo ? null : onVerComprovante,
                icon: const Icon(Icons.receipt_long_outlined, size: 16),
                label: const Text('Ver meu comprovante'),
              ),
            ],
          ] else ...[
            Text(
              'Faça o Pix para $motoristaNome pelo app do seu banco e depois '
              'importe o comprovante aqui.',
              style: AppTypography.caption,
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  const Icon(Icons.pix, color: AppColors.primary, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      temChave
                          ? chave
                          : 'O motorista ainda não cadastrou a chave Pix. '
                                'Combine o pagamento com ele.',
                      style: temChave
                          ? AppTypography.label
                          : AppTypography.caption,
                    ),
                  ),
                  if (temChave)
                    IconButton(
                      onPressed: () => onCopiarPix(chave),
                      icon: const Icon(Icons.copy, size: 18),
                      color: AppColors.primary,
                      tooltip: 'Copiar chave Pix',
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: podeEnviar && !enviando ? onImportar : null,
              icon: enviando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.onPrimary,
                      ),
                    )
                  : const Icon(Icons.upload_file, size: 18),
              label: Text(enviando ? 'Enviando...' : 'Importar comprovante'),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Imagem (JPG, PNG, WEBP) ou PDF, até 5 MB.',
              style: AppTypography.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _DialogoCustos extends StatefulWidget {
  final String kmInicial;
  final String litroInicial;
  final String chavePixInicial;

  const _DialogoCustos({
    required this.kmInicial,
    required this.litroInicial,
    required this.chavePixInicial,
  });

  @override
  State<_DialogoCustos> createState() => _DialogoCustosState();
}

class _DialogoCustosState extends State<_DialogoCustos> {
  late final TextEditingController _kmController = TextEditingController(
    text: widget.kmInicial,
  );
  late final TextEditingController _litroController = TextEditingController(
    text: widget.litroInicial,
  );
  late final TextEditingController _pixController = TextEditingController(
    text: widget.chavePixInicial,
  );

  @override
  void dispose() {
    _kmController.dispose();
    _litroController.dispose();
    _pixController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
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
              controller: _kmController,
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
              controller: _litroController,
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
              controller: _pixController,
              maxLength: AppConstants.chavePixMax,
              decoration: const InputDecoration(
                labelText: 'Sua Chave Pix',
                hintText: 'CPF, celular, e-mail ou chave aleatória',
                helperText: 'Fica salva no seu perfil.',
                prefixIcon: Icon(Icons.pix, size: 18),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            (
              km: _kmController.text,
              litro: _litroController.text,
              chavePix: _pixController.text.trim(),
            ),
          ),
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

class _CustosCard extends StatelessWidget {
  final CustosCarona? custos;
  final bool souMotorista;
  final bool podeEditar;
  final String? chavePixMotorista;
  final VoidCallback onEditar;
  final ValueChanged<String> onCopiarPix;

  const _CustosCard({
    required this.custos,
    required this.souMotorista,
    required this.podeEditar,
    required this.chavePixMotorista,
    required this.onEditar,
    required this.onCopiarPix,
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
                    ? 'Informe os km rodados, o valor do litro e sua chave '
                          'Pix. Os custos são obrigatórios para concluir.'
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

    final porPessoa = c.valorPorPassageiro;
    // c.passageiros conta quem divide o total: passageiros aprovados + o
    // motorista, que paga a própria parte. Ele recebe dos demais.
    final pagantes = (c.passageiros - 1).clamp(0, c.passageiros);
    final aReceberMotorista = porPessoa == null ? 0.0 : porPessoa * pagantes;
    final chavePix = chavePixMotorista;
    final temChave = chavePix != null && chavePix.isNotEmpty;

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
                  tooltip: 'Editar custos e chave Pix',
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
            label:
                'Manutenção do veículo (${formatMoeda(c.taxaPorKm)}/km • motorista)',
            valor: formatMoeda(c.taxa),
          ),
          if (temChave) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                const Icon(Icons.pix, size: 15, color: AppColors.primary),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'Chave Pix: $chavePix',
                    style: AppTypography.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: () => onCopiarPix(chavePix),
                  icon: const Icon(Icons.copy, size: 16),
                  color: AppColors.primary,
                  tooltip: 'Copiar chave Pix do motorista',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: porPessoa == null || pagantes == 0
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
                              'Por pessoa (${c.passageiros}, com o motorista)',
                              style: AppTypography.label,
                            ),
                          ),
                          Text(
                            formatMoeda(porPessoa),
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
                        _LinhaResumoMotorista(
                          rotulo: c.taxaApp > 0
                              ? 'Bruto dos $pagantes passageiro(s)'
                              : 'Você recebe dos $pagantes passageiro(s)',
                          valor: formatMoeda(aReceberMotorista),
                          cor: c.taxaApp > 0
                              ? AppColors.textPrimary
                              : AppColors.success,
                          destaque: c.taxaApp <= 0,
                        ),
                        if (c.taxaApp > 0) ...[
                          const SizedBox(height: 4),
                          _LinhaResumoMotorista(
                            rotulo: '(-) Taxa da plataforma',
                            valor: '- ${formatMoeda(c.taxaApp)}',
                            cor: AppColors.textMuted,
                          ),
                          const SizedBox(height: 6),
                          _LinhaResumoMotorista(
                            rotulo: 'Líquido seu (combustível + manutenção)',
                            valor: formatMoeda(aReceberMotorista - c.taxaApp),
                            cor: AppColors.success,
                            destaque: true,
                          ),
                        ],
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Consumo médio do veículo: ${_numero(c.consumoMedio)} km/L'
            '${c.taxaApp > 0 ? ' • Inclui taxa de serviço da plataforma (${formatMoeda(c.taxaApp)}).' : '.'}',
            style: AppTypography.caption,
          ),
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

/// Card exibido ao motorista para repasse via Pix da taxa de serviço da
/// plataforma ao proprietário do aplicativo.
class _TaxaAppCard extends StatelessWidget {
  final double taxaApp;
  final String? chavePixApp;
  final String? recebedorApp;
  final ValueChanged<String> onCopiarPixApp;

  const _TaxaAppCard({
    required this.taxaApp,
    required this.chavePixApp,
    required this.recebedorApp,
    required this.onCopiarPixApp,
  });

  @override
  Widget build(BuildContext context) {
    final chave = chavePixApp;
    final temChave = chave != null && chave.isNotEmpty;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  recebedorApp ?? 'Share a Ride (Plataforma)',
                  style: AppTypography.label,
                ),
              ),
              Text(
                formatMoeda(taxaApp),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'A taxa de manutenção (${formatMoeda(0.10)}/km) permanece com você. '
            'Este valor refere-se à taxa de serviço da plataforma já incluída '
            'no rateio da viagem.',
            style: AppTypography.caption,
          ),
          if (temChave) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  const Icon(Icons.pix, color: AppColors.primary, size: 18),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      chave,
                      style: AppTypography.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () => onCopiarPixApp(chave),
                    icon: const Icon(Icons.copy, size: 18),
                    color: AppColors.primary,
                    tooltip: 'Copiar chave Pix da plataforma',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LinhaResumoMotorista extends StatelessWidget {
  final String rotulo;
  final String valor;
  final Color cor;
  final bool destaque;

  const _LinhaResumoMotorista({
    required this.rotulo,
    required this.valor,
    required this.cor,
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
        const SizedBox(width: AppSpacing.sm),
        Text(
          valor,
          style: TextStyle(
            color: cor,
            fontSize: destaque ? 16 : 13,
            fontWeight: destaque ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ],
    );
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

  /// Pagamento do passageiro (só para o motorista, depois de concluída).
  final PagamentoPassageiro? pagamento;
  final bool podeDecidir;
  final bool podeRemover;
  final bool decidindo;
  final bool confirmandoPagamento;
  final bool recusandoComprovante;
  final bool abrindoComprovante;
  final VoidCallback onAprovar;
  final VoidCallback onRecusar;
  final VoidCallback onRemover;
  final VoidCallback onVerComprovante;
  final VoidCallback onConfirmarPagamento;
  final VoidCallback onRecusarComprovante;

  const _PassageiroCard({
    required this.passageiro,
    required this.pagamento,
    required this.podeDecidir,
    required this.podeRemover,
    required this.decidindo,
    required this.confirmandoPagamento,
    required this.recusandoComprovante,
    required this.abrindoComprovante,
    required this.onAprovar,
    required this.onRecusar,
    required this.onRemover,
    required this.onVerComprovante,
    required this.onConfirmarPagamento,
    required this.onRecusarComprovante,
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
    final pg = pagamento;

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
          if (podeRemover) ...[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: decidindo ? null : onRemover,
                icon: decidindo
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.person_remove_outlined, size: 16),
                label: Text(decidindo ? 'Removendo...' : 'Remover da carona'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                ),
              ),
            ),
          ],
          if (pg != null) ...[
            const Divider(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: Text(
                    pg.pago
                        ? 'Pagou ${formatMoeda(pg.valor)}'
                            '${pg.dataPagamento != null ? ' em ${formatData(pg.dataPagamento!)}' : ''}'
                        : pg.aguardandoConfirmacao
                            ? 'Comprovante enviado (${formatMoeda(pg.valor)})'
                            : 'Deve ${formatMoeda(pg.valor)}',
                    style: AppTypography.caption,
                  ),
                ),
                StatusBadge(
                  label: pg.pago
                      ? 'Pago'
                      : pg.aguardandoConfirmacao
                          ? 'Aguardando confirmação'
                          : 'Pendente',
                  color: pg.pago ? AppColors.success : AppColors.warning,
                  icon: pg.pago
                      ? Icons.check_circle_outline
                      : pg.aguardandoConfirmacao
                          ? Icons.hourglass_top_rounded
                          : Icons.schedule,
                ),
              ],
            ),
            if (pg.temComprovante) ...[
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: abrindoComprovante ? null : onVerComprovante,
                  icon: abrindoComprovante
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.receipt_long_outlined, size: 16),
                  label: const Text('Ver comprovante'),
                ),
              ),
            ],
            if (pg.aguardandoConfirmacao) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: confirmandoPagamento || recusandoComprovante
                          ? null
                          : onRecusarComprovante,
                      icon: recusandoComprovante
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.close, size: 16),
                      label: Text(
                        recusandoComprovante ? 'Recusando...' : 'Recusar',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: confirmandoPagamento || recusandoComprovante
                          ? null
                          : onConfirmarPagamento,
                      icon: confirmandoPagamento
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.onPrimary,
                              ),
                            )
                          : const Icon(Icons.check_circle_outline, size: 16),
                      label: Text(
                        confirmandoPagamento
                            ? 'Confirmando...'
                            : 'Confirmar Pix',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}
