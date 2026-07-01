import 'dart:js' as js;
import 'dart:js_util' as js_util;

class SerialService {
  static Future<String> getESPParameters() async {
    try {
      final promise = js_util.callMethod(js_util.globalThis, 'readESPSerialParameters', []);
      if (promise == null) {
        throw Exception("readESPSerialParameters is not defined in JS.");
      }
      final result = await js_util.promiseToFuture(promise);
      return result.toString();
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}
