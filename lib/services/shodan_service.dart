import 'package:dio/dio.dart';

import '../models/device_result.dart';

class ShodanService {
  ShodanService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'https://api.shodan.io',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 20),
            ));

  final Dio _dio;

  Future<List<DeviceResult>> search({
    required String apiKey,
    required String query,
    int page = 1,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw ArgumentError('Wpisz klucz API Shodan.');
    }
    if (query.trim().isEmpty) {
      throw ArgumentError('Wpisz zapytanie Shodan.');
    }

    final response = await _dio.get<Map<String, dynamic>>(
      '/shodan/host/search',
      queryParameters: {
        'key': apiKey.trim(),
        'query': query.trim(),
        'page': page,
      },
    );

    final matches = (response.data?['matches'] as List? ?? const [])
        .whereType<Map<String, dynamic>>();

    return matches.map((item) {
      final location = item['location'] as Map<String, dynamic>?;
      final hostnames = (item['hostnames'] as List? ?? const [])
          .whereType<String>()
          .toList();
      final opts = item['opts'] as Map<String, dynamic>?;
      final raw = item['data']?.toString() ?? '';

      return DeviceResult(
        ip: item['ip_str']?.toString() ?? '',
        port: int.tryParse(item['port']?.toString() ?? '') ?? 0,
        protocol: item['_shodan'] is Map
            ? ((item['_shodan'] as Map)['module']?.toString() ?? 'SHODAN')
            : 'SHODAN',
        source: 'Shodan',
        manufacturer: item['product']?.toString(),
        model: opts?['devicetype']?.toString(),
        firmwareVersion: item['version']?.toString(),
        serialNumber: _extractSerial(raw),
        country: location?['country_name']?.toString(),
        organization: item['org']?.toString(),
        hostnames: hostnames,
      );
    }).toList();
  }

  String? _extractSerial(String raw) {
    final patterns = <RegExp>[
      RegExp(r'serial(?:\s*number)?["\s:=]+([A-Za-z0-9._-]{4,64})', caseSensitive: false),
      RegExp(r'"serial_number"\s*:\s*"([^"]+)"', caseSensitive: false),
      RegExp(r'"SerialNumber"\s*:\s*"([^"]+)"', caseSensitive: false),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(raw);
      if (match != null) return match.group(1);
    }
    return null;
  }
}
