import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'services/local_quiz_store.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Firebase ────────────────────────────────────────────────────────────────
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyBPf3hqZA2sUTlnLKHs5Wt7uwt4-snuoOA",
        authDomain: "self-study-app-66c44.firebaseapp.com",
        projectId: "self-study-app-66c44",
        storageBucket: "self-study-app-66c44.firebasestorage.app",
        messagingSenderId: "1022393083216",
        appId: "1:1022393083216:web:4d72a1ae764e7e45a53855",
        measurementId: "G-YN420FX9G1",
      ),
    );
  } else {
    // Mobile uses google-services.json / GoogleService-Info.plist
    await Firebase.initializeApp();
  }

  // Enable Firestore offline persistence on mobile (Android/iOS).
  // On web we skip this — it causes slow startup; Firestore already
  // provides an in-memory cache within the browser session.
  if (!kIsWeb) {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );
  }

  // ── Hive (local offline cache) ───────────────────────────────────────────────
  await Hive.initFlutter();
  await LocalQuizStore.init();

  runApp(const ProviderScope(child: StudieazyApp()));
}
