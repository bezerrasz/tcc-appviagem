'use strict';

// Regras de seguranca/validacao centralizadas.
// Permite ajustar custo do bcrypt via env (em maquinas lentas, baixar pra dev).

module.exports = {
  BCRYPT_COST: Number(process.env.BCRYPT_COST) || 10,
  IDADE_MINIMA: 18,
  SENHA_TAMANHO_MIN: 8,
  NOME_TAMANHO_MIN: 2,
  CPF_TAMANHO: 11,
  EMAIL_REGEX: /^[^\s@]+@[^\s@]+\.[^\s@]+$/,
  GRUPO_NOME_TAMANHO_MIN: 3,
  // Chave Pix: no maximo 77 caracteres (o tamanho da maior chave, e-mail).
  CHAVE_PIX_MAX: 77,
  MENSAGEM_TAMANHO_MIN: 1,
  MENSAGEM_TAMANHO_MAX: 2000,
  BUSCA_TAMANHO_MIN: 2,
  // Tipo de mensagem no chat: texto comum ou um anuncio de carona.
  MENSAGEM_TIPO: { TEXTO: 'TEXTO', CARONA: 'CARONA' },
  // Ciclo de vida da carona. O motorista anuncia (aberta), passageiros pedem
  // para entrar; o motorista conclui ou cancela a viagem.
  CARONA_STATUS: {
    ABERTA: 'aberta',
    CONCLUIDA: 'concluida',
    CANCELADA: 'cancelada',
  },
  // Ciclo de vida do pedido de um passageiro numa carona: pede (pendente), o
  // motorista aprova ou recusa.
  CARONA_PASSAGEIRO_STATUS: {
    PENDENTE: 'pendente',
    APROVADO: 'aprovado',
    RECUSADO: 'recusado',
  },
  // Conteudo fallback gravado na mensagem do anuncio (o app renderiza um card).
  CARONA_MENSAGEM_PADRAO: 'Anunciou uma carona',
  // Limite de caracteres do destino/observacao do anuncio.
  CARONA_DESTINO_MIN: 2,
  CARONA_DESTINO_MAX: 120,
  // Mensagem quando o motorista tenta aprovar alem do limite de passageiros.
  CARONA_LOTADA_MSG: 'A carona ja atingiu o limite de passageiros.',
  // Custos da viagem. O motorista informa quanto rodou e quanto pagou no litro;
  // como nao guardamos o consumo de cada carro, usamos um consumo medio (km/L)
  // para converter os km em litros.
  CARONA_CONSUMO_MEDIO_KM_L: 10,
  // Taxa do app cobrada por km rodado. Entra no total da viagem antes do rateio
  // entre os passageiros.
  CARONA_TAXA_POR_KM: 0.1,
  CARONA_KM_MIN: 0.1,
  CARONA_KM_MAX: 5000,
  CARONA_VALOR_LITRO_MIN: 0.01,
  CARONA_VALOR_LITRO_MAX: 99.99,
  // Tipos de usuario aptos a dirigir/anunciar uma carona (subconjunto do enum
  // usuario.tipo). Passageiro puro nao pode anunciar.
  CARONA_TIPOS_MOTORISTA: ['motorista', 'ambos'],
  // Regras do carro. ano maximo e calculado no validator (ano atual + 1).
  CARRO_TEXTO_MIN: 2,
  CARRO_ANO_MIN: 1900,
  // Capacidade total do carro (motorista incluso). O limite de passageiros de
  // uma carona e capacidade - 1.
  CARRO_CAPACIDADE_MIN: 2,
  // Placa BR apos remover separadores e upcase: antiga AAA9999 e Mercosul
  // AAA9A99 sao cobertas por 3 letras + digito + (digito|letra) + 2 digitos.
  CARRO_PLACA_REGEX: /^[A-Z]{3}[0-9][0-9A-Z][0-9]{2}$/,
  // Mensagem quando um motorista tenta anunciar sem ter um carro ativo.
  CARRO_OBRIGATORIO_MSG:
    'Cadastre e selecione um carro ativo antes de anunciar uma carona.',
  // Foto de perfil: tamanho maximo do upload e formatos aceitos (mimetype ->
  // extensao gravada no disco). O conteudo tambem e conferido pela assinatura
  // do arquivo, entao renomear um .html para .png nao passa.
  FOTO_PERFIL_TAMANHO_MAX: 5 * 1024 * 1024,
  FOTO_PERFIL_TIPOS: {
    'image/jpeg': '.jpg',
    'image/png': '.png',
    'image/webp': '.webp',
  },
  // Comprovante Pix importado pelo passageiro: imagem ou PDF (formato que
  // muitos bancos usam), tambem conferido pela assinatura do arquivo.
  COMPROVANTE_TAMANHO_MAX: 5 * 1024 * 1024,
  COMPROVANTE_TIPOS: {
    'image/jpeg': '.jpg',
    'image/png': '.png',
    'image/webp': '.webp',
    'application/pdf': '.pdf',
  },
  // Mensagem quando o motorista tenta concluir sem informar os custos.
  CARONA_CUSTOS_OBRIGATORIOS_MSG:
    'Informe os km rodados e o valor do litro antes de concluir a carona.',
};
