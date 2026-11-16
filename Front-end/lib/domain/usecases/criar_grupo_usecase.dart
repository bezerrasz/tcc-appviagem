import 'package:test_tcc/domain/entities/grupo.dart';
import 'package:test_tcc/domain/failures/grupo_failure.dart';
import 'package:test_tcc/domain/repositories/grupo_repository.dart';

class CriarGrupoUseCase {
  final GrupoRepository repository;

  const CriarGrupoUseCase(this.repository);

  Future<Grupo> call({required String nome}) {
    final nomeTrim = nome.trim();
    if (nomeTrim.isEmpty) {
      throw const GrupoNomeObrigatorioFailure();
    }
    return repository.criar(nome: nomeTrim);
  }
}
