class Grupo {
  final int idGrupo;
  final String nome;

  /// Se o usuário autenticado é administrador deste grupo.
  final bool isAdm;

  const Grupo({
    required this.idGrupo,
    required this.nome,
    required this.isAdm,
  });
}
