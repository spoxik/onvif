import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_profile.dart';
import '../models/device_result.dart';
import '../models/shodan_query.dart';

class StorageService {
  static const _favoritesKey = 'favorites';
  static const _queriesKey = 'shodan_queries';
  static const _apiKeyKey = 'shodan_api_key';
  static const _authProfilesKey = 'auth_profiles';
  static const _concurrencyKey = 'scan_concurrency';

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

  Future<List<AuthProfile>> loadAuthProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_authProfilesKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List;
    return list
        .whereType<Map<String, dynamic>>()
        .map(AuthProfile.fromJson)
        .toList();
  }

  Future<void> saveAuthProfiles(List<AuthProfile> profiles) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(profiles.map((e) => e.toJson()).toList());
    await prefs.setString(_authProfilesKey, raw);
  }

  Future<String> loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiKeyKey) ?? '';
  }

  Future<void> saveApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyKey, apiKey);
  }

  Future<int> loadConcurrency() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_concurrencyKey) ?? 64;
  }

  Future<void> saveConcurrency(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_concurrencyKey, value.clamp(1, 256));
  }
}
