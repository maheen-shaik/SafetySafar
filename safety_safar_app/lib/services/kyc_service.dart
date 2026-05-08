import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';
import '../utils/api_config.dart';

class KYCDocument {
  final String fileName;
  final String fileType; // "id" or "profile"
  final String uploadTimestamp;

  KYCDocument({
    required this.fileName,
    required this.fileType,
    required this.uploadTimestamp,
  });

  factory KYCDocument.fromJson(Map<String, dynamic> json) {
    return KYCDocument(
      fileName: json['file_name'] as String,
      fileType: json['file_type'] as String,
      uploadTimestamp: json['upload_timestamp'] as String,
    );
  }
}

class KYCService {
  final String _authToken;

  KYCService(this._authToken);

  /// Get list of pending KYC tourists
  Future<List<dynamic>> getPendingKYC() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.kycPending),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        // Handle wrapped object {"tourists": [...]} or raw list [...]
        if (decoded is Map) {
          return decoded['tourists'] ?? decoded['data'] ?? [];
        } else if (decoded is List) {
          return decoded;
        }
        return [];
      } else {
        throw Exception('Failed to load pending KYC: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[KYC Service] ✗ Error: $e');
      throw Exception('Error fetching pending KYC: $e');
    }
  }

  /// Get list of documents for a specific tourist
  Future<List<KYCDocument>> getDocuments(String userId) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.kycDocuments(userId)),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        final List<dynamic> docsList = (decoded is Map) ? (decoded['documents'] ?? []) : decoded;
        return docsList.map((item) => KYCDocument.fromJson(item as Map<String, dynamic>)).toList();
      } else {
        throw Exception('Failed to load documents: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[KYC Service] ✗ Error: $e');
      throw Exception('Error fetching documents: $e');
    }
  }

  /// Download a specific document (returns binary data)
  Future<List<int>> downloadDocument(String userId, String docType) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.kycDownload(userId, docType)),
        headers: {
          'Authorization': 'Bearer $_authToken',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        throw Exception('Failed to download document: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[KYC Service] ✗ Error downloading: $e');
      throw Exception('Error downloading document: $e');
    }
  }

  /// Approve KYC for a tourist
  Future<void> approvKYC(String userId, String? notes) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.kycApprove(userId)),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
        body: jsonEncode({
          'notes': notes,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Failed to approve KYC: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[KYC Service] ✗ Error: $e');
      throw Exception('Error approving KYC: $e');
    }
  }

  /// Reject KYC for a tourist
  Future<void> rejectKYC(String userId, String reason) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.kycReject(userId)),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
        body: jsonEncode({
          'reason': reason,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Failed to reject KYC: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[KYC Service] ✗ Error: $e');
      throw Exception('Error rejecting KYC: $e');
    }
  }
}
