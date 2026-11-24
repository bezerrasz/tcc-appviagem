import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:test_tcc/core/theme/app_colors.dart';
import 'package:test_tcc/core/theme/app_spacing.dart';
import 'package:test_tcc/core/theme/app_typography.dart';
import 'package:test_tcc/data/datasources/session_socket_service.dart';
import 'package:test_tcc/domain/entities/carona_resumo.dart';
import 'package:test_tcc/domain/entities/grupo.dart';
import 'package:test_tcc/domain/entities/mensagem.dart';
import 'package:test_tcc/domain/entities/user.dart';
import 'package:test_tcc/domain/entities/usuario_resumo.dart';
import 'package:test_tcc/domain/failures/grupo_failure.dart';
import 'package:test_tcc/domain/repositories/carona_repository.dart';
import 'package:test_tcc/presentation/controllers/auth_controller.dart';
import 'package:test_tcc/presentation/controllers/carona_detalhe_controller.dart';
import 'package:test_tcc/presentation/controllers/grupo_detalhe_controller.dart';
import 'package:test_tcc/presentation/pages/caronas/carona_detalhe_page.dart';
import 'package:test_tcc/presentation/widgets/app_card.dart';
import 'package:test_tcc/presentation/widgets/carona_status_badge.dart';
import 'package:test_tcc/presentation/widgets/state_views.dart';
import 'package:test_tcc/presentation/widgets/status_badge.dart';

/// Tela de um grupo: abas Chat (tempo-real) e Membros.
/// Espera um [GrupoDetalheController] já provido acima na árvore.
class GrupoDetalhePage extends StatefulWidget {
  final Grupo grupo;

  const GrupoDetalhePage({super.key, required this.grupo});

  @override
  State<GrupoDetalhePage> createState() => _GrupoDetalhePageState();
}

