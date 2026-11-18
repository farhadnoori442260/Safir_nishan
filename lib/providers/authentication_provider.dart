import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection, tr;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:safir_drivers/models/driver.dart';
import 'package:safir_drivers/pages/auth/otp_screen.dart';
import 'package:safir_drivers/pages/auth/register_screen.dart';
import 'package:safir_drivers/utils/lang_helper.dart';

import '../methods/common_method.dart';
import '../models/vehicle_info.dart';

// تبدیل عدد انگلیسی به فارسی/پشتو بر اساس زبان فعال
extension PersianNumberExtension on String {
  String toPersianDigits(BuildContext context) {
    if (Localizations.localeOf(context).languageCode == 'en') {
      return this;
    }

    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const farsi = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];

    String output = this;

    for (int i = 0; i < english.length; i++) {
      output = output.replaceAll(english[i], farsi[i]);
    }

    return output;
  }
}

class AuthenticationProvider extends ChangeNotifier {
  final CommonMethods commonMethods = CommonMethods();

  final FirebaseAuth firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore firebaseFirestore = FirebaseFirestore.instance;
  final FirebaseStorage firebaseStorage = FirebaseStorage.instance;

  final GoogleSignIn googleSignIn = GoogleSignIn(
    serverClientId:
        '983174537944-n532tsodijqddnufq0lgtmevc2g0qr5a.apps.googleusercontent.com',
  );

  bool _isLoading = false;
  bool _isSuccessful = false;
  bool _isGoogleSignedIn = false;
  bool _isGoogleSignInLoading = false;

  int? _resendToken;

  String? _uid;
  String? _phoneNumber;
  Driver? _driverModel;

  Driver? get driverModel => _driverModel;

  String? get uid => _uid;
  String? get phoneNumber => _phoneNumber;

  bool get isSuccessful => _isSuccessful;
  bool get isLoading => _isLoading;
  bool get isGoogleSignedIn => _isGoogleSignedIn;
  bool get isGoogleSigInLoading => _isGoogleSignInLoading;

  /// پیام‌های خطای قابل‌فهم برای راننده (به‌جای متن انگلیسی فایربیس)
  String _authErrorText(FirebaseAuthException e) {
    String t(String key, String fallback) {
      final String v = key.tr();
      return (v.trim().isEmpty || v == key) ? fallback : v;
    }

    switch (e.code) {
      case 'invalid-phone-number':
        return t('auth_invalid_phone', 'شمارهٔ تلفن معتبر نیست');
      case 'too-many-requests':
        return t('auth_too_many_requests',
            'درخواست‌های زیادی ارسال شده؛ کمی بعد دوباره تلاش کنید');
      case 'quota-exceeded':
        return t('auth_quota_exceeded',
            'سقف ارسال پیامک تکمیل شده؛ بعداً دوباره تلاش کنید');
      case 'network-request-failed':
        return t('auth_network_error', 'اتصال اینترنت را بررسی کنید');
      case 'invalid-verification-code':
        return t('auth_wrong_code', 'کد وارد شده اشتباه است');
      case 'session-expired':
        return t('auth_code_expired',
            'کد منقضی شده است؛ دوباره درخواست کد کنید');
      case 'user-disabled':
        return t('auth_user_disabled', 'این حساب غیرفعال شده است');
    }
    return e.message ?? e.toString();
  }

  void startLoading() {
    _isLoading = true;
    notifyListeners();
  }

  void stopLoading() {
    _isLoading = false;
    notifyListeners();
  }

  void startGoogleLoading() {
    _isGoogleSignInLoading = true;
    notifyListeners();
  }

  void stopGoogleLoading() {
    _isGoogleSignInLoading = false;
    notifyListeners();
  }

