import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

class DeviceService {
  DeviceService._privateConstructor();
  static final DeviceService instance = DeviceService._privateConstructor();

  final _secureStorage = const FlutterSecureStorage();
  final _deviceInfo = DeviceInfoPlugin();
  final _uuid = const Uuid();

  String? _cachedDeviceId;

  Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) {
      return _cachedDeviceId!;
    }

    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        // androidInfo.id is the unique hardware-tied Android ID
        _cachedDeviceId = androidInfo.id;
      } else if (Platform.isIOS) {
        // Read UUID from iOS Keychain (survives reinstall)
        String? keychainUuid = await _secureStorage.read(key: 'device_persistent_uuid');
        if (keychainUuid == null || keychainUuid.isEmpty) {
          keychainUuid = _uuid.v4();
          await _secureStorage.write(key: 'device_persistent_uuid', value: keychainUuid);
        }
        _cachedDeviceId = keychainUuid;
      } else {
        // Fallback for other platforms
        _cachedDeviceId = 'fallback_device_id';
      }
    } catch (e) {
      debugPrint('⚠️ Error getting device identifier: $e');
      _cachedDeviceId = 'error_device_fallback';
    }

    return _cachedDeviceId!;
  }
}
