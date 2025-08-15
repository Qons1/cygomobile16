import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:uuid/uuid.dart';

class FirebaseService {
  final _db = FirebaseDatabase.instance.ref();
  final _auth = FirebaseAuth.instance;

  /// Create or update user profile
  Future<void> createUserProfile(User user) async {
    await _db.child("users/${user.uid}").set({
      "displayName": user.displayName ?? "",
      "email": user.email ?? "",
      "isPWD": false,
      "pwdStatus": "none", // 'none' | 'pending' | 'approved' | 'rejected'
      "qrData": user.uid,
      "activeTransaction": null
    });
  }

  /// Save PWD request with uploaded image and PWD number
  Future<void> submitPWDRequest({
    required String imageUrl,
    required String pwdNumber,
  }) async {
    final uid = _auth.currentUser!.uid;
    await _db.child("pwdRequests/$uid").set({
      "imageUrl": imageUrl,
      "pwdNumber": pwdNumber,
      "status": "pending"
    });

    await _db.child("users/$uid/pwdStatus").set("pending");
  }

  /// Start a new parking transaction
  Future<String> createTransaction(String vehicleType, String slot) async {
    final uid = _auth.currentUser!.uid;
    final txId = const Uuid().v4();

    final configSnapshot = await _db.child("config").get();
    final config = configSnapshot.value as Map;

    final rate = (vehicleType == "CAR")
        ? config["carRatePerHour"]
        : config["motorcycleRatePerHour"];

    final isPWD = (await _db.child("users/$uid/isPWD").get()).value as bool;

    await _db.child("transactions/$txId").set({
      "txId": txId,
      "uid": uid,
      "vehicleType": vehicleType,
      "slot": slot,
      "timeIn": DateTime.now().toIso8601String(),
      "timeOut": null,
      "durationHours": null,
      "ratePerHour": rate,
      "amount": null,
      "discountPercent": isPWD ? config["pwdDiscountPercent"] : 0.0,
      "discountAmount": null,
      "amountToPay": null,
      "amountPaid": 0,
      "status": "ONGOING"
    });

    await _db.child("users/$uid/activeTransaction").set(txId);

    return txId;
  }

  /// Fetch config
  Future<Map<String, dynamic>> getConfig() async {
    final snapshot = await _db.child("config").get();
    return Map<String, dynamic>.from(snapshot.value as Map);
  }
}
