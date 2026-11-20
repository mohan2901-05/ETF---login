import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:etf_loans/core/constants/api_constants.dart';
import 'package:etf_loans/core/errors/app_errors.dart' as errors;

class NetworkService {
  final http.Client _client;

  NetworkService({http.Client? client}) : _client = client ?? http.Client();

  Future<Map<String, dynamic>> post(String endpoint, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('${Constants.baseUrl}$endpoint');
    final response = await _send(() => _client.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: body == null ? null : json.encode(body),
        ));

    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> get(String endpoint) async {
    final uri = Uri.parse('${Constants.baseUrl}$endpoint');
    final response = await _send(() => _client.get(
          uri,
          headers: {'Content-Type': 'application/json'},
        ));

    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> put(String endpoint, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('${Constants.baseUrl}$endpoint');
    final response = await _send(() => _client.put(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: body == null ? null : json.encode(body),
        ));

    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> delete(String endpoint) async {
    final uri = Uri.parse('${Constants.baseUrl}$endpoint');
    final response = await _send(() => _client.delete(
          uri,
          headers: {'Content-Type': 'application/json'},
        ));

    return _handleResponse(response);
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(Constants.connectionTimeout);
    } on TimeoutException {
      throw errors.TimeoutException('Request timed out. Please try again.');
    } on http.ClientException {
      throw errors.NetworkException(
          'Could not reach the server. Check your connection and try again.');
    }
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    final responseBody = {
      'statusCode': response.statusCode,
      'body': response.body,
    };

    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        responseBody['data'] = json.decode(response.body);
      } catch (_) {
        responseBody['data'] = response.body;
      }
    } else {
      responseBody['error'] = _parseError(response.body);
    }

    return responseBody;
  }

  dynamic _parseError(String body) {
    try {
      final parsed = json.decode(body);
      return parsed['message'] ?? parsed['error'] ?? 'Unknown error';
    } catch (_) {
      return body.isNotEmpty ? body : 'Unknown error';
    }
  }

  void close() {
    _client.close();
  }
}
