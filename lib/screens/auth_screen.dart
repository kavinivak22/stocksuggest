// lib/screens/auth_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  var _isLoginMode = true;
  var _isLoading = false;
  var _enteredEmail = '';
  var _enteredPassword = '';

  // lib/screens/auth_screen.dart -> _submitForm method

void _submitForm() async {
  final isValid = _formKey.currentState!.validate();
  if (!isValid) {
    return;
  }
  _formKey.currentState!.save();

  setState(() {
    _isLoading = true;
  });

  try {
    if (_isLoginMode) {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _enteredEmail,
        password: _enteredPassword,
      );
    } else {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _enteredEmail,
        password: _enteredPassword,
      );
    }
  } on FirebaseAuthException catch (error) {
    // THE FIX: Check if the widget is still mounted before using its context.
    if (!mounted) return;

    var errorMessage = 'An error occurred, please check your credentials!';
    if (error.message != null) {
      errorMessage = error.message!;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(errorMessage),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
    
    // Also check before setting state again
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _isLoginMode ? 'Welcome Back' : 'Create Account',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 40),
                  TextFormField(
                    key: const ValueKey('email'),
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      labelStyle: TextStyle(color: Colors.grey[400]),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey[700]!),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || !value.contains('@')) {
                        return 'Please enter a valid email address.';
                      }
                      return null;
                    },
                    onSaved: (value) {
                      _enteredEmail = value!;
                    },
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    key: const ValueKey('password'),
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: TextStyle(color: Colors.grey[400]),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey[700]!),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.length < 7) {
                        return 'Password must be at least 7 characters long.';
                      }
                      return null;
                    },
                    onSaved: (value) {
                      _enteredPassword = value!;
                    },
                  ),
                  const SizedBox(height: 30),
                  if (_isLoading) const CircularProgressIndicator(),
                  if (!_isLoading)
                    ElevatedButton(
                      onPressed: _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: Text(
                        _isLoginMode ? 'Login' : 'Signup',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  if (!_isLoading)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isLoginMode = !_isLoginMode;
                        });
                      },
                      child: Text(
                        _isLoginMode
                            ? 'Create new account'
                            : 'I already have an account',
                        style: const TextStyle(color: Colors.blueAccent),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}