import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'splash.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://enqzotqfujkguznhzqxw.supabase.co',
    publishableKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVucXpvdHFmdWprZ3V6bmh6cXh3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE5NDMyMzEsImV4cCI6MjA5NzUxOTIzMX0.v1SQvgNOIxLg1n2IEIF_o04c_QzqxCXSwZMdLw_mS7U',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const Splash(),
    );
  }
}