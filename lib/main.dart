import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models/device_result.dart';
import 'models/shodan_query.dart';
import 'services/export_service.dart';
import 'services/lan_scanner_service.dart';
import 'services/report_service.dart';
import 'services/shodan_service.dart';
import 'services/storage_service.dart';
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
  final _report = ReportService();
  final _storage = StorageService();

  final _cidrController = TextEditingController(text: '10.10.0.0/24');
  final _portsController = TextEditingController(text: '80,8080,8000,8899,554');
  final _apiKeyController = TextEditingController();
  final _queryController = TextEditingController(text: 'product:camera country:PL');
  final _filterController = TextEditingController();

  final List<DeviceResult> _results = [];
  final List<DeviceResult> _favorites = [];
  final List<ShodanQuery> _savedQueries = [];

  bool _busy = false;
  bool _saveShodanKey = true;
  String? _status;

  @override
  void initState() {
    super.initState();
    _loadLocalData();
    _filterController.addListener(() => setState(() {}));
  }

  Future<void> _loadLocalData() async {
    final favorites = await _storage.loadFavorites();
    final queries = await _storage.loadQueries();
    final apiKey = await _storage.loadApiKey();
    if (!mounted) return;
    setState(() {
      _favorites
        ..clear()
        ..addAll(favorites);
      _savedQueries
        ..clear()
        ..addAll(queries);
      _apiKeyController.text = apiKey;
    });
  }

  @override
  void dispose() {
    _cidrController.dispose();
    _portsController.dispose();
    _apiKeyController.dispose();
    _queryController.dispose();
    _filterController.dispose();
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
          setState(() => _results.add(_mergeFavoriteState(result)));
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
      if (_saveShodanKey) {
        await _storage.saveApiKey(_apiKeyController.text);
      }
      final results = await _shodan.search(
        apiKey: _apiKeyController.text,
        query: _queryController.text,
      );
      setState(() {
        _results.addAll(results.map(_mergeFavoriteState));
        _status = 'Shodan: znaleziono ${results.length} wyników.';
      });
    } catch (e) {
      setState(() => _status = 'Błąd Shodan: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportCsv() async {
    final list = _filteredResults;
    if (list.isEmpty) return;
    setState(() => _status = 'Eksport CSV...');
    await _export.shareCsv(list);
    setState(() => _status = 'CSV gotowy do udostępnienia.');
  }

  Future<void> _exportPdf() async {
    final list = _filteredResults;
    if (list.isEmpty) return;
    setState(() => _status = 'Generowanie PDF...');
    await _report.sharePdf(list);
    setState(() => _status = 'PDF gotowy do udostępnienia.');
  }

  DeviceResult _mergeFavoriteState(DeviceResult result) {
    final index = _favorites.indexWhere((e) => e.id == result.id || e.ip == result.ip);
    if (index == -1) return result;
    final fav = _favorites[index];
    return result.copyWith(
      favorite: true,
      labels: fav.labels,
      note: fav.note,
      rtspUrl: fav.rtspUrl,
    );
  }

  Future<void> _toggleFavorite(DeviceResult result) async {
    final exists = _favorites.indexWhere((e) => e.id == result.id || e.ip == result.ip);
    final updated = result.copyWith(favorite: exists == -1);
    setState(() {
      if (exists == -1) {
        _favorites.add(updated);
      } else {
        _favorites.removeAt(exists);
      }
      _replaceResult(updated);
    });
    await _storage.saveFavorites(_favorites);
  }

  void _replaceResult(DeviceResult updated) {
    final index = _results.indexWhere((e) => e.id == updated.id || e.ip == updated.ip);
    if (index != -1) _results[index] = updated;
  }

  Future<void> _editDevice(DeviceResult result) async {
    final noteController = TextEditingController(text: result.note ?? '');
    final labelController = TextEditingController(text: result.labels.join(', '));
    final rtspController = TextEditingController(
      text: result.rtspUrl ?? 'rtsp://${result.ip}:554/Streaming/Channels/101',
    );

    final updated = await showDialog<DeviceResult>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Urządzenie ${result.ip}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelController,
                decoration: const InputDecoration(
                  labelText: 'Etykiety',
                  hintText: 'np. Dahua, klient A, magazyn',
                ),
              ),
              TextField(
                controller: noteController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Notatka'),
              ),
              TextField(
                controller: rtspController,
                decoration: const InputDecoration(labelText: 'Adres RTSP'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Anuluj')),
          FilledButton(
            onPressed: () {
              Navigator.pop(
                context,
                result.copyWith(
                  labels: labelController.text
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList(),
                  note: noteController.text.trim(),
                  rtspUrl: rtspController.text.trim(),
                ),
              );
            },
            child: const Text('Zapisz'),
          ),
        ],
      ),
    );

    noteController.dispose();
    labelController.dispose();
    rtspController.dispose();

    if (updated == null) return;
    setState(() {
      _replaceResult(updated);
      final favIndex = _favorites.indexWhere((e) => e.id == updated.id || e.ip == updated.ip);
      if (favIndex != -1) _favorites[favIndex] = updated.copyWith(favorite: true);
    });
    await _storage.saveFavorites(_favorites);
  }

  Future<void> _openMap(DeviceResult result) async {
    if (!result.hasLocation) {
      setState(() => _status = 'Ten wynik nie ma współrzędnych lokalizacji.');
      return;
    }
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${result.latitude},${result.longitude}');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Future<void> _saveCurrentQuery() async {
    final nameController = TextEditingController(text: 'Zapytanie ${_savedQueries.length + 1}');
    final queryController = TextEditingController(text: _queryController.text);
    final saved = await showDialog<ShodanQuery>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Zapisz zapytanie Shodan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nazwa')),
            TextField(controller: queryController, decoration: const InputDecoration(labelText: 'Zapytanie')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Anuluj')),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              ShodanQuery(name: nameController.text.trim(), query: queryController.text.trim()),
            ),
            child: const Text('Zapisz'),
          ),
        ],
      ),
    );
    nameController.dispose();
    queryController.dispose();
    if (saved == null || saved.query.isEmpty) return;
    setState(() => _savedQueries.add(saved));
    await _storage.saveQueries(_savedQueries);
  }

  Future<void> _exportQueries() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/shodan_queries.json');
    await file.writeAsString(jsonEncode(_savedQueries.map((e) => e.toJson()).toList()));
    await Share.shareXFiles([XFile(file.path)], text: 'Eksport zapytań Shodan');
  }

  Future<void> _importExampleQueries() async {
    const examples = [
      ShodanQuery(name: 'Kamery w Polsce', query: 'product:camera country:PL'),
      ShodanQuery(name: 'RTSP w Polsce', query: 'port:554 country:PL'),
      ShodanQuery(name: 'ONVIF HTTP', query: 'onvif port:80 country:PL'),
    ];
    setState(() {
      for (final q in examples) {
        if (!_savedQueries.any((e) => e.query == q.query)) _savedQueries.add(q);
      }
    });
    await _storage.saveQueries(_savedQueries);
    setState(() => _status = 'Dodano przykładowe zapytania Shodan.');
  }

  List<DeviceResult> get _filteredResults {
    final q = _filterController.text.trim().toLowerCase();
    if (q.isEmpty) return List.unmodifiable(_results);
    return _results.where((r) {
      final haystack = [
        r.ip,
        r.manufacturer,
        r.model,
        r.serialNumber,
        r.firmwareVersion,
        r.country,
        r.organization,
        r.labels.join(' '),
        r.note,
      ].whereType<String>().join(' ').toLowerCase();
      return haystack.contains(q);
    }).toList();
  }

  List<DeviceResult> get _cameraResults => _filteredResults
      .where((r) => r.port == 554 || r.protocol.contains('ONVIF') || r.hasOnvifInfo)
      .toList();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ONVIF Scanner'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.lan), text: 'LAN'),
              Tab(icon: Icon(Icons.videocam), text: 'Kamery'),
              Tab(icon: Icon(Icons.public), text: 'Shodan'),
              Tab(icon: Icon(Icons.star), text: 'Ulubione'),
              Tab(icon: Icon(Icons.settings), text: 'Ustawienia'),
            ],
          ),
          actions: [
            IconButton(
              onPressed: _results.isEmpty || _busy ? null : _exportCsv,
              icon: const Icon(Icons.table_view),
              tooltip: 'Eksport CSV',
            ),
            IconButton(
              onPressed: _results.isEmpty || _busy ? null : _exportPdf,
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'Raport PDF',
            ),
          ],
        ),
        body: Column(
          children: [
            if (_busy) const LinearProgressIndicator(),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: TextField(
                controller: _filterController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.filter_alt),
                  labelText: 'Filtr: numer seryjny, model, producent, etykieta, IP',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildLanTab(),
                  _buildCamerasTab(),
                  _buildShodanTab(),
                  _buildFavoritesTab(),
                  _buildSettingsTab(),
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
      list: _filteredResults,
    );
  }

  Widget _buildCamerasTab() {
    return _buildTabBody(
      top: Align(
        alignment: Alignment.centerLeft,
        child: Text('Kamery i NVR z ONVIF/RTSP: ${_cameraResults.length}'),
      ),
      list: _cameraResults,
      cameraMode: true,
    );
  }

  Widget _buildShodanTab() {
    return _buildTabBody(
      top: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Używaj tylko do własnych/autoryzowanych zasobów. Wpisz własny klucz API Shodan.'),
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
          Wrap(
            spacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _busy ? null : _searchShodan,
                icon: const Icon(Icons.public),
                label: const Text('Szukaj'),
              ),
              OutlinedButton.icon(
                onPressed: _saveCurrentQuery,
                icon: const Icon(Icons.save),
                label: const Text('Zapisz zapytanie'),
              ),
              OutlinedButton.icon(
                onPressed: _exportQueries,
                icon: const Icon(Icons.upload_file),
                label: const Text('Eksport zapytań'),
              ),
              OutlinedButton.icon(
                onPressed: _importExampleQueries,
                icon: const Icon(Icons.download),
                label: const Text('Import przykładów'),
              ),
            ],
          ),
          if (_savedQueries.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _savedQueries
                  .map(
                    (q) => ActionChip(
                      label: Text(q.name),
                      onPressed: () => setState(() => _queryController.text = q.query),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
      list: _filteredResults,
      showMap: true,
    );
  }

  Widget _buildFavoritesTab() {
    return _buildTabBody(
      top: Align(
        alignment: Alignment.centerLeft,
        child: Text('Ulubione urządzenia: ${_favorites.length}'),
      ),
      list: _favorites,
      showMap: true,
      cameraMode: true,
    );
  }

  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        SwitchListTile(
          value: _saveShodanKey,
          onChanged: (value) => setState(() => _saveShodanKey = value),
          title: const Text('Zapisuj klucz API Shodan lokalnie'),
          subtitle: const Text('Klucz zostaje w pamięci telefonu. Nie dodawaj go do repozytorium.'),
        ),
        ListTile(
          leading: const Icon(Icons.star),
          title: const Text('Ulubione urządzenia'),
          subtitle: Text('${_favorites.length} zapisanych pozycji'),
        ),
        ListTile(
          leading: const Icon(Icons.search),
          title: const Text('Zapisane zapytania Shodan'),
          subtitle: Text('${_savedQueries.length} pozycji'),
        ),
        const Divider(),
        const ListTile(
          leading: Icon(Icons.info),
          title: Text('Tryb użycia'),
          subtitle: Text('Aplikacja jest do audytu własnych lub autoryzowanych sieci i zasobów.'),
        ),
      ],
    );
  }

  Widget _buildTabBody({
    required Widget top,
    required List<DeviceResult> list,
    bool showMap = false,
    bool cameraMode = false,
  }) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          top,
          const Divider(height: 24),
          Expanded(
            child: list.isEmpty
                ? const Center(child: Text('Brak wyników'))
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final result = list[index];
                      return Column(
                        children: [
                          DeviceResultTile(result: result),
                          Wrap(
                            spacing: 8,
                            children: [
                              TextButton.icon(
                                onPressed: () => _toggleFavorite(result),
                                icon: Icon(result.favorite ? Icons.star : Icons.star_border),
                                label: Text(result.favorite ? 'Usuń z ulubionych' : 'Ulubione'),
                              ),
                              TextButton.icon(
                                onPressed: () => _editDevice(result),
                                icon: const Icon(Icons.edit_note),
                                label: const Text('Notatki / etykiety'),
                              ),
                              if (showMap || result.hasLocation)
                                TextButton.icon(
                                  onPressed: () => _openMap(result),
                                  icon: const Icon(Icons.map),
                                  label: const Text('Mapa'),
                                ),
                              if (cameraMode)
                                TextButton.icon(
                                  onPressed: () => _editDevice(result),
                                  icon: const Icon(Icons.play_circle),
                                  label: const Text('RTSP'),
                                ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
