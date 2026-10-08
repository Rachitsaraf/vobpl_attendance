import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../dashboard/dashboard_screen.dart';
import 'login_screen.dart';
import 'profile_setup_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (authProvider.status == AuthStatus.authenticating) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (authProvider.status == AuthStatus.authenticated) {
      // Check if profile (PIN and Unit) is set up
      if (authProvider.user?.pin == null || authProvider.user?.unit == null) {
        return const ProfileSetupScreen();
      }
      return const DashboardScreen();
    }

    // Redirect to Actual Login Screen
    return const LoginScreen();
  }
}
