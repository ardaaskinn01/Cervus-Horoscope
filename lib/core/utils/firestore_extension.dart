import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

extension FirestoreSafeGet<T> on DocumentReference<T> {
  Future<DocumentSnapshot<T>> safeGet({Duration timeout = const Duration(seconds: 5)}) async {
    try {
      return await get().timeout(timeout);
    } catch (e) {
      debugPrint('⚠️ Firestore get() hatası/timeout ($e), cache deneniyor...');
      try {
        final cacheDoc = await get(const GetOptions(source: Source.cache));
        if (cacheDoc.exists) {
          debugPrint('ℹ️ Firestore cache okuması başarılı.');
          return cacheDoc;
        }
      } catch (cacheError) {
        debugPrint('⚠️ Firestore cache get() hatası: $cacheError');
      }
      rethrow;
    }
  }
}

extension FirestoreSafeQueryGet<T> on Query<T> {
  Future<QuerySnapshot<T>> safeGet({Duration timeout = const Duration(seconds: 5)}) async {
    try {
      return await get().timeout(timeout);
    } catch (e) {
      debugPrint('⚠️ Firestore query get() hatası/timeout ($e), cache deneniyor...');
      try {
        return await get(const GetOptions(source: Source.cache));
      } catch (cacheError) {
        debugPrint('⚠️ Firestore cache query get() hatası: $cacheError');
      }
      rethrow;
    }
  }
}
