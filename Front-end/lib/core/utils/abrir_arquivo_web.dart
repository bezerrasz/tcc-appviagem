import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Abre o arquivo numa nova aba do navegador. Se o bloqueador de pop-up
/// impedir (a aba é aberta depois do download, fora do clique), baixa o
/// arquivo. Retorna true se conseguiu uma das duas coisas.
bool abrirArquivo(Uint8List bytes, String contentType, String nomeArquivo) {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: contentType),
  );
  final url = web.URL.createObjectURL(blob);
  // Libera a memória do blob depois que a aba/download já o carregou.
  Future<void>.delayed(
    const Duration(minutes: 1),
    () => web.URL.revokeObjectURL(url),
  );

  if (web.window.open(url, '_blank') != null) return true;

  final link = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = nomeArquivo;
  web.document.body?.append(link);
  link.click();
  link.remove();
  return true;
}
