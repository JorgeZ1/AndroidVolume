import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

enum ReportCategory { volume, positioning, appearance, ads, crash, other }

class ReportImage {
  const ReportImage(this.bytes, this.mime);
  final Uint8List bytes;
  final String mime;
  Map<String, Object> toJson() => {'mime': mime, 'data': base64Encode(bytes)};
}

class ReportException implements Exception {
  const ReportException(this.code);
  final String code;
}

class ReportService {
  ReportService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  static const maxImages = 2;
  static const maxImageBytes = 2 * 1024 * 1024;
  static const endpoint =
      'https://clxclwegjkqvveuyzmaf.supabase.co/functions/v1/submit-report';
  // Public project key only. Server secrets never belong in the app.
  static const _anon =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNseGNsd2VnamtxdnZldXl6bWFmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTA5ODMwNDgsImV4cCI6MjEwNjU1OTA0OH0.aur8rrdUhI55AjnJCk8L-T_6WVNnJrvGTp9SHAbQMzM';

  static String newId() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  Future<String> submit({
    required String id,
    required ReportCategory category,
    required String description,
    required List<ReportImage> images,
    required Map<String, Object?> diagnostics,
  }) async {
    if (description.trim().length < 10 || description.trim().length > 2000) {
      throw const ReportException('description');
    }
    if (images.length > maxImages ||
        images.any(
          (i) =>
              i.bytes.isEmpty ||
              i.bytes.length > maxImageBytes ||
              !['image/jpeg', 'image/png'].contains(i.mime),
        )) {
      throw const ReportException('images');
    }
    try {
      final response = await _client
          .post(
            Uri.parse(endpoint),
            headers: {
              'Authorization': 'Bearer $_anon',
              'apikey': _anon,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'id': id,
              'category': category.name,
              'description': description.trim(),
              'images': images.map((i) => i.toJson()).toList(),
              'diagnostics': diagnostics,
            }),
          )
          .timeout(const Duration(seconds: 45));
      if (response.statusCode == 429) throw const ReportException('limit');
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw const ReportException('send');
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['id'] != id) throw const ReportException('send');
      return id;
    } on TimeoutException {
      throw const ReportException('network');
    } on http.ClientException {
      throw const ReportException('network');
    } on FormatException {
      throw const ReportException('send');
    }
  }

  void close() => _client.close();
}
