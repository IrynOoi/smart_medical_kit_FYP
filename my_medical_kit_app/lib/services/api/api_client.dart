// lib/services/api/api_client.dart
// HTTP client wrapper for all API calls to the backend server.
// Provides GET, POST, PUT, DELETE methods with consistent headers and base URL.

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiClient {
  /// Returns the base URL for the API from environment variables,
  /// with a fallback to localhost:5000 for development.
  static String get baseUrl {
    return dotenv.env['API_BASE_URL'] ?? 'http://localhost:5000';
  }

  /// Default headers sent with every request:
  /// - Content-Type: application/json (assumes JSON API)
  /// - ngrok-skip-browser-warning: 'true' to bypass ngrok's interstitial warning page when using tunnels.
  static Map<String, String> get defaultHeaders {
    return {
      'Content-Type': 'application/json',
      'ngrok-skip-browser-warning': 'true',
    };
  }

  // ---------------------- GET Request ----------------------
  /// Sends a GET request to the given endpoint.
  /// Returns the raw http.Response.
  static Future<http.Response> get(String endpoint) async {
    return await http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: defaultHeaders,
    );
  }

  // ---------------------- POST Request ----------------------
  /// Sends a POST request with an optional JSON body.
  /// Body is automatically encoded as JSON.
  /// Includes a 30-second timeout to avoid hanging on slow networks.
  static Future<http.Response> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final response = await http
        .post(
          uri,
          headers: defaultHeaders,
          body: jsonEncode(body), // convert Map to JSON string
        )
        .timeout(const Duration(seconds: 30)); // timeout after 30 seconds
    return response;
  }

  // ---------------------- PUT Request ----------------------
  /// Sends a PUT request with an optional JSON body.
  /// Body is encoded as JSON if provided.
  static Future<http.Response> put(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    return await http.put(
      Uri.parse('$baseUrl$endpoint'),
      headers: defaultHeaders,
      body: body != null ? jsonEncode(body) : null,
    );
  }

  // ---------------------- DELETE Request ----------------------
  /// Sends a DELETE request to the given endpoint.
  /// (No body is sent; all data is in the URL or headers.)
  static Future<http.Response> delete(String endpoint) async {
    return await http.delete(
      Uri.parse('$baseUrl$endpoint'),
      headers: defaultHeaders,
    );
  }
}
