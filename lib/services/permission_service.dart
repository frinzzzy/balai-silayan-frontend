import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Runtime permission helpers para sa storage (receipt printing / sales records).
class PermissionService {
  PermissionService._();

  /// Kunin ang storage permission (READ/WRITE_EXTERNAL_STORAGE) para sa
  /// receipt printing at sales/export na nag-a-save ng files.
  /// - Android 13+ : `Permission.storage` ay nangangahulugang photo/media access;
  ///   pero para sa app-specific storage ay granted na naman — kaya ligtas lang
  ///   i-request.
  /// - Android 12- : legacy storage permission.
  static Future<bool> requestStoragePermission() async {
    try {
      final PermissionStatus status = await Permission.storage.request();
      return status.isGranted;
    } catch (e) {
      debugPrint('⚠️ [PermissionService] storage permission request failed: $e');
      return false;
    }
  }

  static Future<bool> hasStoragePermission() async {
    try {
      return await Permission.storage.isGranted;
    } catch (e) {
      debugPrint('⚠️ [PermissionService] storage permission check failed: $e');
      return false;
    }
  }
}
