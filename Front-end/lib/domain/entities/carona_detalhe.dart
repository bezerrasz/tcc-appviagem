import 'package:test_tcc/domain/entities/carona_resumo.dart';

/// Pagamento de um passageiro aprovado, definido quando a carona é concluída.
/// Só vem para o motorista e para o próprio passageiro.
class PagamentoPassageiro {
  /// Rateio fixado na conclusão da carona.
  final double valor;

  /// Comprovante Pix confirmado pelo motorista (pendência quitada).
  final bool pago;
  final DateTime? dataPagamento;
  final bool temComprovante;

  const PagamentoPassageiro({
    required this.valor,
    required this.pago,
    required this.dataPagamento,
    required this.temComprovante,
  });

  /// Passageiro já anexou o comprovante, aguardando o motorista confirmar.
  bool get aguardandoConfirmacao => !pago && temComprovante;
}

/// Um passageiro de uma carona, com o status do seu pedido.
class PassageiroCarona {
  final int idUsuario;
  final String nome;
  final StatusPassageiro status;

  /// Null enquanto a carona não foi concluída, ou quando quem vê não é o
  /// motorista nem o próprio passageiro.
  final PagamentoPassageiro? pagamento;

  const PassageiroCarona({
    required this.idUsuario,
    required this.nome,
    required this.status,
    this.pagamento,
  });
}

/// O carro atrelado a uma carona (o carro ativo do motorista no anúncio).
class CarroCarona {
  final int idCarro;
  final String marca;
  final String modelo;
  final int anoFabricacao;
  final String cor;
  final String placa;
  final int capacidade;
  final double? consumoMedio;

  const CarroCarona({
    required this.idCarro,
    required this.marca,
    required this.modelo,
    required this.anoFabricacao,
    required this.cor,
    required this.placa,
    required this.capacidade,
    this.consumoMedio,
  });

  String get descricao => '$marca $modelo';
  String get detalhe => '$cor • $anoFabricacao';
}

/// Custos da viagem e o rateio, calculados pelo backend a partir dos km
/// rodados, valor do litro e consumo médio real do carro associado.
class CustosCarona {
  final double kmRodados;
  final double valorLitro;

  /// Consumo médio (km/L) do veículo usado para converter km em litros.
  final double consumoMedio;
  final double litros;
  final double combustivel;

  /// Taxa de manutenção veicular por km rodado (fica com o motorista).
  final double taxaPorKm;
  final double taxa;

  /// Taxa de serviço da plataforma embutida no total da viagem, e os dados Pix
  /// do proprietário do aplicativo para repasse.
  final double taxaApp;
  final String? chavePixApp;
  final String? recebedorApp;

  /// Combustível + manutenção veicular + taxa de serviço da plataforma.
  final double total;

  /// Ocupantes (passageiros aprovados + motorista) que dividem o total.
  final int passageiros;

  /// Total ÷ passageiros. Null enquanto não há passageiro aprovado.
  final double? valorPorPassageiro;

  const CustosCarona({
    required this.kmRodados,
    required this.valorLitro,
    required this.consumoMedio,
    required this.litros,
    required this.combustivel,
    required this.taxaPorKm,
    required this.taxa,
    this.taxaApp = 0,
    this.chavePixApp,
    this.recebedorApp,
    required this.total,
    required this.passageiros,
    required this.valorPorPassageiro,
  });
}

/// Detalhe de uma carona: motorista + carro + passageiros (com status).
class CaronaDetalhe {
  final int idCarona;
  final int idGrupo;
  final String grupoNome;
  final StatusCarona status;
  final DateTime data;
  final String? destino;
  final int? idMotorista;
  final String? motoristaNome;

  /// Chave Pix do motorista. Só vem depois da carona concluída, para o
  /// motorista e os passageiros aprovados (quem tem algo a pagar).
  final String? chavePixMotorista;
  final CarroCarona? carro;

  /// Vagas de passageiro (capacidade - 1) e quantas já ocupadas (aprovados).
  final int? lugares;
  final int ocupadas;

  final List<PassageiroCarona> passageiros;

  /// Custos da viagem. Null enquanto o motorista não informar km + R$/litro.
  final CustosCarona? custos;

  const CaronaDetalhe({
    required this.idCarona,
    required this.idGrupo,
    required this.grupoNome,
    required this.status,
    required this.data,
    required this.destino,
    required this.idMotorista,
    required this.motoristaNome,
    this.chavePixMotorista,
    required this.carro,
    required this.lugares,
    required this.ocupadas,
    required this.passageiros,
    required this.custos,
  });

  /// Vagas restantes (nunca negativo), quando há informação de lugares.
  int? get vagasRestantes =>
      lugares == null ? null : (lugares! - ocupadas).clamp(0, lugares!);

  /// Cópia com novo status (após concluir/cancelar).
  CaronaDetalhe copyWith({StatusCarona? status}) {
    return CaronaDetalhe(
      idCarona: idCarona,
      idGrupo: idGrupo,
      grupoNome: grupoNome,
      status: status ?? this.status,
      data: data,
      destino: destino,
      idMotorista: idMotorista,
      motoristaNome: motoristaNome,
      chavePixMotorista: chavePixMotorista,
      carro: carro,
      lugares: lugares,
      ocupadas: ocupadas,
      passageiros: passageiros,
      custos: custos,
    );
  }
}
