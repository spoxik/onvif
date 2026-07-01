import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/device_result.dart';

class ReportService {
  Future<File> savePdf(List<DeviceResult> results) async {
    final doc = pw.Document();
    final now = DateTime.now();

    doc.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(level: 0, child: pw.Text('Raport ONVIF / Shodan')),
          pw.Text('Data: ${now.toLocal()}'),
          pw.Text('Liczba wynikow: ${results.length}'),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: const [
              'Zrodlo',
              'IP',
              'Port',
              'Producent',
              'Model',
              'SN',
              'Etykiety',
            ],
            data: results
                .map(
                  (r) => [
                    r.source,
                    r.ip,
                    r.port.toString(),
                    r.manufacturer ?? '',
                    r.model ?? '',
                    r.serialNumber ?? '',
                    r.labels.join(', '),
                  ],
                )
                .toList(),
          ),
        ],
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final stamp = now.toIso8601String().replaceAll(':', '-');
    final file = File('${dir.path}/onvif_report_$stamp.pdf');
    await file.writeAsBytes(await doc.save());
    return file;
  }

  Future<void> sharePdf(List<DeviceResult> results) async {
    final file = await savePdf(results);
    await Share.shareXFiles([XFile(file.path)], text: 'Raport ONVIF / Shodan');
  }
}
