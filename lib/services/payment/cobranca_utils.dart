import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class MaskTextInputFormatter extends TextInputFormatter {
  final String mask; // '0' = dígito
  MaskTextInputFormatter(this.mask);

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    var digitIndex = 0;

    for (var i = 0; i < mask.length && digitIndex < digits.length; i++) {
      if (mask[i] == '0') {
        buffer.write(digits[digitIndex]);
        digitIndex++;
      } else {
        buffer.write(mask[i]);
      }
    }

    return TextEditingValue(text: buffer.toString(), selection: TextSelection.collapsed(offset: buffer.length));
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

class CpfValidator {
  static bool isValid(String cpf) {
    final digits = cpf.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 11) return false;
    if (RegExp(r'^(\d)\1*$').hasMatch(digits)) return false;

    final nums = digits.split('').map(int.parse).toList();

    int calcDigit(List<int> base) {
      var factor = base.length + 1;
      var sum = 0;
      for (final n in base) {
        sum += n * factor--;
      }
      final rest = sum % 11;
      return rest < 2 ? 0 : 11 - rest;
    }

    return calcDigit(nums.sublist(0, 9)) == nums[9] && calcDigit(nums.sublist(0, 10)) == nums[10];
  }
}

class EnderecoService {
  static Future<Map<String, String>?> buscarPorCep(String cep) async {
    final cepLimpo = cep.replaceAll(RegExp(r'\D'), '');
    if (cepLimpo.length != 8) return null;
    try {
      final res = await http
          .get(Uri.parse('https://viacep.com.br/ws/$cepLimpo/json/'))
          .timeout(const Duration(seconds: 5));

      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['erro'] == true) return null;

      return {
        'logradouro': data['logradouro']?.toString() ?? '',
        'bairro': data['bairro']?.toString() ?? '',
        'cidade': data['localidade']?.toString() ?? '',
        'estado': data['uf']?.toString() ?? '',
      };
    } catch (_) {
      return null;
    }
  }
}