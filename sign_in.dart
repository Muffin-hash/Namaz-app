import 'package:flutter/material.dart';
import 'sign_up.dart';
import 'auth.dart';
import 'homepage.dart'; // <-- Make sure to import your Homepage file here

class SignIn extends StatefulWidget {
  const SignIn({super.key});

  @override
  State<SignIn> createState() => _SignInState();
}

class _SignInState extends State<SignIn> {
  // 1. Add controllers to get the text from the TextFields
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  // Optional: Add a loading state to prevent multiple taps
  bool _isLoading = false;

  // 2. Move the sign in logic inside the State class
  Future<void> _handleSignIn() async {
    setState(() {
      _isLoading = true; // Start loading
    });

    try {
      // --- MOCK API CALL ---
      // In a real app, you would use _emailController.text and _passwordController.text
      // e.g., final response = await api.signIn(_emailController.text, _passwordController.text);
      
      // Pretend the API returned this token
      String serverToken = "eyJhbGciOiJIUzI1NiIsInR5c..."; 
      
      // SAVE THE TOKEN TO THE DEVICE
      await AuthService.saveToken(serverToken);

      // 3. NAVIGATE TO HOMEPAGE
      // Use pushReplacement so the user can't go back to the login screen by pressing the back button
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) =>const NamazTimingPage()), 
          
        );
      }
    } catch (e) {
      // Handle errors here (e.g., show a Snackbar)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in failed. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false; // Stop loading
        });
      }
    }
  }

  @override
  void dispose() {
    // Always dispose controllers to prevent memory leaks
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text("Sign In"),
        backgroundColor: Colors.blue,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const SizedBox(height: 100),
                TextField(
                  // 4. Attach the controller
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: "Email",
                    hintText: "Enter your email address",
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 20),
                TextField(
                  // 4. Attach the controller
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: "Password",
                    hintText: "Enter your password",
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.text,
                  obscureText: true,
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    // 5. Call the sign in function
                    onPressed: _isLoading ? null : _handleSignIn, // Disable button while loading
                    child: _isLoading 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white))
                        : const Text("Sign In"),
                  ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const SignUp()),
                    );
                  },
                  child: const Text("Don't have an account? Sign Up"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}