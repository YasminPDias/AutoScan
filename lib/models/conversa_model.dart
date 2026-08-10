class UltimaMensagem {
  final String id;
  final String conteudo;
  final String tipo;
  final String? midiaUrl;
  final DateTime createdAt;
  final DateTime? readAt;
  final String? remetenteNome;
  final String? remetenteId;

  UltimaMensagem({
    required this.id,
    required this.conteudo,
    required this.tipo,
    this.midiaUrl,
    required this.createdAt,
    this.readAt,
    this.remetenteNome,
    this.remetenteId,
  });

  factory UltimaMensagem.fromJson(Map<String, dynamic> json) {
   
    return UltimaMensagem(
      id: json['id']?.toString() ?? '',
      conteudo: json['conteudo']?.toString() ?? '',
      tipo: json['tipo']?.toString() ?? 'TEXTO',
      midiaUrl: json['midiaUrl']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      readAt: json['readAt'] != null
          ? DateTime.tryParse(json['readAt'].toString())
          : null,
      remetenteNome: json['remetenteNome']?.toString(),
      remetenteId: json['remetenteId']?.toString(),
    );
  }

  // preview de exibição na lista — adapta por tipo de mídia
  String get preview {
    switch (tipo.toUpperCase()) {
      case 'IMAGEM': return '🖼 Imagem';
      case 'AUDIO': return '🎵 Áudio';
      case 'VIDEO': return '🎥 Vídeo';
      default:
        return conteudo.length > 90 ? '${conteudo.substring(0, 90)}…' : conteudo;
    }
  }
}

class ConversaModel {
  final String id;
  final String? aiDiagnosticoId;
  final String? status;
  final String? clienteNome;
  final String? clienteId;
  final String? atendenteNome;
  final String? atendenteId;
  final DateTime? createdAt;
  final UltimaMensagem? ultimaMensagem;

  ConversaModel({
    required this.id,
    this.aiDiagnosticoId,
    this.status,
    this.clienteNome,
    this.clienteId,
    this.atendenteNome,
    this.atendenteId,
    this.createdAt,
    this.ultimaMensagem,
  });

  factory ConversaModel.fromJson(Map<String, dynamic> json) {

    return ConversaModel(
      id: json['id']?.toString() ?? '',
      aiDiagnosticoId: json['aiDiagnosticoId']?.toString(),
      status: json['status']?.toString(),
      clienteNome: json['clienteNome']?.toString(),
      clienteId: json['clienteId']?.toString(),
      atendenteNome: json['atendenteNome']?.toString(),
      atendenteId: json['atendenteId']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      ultimaMensagem: json['ultimaMensagem'] != null
          ? UltimaMensagem.fromJson(json['ultimaMensagem'] as Map<String, dynamic>)
          : null,
    );
  }
}