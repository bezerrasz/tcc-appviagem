// Abre um arquivo (ex.: comprovante em PDF) fora do app. No navegador abre numa
// nova aba; nas outras plataformas ainda não há suporte (retorna false).
export 'abrir_arquivo_stub.dart'
    if (dart.library.js_interop) 'abrir_arquivo_web.dart';
