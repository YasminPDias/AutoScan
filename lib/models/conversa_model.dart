class ConversaModel {
  final String id;
  final String aiDiagnosticoId;
  final String? status;
  final String? createdAt;
  final Map<String, dynamic>? cliente;

  ConversaModel({
    required this.id,
    required this.aiDiagnosticoId,
    this.status,
    this.createdAt,
    this.cliente,
  });

  factory ConversaModel.fromJson(Map<String, dynamic> json) {
    return ConversaModel(
      id: json['id']?.toString() ?? '',
      aiDiagnosticoId: json['aiDiagnosticoId']?.toString() ?? '',
      status: json['status']?.toString(),
      createdAt: json['createdAt']?.toString(),
      cliente: json['cliente'] as Map<String, dynamic>?,
    );
  }
}
