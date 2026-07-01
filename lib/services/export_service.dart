import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
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
    final file = await _file('onvif_scan', 'csv');
    return file.writeAsString(csv);
  }

  Future<File> saveJson(List<DeviceResult> results) async {
    final data = const JsonEncoder.withIndent('  ')
        .convert(results.map((e) => e.toJson()).toList());
    final file = await _file('onvif_scan', 'json');
    return file.writeAsString(data);
  }

  Future<File> saveXlsx(List<DeviceResult> results) async {
    final excel = Excel.createExcel();
    final sheet = excel['Wyniki'];
    sheet.appendRow(DeviceResult.csvHeader.map(TextCellValue.new).toList());
    for (final result in results) {
      sheet.appendRow(result.toCsvRow().map(TextCellValue.new).toList());
    }
    excel.delete('Sheet1');
    final bytes = excel.encode() ?? <int>[];
    final file = await _file('onvif_scan', 'xlsx');
    return file.writeAsBytes(bytes);
  }

  Future<void> shareCsv(List<DeviceResult> results) async {
    final file = await saveCsv(results);
    await Share.shareXFiles([XFile(file.path)], text: 'Wyniki skanowania ONVIF/Shodan CSV');
  }

  Future<void> shareJson(List<DeviceResult> results) async {
    final file = await saveJson(results);
    await Share.shareXFiles([XFile(file.path)], text: 'Wyniki skanowania ONVIF/Shodan JSON');
  }

  Future<void> shareXlsx(List<DeviceResult> results) async {
    final file = await saveXlsx(results);
    await Share.shareXFiles([XFile(file.path)], text: 'Wyniki skanowania ONVIF/Shodan XLSX');
  }

  Future<File> _file(String prefix, String ext) async {
    final dir = await getApplicationDocumentsDirectory();
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    return File('${dir.path}/${prefix}_$stamp.$ext');
  }
}
