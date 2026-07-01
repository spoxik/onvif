import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models/auth_profile.dart';
import 'models/device_result.dart';
import 'models/shodan_query.dart';
import 'services/export_service.dart';
import 'services/lan_scanner_service.dart';
import 'services/report_service.dart';
import 'services/rtsp_service.dart';
import 'services/shodan_service.dart';
import 'services/storage_service.dart';
import 'widgets/device_result_tile.dart';

void main() => runApp(const OnvifScannerApp());

class OnvifScannerApp extends StatelessWidget {
  const OnvifScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ONVIF Scanner',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blueGrey),
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
  final _rtsp = RtspService();

  final _cidrController = TextEditingController(text: '10.10.0.0/24');
  final _portsController = TextEditingController(text: '80,8080,8000,8899,554');
  final _apiKeyController = TextEditingController();
  final _queryController = TextEditingController(text: 'product:camera country:PL');
  final _serialController = TextEditingController();
  final _filterController = TextEditingController();
  final _resultSerialFilterController = TextEditingController();
  final _concurrencyController = TextEditingController(text: '64');

  final List<DeviceResult> _results = [];
  final List<DeviceResult> _favorites = [];
  final List<ShodanQuery> _savedQueries = [];
  final List<AuthProfile> _authProfiles = [];

  bool _busy = false;
  bool _saveShodanKey = true;
  String? _status;

  @override
  void initState() {
    super.initState();
    _loadLocalData();
    _filterController.addListener(() => setState(() {}));
    _resultSerialFilterController.addListener(() => setState(() {}));
  }

  Future<void> _loadLocalData() async {
    final favorites = await _storage.loadFavorites();
    final queries = await _storage.loadQueries();
    final apiKey = await _storage.loadApiKey();
    final authProfiles = await _storage.loadAuthProfiles();
    final concurrency = await _storage.loadConcurrency();
    if (!mounted) return;
    setState(() {
      _favorites
        ..clear()
        ..addAll(favorites);
      _savedQueries
        ..clear()
        ..addAll(queries);
      _authProfiles
        ..clear()
        ..addAll(authProfiles);
      _apiKeyController.text = apiKey;
      _concurrencyController.text = concurrency.toString();
    });
  }

  @override
  void dispose() {
    _cidrController.dispose();
    _portsController.dispose();
    _apiKeyController.dispose();
    _queryController.dispose();
    _serialController.dispose();
    _filterController.dispose();
    _resultSerialFilterController.dispose();
    _concurrencyController.dispose();
    super.dispose();
  }

