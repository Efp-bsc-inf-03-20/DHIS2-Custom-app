import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AuthProvider with ChangeNotifier {
  bool _isLoggedIn = false;
  String _username = '';
  String _organizationUnit = ''; // Stores Organization Unit ID
  String _organizationName = ''; // Stores Organization Unit Name
  String _authToken = ''; // Stores the Basic Auth token

  bool get isLoggedIn => _isLoggedIn;
  String get username => _username;
  String get organizationUnit => _organizationUnit;
  String get organizationName => _organizationName;
  String get authToken =>
      _authToken; // This can be used for subsequent API calls

  String _lastErrorMessage = '';
  String get lastErrorMessage => _lastErrorMessage;

  final String _baseUrl = 'https://project.ccdev.org/ictprojects';

  // Keys for SharedPreferences
  static const String _prefsKeyIsLoggedIn = 'isLoggedIn';
  static const String _prefsKeyUsername = 'username';
  static const String _prefsKeyOrgUnit = 'organizationUnit';
  static const String _prefsKeyOrgName = 'organizationName';
  static const String _prefsKeyAuthToken = 'authToken';

  // Validates credentials without setting organization
  Future<String?> validateCredentials(String username, String password) async {
    _lastErrorMessage = '';
    final String basicAuth =
        'Basic ${base64Encode(utf8.encode('$username:$password'))}';

    try {
      // Validate credentials with /api/me
      final meUrl = '$_baseUrl/api/me';
      final meResponse = await http
          .get(
            Uri.parse(meUrl),
            headers: {
              'Authorization': basicAuth,
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (meResponse.statusCode == 200) {
        // Credentials are valid, return the auth token
        return basicAuth;
      } else {
        // Handle different error codes from /api/me
        _handleLoginError(meResponse.statusCode, meResponse.body);
        return null;
      }
    } catch (error) {
      _lastErrorMessage = 'Connection error: Unable to reach the server.';
      notifyListeners();
      return null;
    }
  }

  /// Saves credentials that have been obtained externally (e.g., from WebView).
  /// This method assumes the credentials are valid and does not re-authenticate.
  Future<void> saveCredentials(
    String username,
    String password,
    String orgUnitId,
    String orgUnitName,
  ) async {
    _isLoggedIn = true;
    _username = username;
    // Generate and store the auth token from the provided username and password
    _authToken = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    _organizationUnit = orgUnitId;
    _organizationName = orgUnitName;

    await _persistCredentials();
    notifyListeners();
    if (kDebugMode) {
      print(
        'Credentials saved from external source. Username: $username, OrgUnit: $orgUnitId',
      );
    }
  }

  /// Persists the current authentication state to SharedPreferences.
  Future<void> _persistCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKeyIsLoggedIn, _isLoggedIn);
    await prefs.setString(_prefsKeyUsername, _username);
    await prefs.setString(_prefsKeyOrgUnit, _organizationUnit);
    await prefs.setString(_prefsKeyOrgName, _organizationName);
    await prefs.setString(_prefsKeyAuthToken, _authToken);
  }

  /// Handles different HTTP error codes from the login attempt.
  void _handleLoginError(int statusCode, String responseBody) {
    switch (statusCode) {
      case 401:
        _lastErrorMessage = 'Invalid username or password. Please try again.';
        break;
      case 403:
        _lastErrorMessage =
            'Access denied: You do not have permission to access this resource.';
        break;
      default:
        _lastErrorMessage =
            'Login failed: Server returned status $statusCode. Please contact support if the issue persists.';
    }
    if (kDebugMode) {
      print('Authentication failed: $statusCode - $responseBody');
    }
    notifyListeners(); // Notify to update UI with the error message
  }

  /// Attempts to auto-login by loading saved credentials from SharedPreferences.
  Future<bool> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_prefsKeyIsLoggedIn) ?? false)) {
      return false; // Not logged in or no preference saved
    }

    // Retrieve all necessary information
    final username = prefs.getString(_prefsKeyUsername);
    final authToken = prefs.getString(_prefsKeyAuthToken);
    final orgUnit = prefs.getString(_prefsKeyOrgUnit);
    final orgName = prefs.getString(_prefsKeyOrgName);

    // Ensure essential data for a logged-in state is present
    if (username == null ||
        username.isEmpty ||
        authToken == null ||
        authToken.isEmpty) {
      if (kDebugMode) {
        print(
          'Auto-login failed: Essential credential data missing from SharedPreferences.',
        );
      }
      // Optionally clear inconsistent data
      // await logout(); // This would log them out fully
      return false;
    }

    _isLoggedIn = true;
    _username = username;
    _organizationUnit =
        orgUnit ??
        ''; // Default to empty if not found, though it should be there
    _organizationName = orgName ?? ''; // Default to empty
    _authToken = authToken;

    notifyListeners();
    if (kDebugMode) {
      print('Auto-login successful for user: $_username');
    }
    return true;
  }

  /// Updates the organization unit for the current user
  Future<void> updateOrganization(String orgUnitId, String orgUnitName) async {
    _organizationUnit = orgUnitId;
    _organizationName = orgUnitName;

    await _persistCredentials();
    notifyListeners();

    if (kDebugMode) {
      print('Organization updated to: $orgUnitName ($orgUnitId)');
    }
  }

  /// Logs out the user, clears all saved credentials, and resets the state.
  Future<void> logout() async {
    _isLoggedIn = false;
    _username = '';
    _organizationUnit = '';
    _organizationName = '';
    _authToken = '';
    _lastErrorMessage = ''; // Clear any previous error messages

    final prefs = await SharedPreferences.getInstance();
    // More targeted removal, or clear all if that's the app's policy
    // await prefs.remove(_prefsKeyIsLoggedIn);
    // await prefs.remove(_prefsKeyUsername);
    // await prefs.remove(_prefsKeyOrgUnit);
    // await prefs.remove(_prefsKeyOrgName);
    // await prefs.remove(_prefsKeyAuthToken);
    await prefs
        .clear(); // Clears all data for the app, which is usually fine for logout

    notifyListeners();
    if (kDebugMode) {
      print('User logged out and credentials cleared.');
    }
  }
}
