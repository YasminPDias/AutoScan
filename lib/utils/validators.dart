/// Classe utilitária com funções de validação do app.
class Validators {
  /// Expressão regular padrão para validação de e-mail (RFC 5322 simplificada)
  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  /// Retorna `true` se a string for um formato de e-mail válido.
  static bool isValidEmail(String? email) {
    if (email == null || email.trim().isEmpty) return false;
    return _emailRegex.hasMatch(email.trim());
  }

  /// Retorna uma mensagem de erro em português se o e-mail for inválido,
  /// ou `null` caso o e-mail seja válido.
  static String? validateEmail(String? email) {
    if (email == null || email.trim().isEmpty) {
      return 'Por favor, informe o e-mail.';
    }
    if (!isValidEmail(email)) {
      return 'Por favor, insira um e-mail válido (ex: usuario@exemplo.com).';
    }
    return null;
  }
}
