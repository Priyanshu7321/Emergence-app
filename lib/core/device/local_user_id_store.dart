import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class LocalUserIdStore {
  LocalUserIdStore._();

  static const _fileName = 'location_user_id.txt';
  static String? _cachedId;
  static Future<String>? _pendingFuture;

  static Future<String> getOrCreate() async {
    if (_cachedId != null && _cachedId!.isNotEmpty) {
      return _cachedId!;
    }
    if (_pendingFuture != null) {
      return _pendingFuture!;
    }
    _pendingFuture = _doGetOrCreate();
    final id = await _pendingFuture!;
    _cachedId = id;
    _pendingFuture = null;
    return id;
  }

  static Future<String> _doGetOrCreate() async {
    try {
      final directory = await getApplicationSupportDirectory();
      final file = File('${directory.path}/$_fileName');

      if (await file.exists()) {
        final id = (await file.readAsString()).trim();
        if (id.isNotEmpty) {
          return id;
        }
      }

      final id = const Uuid().v4();
      unawaited(file.writeAsString(id));
      return id;
    } catch (_) {
      return const Uuid().v4();
    }
  }
}

void unawaited(Future<void> future) {}
