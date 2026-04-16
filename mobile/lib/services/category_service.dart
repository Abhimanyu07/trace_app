import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Local category storage for app classification.
/// Works for both phone apps and desktop apps.
/// Desktop categories are also synced to the desktop API.
class CategoryService {
  static const _key = 'app_categories';

  Future<Map<String, String>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key);
    if (json == null) return {};
    final map = jsonDecode(json) as Map<String, dynamic>;
    return map.map((k, v) => MapEntry(k, v as String));
  }

  Future<String> getCategory(String appName) async {
    final cats = await getAll();
    return cats[appName] ?? 'unclassified';
  }

  Future<void> setCategory(String appName, String category) async {
    final prefs = await SharedPreferences.getInstance();
    final cats = await getAll();
    cats[appName] = category;
    await prefs.setString(_key, jsonEncode(cats));
  }

  Future<void> applyCategories(List<Map<String, dynamic>> apps) async {
    final cats = await getAll();
    for (final app in apps) {
      final name = app['app_name'] as String? ?? '';
      if (cats.containsKey(name)) {
        app['category'] = cats[name];
      }
    }
  }
}
