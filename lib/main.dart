import 'package:flutter/material.dart';

import 'models/device_result.dart';
import 'services/export_service.dart';
import 'services/lan_scanner_service.dart';
import 'services/shodan_service.dart';
import 'widgets/device_result_tile.dart';

void main() {
  runApp(const OnvifScannerApp());
}

class OnvifScannerApp extends StatelessWidget {
  const OnvifScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ONVIF Scanner',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blueGrey,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _lanScanner = LanScannerService();
  final _shodan = ShodanService();
  final _export = ExportService();

  final _cidrController = TextEditingController(text: '10.10.0.0/24');
  final _portsController = TextEditingController(text: '80,8080,8000,8899,554');
  final _apiKeyController = TextEditingController();
  final _queryController = TextEditingController(text: 'product:camera country:PL');

  final List<DeviceResult> _results = [];
  bool _busy = false;
  String? _status;

  @override
  void dispose() {
    _cidrController.dispose();
    _portsController.dispose();
    _apiKeyController.dispose();
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _scanLan() async {
    setState(() {
      _busy = true;
      _status = 'Skanowanie LAN/VPN...';
      _results.clear();
    });

    try {
      final ports = _portsController.text
          .split(',')
          .map((e) => int.tryParse(e.trim()))
          .whereType<int>()
          .toList();

      await _lanScanner.scanCidr(
        cidr: _cidrController.text,
        ports: ports.isEmpty ? LanScannerService.defaultPorts : ports,
        onResult: (result) {
          if (!mounted) return;
          setState(() => _results.add(result));
        },
      );
      setState(() => _status = 'Zakończono. Wyników: ${_results.length}');
    } catch (e) {
      setState(() => _status = 'Błąd: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _searchShodan() async {
    setState(() {
      _busy = true;
      _status = 'Pobieranie wyników z Shodan...';
      _results.clear();
    });

    try {
      final results = await _shodan.search(
        apiKey: _apiKeyController.text,
        query: _queryController.text,
      );
      setState(() {
        _results.addAll(results);
        _status = 'Shodan: znaleziono ${results.length} wyników.';
      });
    } catch (e) {
      setState(() => _status = 'Błąd Shodan: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportCsv() async {
    if (_results.isEmpty) return;
    setState(() => _status = 'Eksport CSV...');
    await _export.shareCsv(_results);
    setState(() => _status = 'CSV gotowy do udostępnienia.');
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ONVIF Scanner'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.lan), text: 'LAN / VPN'),
              Tab(icon: Icon(Icons.public), text: 'Shodan'),
            ],
          ),
          actions: [
            IconButton(
              onPressed: _results.isEmpty || _busy ? null : _exportCsv,
              icon: const Icon(Icons.ios_share),
              tooltip: 'Eksport CSV',
            ),
          ],
        ),
        body: Column(
          children: [
            if (_busy) const LinearProgressIndicator(),
            Expanded(
              child: TabBarView(
                children: [
                  _buildLanTab(),
                  _buildShodanTab(),
                ],
              ),
            ),
            if (_status != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_status!),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanTab() {
    return _buildTabBody(
      top: Column(
        children: [
          TextField(
            controller: _cidrController,
            decoration: const InputDecoration(
              labelText: 'Podsieć CIDR',
              hintText: 'np. 10.10.0.0/24',
            ),
          ),
          TextField(
            controller: _portsController,
            decoration: const InputDecoration(
              labelText: 'Porty',
              hintText: '80,8080,8000,8899,554',
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _busy ? null : _scanLan,
            icon: const Icon(Icons.search),
            label: const Text('Skanuj LAN/VPN'),
          ),
        ],
      ),
    );
  }

  Widget _buildShodanTab() {
    return _buildTabBody(
      top: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Używaj tylko do własnych/autoryzowanych zasobów. Wpisz własny klucz API Shodan.',
          ),
          TextField(
            controller: _apiKeyController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Shodan API key'),
          ),
          TextField(
            controller: _queryController,
            decoration: const InputDecoration(
              labelText: 'Zapytanie Shodan',
              hintText: 'np. product:camera country:PL',
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _busy ? null : _searchShodan,
            icon: const Icon(Icons.public),
            label: const Text('Szukaj w Shodan'),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBody({required Widget top}) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          top,
          const Divider(height: 24),
          Expanded(
            child: _results.isEmpty
                ? const Center(child: Text('Brak wyników'))
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, index) =>
                        DeviceResultTile(result: _results[index]),
                  ),
          ),
        ],
      ),
    );
  }
}
