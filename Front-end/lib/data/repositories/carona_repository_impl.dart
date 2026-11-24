import 'dart:typed_data';

import 'package:test_tcc/data/datasources/carona_remote_datasource.dart';
import 'package:test_tcc/domain/entities/carona_detalhe.dart';
import 'package:test_tcc/domain/entities/carona_item.dart';
import 'package:test_tcc/domain/entities/carona_resumo.dart';
import 'package:test_tcc/domain/repositories/carona_repository.dart';

class CaronaRepositoryImpl implements CaronaRepository {
  final CaronaRemoteDatasource remote;

  const CaronaRepositoryImpl(this.remote);

  @override
  Future<List<CaronaItem>> listarMinhas() => remote.listarMinhas();

  @override
  Future<CaronaDetalhe> detalhe(int idCarona) => remote.detalhe(idCarona);

  @override
  Future<CaronaDetalhe> pedir(int idCarona) => remote.pedir(idCarona);

  @override
  Future<CaronaDetalhe> cancelarPedido(int idCarona) =>
      remote.cancelarPedido(idCarona);

  @override
  Future<CaronaDetalhe> decidir({
    required int idCarona,
    required int idPassageiro,
    required bool aprovar,
  }) =>
      remote.decidir(
        idCarona: idCarona,
        idPassageiro: idPassageiro,
        aprovar: aprovar,
      );

  @override
  Future<CaronaDetalhe> atualizarCustos({
    required int idCarona,
    required double kmRodados,
    required double valorLitro,
  }) =>
      remote.atualizarCustos(
        idCarona: idCarona,
        kmRodados: kmRodados,
        valorLitro: valorLitro,
      );

  @override
  Future<CaronaDetalhe> concluir(int idCarona) => remote.concluir(idCarona);

  @override
  Future<CaronaDetalhe> enviarComprovante({
    required int idCarona,
    required List<int> bytes,
    required String nomeArquivo,
    required String mimeType,
  }) =>
      remote.enviarComprovante(
        idCarona: idCarona,
        bytes: bytes,
        nomeArquivo: nomeArquivo,
        mimeType: mimeType,
      );

  @override
  Future<({Uint8List bytes, String contentType})> baixarComprovante({
    required int idCarona,
    required int idPassageiro,
  }) =>
      remote.baixarComprovante(idCarona: idCarona, idPassageiro: idPassageiro);

  @override
  Future<StatusCarona> cancelar(int idCarona) => remote.cancelar(idCarona);
}
