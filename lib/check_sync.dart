// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/settings_service.dart';
import 'services/mysql_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Connect to DB first so SettingsService can load
  final db = MySQLService();
  await db.connect();
  
  await SettingsService().loadSettings();
  await Firebase.initializeApp();
  
  final settings = SettingsService();
  final email = settings.firebaseAuthEmail;
  final password = settings.firebaseAuthPassword;

  print('Email: $email');
  
  if (email.isNotEmpty && password.isNotEmpty) {
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    print('Logged in to Firebase');
  } else {
    print('No credentials!');
    return;
  }

  try {
      final query = await FirebaseFirestore.instance
          .collection('jobs')
          .where('status', isEqualTo: 'completed')
          .limit(20)
          .get();
          
      print('Found ${query.docs.length} completed jobs.');
      
      for(var doc in query.docs) {
         print('Job ID: ${doc.id}');
      }
  } catch(e) {
      print('Query error: $e');
  }
}
