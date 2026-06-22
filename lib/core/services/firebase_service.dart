import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:horoscope/core/models/user_model.dart';
import 'package:horoscope/core/utils/firestore_extension.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Anonim oturum aç
  Future<User?> signInAnonymously() async {
    try {
      final UserCredential userCredential = await _auth.signInAnonymously();
      return userCredential.user;
    } catch (e) {
      debugPrint('⚠️ Firebase Anonim Giriş Hatası: $e');
      return null;
    }
  }

  // Kullanıcı profilini Firestore'a kaydet
  Future<void> saveUserProfile(UserModel user) async {
    try {
      await _firestore.collection('users').doc(user.uid).set(user.toMap(), SetOptions(merge: true));
      debugPrint('✅ Kullanıcı profili Firestore\'a kaydedildi: ${user.uid}');
    } catch (e) {
      debugPrint('⚠️ Firestore Kullanıcı Kayıt Hatası: $e');
      rethrow;
    }
  }

  // Kullanıcı profilini Firestore'dan çek
  Future<UserModel?> getUserProfile(String uid) async {
    try {
      final DocumentSnapshot doc = await _firestore.collection('users').doc(uid).safeGet();
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint('⚠️ Firestore Profil Çekme Hatası: $e');
      return null;
    }
  }

  // Mevcut Firebase kullanıcısını al
  User? get currentUser => _auth.currentUser;
}
