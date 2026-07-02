import 'dart:js' as js;
import 'dart:js_util' as js_util;

class SerialService {
  static Future<String> getESPParameters([String? secret]) async {
    try {
      final promise = js_util.callMethod(js_util.globalThis, 'readESPSerialParameters', [secret]);
      if (promise == null) {
        throw Exception("readESPSerialParameters is not defined in JS.");
      }
      final result = await js_util.promiseToFuture(promise);
      return result.toString();
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  static Future<void> writeSecret(String secret) async {
    try {
      final promise = js_util.callMethod(js_util.globalThis, 'writeESPSecret', [secret]);
      if (promise == null) {
        throw Exception("writeESPSecret is not defined in JS.");
      }
      await js_util.promiseToFuture(promise);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  static void registerDisconnectCallback(void Function() callback) {
    js_util.setProperty(js_util.globalThis, 'onESPDeviceDisconnected', js.allowInterop(callback));
  }

  static Future<void> flashFirmware(String base64Data, Function(double) onProgress) async {
    try {
      final promise = js_util.callMethod(js_util.globalThis, 'flashESPFirmware', [
        base64Data,
        js_util.allowInterop(onProgress)
      ]);
      if (promise == null) {
        throw Exception("flashESPFirmware is not defined in JS.");
      }
      await js_util.promiseToFuture(promise);
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}
