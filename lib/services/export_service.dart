import 'dart:io';

import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/device_result.dart';

class ExportService {
  Future<File> saveCsv(List<DeviceResult> results) async {
    final rows = [
      DeviceResult.csvHeader,
      ...results.map((e) => e.toCsvRow()),
    ];
    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getApplicationDocumentsDirectory();
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final file = File('${dir.path}/onvif_scan_$stamp.csv');
    return file.writeAsString(csv);
  }

  Future<void> shareCsv(List<DeviceResult> results) async {
    final file = await saveCsv(results);
    await Share.shareXFiles([XFile(file.path)], text: 'Wyniki skanowania ONVIF/Shodan');
  }
}
