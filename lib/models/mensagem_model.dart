class MensagemUsuario {
  final String id;
  final String nome;
  final String? funcao;

  /// URL assinada (SAS). Expira em ~10 min — nao persistir.
  final String? fotoPerfil;

  /// Blob path. Chave estavel de cache (cacheKey do CachedNetworkImage).
  final String? fotoPerfilRef;

  const MensagemUsuario({
    required this.id,
    required this.nome,
    this.funcao,
    this.fotoPerfil,
    this.fotoPerfilRef,
  });

  factory MensagemUsuario.fromJson(Map<String, dynamic> json) {
    return MensagemUsuario(
      id: json['id']?.toString() ?? '',
      nome: json['nome']?.toString() ?? json['name']?.toString() ?? 'Usuário',
      funcao: json['funcao']?.toString() ?? json['role']?.toString(),
      fotoPerfil: json['fotoPerfil']?.toString(),
      fotoPerfilRef: json['fotoPerfilRef']?.toString(),
    );
  }
}

class MensagemModel {
  final String id;

  /// TEXTO, IMAGEM, AUDIO, DOCUMENTO
  final String tipo;

  /// URL assinada (SAS). TTL de 10 min (imagem) ou 30 min (audio).
  /// Sempre https:// quando resolvida. Se vier um blob path aqui, o backend
  /// esqueceu de passar o mapa de URLs ao mapper — ver `midiaPronta`.
  final String? midiaUrl;

  /// Blob path. Chave estavel de cache — a URL rotaciona a cada leitura.
  final String? midiaRef;

  final String conteudo;
  final DateTime createdAt;
  final MensagemUsuario? usuario;
  final DateTime? readAt;

  /// Id gerado no cliente antes do envio. Usado para reconciliar a mensagem
  /// otimista com a confirmada, inclusive quando ela chega pelo WebSocket.
  final String? clientMessageId;

  final bool isPending;
  final bool falhou;

  const MensagemModel({
    required this.id,
    required this.tipo,
    required this.conteudo,
    required this.createdAt,
    this.midiaUrl,
    this.midiaRef,
    this.usuario,
    this.readAt,
    this.clientMessageId,
    this.isPending = false,
    this.falhou = false,
  });

  /// Uma referencia nao resolvida (blob path em vez de URL) e bug de backend,
  /// nao falha de rede. Sem esta checagem o app monta
  /// `${baseUrl}chat/2026-.../uuid.jpg` e recebe 404 silencioso.
  bool get midiaPronta => midiaUrl != null && midiaUrl!.startsWith('http');

  factory MensagemModel.fromJson(Map<String, dynamic> json) {
    return MensagemModel(
      id: json['id']?.toString() ?? '',
      tipo: json['tipo']?.toString() ?? 'TEXTO',
      midiaUrl: json['midiaUrl']?.toString(),
      midiaRef: json['midiaRef']?.toString(),
      conteudo: json['conteudo']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      usuario: json['usuario'] != null
          ? MensagemUsuario.fromJson(json['usuario'] as Map<String, dynamic>)
          : null,
      readAt: json['readAt'] != null
          ? DateTime.tryParse(json['readAt'].toString())
          : null,
      clientMessageId: json['clientMessageId']?.toString(),
    );
  }

  /// Todos os campos sao repassados. Omitir qualquer um faz `onMensagensLidas`
  /// zerar silenciosamente o dado ao remontar a lista inteira.
  MensagemModel copyWith({
    String? id,
    String? tipo,
    String? midiaUrl,
    String? midiaRef,
    String? conteudo,
    DateTime? createdAt,
    MensagemUsuario? usuario,
    DateTime? readAt,
    String? clientMessageId,
    bool? isPending,
    bool? falhou,
  }) {
    return MensagemModel(
      id: id ?? this.id,
      tipo: tipo ?? this.tipo,
      midiaUrl: midiaUrl ?? this.midiaUrl,
      midiaRef: midiaRef ?? this.midiaRef,
      conteudo: conteudo ?? this.conteudo,
      createdAt: createdAt ?? this.createdAt,
      usuario: usuario ?? this.usuario,
      readAt: readAt ?? this.readAt,
      clientMessageId: clientMessageId ?? this.clientMessageId,
      isPending: isPending ?? this.isPending,
      falhou: falhou ?? this.falhou,
    );
  }
}