class _GrupoDetalhePageState extends State<GrupoDetalhePage> {
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();
  int _shownCount = 0;

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _enviar(GrupoDetalheController c) async {
    if (_msgController.text.trim().isEmpty || c.enviando) return;
    final ok = await c.enviar(_msgController.text);
    if (!mounted) return;
    if (ok) {
      _msgController.clear();
    } else if (c.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(c.error!)),
      );
    }
  }

  Future<void> _anunciarCarona(GrupoDetalheController c) async {
    if (c.enviando) return;
    final destinoController = TextEditingController();
    final destino = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Anunciar carona'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Diga para onde você vai sair. Os membros do grupo poderão pedir '
              'uma vaga, e você aprova quem entra.',
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: destinoController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Destino (ex.: Faculdade às 18h)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, destinoController.text.trim()),
            child: const Text('Anunciar'),
          ),
        ],
      ),
    );
    destinoController.dispose();
    if (destino == null || !mounted) return; // cancelou
    final ok = await c.anunciarCarona(destino: destino.isEmpty ? null : destino);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Carona anunciada ao grupo.'
              : (c.error ?? 'Não foi possível anunciar a carona.'),
        ),
      ),
    );
  }

  // Abre o detalhe da carona (onde se pede vaga / o motorista aprova).
  void _abrirCarona(int idCarona) {
    final repo = context.read<CaronaRepository>();
    final sessionSocket = context.read<SessionSocketService>();
    final userId = context.read<AuthController>().currentUser?.idUsuario;
    if (userId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => CaronaDetalheController(
            repo: repo,
            idCarona: idCarona,
            currentUserId: userId,
            sessionSocket: sessionSocket,
          )..iniciar(),
          child: const CaronaDetalhePage(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<GrupoDetalheController>();

    // Só motorista/ambos podem anunciar caronas (o gate definitivo é no backend).
    final user = context.read<AuthController>().currentUser;
    final podeAnunciar = user != null &&
        (user.tipo == TipoUsuario.motorista || user.tipo == TipoUsuario.ambos);

    // Rola pro fim quando chega mensagem nova (histórico, envio ou socket).
    if (c.mensagens.length != _shownCount) {
      _shownCount = c.mensagens.length;
      _scrollToBottom();
    }

    final falhouCarregar =
        !c.loading && c.error != null && c.membros.isEmpty;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.grupo.nome),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Chat', icon: Icon(Icons.chat_bubble_outline)),
              Tab(text: 'Membros', icon: Icon(Icons.group_outlined)),
            ],
          ),
        ),
        body: c.loading
            ? const LoadingView()
            : falhouCarregar
                ? ErrorView(message: c.error!, onRetry: c.iniciar)
                : TabBarView(
                    children: [
                      _ChatTab(
                        controller: c,
                        scrollController: _scrollController,
                        msgController: _msgController,
                        onSend: () => _enviar(c),
                        onAnunciar: () => _anunciarCarona(c),
                        podeAnunciar: podeAnunciar,
                        onAbrirCarona: _abrirCarona,
                      ),
                      _MembrosTab(
                        controller: c,
                        podeAdicionar: widget.grupo.isAdm,
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _ChatTab extends StatelessWidget {
  final GrupoDetalheController controller;
  final ScrollController scrollController;
  final TextEditingController msgController;
  final VoidCallback onSend;
  final VoidCallback onAnunciar;
  final bool podeAnunciar;
  final void Function(int idCarona) onAbrirCarona;

  const _ChatTab({
    required this.controller,
    required this.scrollController,
    required this.msgController,
    required this.onSend,
    required this.onAnunciar,
    required this.podeAnunciar,
    required this.onAbrirCarona,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: controller.mensagens.isEmpty
              ? ListView(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                  children: const [
                    EmptyState(
                      icon: Icons.forum_outlined,
                      title: 'Nenhuma mensagem ainda',
                      message: 'Seja o primeiro a enviar uma mensagem neste grupo.',
                    ),
                  ],
                )
              : ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: controller.mensagens.length,
                  itemBuilder: (_, i) {
                    final m = controller.mensagens[i];
                    final ehMinha = controller.ehMinha(m);
                    if (m.tipo == TipoMensagem.carona) {
                      final carona = m.carona;
                      return _CaronaCard(
                        mensagem: m,
                        ehMinha: ehMinha,
                        onAbrir: carona == null
                            ? null
                            : () => onAbrirCarona(carona.idCarona),
                      );
                    }
                    return _Bubble(mensagem: m, ehMinha: ehMinha);
                  },
                ),
        ),
        _Composer(
          controller: msgController,
          enviando: controller.enviando,
          onSend: onSend,
          onAnunciar: podeAnunciar ? onAnunciar : null,
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  final Mensagem mensagem;
  final bool ehMinha;

  const _Bubble({required this.mensagem, required this.ehMinha});

  String get _hora {
    final h = mensagem.dataEnvio.hour.toString().padLeft(2, '0');
    final m = mensagem.dataEnvio.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final bg = ehMinha ? AppColors.primary : AppColors.surface;
    final fg = ehMinha ? AppColors.onPrimary : AppColors.textPrimary;
    final maxW = MediaQuery.sizeOf(context).width * 0.75;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment:
            ehMinha ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: maxW),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(AppRadius.lg),
                topRight: const Radius.circular(AppRadius.lg),
                bottomLeft: Radius.circular(ehMinha ? AppRadius.lg : AppRadius.sm),
                bottomRight: Radius.circular(ehMinha ? AppRadius.sm : AppRadius.lg),
              ),
              border: ehMinha ? null : Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!ehMinha) ...[
                  Text(
                    mensagem.autorNome,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  mensagem.conteudo,
                  style: TextStyle(color: fg, fontSize: 15, height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(_hora, style: AppTypography.caption),
        ],
      ),
    );
  }
}

/// Card de um anúncio de carona no chat (mensagem do tipo CARONA). Mostra
/// motorista, destino e vagas; tocar abre o detalhe (pedir vaga / aprovar).
class _CaronaCard extends StatelessWidget {
  final Mensagem mensagem;
  final bool ehMinha;
  final VoidCallback? onAbrir;

  const _CaronaCard({
    required this.mensagem,
    required this.ehMinha,
    required this.onAbrir,
  });

  String get _hora {
    final h = mensagem.dataEnvio.hour.toString().padLeft(2, '0');
    final m = mensagem.dataEnvio.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final carona = mensagem.carona;
    final status = carona?.status ?? StatusCarona.aberta;
    final titulo = ehMinha
        ? 'Você vai sair'
        : '${mensagem.autorNome} vai sair';
    final maxW = MediaQuery.sizeOf(context).width * 0.85;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: maxW),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onAbrir,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const CircleAvatar(
                          backgroundColor: AppColors.primary,
                          child: Icon(Icons.directions_car,
                              color: AppColors.onPrimary, size: 20),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Carona',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(titulo, style: AppTypography.label),
                              if (carona?.destino != null &&
                                  carona!.destino!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text('→ ${carona.destino}',
                                    style: AppTypography.body),
                              ],
                              if (carona?.vagasLabel != null) ...[
                                const SizedBox(height: 2),
                                Text(carona!.vagasLabel!,
                                    style: AppTypography.caption),
                              ],
                              if ((carona?.pendentes ?? 0) > 0) ...[
                                const SizedBox(height: 2),
                                Text(
                                  '${carona!.pendentes} pedido(s) pendente(s)',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.warning,
                                  ),
                                ),
                              ],
                              const SizedBox(height: AppSpacing.sm),
                              Row(
                                children: [
                                  CaronaStatusBadge(status: status),
                                  const Spacer(),
                                  Text(_hora, style: AppTypography.caption),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right,
                            color: AppColors.textMuted),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool enviando;
  final VoidCallback onSend;
  // Nulo quando o usuário não pode anunciar (passageiro puro): botão escondido.
  final VoidCallback? onAnunciar;

  const _Composer({
    required this.controller,
    required this.enviando,
    required this.onSend,
    required this.onAnunciar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'Mensagem...',
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ),
            if (onAnunciar != null) ...[
              const SizedBox(width: AppSpacing.sm),
              _CaronaButton(enviando: enviando, onTap: onAnunciar!),
            ],
            const SizedBox(width: AppSpacing.sm),
            _SendButton(enviando: enviando, onSend: onSend),
          ],
        ),
      ),
    );
  }
}

