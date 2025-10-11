// lib/main_persistencia_web_snippet.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';

/// Llama esto en main() antes de runApp().
Future<void> initFirestorePersistenceForWeb() async {
  if (kIsWeb) {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      // cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED, // opcional
    );
  }
}
