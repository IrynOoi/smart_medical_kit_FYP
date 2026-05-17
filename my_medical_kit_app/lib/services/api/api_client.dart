// lib/services/api/api_client.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiClient {
  static String get baseUrl {
    return dotenv.env['API_BASE_URL'] ?? 'http://localhost:5000';
  }

  static Map<String, String> get defaultHeaders {
    return {
      'Content-Type': 'application/json',
      'ngrok-skip-browser-warning': 'true',
    };
  }

  static Future<http.Response> get(String endpoint) async {
    return await http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: defaultHeaders,
    );
  }

  static Future<http.Response> post(String endpoint, {Map<String, dynamic>? body}) async {
    return await http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: defaultHeaders,
      body: body != null ? jsonEncode(body) : null,
    );
  }

  static Future<http.Response> put(String endpoint, {Map<String, dynamic>? body}) async {
    return await http.put(
      Uri.parse('$baseUrl$endpoint'),
      headers: defaultHeaders,
      body: body != null ? jsonEncode(body) : null,
    );
  }

  static Future<http.Response> delete(String endpoint) async {
    return await http.delete(
      Uri.parse('$baseUrl$endpoint'),
      headers: defaultHeaders,
    );
  }
}
