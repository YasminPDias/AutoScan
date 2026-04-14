class MensagemUsuario {
  final String id;
  final String nome;
  final String? funcao;
  final String? fotoPerfil;

  MensagemUsuario({
    required this.id,
    required this.nome,
    this.funcao,
    this.fotoPerfil,
  });

  factory MensagemUsuario.fromJson(Map<String, dynamic> json) {
    return MensagemUsuario(
      id: json['id']?.toString() ?? '',
      nome: json['nome']?.toString() ??
          json['name']?.toString() ??
          'Usuário',
      funcao: json['funcao']?.toString() ?? json['role']?.toString(),
      fotoPerfil:
          json['fotoPerfil']?.toString() ?? json['profilePhoto']?.toString(),
    );
  }
}

class MensagemModel {
  final String id;
  final String tipo; // TEXTO, IMAGEM, AUDIO, VIDEO
  final String? midiaUrl;
  final String conteudo;
  final DateTime createdAt;
  final MensagemUsuario? usuario;
  final bool isPending;

  MensagemModel({
    required this.id,
    required this.tipo,
    this.midiaUrl,
    required this.conteudo,
    required this.createdAt,
    this.usuario,
    this.isPending = false,
  });

  factory MensagemModel.fromJson(Map<String, dynamic> json) {
    return MensagemModel(
      id: json['id']?.toString() ?? '',
      tipo: json['tipo']?.toString() ?? 'TEXTO',
      midiaUrl: json['midiaUrl']?.toString(),
      conteudo: json['conteudo']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      usuario: json['usuario'] != null
          ? MensagemUsuario.fromJson(json['usuario'] as Map<String, dynamic>)
          : null,
    );
  }

  MensagemModel copyWith({bool? isPending}) {
    return MensagemModel(
      id: id,
      tipo: tipo,
      midiaUrl: midiaUrl,
      conteudo: conteudo,
      createdAt: createdAt,
      usuario: usuario,
      isPending: isPending ?? this.isPending,
    );
  }
}
