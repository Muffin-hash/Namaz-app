import 'package:flutter/material.dart';
import 'sign_up.dart';

class Splash extends StatefulWidget {
  const Splash({super.key});

  @override
  State<Splash> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<Splash> {
  
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  void _navigate() async {
    await Future.delayed(const Duration(milliseconds: 2000));
    
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SignUp()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(  // No MaterialApp here!
      body: Center(
        child: const Text(
          "My app",
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}