import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:test_tcc/core/config/api_config.dart';
import 'package:test_tcc/core/theme/app_colors.dart';
import 'package:test_tcc/data/datasources/token_storage.dart';

/// Avatar circular com a foto de perfil do usuário, ou o ícone padrão quando
/// ele não tem foto (ou ela não carrega).
///
/// A rota das fotos exige autenticação, então a imagem é baixada com o token
/// no header (no navegador o Flutter faz isso via fetch, não com <img>).
class UserAvatar extends StatelessWidget {
  /// Nome do arquivo salvo no usuário (`<idUsuario>-<ms>.<ext>`).
  final String? fotoPerfil;
  final double radius;

  const UserAvatar({super.key, required this.fotoPerfil, this.radius = 44});

  static String urlDa(String nomeArquivo) =>
      '${ApiConfig.baseUrl}/uploads/profilePictures/'
      '${Uri.encodeComponent(nomeArquivo)}';

  @override
  Widget build(BuildContext context) {
    final token = context.read<TokenStorage>().read();
    final padrao = Icon(
      Icons.person,
      size: radius * 1.1,
      color: AppColors.primary,
    );
    final foto = fotoPerfil;

    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primarySoft,
      child: (foto == null || token == null)
          ? padrao
          : ClipOval(
              child: Image.network(
                urlDa(foto),
                // O nome muda a cada envio, então a key nova força recarregar.
                key: ValueKey(foto),
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                headers: {
                  'Authorization': 'Bearer $token',
                  'ngrok-skip-browser-warning': 'true',
                },
                loadingBuilder: (_, child, progresso) => progresso == null
                    ? child
                    : const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                errorBuilder: (_, _, _) => padrao,
              ),
            ),
    );
  }
}
