import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'repositories/workspace_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr');
  final preferences = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [preferencesProvider.overrideWithValue(preferences)],
      child: const MyAgendaApp(),
    ),
  );
}
