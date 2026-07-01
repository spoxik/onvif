import 'dart:async';
import 'dart:io';

import '../models/auth_profile.dart';
import '../models/device_result.dart';
import 'onvif_service.dart';
import 'rtsp_service.dart';

class LanScannerService {
  LanScannerService({OnvifService? onvifService, RtspService? rtspService})
      : _onvifService = onvifService ?? OnvifService(),
        _rtspService = rtspService ?? RtspService();

  final OnvifService _onvifService;
  final RtspService _rtspService;

  static const defaultPorts = [80, 8080, 8000, 8899, 554];

  Future<List<DeviceResult>> scanCidr({
    required String cidr,
    List<int> ports = defaultPorts,
    int concurrency = 64,
    List<AuthProfile> authProfiles = const [],
    void Function(DeviceResult result)? onResult,
  }) async {
    final ips = _expandCidr24(cidr);
    final results = <DeviceResult>[];
    final queue = Stream.fromIterable(ips);

    final subscriptions = <Future<void>>[];
    final iterator = StreamIterator(queue);
    final workerCount = concurrency.clamp(1, 256);

    Future<void> worker() async {
      while (await iterator.moveNext()) {
        final ip = iterator.current;
        for (final port in ports) {
          final isOpen = await _isTcpOpen(ip, port);
          if (!isOpen) continue;

          final onvif = await _onvifService.getDeviceInformation(
            ip,
            port,
            authProfiles: authProfiles,
          );
          final rtspOk = port == 554 ? await _rtspService.testRtsp(ip) : null;
          final result = (onvif ??
                  DeviceResult(
                    ip: ip,
                    port: port,
                    protocol: port == 554 ? 'RTSP/TCP' : 'TCP',
                    source: 'LAN',
                  ))
              .copyWith(rtspOk: rtspOk);
          results.add(result);
          onResult?.call(result);
        }
      }
    }

    for (var i = 0; i < workerCount; i++) {
      subscriptions.add(worker());
    }
    await Future.wait(subscriptions);
    return results;
  }

  Future<bool> _isTcpOpen(String ip, int port) async {
    try {
      final socket = await Socket.connect(
        ip,
        port,
        timeout: const Duration(milliseconds: 700),
      );
      await socket.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  List<String> _expandCidr24(String cidr) {
    final clean = cidr.trim();
    final parts = clean.split('/');
    if (parts.length != 2 || parts[1] != '24') {
      throw ArgumentError('Na start obsługiwany jest format /24, np. 10.10.0.0/24');
    }
    final octets = parts[0].split('.');
    if (octets.length != 4) {
      throw ArgumentError('Nieprawidłowy adres sieci: $cidr');
    }
    final prefix = '${octets[0]}.${octets[1]}.${octets[2]}';
    return [for (var i = 1; i <= 254; i++) '$prefix.$i'];
  }
}
