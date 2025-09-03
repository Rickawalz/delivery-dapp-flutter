import 'dart:convert';

class AbiUtils {
  static String convertAbiToJson(List<dynamic> abi) {
    return jsonEncode(abi);
  }
} 