import 'package:flutter/material.dart';

import 'database_helper.dart';
import 'card_repository.dart';
import 'catalogue_screens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final helper = DatabaseHelper();
  try {
    await helper.init();
  } catch (error, stackTrace) {
    debugPrint('Database initialization failed: $error\n$stackTrace');
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Could not open local storage. Restart the app and check the logs. '
                  'Existing data has not been erased.',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return;
  }
  runApp(
    MaterialApp(
      title: 'Card Catalogue',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: FoldersScreen(repository: CardRepository(helper)),
    ),
  );
}
