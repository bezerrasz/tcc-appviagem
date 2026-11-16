import 'package:test_tcc/domain/entities/grupo.dart';

abstract class GrupoRepository {
  Future<Grupo> criar({required String nome});

  Future<List<Grupo>> listarMeus();
}