/// Botão para pedir uma carona, à direita do campo de texto. Estilo "tonal"
/// (fundo suave) para se distinguir do botão de enviar (sólido).
class _CaronaButton extends StatelessWidget {
  final bool enviando;
  final VoidCallback onTap;

  const _CaronaButton({required this.enviando, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primarySoft,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enviando ? null : onTap,
        child: const Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Icon(Icons.directions_car_outlined,
              color: AppColors.primary, size: 20),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final bool enviando;
  final VoidCallback onSend;

  const _SendButton({required this.enviando, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enviando ? null : onSend,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: enviando
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.onPrimary,
                  ),
                )
              : const Icon(Icons.send_rounded, color: AppColors.onPrimary, size: 20),
        ),
      ),
    );
  }
}

class _MembrosTab extends StatelessWidget {
  final GrupoDetalheController controller;
  final bool podeAdicionar;

  const _MembrosTab({required this.controller, required this.podeAdicionar});

  void _abrirBusca(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => _AdicionarMembroSheet(controller: controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    final membros = controller.membros;
    return Column(
      children: [
        if (podeAdicionar)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () => _abrirBusca(context),
                icon: const Icon(Icons.person_add_alt_1, size: 20),
                label: const Text('Adicionar membro'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primarySoft,
                  foregroundColor: AppColors.primary,
                ),
              ),
            ),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: membros.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, i) {
              final m = membros[i];
              final inicial = m.nome.trim().isEmpty
                  ? '?'
                  : m.nome.trim().characters.first.toUpperCase();
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.nome,
                            style: AppTypography.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(m.tipo.label, style: AppTypography.caption),
                        ],
                      ),
                    ),
                    if (m.isAdm)
                      const StatusBadge(
                        label: 'Admin',
                        icon: Icons.shield_outlined,
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Bottom sheet de busca de usuários para adicionar ao grupo (debounced).
class _AdicionarMembroSheet extends StatefulWidget {
  final GrupoDetalheController controller;

  const _AdicionarMembroSheet({required this.controller});

  @override
  State<_AdicionarMembroSheet> createState() => _AdicionarMembroSheetState();
}

class _AdicionarMembroSheetState extends State<_AdicionarMembroSheet> {
  final _buscaController = TextEditingController();
  Timer? _debounce;
  bool _loading = false;
  String? _erro;
  List<UsuarioResumo> _resultados = const [];
  int? _adicionandoId;

  @override
  void dispose() {
    _debounce?.cancel();
    _buscaController.dispose();
    super.dispose();
  }

  void _onChanged(String termo) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _buscar(termo));
  }

  Future<void> _buscar(String termo) async {
    final t = termo.trim();
    if (t.length < 2) {
      setState(() {
        _resultados = const [];
        _erro = null;
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _erro = null;
    });
    try {
      final res = await widget.controller.buscarUsuarios(t);
      // Ignora resultado obsoleto (o texto já mudou desde a busca).
      if (!mounted || _buscaController.text.trim() != t) return;
      setState(() {
        _resultados = res;
        _loading = false;
      });
    } on GrupoFailure catch (f) {
      if (!mounted) return;
      setState(() {
        _erro = f.message;
        _loading = false;
      });
    }
  }

  Future<void> _adicionar(UsuarioResumo u) async {
    setState(() => _adicionandoId = u.idUsuario);
    final ok = await widget.controller.adicionarMembro(u);
    if (!mounted) return;
    setState(() {
      _adicionandoId = null;
      if (ok) {
        _resultados =
            _resultados.where((r) => r.idUsuario != u.idUsuario).toList();
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? '${u.nome} adicionado ao grupo.'
              : (widget.controller.error ?? 'Não foi possível adicionar.'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.md,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Adicionar membro', style: AppTypography.title),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _buscaController,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: _onChanged,
            decoration: InputDecoration(
              hintText: 'Buscar por nome ou e-mail',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(height: 320, child: _buildResultados()),
        ],
      ),
    );
  }

  Widget _buildResultados() {
    if (_loading) return const LoadingView();
    if (_erro != null) {
      return Center(
        child: Text(_erro!, textAlign: TextAlign.center, style: AppTypography.body),
      );
    }
    if (_buscaController.text.trim().length < 2) {
      return Center(
        child: Text(
          'Digite ao menos 2 caracteres para buscar.',
          textAlign: TextAlign.center,
          style: AppTypography.caption,
        ),
      );
    }
    if (_resultados.isEmpty) {
      return Center(
        child: Text('Nenhum usuário encontrado.', style: AppTypography.body),
      );
    }
    return ListView.separated(
      itemCount: _resultados.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final u = _resultados[i];
        final adicionando = _adicionandoId == u.idUsuario;
        final inicial = u.nome.trim().isEmpty
            ? '?'
            : u.nome.trim().characters.first.toUpperCase();
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: AppColors.primarySoft,
            child: Text(
              inicial,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          title: Text(u.nome, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(u.email, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: adicionando
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                )
              : const Icon(Icons.add_circle, color: AppColors.primary),
          onTap: _adicionandoId == null ? () => _adicionar(u) : null,
        );
      },
    );
  }
}
