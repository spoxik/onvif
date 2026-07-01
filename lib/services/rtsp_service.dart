import 'dart:convert';
import 'dart:io';

class RtspService {
  Future<bool> testRtsp(String host, {int port = 554}) async {
    try {
      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 2),
      );
      socket.write('OPTIONS rtsp://$host:$port/ RTSP/1.0\r\nCSeq: 1\r\n\r\n');
      final response = await socket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .first
          .timeout(const Duration(seconds: 2));
      await socket.close();
      return response.contains('RTSP/1.0');
    } catch (_) {
      return false;
    }
  }
}
