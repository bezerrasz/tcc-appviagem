import 'package:test_tcc/core/config/app_constants.dart';
import 'package:test_tcc/core/utils/email_validator.dart';
import 'package:test_tcc/domain/entities/user.dart';
import 'package:test_tcc/domain/failures/auth_failure.dart';
import 'package:test_tcc/domain/repositories/auth_repository.dart';

/// Edita o próprio perfil (e-mail, data de nascimento e/ou chave Pix). Valida no
/// cliente antes de chamar o backend (que revalida e checa unicidade do e-mail).
class AtualizarPerfilUseCase {
  final AuthRepository repository;

  const AtualizarPerfilUseCase(this.repository);

  Future<User> call({
    String? email,
    DateTime? dataNascimento,
    String? chavePix,
  }) async {
    if (email == null && dataNascimento == null && chavePix == null) {
      throw const EmptyFieldsFailure();
    }

    String? emailLimpo;
    if (email != null) {
      emailLimpo = email.trim();
      if (!isValidEmail(emailLimpo)) {
        throw const InvalidEmailFailure();
      }
    }

    if (dataNascimento != null && _idade(dataNascimento) < 18) {
      throw const UnderageFailure();
    }

    // Chave Pix é texto livre (CPF, celular, e-mail ou aleatória); vazia
    // remove a chave. A única regra é o tamanho.
    final chaveLimpa = chavePix?.trim();
    if (chaveLimpa != null && chaveLimpa.length > AppConstants.chavePixMax) {
      throw const InvalidChavePixFailure();
    }

    return repository.atualizarPerfil(
      email: emailLimpo,
      dataNascimento: dataNascimento,
      chavePix: chaveLimpa,
    );
  }

  int _idade(DateTime nasc) {
    final hoje = DateTime.now();
    var idade = hoje.year - nasc.year;
    final aniversarioPassou = hoje.month > nasc.month ||
        (hoje.month == nasc.month && hoje.day >= nasc.day);
    if (!aniversarioPassou) idade--;
    return idade;
  }
}
