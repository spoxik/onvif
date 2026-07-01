import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:xml/xml.dart';

import '../models/auth_profile.dart';
import '../models/device_result.dart';

class OnvifService {
  OnvifService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 3),
              receiveTimeout: const Duration(seconds: 5),
              sendTimeout: const Duration(seconds: 5),
            ));

  final Dio _dio;

  Future<DeviceResult?> getDeviceInformation(
    String ip,
    int port, {
    List<AuthProfile> authProfiles = const [],
  }) async {
    final unauthenticated = await _tryGetDeviceInformation(ip, port);
    if (unauthenticated != null && unauthenticated.error != 'ONVIF wymaga logowania') {
      return unauthenticated;
    }

    for (final profile in authProfiles.where((p) => p.username.isNotEmpty)) {
      final result = await _tryGetDeviceInformation(
        ip,
        port,
        basicAuthHeader: _basicAuth(profile),
        authProfileName: profile.name,
      );
      if (result != null && result.error != 'ONVIF wymaga logowania') {
        return result;
      }
    }

    return unauthenticated;
  }

  Future<DeviceResult?> _tryGetDeviceInformation(
    String ip,
    int port, {
    String? basicAuthHeader,
    String? authProfileName,
  }) async {
    final uri = 'http://$ip:$port/onvif/device_service';
    const envelope = '''<?xml version="1.0" encoding="UTF-8"?>
<s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope">
  <s:Body>
    <GetDeviceInformation xmlns="http://www.onvif.org/ver10/device/wsdl" />
  </s:Body>
</s:Envelope>''';

    try {
      final response = await _dio.post<String>(
        uri,
        data: envelope,
        options: Options(
          contentType: 'application/soap+xml; charset=utf-8',
          responseType: ResponseType.plain,
          headers: basicAuthHeader == null ? null : {'Authorization': basicAuthHeader},
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      final body = response.data ?? '';
      if (response.statusCode == 401) {
        return DeviceResult(
          ip: ip,
          port: port,
          protocol: 'ONVIF',
          source: 'LAN',
          authProfileName: authProfileName,
          error: 'ONVIF wymaga logowania',
        );
      }
      if (!body.contains('GetDeviceInformationResponse')) return null;

      final doc = XmlDocument.parse(body);
      String? text(String name) {
        final elements = doc.findAllElements(name);
        if (elements.isEmpty) return null;
        return elements.first.innerText.trim();
      }

      return DeviceResult(
        ip: ip,
        port: port,
        protocol: 'ONVIF',
        source: 'LAN',
        manufacturer: text('Manufacturer'),
        model: text('Model'),
        firmwareVersion: text('FirmwareVersion'),
        serialNumber: text('SerialNumber'),
        hardwareId: text('HardwareId'),
        authProfileName: authProfileName,
      );
    } catch (_) {
      return null;
    }
  }

  String _basicAuth(AuthProfile profile) {
    final raw = '${profile.username}:${profile.secret}';
    return 'Basic ${base64Encode(utf8.encode(raw))}';
  }
}
