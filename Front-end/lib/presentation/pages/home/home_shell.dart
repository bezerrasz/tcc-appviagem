import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:test_tcc/domain/entities/user.dart';
import 'package:test_tcc/presentation/controllers/auth_controller.dart';
import 'package:test_tcc/presentation/controllers/carona_controller.dart';
import 'package:test_tcc/presentation/controllers/carro_controller.dart';
import 'package:test_tcc/presentation/controllers/financeiro_controller.dart';
import 'package:test_tcc/presentation/controllers/grupo_controller.dart';
import 'package:test_tcc/presentation/pages/home/tabs/inicio_tab.dart';
import 'package:test_tcc/presentation/pages/home/tabs/grupos_tab.dart';
import 'package:test_tcc/presentation/pages/home/tabs/caronas_tab.dart';
import 'package:test_tcc/presentation/pages/home/tabs/perfil_tab.dart';

/// Casca do app autenticado: barra inferior + as abas reais. A aba "Caronas"
/// só aparece para motorista/ambos.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final grupos = context.read<GrupoController>();
      grupos.carregar();
      context.read<FinanceiroController>().carregar();
      // Realtime de sessão: recebe ao vivo grupos em que o usuário for
      // adicionado enquanto está logado. Encerrado no dispose (logout).
      grupos.iniciarSessaoRealtime();
    });
  }

  @override
  void dispose() {
    context.read<GrupoController>().encerrarSessaoRealtime();
    // Logout: não mostrar os saldos deste usuário para o próximo.
    context.read<FinanceiroController>().limpar();
    super.dispose();
  }

  void _irPara(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthController>().currentUser;
    final podeSerMotorista = user != null &&
        (user.tipo == TipoUsuario.motorista || user.tipo == TipoUsuario.ambos);

    // Controllers globais: cada aba dispara um GET das suas informações ao ser
    // exibida (onShow), então o conteúdo é sempre buscado fresco do servidor.
    final grupos = context.read<GrupoController>();
    final caronas = context.read<CaronaController>();
    final carros = context.read<CarroController>();
    final financeiro = context.read<FinanceiroController>();

    final tabs = <_TabItem>[
      _TabItem(
        page: InicioTab(onVerGrupos: () {
          _irPara(1);
          grupos.carregar();
        }),
        destino: const NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Início',
        ),
        onShow: () {
          grupos.carregar();
          financeiro.carregar();
        },
      ),
      _TabItem(
        page: const GruposTab(),
        destino: const NavigationDestination(
          icon: Icon(Icons.groups_outlined),
          selectedIcon: Icon(Icons.groups),
          label: 'Grupos',
        ),
        onShow: grupos.carregar,
      ),
      if (podeSerMotorista)
        _TabItem(
          page: const CaronasTab(),
          destino: const NavigationDestination(
            icon: Icon(Icons.directions_car_outlined),
            selectedIcon: Icon(Icons.directions_car),
            label: 'Caronas',
          ),
          onShow: caronas.carregar,
        ),
      _TabItem(
        page: const PerfilTab(),
        destino: const NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Perfil',
        ),
        onShow: carros.carregar,
      ),
    ];

    // Protege contra índice fora do range se o conjunto de abas mudar.
    final index = _index.clamp(0, tabs.length - 1);

    return Scaffold(
      body: IndexedStack(
        index: index,
        children: [for (final t in tabs) t.page],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) {
          _irPara(i);
          tabs[i].onShow?.call();
        },
        destinations: [for (final t in tabs) t.destino],
      ),
    );
  }
}

class _TabItem {
  final Widget page;
  final NavigationDestination destino;
  // Disparado quando a aba passa a ser exibida: faz o GET das informações dela.
  final VoidCallback? onShow;

  const _TabItem({required this.page, required this.destino, this.onShow});
}
