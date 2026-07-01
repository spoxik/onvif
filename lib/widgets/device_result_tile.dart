import 'package:flutter/material.dart';

import '../models/device_result.dart';

class DeviceResultTile extends StatelessWidget {
  const DeviceResultTile({super.key, required this.result});

  final DeviceResult result;

  @override
  Widget build(BuildContext context) {
    final title = '${result.ip}:${result.port}  •  ${result.source}';
    final subtitle = [
      if (result.manufacturer != null) result.manufacturer,
      if (result.model != null) result.model,
      if (result.serialNumber != null) 'SN: ${result.serialNumber}',
      if (result.firmwareVersion != null) 'FW: ${result.firmwareVersion}',
      if (result.rtspOk != null) 'RTSP: ${result.rtspOk! ? 'OK' : 'BRAK'}',
      if (result.authProfileName != null) 'profil: ${result.authProfileName}',
      if (result.country != null) result.country,
      if (result.organization != null) result.organization,
      if (result.labels.isNotEmpty) 'tagi: ${result.labels.join(', ')}',
      if (result.error != null) result.error,
    ].join('  |  ');

    return Card(
      child: ListTile(
        leading: Icon(result.source == 'Shodan' ? Icons.public : Icons.videocam),
        title: Text(title),
        subtitle: Text(subtitle.isEmpty ? result.protocol : subtitle),
        trailing: result.hasOnvifInfo
            ? const Icon(Icons.verified, color: Colors.green)
            : result.rtspOk == true
                ? const Icon(Icons.network_check, color: Colors.green)
                : null,
      ),
    );
  }
}
