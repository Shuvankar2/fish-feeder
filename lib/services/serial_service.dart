import 'dart:js_interop';
import 'package:flutter/foundation.dart' show kIsWeb;

@JS('window.readESPSerialParameters')
external JSPromise<JSString> _readESPSerialParameters();

class SerialService {
  static Future<String> getESPParameters() async {
    if (!kIsWeb) {
      throw Exception('Wired Serial COM is only supported in web browsers.');
    }
    try {
      final jsStr = await _readESPSerialParameters().toDart;
      return jsStr.toDart;
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}
