import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/device_result.dart';
import '../models/shodan_query.dart';

class StorageService {
  static const _favoritesKey = 'favorites';
  static const _queriesKey = 'shodan_queries';
  static const _apiKeyKey = 'shodan_api_key';

  Future<List<DeviceResult>> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_favoritesKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List;
    return list
        .whereType<Map<String, dynamic>>()
        .map(DeviceResult.fromJson)
        .toList();
  }

  Future<void> saveFavorites(List<DeviceResult> devices) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(devices.map((e) => e.toJson()).toList());
    await prefs.setString(_favoritesKey, raw);
  }

  Future<List<ShodanQuery>> loadQueries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_queriesKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List;
    return list
        .whereType<Map<String, dynamic>>()
        .map(ShodanQuery.fromJson)
        .toList();
  }

  Future<void> saveQueries(List<ShodanQuery> queries) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(queries.map((e) => e.toJson()).toList());
    await prefs.setString(_queriesKey, raw);
  }

  Future<String> loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiKeyKey) ?? '';
  }

  Future<void> saveApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyKey, apiKey);
  }
}
