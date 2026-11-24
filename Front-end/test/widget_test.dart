import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:test_tcc/app.dart';
import 'package:test_tcc/data/datasources/auth_remote_datasource.dart';
import 'package:test_tcc/data/datasources/carona_remote_datasource.dart';
import 'package:test_tcc/data/datasources/carro_remote_datasource.dart';
import 'package:test_tcc/data/datasources/chat_remote_datasource.dart';
import 'package:test_tcc/data/datasources/chat_socket_service.dart';
import 'package:test_tcc/data/datasources/grupo_remote_datasource.dart';
import 'package:test_tcc/data/datasources/session_socket_service.dart';
import 'package:test_tcc/data/datasources/token_storage.dart';
import 'package:test_tcc/data/repositories/auth_repository_impl.dart';
import 'package:test_tcc/data/repositories/carona_repository_impl.dart';
import 'package:test_tcc/data/repositories/carro_repository_impl.dart';
import 'package:test_tcc/data/repositories/chat_repository_impl.dart';
import 'package:test_tcc/data/repositories/grupo_repository_impl.dart';
import 'package:test_tcc/domain/repositories/auth_repository.dart';
import 'package:test_tcc/domain/repositories/carona_repository.dart';
import 'package:test_tcc/domain/repositories/carro_repository.dart';
import 'package:test_tcc/domain/repositories/chat_repository.dart';
import 'package:test_tcc/domain/repositories/grupo_repository.dart';
import 'package:test_tcc/domain/usecases/atualizar_foto_perfil_usecase.dart';
import 'package:test_tcc/domain/usecases/atualizar_perfil_usecase.dart';
import 'package:test_tcc/domain/usecases/criar_grupo_usecase.dart';
import 'package:test_tcc/domain/usecases/listar_grupos_usecase.dart';
import 'package:test_tcc/domain/usecases/login_usecase.dart';
import 'package:test_tcc/domain/usecases/logout_usecase.dart';
import 'package:test_tcc/domain/usecases/register_usecase.dart';
import 'package:test_tcc/presentation/controllers/auth_controller.dart';
import 'package:test_tcc/presentation/controllers/carona_controller.dart';
import 'package:test_tcc/presentation/controllers/carro_controller.dart';
import 'package:test_tcc/presentation/controllers/financeiro_controller.dart';
import 'package:test_tcc/presentation/controllers/grupo_controller.dart';

