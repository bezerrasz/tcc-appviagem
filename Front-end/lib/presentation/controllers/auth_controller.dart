import 'package:flutter/foundation.dart';
import 'package:test_tcc/core/config/app_constants.dart';
import 'package:test_tcc/domain/entities/user.dart';
import 'package:test_tcc/domain/failures/auth_failure.dart';
import 'package:test_tcc/domain/usecases/atualizar_foto_perfil_usecase.dart';
import 'package:test_tcc/domain/usecases/atualizar_perfil_usecase.dart';
import 'package:test_tcc/domain/usecases/login_usecase.dart';
import 'package:test_tcc/domain/usecases/logout_usecase.dart';
import 'package:test_tcc/domain/usecases/register_usecase.dart';

class AuthController extends ChangeNotifier {
  final LoginUseCase _loginUseCase;
  final RegisterUseCase _registerUseCase;
  final LogoutUseCase _logoutUseCase;
  final AtualizarPerfilUseCase _atualizarPerfilUseCase;
  final AtualizarFotoPerfilUseCase _atualizarFotoPerfilUseCase;

  AuthController({
    required LoginUseCase loginUseCase,
    required RegisterUseCase registerUseCase,
    required LogoutUseCase logoutUseCase,
    required AtualizarPerfilUseCase atualizarPerfilUseCase,
    required AtualizarFotoPerfilUseCase atualizarFotoPerfilUseCase,
  })  : _loginUseCase = loginUseCase,
        _registerUseCase = registerUseCase,
        _logoutUseCase = logoutUseCase,
        _atualizarPerfilUseCase = atualizarPerfilUseCase,
        _atualizarFotoPerfilUseCase = atualizarFotoPerfilUseCase;

  User? _currentUser;
  String? _error;

  User? get currentUser => _currentUser;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;
  bool get isAdmin => _currentUser?.email == AppConstants.adminEmail;

  Future<bool> login({
    required String identifier,
    required String password,
  }) async {
    try {
      _currentUser = await _loginUseCase(
        identifier: identifier,
        password: password,
      );
      _error = null;
      notifyListeners();
      return true;
    } on AuthFailure catch (f) {
      _error = f.message;
      notifyListeners();
      return false;
    }
  }

  Future<User?> register({
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
    required String cpf,
    required DateTime? dataNascimento,
    required TipoUsuario tipo,
  }) async {
    try {
      final user = await _registerUseCase(
        name: name,
        email: email,
        password: password,
        confirmPassword: confirmPassword,
        cpf: cpf,
        dataNascimento: dataNascimento,
        tipo: tipo,
      );
      _error = null;
      notifyListeners();
      return user;
    } on AuthFailure catch (f) {
      _error = f.message;
      notifyListeners();
      return null;
    }
  }

  /// Edita o perfil (e-mail, data de nascimento e/ou chave Pix) e atualiza o
  /// usuário corrente. Retorna true em sucesso; em falha, [error] traz a
  /// mensagem.
  Future<bool> atualizarPerfil({
    String? email,
    DateTime? dataNascimento,
    String? chavePix,
  }) async {
    try {
      _currentUser = await _atualizarPerfilUseCase(
        email: email,
        dataNascimento: dataNascimento,
        chavePix: chavePix,
      );
      _error = null;
      notifyListeners();
      return true;
    } on AuthFailure catch (f) {
      _error = f.message;
      notifyListeners();
      return false;
    }
  }

  /// Troca a foto de perfil e atualiza o usuário corrente. Retorna true em
  /// sucesso; em falha, [error] traz a mensagem.
  Future<bool> atualizarFoto(List<int> bytes) async {
    try {
      _currentUser = await _atualizarFotoPerfilUseCase(bytes: bytes);
      _error = null;
      notifyListeners();
      return true;
    } on AuthFailure catch (f) {
      _error = f.message;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _logoutUseCase();
    _currentUser = null;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }
}
