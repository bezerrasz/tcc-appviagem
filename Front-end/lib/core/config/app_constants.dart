// Identificadores e regras fixas do app.
// Override via --dart-define quando precisar variar por ambiente.

class AppConstants {
  AppConstants._();

  static const String adminEmail = String.fromEnvironment(
    'ADMIN_EMAIL',
    defaultValue: 'admin@admin.com',
  );

  // Regras do carro (espelham config/security.js no backend, que é a fonte de
  // verdade; aqui são só para validação imediata no formulário).
  static const int carroAnoMin = 1900;
  // Capacidade total (motorista incluso). Vagas de passageiro = capacidade - 1.
  static const int carroCapacidadeMin = 2;
  // Placa BR (após upcase): antiga ABC1234 e Mercosul ABC1D23.
  static final RegExp carroPlacaRegex =
      RegExp(r'^[A-Z]{3}[0-9][0-9A-Z][0-9]{2}$');

  // Saldo do usuário (tela Início). Faixa aceita pelo backend.
  static const double saldoMin = 0;
  static const double saldoMax = 999999.99;

  // Custos da viagem informados pelo motorista. O total e o rateio são
  // calculados no backend; aqui só validamos o formulário.
  static const double caronaKmMin = 0.1;
  static const double caronaKmMax = 5000;
  static const double caronaValorLitroMin = 0.01;
  static const double caronaValorLitroMax = 99.99;

  // Foto de perfil (espelha FOTO_PERFIL_* em config/security.js no backend).
  static const int fotoPerfilTamanhoMax = 5 * 1024 * 1024;
}