  /// [replaceCurrent] = true هنگام «ارسال مجدد» از صفحهٔ کد: صفحهٔ کد قبلی
  /// با صفحهٔ جدید جایگزین می‌شود (به‌جای انباشته شدن روی هم).
  void signInWithPhone({
    required BuildContext context,
    required String phoneNumber,
    bool replaceCurrent = false,
  }) async {
    startLoading();

    try {
      await firebaseAuth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        forceResendingToken: replaceCurrent ? _resendToken : null,
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            final UserCredential result =
                await firebaseAuth.signInWithCredential(credential);

            _uid = result.user?.uid;
            _phoneNumber = phoneNumber;
            _isSuccessful = result.user != null;

            notifyListeners();
          } on FirebaseAuthException catch (e) {
            if (context.mounted) {
              commonMethods.displaySnackBar(
                _authErrorText(e),
                context,
              );
            }
          } finally {
            stopLoading();
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          stopLoading();

          if (context.mounted) {
            commonMethods.displaySnackBar(
              _authErrorText(e),
              context,
            );
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          _phoneNumber = phoneNumber;
          _resendToken = resendToken;
          stopLoading();
          notifyListeners();

          Future.delayed(const Duration(seconds: 1), () {
            if (!context.mounted) return;

            final Route<dynamic> route = MaterialPageRoute(
              builder: (context) => OTPScreen(
                verificationId: verificationId,
                phoneNumber: phoneNumber,
              ),
            );

            if (replaceCurrent) {
              Navigator.pushReplacement(context, route);
            } else {
              Navigator.push(context, route);
            }
          });
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          stopLoading();
        },
      );
    } on FirebaseException catch (e) {
      stopLoading();

      if (context.mounted) {
        commonMethods.displaySnackBar(
          e.message ?? tr(context, 'err_generic'),
          context,
        );
      }
    }
  }

  void verifyOTP({
    required BuildContext context,
    required String verificationId,
    required String smsCode,
    required Function onSuccess,
  }) async {
    startLoading();

    try {
      final PhoneAuthCredential phoneAuthCredential =
          PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      final UserCredential userCredential =
          await firebaseAuth.signInWithCredential(phoneAuthCredential);

      final User? user = userCredential.user;

      if (user != null) {
        _uid = user.uid;
        _phoneNumber = user.phoneNumber ?? _phoneNumber;
        _isSuccessful = true;

        notifyListeners();
        onSuccess();
      }
    } on FirebaseAuthException catch (e) {
      if (context.mounted) {
        commonMethods.displaySnackBar(
          _authErrorText(e),
          context,
        );
      }
    } finally {
      stopLoading();
    }
  }

  void saveUserDataToFirebase({
    required BuildContext context,
    required Driver driverModel,
    required VoidCallback onSuccess,
  }) async {
    startLoading();

    try {
      await firebaseFirestore
          .collection('drivers')
          .doc(driverModel.id)
          .set(driverModel.toMap(), SetOptions(merge: true));

      _driverModel = driverModel;
      _uid = driverModel.id;

      notifyListeners();
      onSuccess();
    } on FirebaseException catch (e) {
      if (context.mounted) {
        commonMethods.displaySnackBar(
          e.message ?? tr(context, 'err_save_failed'),
          context,
        );
      }
    } finally {
      stopLoading();
    }
  }

  Future<bool> checkUserExistByEmail(String email) async {
    final QuerySnapshot snapshot = await firebaseFirestore
        .collection('drivers')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  Future<bool> checkUserExistById() async {
    final User? user = firebaseAuth.currentUser;

    if (user == null) return false;

    final DocumentSnapshot doc =
        await firebaseFirestore.collection('drivers').doc(user.uid).get();

    return doc.exists;
  }

  Future<void> getUserDataFromFirebaseDatabase() async {
    final User? user = firebaseAuth.currentUser;

    if (user == null) return;

    try {
      final DocumentSnapshot doc =
          await firebaseFirestore.collection('drivers').doc(user.uid).get();

      if (!doc.exists || doc.data() == null) return;

      final Map<String, dynamic> driverData =
          Map<String, dynamic>.from(doc.data() as Map);

      _driverModel = Driver(
        id: driverData['id'] ?? user.uid,
        firstName: driverData['firstName'] ?? '',
        secondName: driverData['secondName'] ?? '',
        phoneNumber: driverData['phoneNumber'] ?? '',
        address: driverData['address'] ?? '',
        profilePicture: driverData['profilePicture'] ?? '',
        dob: driverData['dob'] ?? '',
        email: driverData['email'] ?? '',
        cnicNumber: driverData['cnicNumber'] ?? '',
        cnicFrontImage: driverData['cnicFrontImage'] ?? '',
        cnicBackImage: driverData['cnicBackImage'] ?? '',
        driverFaceWithCnic: driverData['driverFaceWithCnic'] ?? '',
        drivingLicenseNumber: driverData['drivingLicenseNumber'] ?? '',
        drivingLicenseFrontImage:
            driverData['drivingLicenseFrontImage'] ?? '',
        drivingLicenseBackImage:
            driverData['drivingLicenseBackImage'] ?? '',
        blockStatus: driverData['blockStatus'] ?? '',
        deviceToken: driverData['deviceToken'] ?? '',
        driverRatings:
            driverData['driverRatings'] ?? driverData['driverRattings'] ?? '',
        earnings: driverData['earnings'] ?? '',
        vehicleInfo: driverData['vehicleInfo'] != null
            ? VehicleInfo.fromMap(
                Map<String, dynamic>.from(driverData['vehicleInfo']),
              )
            : VehicleInfo.empty(),
      );

      _uid = _driverModel?.id;
      _phoneNumber = _driverModel?.phoneNumber;

      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching driver data: $e');
    }
  }

  Future<bool> checkDriverFieldsFilled() async {
    final User? user = firebaseAuth.currentUser;

    if (user == null) return false;

    try {
      final DocumentSnapshot doc =
          await firebaseFirestore.collection('drivers').doc(user.uid).get();

      if (!doc.exists || doc.data() == null) return false;

      final Map<String, dynamic> driverData =
          Map<String, dynamic>.from(doc.data() as Map);

      final Map<String, dynamic> vehicleInfo =
          driverData['vehicleInfo'] is Map
              ? Map<String, dynamic>.from(driverData['vehicleInfo'] as Map)
              : <String, dynamic>{};

      final requiredValues = <dynamic>[
        driverData['profilePicture'],
        driverData['firstName'],
        driverData['secondName'],
        driverData['phoneNumber'],
        driverData['dob'],
        driverData['email'],
        driverData['cnicNumber'],
        driverData['cnicFrontImage'],
        driverData['cnicBackImage'],
        driverData['driverFaceWithCnic'],
        driverData['drivingLicenseNumber'],
        driverData['drivingLicenseFrontImage'],
        driverData['drivingLicenseBackImage'],
        vehicleInfo['brand'],
        vehicleInfo['color'],
        vehicleInfo['productionYear'],
        vehicleInfo['vehiclePicture'],
        vehicleInfo['type'],
        vehicleInfo['registrationPlateNumber'],
        vehicleInfo['plateProvince'],
        vehicleInfo['registrationCertificateFrontImage'],
        vehicleInfo['registrationCertificateBackImage'],
      ];

      return requiredValues.every(
        (value) => value != null && value.toString().trim().isNotEmpty,
      );
    } catch (e) {
      debugPrint('Error checking driver fields: $e');
      return false;
    }
  }

  Future<void> signInWithGoogle(
    BuildContext context,
    VoidCallback onSuccess,
  ) async {
    startGoogleLoading();

    try {
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await firebaseAuth.signInWithCredential(credential);

      final User? user = userCredential.user;

      if (user == null) return;

      _uid = user.uid;
      _phoneNumber = user.phoneNumber;
      _isGoogleSignedIn = true;
      _isSuccessful = true;

      notifyListeners();
      onSuccess();
    } on FirebaseAuthException catch (e) {
      if (context.mounted) {
        commonMethods.displaySnackBar(
          _authErrorText(e),
          context,
        );
      }
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      if (context.mounted) {
        commonMethods.displaySnackBar(
          tr(context, 'err_generic'),
          context,
        );
      }
    } finally {
      stopGoogleLoading();
    }
  }

  Future<bool> checkIfDriverIsBlocked() async {
    final User? user = firebaseAuth.currentUser;

    if (user == null) return false;

    try {
      final DocumentSnapshot doc =
          await firebaseFirestore.collection('drivers').doc(user.uid).get();

      if (!doc.exists || doc.data() == null) return false;

      final Map<String, dynamic> driverData =
          Map<String, dynamic>.from(doc.data() as Map);

      final String blockStatus = driverData['blockStatus'] ?? 'no';

      if (blockStatus != 'yes') return false;

      await firebaseAuth.signOut();
      await googleSignIn.signOut();

      _clearLocalSession();
      return true;
    } catch (e) {
      debugPrint('Error checking block status: $e');
      return false;
    }
  }

  Future<bool> deleteCurrentDriverAccount(BuildContext context) async {
    final User? user = firebaseAuth.currentUser;

    if (user == null) {
      if (context.mounted) {
        commonMethods.displaySnackBar(
          tr(context, 'err_account_not_found'),
          context,
        );
      }
      return false;
    }

    startLoading();

    try {
      final String uid = user.uid;

      // مدارک در Cloudinary هستند؛ حذف امن آنها باید در backend باشد.
      // اینجا فقط پروفایل Firestore و حساب Firebase Auth حذف می‌شوند.
      await firebaseFirestore.collection('drivers').doc(uid).delete();

      await googleSignIn.signOut();
      await user.delete();

      _clearLocalSession();
      stopLoading();

      return true;
    } on FirebaseAuthException catch (e) {
      if (context.mounted) {
        final String message = e.code == 'requires-recent-login'
            ? tr(context, 'err_recent_login_required')
            : e.message ?? tr(context, 'err_delete_account');

        commonMethods.displaySnackBar(message, context);
      }

      stopLoading();
      return false;
    } catch (e) {
      debugPrint('Error deleting driver account: $e');

      if (context.mounted) {
        commonMethods.displaySnackBar(
          tr(context, 'err_delete_account'),
          context,
        );
      }

      stopLoading();
      return false;
    }
  }

  Future<void> signOut(BuildContext context) async {
    startLoading();

    try {
      await firebaseAuth.signOut();
      await googleSignIn.signOut();

      _clearLocalSession();

      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const RegisterScreen(),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Sign out error: $e');
      if (context.mounted) {
        commonMethods.displaySnackBar(
          tr(context, 'err_sign_out'),
          context,
        );
      }
    } finally {
      stopLoading();
    }
  }

  void _clearLocalSession() {
    _uid = null;
    _phoneNumber = null;
    _driverModel = null;
    _isGoogleSignedIn = false;
    _isSuccessful = false;
    _resendToken = null;

    notifyListeners();
  }
}
