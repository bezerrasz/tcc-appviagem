import 'package:test_tcc/core/config/app_constants.dart';
import 'package:test_tcc/domain/entities/user.dart';
import 'package:test_tcc/domain/failures/auth_failure.dart';
import 'package:test_tcc/domain/repositories/auth_repository.dart';

/// Troca a foto de perfil. Valida tamanho e formato no cliente antes do
/// upload (o backend revalida). O formato vem da assinatura do arquivo, não da
/// extensão: no navegador o nome/mimetype informado nem sempre é confiável.
class AtualizarFotoPerfilUseCase {
  final AuthRepository repository;

  const AtualizarFotoPerfilUseCase(this.repository);

  Future<User> call({required List<int> bytes}) {
    if (bytes.length > AppConstants.fotoPerfilTamanhoMax) {
      throw const FotoTooLargeFailure();
    }
    final tipo = _detectarTipo(bytes);
    if (tipo == null) {
      throw const InvalidFotoFailure();
    }
    return repository.atualizarFoto(
      bytes: bytes,
      // O backend ignora este nome e grava como <idUsuario>-<ms>.<ext>.
      nomeArquivo: 'foto${tipo.ext}',
      mimeType: tipo.mime,
    );
  }

  /// JPEG FF D8 FF; PNG 89 50 4E 47; WEBP "RIFF"...."WEBP".
  ({String mime, String ext})? _detectarTipo(List<int> b) {
    if (b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) {
      return (mime: 'image/jpeg', ext: '.jpg');
    }
    if (b.length >= 4 &&
        b[0] == 0x89 &&
        b[1] == 0x50 &&
        b[2] == 0x4E &&
        b[3] == 0x47) {
      return (mime: 'image/png', ext: '.png');
    }
    if (b.length >= 12 &&
        String.fromCharCodes(b.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(b.sublist(8, 12)) == 'WEBP') {
      return (mime: 'image/webp', ext: '.webp');
    }
    return null;
  }
}
