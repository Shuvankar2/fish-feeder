// ignore_for_file: uri_does_not_exist, avoid_web_libraries_in_non_web
import 'dart:js' as js;

void downloadFileWeb(String base64Data, String filename) {
  final dataUrl = 'data:image/png;base64,$base64Data';
  js.context.callMethod('eval', [
    "const a = document.createElement('a'); a.href = '$dataUrl'; a.download = '$filename'; document.body.appendChild(a); a.click(); document.body.removeChild(a);"
  ]);
}