  Future<void> _scanLan() async {
    final concurrency = int.tryParse(_concurrencyController.text.trim()) ?? 64;
    await _storage.saveConcurrency(concurrency);
    setState(() {
      _busy = true;
      _status = 'Skanowanie wielowątkowe LAN/VPN...';
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
        concurrency: concurrency,
        authProfiles: _authProfiles,
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
      if (_saveShodanKey) await _storage.saveApiKey(_apiKeyController.text);
      final results = await _shodan.search(apiKey: _apiKeyController.text, query: _queryController.text);
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

  Future<void> _searchShodanSerial() async {
    final serial = _serialController.text.trim();
    if (serial.isEmpty) {
      setState(() => _status = 'Wpisz numer seryjny do wyszukania.');
      return;
    }
    final query = '"$serial"';
    _queryController.text = query;
    _resultSerialFilterController.text = serial;
    setState(() {
      _busy = true;
      _status = 'Szukam numeru seryjnego w Shodan: $serial';
      _results.clear();
    });

    try {
      if (_saveShodanKey) await _storage.saveApiKey(_apiKeyController.text);
      final results = await _shodan.search(apiKey: _apiKeyController.text, query: query);
      final filtered = results.where((r) {
        final haystack = [
          r.ip,
          r.manufacturer,
          r.model,
          r.serialNumber,
          r.firmwareVersion,
          r.organization,
          r.hostnames.join(' '),
        ].whereType<String>().join(' ').toLowerCase();
        return haystack.contains(serial.toLowerCase()) || r.serialNumber != null;
      }).toList();
      setState(() {
        _results.addAll((filtered.isEmpty ? results : filtered).map(_mergeFavoriteState));
        _status = 'Shodan SN: znaleziono ${_results.length} wyników dla $serial.';
      });
    } catch (e) {
      setState(() => _status = 'Błąd Shodan SN: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportCsv() async {
    final list = _filteredResults;
    if (list.isEmpty) return;
    setState(() => _status = 'Eksport CSV...');
    await _export.shareCsv(list);
    setState(() => _status = 'CSV gotowy.');
  }

  Future<void> _exportXlsx() async {
    final list = _filteredResults;
    if (list.isEmpty) return;
    setState(() => _status = 'Eksport XLSX...');
    await _export.shareXlsx(list);
    setState(() => _status = 'XLSX gotowy.');
  }

  Future<void> _exportJson() async {
    final list = _filteredResults;
    if (list.isEmpty) return;
    setState(() => _status = 'Eksport JSON...');
    await _export.shareJson(list);
    setState(() => _status = 'JSON gotowy.');
  }

  Future<void> _exportPdf() async {
    final list = _filteredResults;
    if (list.isEmpty) return;
    setState(() => _status = 'Generowanie PDF...');
    await _report.sharePdf(list);
    setState(() => _status = 'PDF gotowy.');
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
      rtspOk: fav.rtspOk,
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
    final rtspController = TextEditingController(text: result.rtspUrl ?? 'rtsp://${result.ip}:554/Streaming/Channels/101');

    final updated = await showDialog<DeviceResult>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Urządzenie ${result.ip}'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: labelController, decoration: const InputDecoration(labelText: 'Etykiety', hintText: 'np. Dahua, magazyn')),
            TextField(controller: noteController, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Notatka')),
            TextField(controller: rtspController, decoration: const InputDecoration(labelText: 'Adres RTSP / link')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Anuluj')),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              result.copyWith(
                labels: labelController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
                note: noteController.text.trim(),
                rtspUrl: rtspController.text.trim(),
              ),
            ),
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

  Future<void> _testRtsp(DeviceResult result) async {
    setState(() => _status = 'Test RTSP ${result.ip}:554...');
    final ok = await _rtsp.testRtsp(result.ip);
    final updated = result.copyWith(rtspOk: ok, rtspUrl: result.rtspUrl ?? 'rtsp://${result.ip}:554/');
    setState(() {
      _replaceResult(updated);
      final favIndex = _favorites.indexWhere((e) => e.id == updated.id || e.ip == updated.ip);
      if (favIndex != -1) _favorites[favIndex] = updated.copyWith(favorite: true);
      _status = ok ? 'RTSP działa: ${result.ip}' : 'RTSP nie odpowiedział: ${result.ip}';
    });
    await _storage.saveFavorites(_favorites);
  }

  Future<void> _addAuthProfile() async {
    final name = TextEditingController(text: 'Profil ${_authProfiles.length + 1}');
    final user = TextEditingController(text: 'admin');
    final secret = TextEditingController();

    final profile = await showDialog<AuthProfile>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dodaj profil logowania'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Dodawaj tylko poświadczenia do urządzeń, którymi możesz zarządzać.'),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Nazwa profilu')),
            TextField(controller: user, decoration: const InputDecoration(labelText: 'Login')),
            TextField(controller: secret, obscureText: true, decoration: const InputDecoration(labelText: 'Hasło / sekret')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Anuluj')),
          FilledButton(
            onPressed: () => Navigator.pop(context, AuthProfile(name: name.text.trim(), username: user.text.trim(), secret: secret.text)),
            child: const Text('Zapisz lokalnie'),
          ),
        ],
      ),
    );
    name.dispose();
    user.dispose();
    secret.dispose();
    if (profile == null || profile.username.isEmpty) return;
    setState(() => _authProfiles.add(profile));
    await _storage.saveAuthProfiles(_authProfiles);
  }

  Future<void> _openExternal(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null || !uri.hasScheme) {
      setState(() => _status = 'Nieprawidłowy link: $rawUrl');
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) setState(() => _status = 'Nie udało się otworzyć linku: $rawUrl');
  }

  Future<void> _openWeb(DeviceResult result) async {
    final scheme = result.port == 443 ? 'https' : 'http';
    await _openExternal('$scheme://${result.ip}:${result.port}/');
  }

  Future<void> _openRtsp(DeviceResult result) async {
    final url = result.rtspUrl?.trim().isNotEmpty == true ? result.rtspUrl!.trim() : 'rtsp://${result.ip}:554/';
    await _openExternal(url);
  }

  Future<void> _openMap(DeviceResult result) async {
    if (!result.hasLocation) {
      setState(() => _status = 'Ten wynik nie ma współrzędnych lokalizacji.');
      return;
    }
    await _openExternal('https://www.google.com/maps/search/?api=1&query=${result.latitude},${result.longitude}');
  }

  Future<void> _saveCurrentQuery() async {
    final nameController = TextEditingController(text: 'Zapytanie ${_savedQueries.length + 1}');
    final queryController = TextEditingController(text: _queryController.text);
    final saved = await showDialog<ShodanQuery>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Zapisz zapytanie Shodan'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nazwa')),
            TextField(controller: queryController, decoration: const InputDecoration(labelText: 'Zapytanie')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Anuluj')),
          FilledButton(onPressed: () => Navigator.pop(context, ShodanQuery(name: nameController.text.trim(), query: queryController.text.trim())), child: const Text('Zapisz')),
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
      ShodanQuery(name: 'Przykład SN', query: '"SERIAL_NUMBER_TUTAJ"'),
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
    final sn = _resultSerialFilterController.text.trim().toLowerCase();
    final source = _results.where((r) {
      final generalHaystack = [
        r.ip,
        r.manufacturer,
        r.model,
        r.serialNumber,
        r.firmwareVersion,
        r.country,
        r.organization,
        r.labels.join(' '),
        r.note,
        r.authProfileName,
      ].whereType<String>().join(' ').toLowerCase();

      final serialHaystack = [
        r.serialNumber,
        r.hardwareId,
        r.model,
        r.manufacturer,
      ].whereType<String>().join(' ').toLowerCase();

      final generalOk = q.isEmpty || generalHaystack.contains(q);
      final serialOk = sn.isEmpty || serialHaystack.contains(sn);
      return generalOk && serialOk;
    }).toList();
    return List.unmodifiable(source);
  }

  List<DeviceResult> get _cameraResults => _filteredResults.where((r) => r.port == 554 || r.protocol.contains('ONVIF') || r.hasOnvifInfo).toList();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ONVIF Scanner'),
          bottom: const TabBar(isScrollable: true, tabs: [
            Tab(icon: Icon(Icons.lan), text: 'LAN'),
            Tab(icon: Icon(Icons.videocam), text: 'Kamery'),
            Tab(icon: Icon(Icons.public), text: 'Shodan'),
            Tab(icon: Icon(Icons.star), text: 'Ulubione'),
            Tab(icon: Icon(Icons.settings), text: 'Ustawienia'),
          ]),
          actions: [
            PopupMenuButton<String>(
              tooltip: 'Eksport',
              onSelected: (v) {
                if (v == 'csv') _exportCsv();
                if (v == 'xlsx') _exportXlsx();
                if (v == 'json') _exportJson();
                if (v == 'pdf') _exportPdf();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'csv', child: Text('Eksport CSV')),
                PopupMenuItem(value: 'xlsx', child: Text('Eksport XLSX')),
                PopupMenuItem(value: 'json', child: Text('Eksport JSON')),
                PopupMenuItem(value: 'pdf', child: Text('Raport PDF')),
              ],
              icon: const Icon(Icons.ios_share),
            ),
          ],
        ),
        body: Column(children: [
          if (_busy) const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: TextField(controller: _filterController, decoration: const InputDecoration(prefixIcon: Icon(Icons.filter_alt), labelText: 'Filtr ogólny: model, producent, etykieta, IP', border: OutlineInputBorder())),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: TextField(
              controller: _resultSerialFilterController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.confirmation_number),
                labelText: 'Filtr wyników po Serial Number',
                hintText: 'Wpisz cały lub fragment numeru seryjnego',
                border: const OutlineInputBorder(),
                suffixIcon: _resultSerialFilterController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _resultSerialFilterController.clear(),
                      ),
              ),
            ),
          ),
          Expanded(child: TabBarView(children: [_buildLanTab(), _buildCamerasTab(), _buildShodanTab(), _buildFavoritesTab(), _buildSettingsTab()])),
          if (_status != null) Padding(padding: const EdgeInsets.all(12), child: Text(_status!)),
        ]),
      ),
    );
  }

  Widget _buildLanTab() => _buildTabBody(
        top: Column(children: [
          TextField(controller: _cidrController, decoration: const InputDecoration(labelText: 'Podsieć CIDR', hintText: 'np. 10.10.0.0/24')),
          TextField(controller: _portsController, decoration: const InputDecoration(labelText: 'Porty', hintText: '80,8080,8000,8899,554')),
          TextField(controller: _concurrencyController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Wątki skanowania', hintText: 'np. 64')),
          const SizedBox(height: 8),
          FilledButton.icon(onPressed: _busy ? null : _scanLan, icon: const Icon(Icons.search), label: const Text('Skanuj LAN/VPN')),
        ]),
        list: _filteredResults,
      );

  Widget _buildCamerasTab() => _buildTabBody(top: Align(alignment: Alignment.centerLeft, child: Text('Kamery i NVR z ONVIF/RTSP: ${_cameraResults.length}')), list: _cameraResults, cameraMode: true);

  Widget _buildShodanTab() => _buildTabBody(
        top: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Używaj tylko do własnych/autoryzowanych zasobów. Wpisz własny klucz API Shodan.'),
          TextField(controller: _apiKeyController, obscureText: true, decoration: const InputDecoration(labelText: 'Shodan API key')),
          TextField(controller: _queryController, decoration: const InputDecoration(labelText: 'Zapytanie Shodan', hintText: 'np. product:camera country:PL')),
          const SizedBox(height: 8),
          TextField(
            controller: _serialController,
            decoration: const InputDecoration(
              labelText: 'Serial Number do wyszukania w Shodan',
              hintText: 'np. 3H043D1PAJADF77',
              prefixIcon: Icon(Icons.confirmation_number),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 4, children: [
            FilledButton.icon(onPressed: _busy ? null : _searchShodan, icon: const Icon(Icons.public), label: const Text('Szukaj')),
            FilledButton.icon(onPressed: _busy ? null : _searchShodanSerial, icon: const Icon(Icons.confirmation_number), label: const Text('Szukaj SN')),
            OutlinedButton.icon(onPressed: _saveCurrentQuery, icon: const Icon(Icons.save), label: const Text('Zapisz zapytanie')),
            OutlinedButton.icon(onPressed: _exportQueries, icon: const Icon(Icons.upload_file), label: const Text('Eksport zapytań')),
            OutlinedButton.icon(onPressed: _importExampleQueries, icon: const Icon(Icons.download), label: const Text('Import przykładów')),
          ]),
          if (_savedQueries.isNotEmpty) Wrap(spacing: 8, children: _savedQueries.map((q) => ActionChip(label: Text(q.name), onPressed: () => setState(() => _queryController.text = q.query))).toList()),
        ]),
        list: _filteredResults,
        showMap: true,
      );

  Widget _buildFavoritesTab() => _buildTabBody(top: Align(alignment: Alignment.centerLeft, child: Text('Ulubione urządzenia: ${_favorites.length}')), list: _favorites, showMap: true, cameraMode: true);

  Widget _buildSettingsTab() => ListView(padding: const EdgeInsets.all(12), children: [
        SwitchListTile(value: _saveShodanKey, onChanged: (value) => setState(() => _saveShodanKey = value), title: const Text('Zapisuj klucz API Shodan lokalnie'), subtitle: const Text('Klucz zostaje w pamięci telefonu. Nie dodawaj go do repozytorium.')),
        ListTile(leading: const Icon(Icons.speed), title: const Text('Wielowątkowość skanowania'), subtitle: Text('Aktualnie: ${_concurrencyController.text} wątków')),
        ListTile(leading: const Icon(Icons.key), title: const Text('Profile logowania do urządzeń'), subtitle: Text('${_authProfiles.length} zapisanych profili lokalnych'), trailing: IconButton(icon: const Icon(Icons.add), onPressed: _addAuthProfile)),
        ..._authProfiles.asMap().entries.map((entry) => ListTile(
              leading: const Icon(Icons.person),
              title: Text(entry.value.label),
              subtitle: const Text('Używany tylko lokalnie podczas skanowania ONVIF'),
              trailing: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () async {
                  setState(() => _authProfiles.removeAt(entry.key));
                  await _storage.saveAuthProfiles(_authProfiles);
                },
              ),
            )),
        const Divider(),
        ListTile(leading: const Icon(Icons.star), title: const Text('Ulubione urządzenia'), subtitle: Text('${_favorites.length} zapisanych pozycji')),
        ListTile(leading: const Icon(Icons.search), title: const Text('Zapisane zapytania Shodan'), subtitle: Text('${_savedQueries.length} pozycji')),
        const ListTile(leading: Icon(Icons.info), title: Text('Tryb użycia'), subtitle: Text('Aplikacja jest do audytu własnych lub autoryzowanych sieci i zasobów.')),
      ]);

  Widget _buildTabBody({required Widget top, required List<DeviceResult> list, bool showMap = false, bool cameraMode = false}) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        top,
        const Divider(height: 24),
        if (list.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: Text('Brak wyników')),
          )
        else
          ...list.map((result) => Column(children: [
                DeviceResultTile(result: result),
                Wrap(spacing: 8, runSpacing: 4, children: [
                  TextButton.icon(onPressed: () => _toggleFavorite(result), icon: Icon(result.favorite ? Icons.star : Icons.star_border), label: Text(result.favorite ? 'Usuń z ulubionych' : 'Ulubione')),
                  TextButton.icon(onPressed: () => _editDevice(result), icon: const Icon(Icons.edit_note), label: const Text('Notatki / etykiety')),
                  TextButton.icon(onPressed: () => _openWeb(result), icon: const Icon(Icons.open_in_browser), label: const Text('WWW')),
                  if (showMap || result.hasLocation) TextButton.icon(onPressed: () => _openMap(result), icon: const Icon(Icons.map), label: const Text('Mapa')),
                  if (cameraMode || result.port == 554) TextButton.icon(onPressed: () => _testRtsp(result), icon: const Icon(Icons.network_check), label: Text(result.rtspOk == true ? 'RTSP OK' : 'Test RTSP')),
                  if (cameraMode || result.rtspUrl != null || result.port == 554) TextButton.icon(onPressed: () => _openRtsp(result), icon: const Icon(Icons.play_circle), label: const Text('Otwórz RTSP')),
                ]),
                const SizedBox(height: 8),
              ])),
      ],
    );
  }
}
