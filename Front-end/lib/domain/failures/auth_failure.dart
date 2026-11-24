sealed class AuthFailure implements Exception {
  final String message;
  const AuthFailure(this.message);

  @override
  String toString() => message;
}

class InvalidCredentialsFailure extends AuthFailure {
  const InvalidCredentialsFailure() : super('Usuário ou senha inválidos');
}

class EmptyFieldsFailure extends AuthFailure {
  const EmptyFieldsFailure() : super('Preencha todos os campos.');
}

class InvalidEmailFailure extends AuthFailure {
  const InvalidEmailFailure()
      : super('Digite um e-mail válido (ex: nome@email.com).');
}

class EmailInUseFailure extends AuthFailure {
  const EmailInUseFailure()
      : super('Este e-mail já está em uso por outra conta.');
}

class NameInUseFailure extends AuthFailure {
  const NameInUseFailure()
      : super('Este nome já está em uso. Escolha outro para o login.');
}

class WeakPasswordFailure extends AuthFailure {
  const WeakPasswordFailure() : super('A senha deve ter no mínimo 8 caracteres.');
}

class PasswordMismatchFailure extends AuthFailure {
  const PasswordMismatchFailure() : super('As senhas não coincidem.');
}

class CpfInUseFailure extends AuthFailure {
  const CpfInUseFailure()
      : super('Este CPF já está cadastrado.');
}

class InvalidCpfFailure extends AuthFailure {
  const InvalidCpfFailure() : super('CPF deve conter 11 dígitos.');
}

class UnderageFailure extends AuthFailure {
  const UnderageFailure() : super('Usuário deve ter no mínimo 18 anos.');
}

class InvalidChavePixFailure extends AuthFailure {
  const InvalidChavePixFailure()
      : super('A chave Pix deve ter no máximo 77 caracteres.');
}

class InvalidFotoFailure extends AuthFailure {
  const InvalidFotoFailure()
      : super('Formato inválido. Escolha uma imagem JPG, PNG ou WEBP.');
}

class FotoTooLargeFailure extends AuthFailure {
  const FotoTooLargeFailure() : super('A imagem deve ter no máximo 5 MB.');
}

class RegistrationFailure extends AuthFailure {
  const RegistrationFailure(super.message);
}