void main() {
  testWidgets('App inicia na tela de login', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<TokenStorage>(create: (_) => TokenStorage()),
          ProxyProvider<TokenStorage, AuthRemoteDatasource>(
            update: (_, storage, _) =>
                AuthRemoteDatasource(tokenStorage: storage),
          ),
          ProxyProvider<TokenStorage, GrupoRemoteDatasource>(
            update: (_, storage, _) =>
                GrupoRemoteDatasource(tokenStorage: storage),
          ),
          ProxyProvider<TokenStorage, ChatRemoteDatasource>(
            update: (_, storage, _) =>
                ChatRemoteDatasource(tokenStorage: storage),
          ),
          ProxyProvider<TokenStorage, ChatSocketService>(
            update: (_, storage, _) => ChatSocketService(tokenStorage: storage),
          ),
          ProxyProvider<TokenStorage, CaronaRemoteDatasource>(
            update: (_, storage, _) =>
                CaronaRemoteDatasource(tokenStorage: storage),
          ),
          ProxyProvider<TokenStorage, CarroRemoteDatasource>(
            update: (_, storage, _) =>
                CarroRemoteDatasource(tokenStorage: storage),
          ),
          ProxyProvider<TokenStorage, SessionSocketService>(
            update: (_, storage, _) =>
                SessionSocketService(tokenStorage: storage),
          ),
          ProxyProvider<AuthRemoteDatasource, AuthRepository>(
            update: (_, remote, _) => AuthRepositoryImpl(remote),
          ),
          ProxyProvider<GrupoRemoteDatasource, GrupoRepository>(
            update: (_, remote, _) => GrupoRepositoryImpl(remote),
          ),
          ProxyProvider2<ChatRemoteDatasource, ChatSocketService,
              ChatRepository>(
            update: (_, remote, socket, _) =>
                ChatRepositoryImpl(remote: remote, socket: socket),
          ),
          ProxyProvider<CaronaRemoteDatasource, CaronaRepository>(
            update: (_, remote, _) => CaronaRepositoryImpl(remote),
          ),
          ProxyProvider<CarroRemoteDatasource, CarroRepository>(
            update: (_, remote, _) => CarroRepositoryImpl(remote),
          ),
          ProxyProvider<AuthRepository, LoginUseCase>(
            update: (_, repo, _) => LoginUseCase(repo),
          ),
          ProxyProvider<AuthRepository, RegisterUseCase>(
            update: (_, repo, _) => RegisterUseCase(repo),
          ),
          ProxyProvider<TokenStorage, LogoutUseCase>(
            update: (_, storage, _) => LogoutUseCase(storage),
          ),
          ProxyProvider<AuthRepository, AtualizarPerfilUseCase>(
            update: (_, repo, _) => AtualizarPerfilUseCase(repo),
          ),
          ProxyProvider<AuthRepository, AtualizarFotoPerfilUseCase>(
            update: (_, repo, _) => AtualizarFotoPerfilUseCase(repo),
          ),
          ProxyProvider<GrupoRepository, CriarGrupoUseCase>(
            update: (_, repo, _) => CriarGrupoUseCase(repo),
          ),
          ProxyProvider<GrupoRepository, ListarGruposUseCase>(
            update: (_, repo, _) => ListarGruposUseCase(repo),
          ),
          ChangeNotifierProxyProvider5<LoginUseCase, RegisterUseCase,
              LogoutUseCase, AtualizarPerfilUseCase, AtualizarFotoPerfilUseCase,
              AuthController>(
            create: (ctx) => AuthController(
              loginUseCase: ctx.read<LoginUseCase>(),
              registerUseCase: ctx.read<RegisterUseCase>(),
              logoutUseCase: ctx.read<LogoutUseCase>(),
              atualizarPerfilUseCase: ctx.read<AtualizarPerfilUseCase>(),
              atualizarFotoPerfilUseCase:
                  ctx.read<AtualizarFotoPerfilUseCase>(),
            ),
            update: (_, login, register, logout, atualizarPerfil,
                    atualizarFoto, previous) =>
                previous ??
                AuthController(
                  loginUseCase: login,
                  registerUseCase: register,
                  logoutUseCase: logout,
                  atualizarPerfilUseCase: atualizarPerfil,
                  atualizarFotoPerfilUseCase: atualizarFoto,
                ),
          ),
          ChangeNotifierProxyProvider2<CaronaRepository, SessionSocketService,
              CaronaController>(
            create: (ctx) => CaronaController(
              ctx.read<CaronaRepository>(),
              sessionSocket: ctx.read<SessionSocketService>(),
            ),
            update: (_, repo, sessionSocket, previous) =>
                previous ??
                CaronaController(repo, sessionSocket: sessionSocket),
          ),
          ChangeNotifierProxyProvider2<AuthRepository, SessionSocketService,
              FinanceiroController>(
            create: (ctx) => FinanceiroController(
              repo: ctx.read<AuthRepository>(),
              sessionSocket: ctx.read<SessionSocketService>(),
            ),
            update: (_, repo, sessionSocket, previous) =>
                previous ??
                FinanceiroController(repo: repo, sessionSocket: sessionSocket),
          ),
          ChangeNotifierProxyProvider<CarroRepository, CarroController>(
            create: (ctx) => CarroController(ctx.read<CarroRepository>()),
            update: (_, repo, previous) => previous ?? CarroController(repo),
          ),
          ChangeNotifierProxyProvider3<ListarGruposUseCase, CriarGrupoUseCase,
              SessionSocketService, GrupoController>(
            create: (ctx) => GrupoController(
              listar: ctx.read<ListarGruposUseCase>(),
              criar: ctx.read<CriarGrupoUseCase>(),
              sessionSocket: ctx.read<SessionSocketService>(),
            ),
            update: (_, listar, criar, sessionSocket, previous) =>
                previous ??
                GrupoController(
                  listar: listar,
                  criar: criar,
                  sessionSocket: sessionSocket,
                ),
          ),
        ],
        child: const App(),
      ),
    );

    expect(find.text('Share a Ride'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });
}
