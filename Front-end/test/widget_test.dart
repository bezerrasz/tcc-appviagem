import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:test_tcc/app.dart';
import 'package:test_tcc/data/datasources/auth_remote_datasource.dart';
import 'package:test_tcc/data/datasources/token_storage.dart';
import 'package:test_tcc/data/repositories/auth_repository_impl.dart';
import 'package:test_tcc/domain/repositories/auth_repository.dart';
import 'package:test_tcc/domain/usecases/atualizar_foto_perfil_usecase.dart';
import 'package:test_tcc/domain/usecases/atualizar_perfil_usecase.dart';
import 'package:test_tcc/domain/usecases/login_usecase.dart';
import 'package:test_tcc/domain/usecases/logout_usecase.dart';
import 'package:test_tcc/domain/usecases/register_usecase.dart';
import 'package:test_tcc/presentation/controllers/auth_controller.dart';

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
          ProxyProvider<AuthRemoteDatasource, AuthRepository>(
            update: (_, remote, _) => AuthRepositoryImpl(remote),
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
        ],
        child: const App(),
      ),
    );

    expect(find.text('Compartilhe Caronas'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });
}
