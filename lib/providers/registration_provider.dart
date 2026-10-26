import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'package:safir_drivers/global/global.dart';
import 'package:safir_drivers/methods/common_method.dart';
import 'package:safir_drivers/methods/image_picker_service.dart';
import 'package:safir_drivers/models/driver.dart';
import 'package:safir_drivers/models/vehicle_info.dart';
import 'package:safir_drivers/providers/authentication_provider.dart';
import 'package:safir_drivers/utils/lang_helper.dart';

class RegistrationProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;
  final FirebaseStorage _storage =
      FirebaseStorage.instance;

  bool _isLoading = false;
  bool _isFetchLoading = false;

  XFile? _profilePhoto;
  bool _isPhotoAdded = false;

  bool _isFormValidBasic = false;
  bool _isFormValidCninc = false;

  XFile? _cnicFrontImage;
  XFile? _cnicBackImage;
  XFile? _cnicWithSelfieImage;

  bool _isFormValidDrivingLicense = false;
  XFile? _drivingLicenseFrontImage;
  XFile? _drivingLicenseBackImage;

  String? _selectedVehicle;
  bool _isVehicleBasicFormValid = false;

  final RegExp licenseRegExp =
      RegExp(r'^[A-Z]{2}-d{2}-d{4}$');

  XFile? _vehicleImage;
  bool _isVehiclePhotoAdded = false;

  XFile? _vehicleRegistrationFrontImage;
  XFile? _vehicleRegistrationBackImage;

  bool _isDataFetched = false;

  bool get isDataFetched => _isDataFetched;

  double _driverEarnings = 0.0;

  double get driverEarnings => _driverEarnings;

  String _plateProvince = 'کابل';
  String _plateCategory = 'ش';
  String _plateType = 'شخصی';

  String get plateProvince => _plateProvince;
  String get plateCategory => _plateCategory;
  String get plateType => _plateType;

  void setPlateProvince(String val) {
    _plateProvince = val;
    checkVehicleBasicFormValidity();
    notifyListeners();
  }

  void setPlateCategory(String val) {
    _plateCategory = val;
    checkVehicleBasicFormValidity();
    notifyListeners();
  }

  void setPlateType(String val) {
    _plateType = val;
    checkVehicleBasicFormValidity();
    notifyListeners();
  }

  final TextEditingController firstNameController =
      TextEditingController();

  final TextEditingController lastNameController =
      TextEditingController();

  final TextEditingController dobController =
      TextEditingController();

  final TextEditingController addressController =
      TextEditingController();

  final TextEditingController emailController =
      TextEditingController();

  final TextEditingController phoneController =
      TextEditingController();

  final TextEditingController cnicController =
      TextEditingController();

  final TextEditingController drivingLicenseController =
      TextEditingController();

  final TextEditingController brandController =
      TextEditingController();

  final TextEditingController colorController =
      TextEditingController();

  final TextEditingController numberPlateController =
      TextEditingController();

  final TextEditingController productionYearController =
      TextEditingController();

  XFile? get profilePhoto => _profilePhoto;
  bool get isPhotoAdded => _isPhotoAdded;
  bool get isFormValidBasic => _isFormValidBasic;
  bool get isLoading => _isLoading;
  bool get isFetchLoading => _isFetchLoading;
  bool get isFormValidCninc => _isFormValidCninc;
  bool get isFormValidDrivingLicnese =>
      _isFormValidDrivingLicense;
  bool get isVehicleBasicFormValid =>
      _isVehicleBasicFormValid;
  String? get selectedVehicle => _selectedVehicle;

  XFile? get vehicleRegistrationFrontImage =>
      _vehicleRegistrationFrontImage;

  set vehicleRegistrationFrontImage(XFile? val) {
    _vehicleRegistrationFrontImage = val;
    notifyListeners();
  }

  XFile? get vehicleRegistrationBackImage =>
      _vehicleRegistrationBackImage;

  set vehicleRegistrationBackImage(XFile? val) {
    _vehicleRegistrationBackImage = val;
    notifyListeners();
  }

  Timer? _debounce;

  CommonMethods commonMethods = CommonMethods();

  XFile? get cnicWithSelfieImage =>
      _cnicWithSelfieImage;

  set cnicWithSelfieImage(XFile? val) {
    _cnicWithSelfieImage = val;
    notifyListeners();
  }

  XFile? get cnincFrontImage => _cnicFrontImage;

  set cnincFrontImage(XFile? val) {
    _cnicFrontImage = val;
    notifyListeners();
  }

  XFile? get cnincBackImage => _cnicBackImage;

  set cnincBackImage(XFile? val) {
    _cnicBackImage = val;
    notifyListeners();
  }

  XFile? get drivingLicenseFrontImage =>
      _drivingLicenseFrontImage;

  set drivingLicenseFrontImage(XFile? val) {
    _drivingLicenseFrontImage = val;
    notifyListeners();
  }

  XFile? get drivingLicenseBackImage =>
      _drivingLicenseBackImage;

  set drivingLicenseBackImage(XFile? val) {
    _drivingLicenseBackImage = val;
    notifyListeners();
  }

  XFile? get vehicleImage => _vehicleImage;

  set vehicleImage(XFile? val) {
    _vehicleImage = val;
    notifyListeners();
  }

  bool get isVehiclePhotoAdded =>
      _isVehiclePhotoAdded;

  set isVehiclePhotoAdded(bool val) {
    _isVehiclePhotoAdded = val;
    notifyListeners();
  }

  Map<String, dynamic> get driverInformation {
    return {
      'name':
          '$driverName $driverSecondName'.trim().isNotEmpty
              ? '$driverName $driverSecondName'
              : firstNameController.text,
      'phone': driverPhone.isNotEmpty
          ? driverPhone
          : phoneController.text,
      'email': driverEmail.isNotEmpty
          ? driverEmail
          : emailController.text,
      'rating': rating.isNotEmpty ? rating : '0.0',
      'photo': driverPhoto,
      'carModel': carModel,
      'carColor': carColor,
      'carNumber': carNumber,
    };
  }

  void startLoading() {
    _isLoading = true;
    notifyListeners();
  }

  void stopLoading() {
    _isLoading = false;
    notifyListeners();
  }

  void startFetchLoading() {
    _isFetchLoading = true;
    notifyListeners();
  }

  void stopFetchLoading() {
    _isFetchLoading = false;
    notifyListeners();
  }

  void initFields(
    AuthenticationProvider authProvider,
  ) {
    if (!authProvider.isGoogleSignedIn) {
      phoneController.text =
          authProvider.phoneNumber ?? '';
    } else {
      emailController.text = authProvider
              .firebaseAuth.currentUser?.email ??
          '';
      phoneController.text = '';
    }

    checkBasicFormValidity();
  }

  void checkVehicleBasicFormValidity() {
  if (_debounce?.isActive ?? false) {
    _debounce!.cancel();
  }

  _debounce = Timer(
    const Duration(milliseconds: 300),
    () {
      final bool isValid =
          _selectedVehicle != null &&
          _selectedVehicle!.isNotEmpty &&
          brandController.text.trim().isNotEmpty &&
          colorController.text.trim().isNotEmpty &&
          numberPlateController.text.trim().isNotEmpty &&
          productionYearController.text.trim().isNotEmpty &&
          _plateProvince.isNotEmpty &&
          _plateCategory.isNotEmpty &&
          _plateType.isNotEmpty;

      // فقط در صورت تغییر واقعیِ وضعیت دکمه، صفحه بازسازی شود.
      if (_isVehicleBasicFormValid == isValid) {
        return;
      }

      _isVehicleBasicFormValid = isValid;
      notifyListeners();
    },
  );
  }

  void checkCNICFormValidity() {
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
    }

    _debounce = Timer(
      const Duration(milliseconds: 300),
      () {
        _isFormValidCninc =
            _cnicFrontImage != null &&
                _cnicBackImage != null &&
                cnicController.text.isNotEmpty &&
                cnicController.text.length >= 10;

        notifyListeners();
      },
    );
  }

  void checkDrivingLicenseFormValidity() {
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
    }

    _debounce = Timer(
      const Duration(milliseconds: 300),
      () {
        _isFormValidDrivingLicense =
            _drivingLicenseFrontImage != null &&
                _drivingLicenseBackImage != null &&
                drivingLicenseController.text.isNotEmpty;

        notifyListeners();
      },
    );
  }

  void checkVehicleBasicFormValidity() {
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
    }

    _debounce = Timer(
      const Duration(milliseconds: 300),
      () {
        _isVehicleBasicFormValid =
            _selectedVehicle != null &&
                brandController.text.isNotEmpty &&
                colorController.text.isNotEmpty &&
                numberPlateController.text.isNotEmpty &&
                productionYearController.text.isNotEmpty &&
                _plateProvince.isNotEmpty &&
                _plateCategory.isNotEmpty &&
                _plateType.isNotEmpty;

        notifyListeners();
      },
    );
  }

  void setSelectedVehicle(String vehicle) {
    _selectedVehicle = vehicle;
    checkVehicleBasicFormValidity();
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();

    firstNameController.dispose();
    lastNameController.dispose();
    dobController.dispose();
    cnicController.dispose();
    emailController.dispose();
    phoneController.dispose();
    drivingLicenseController.dispose();
    brandController.dispose();
    colorController.dispose();
    numberPlateController.dispose();
    productionYearController.dispose();

    super.dispose();
  }

  Future<void> pickProfileImageFromGallary() async {
    final ImagePicker picker = ImagePicker();

    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
    );

    if (image != null) {
      _profilePhoto = image;
      _isPhotoAdded = true;

      checkBasicFormValidity();
      notifyListeners();
    }
  }

  Future<void> pickVehicleImageFromCamera() async {
    final ImagePicker picker = ImagePicker();

    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
    );

    if (image != null) {
      _vehicleImage = image;
      _isVehiclePhotoAdded = true;
      notifyListeners();
    }
  }

  Future<void> pickAndCropCnincImage(
    BuildContext context,
    bool isFrontImage,
  ) async {
    final ImagePickerService imagePickerService =
        ImagePickerService();

    final XFile? pickedFile =
        await imagePickerService.pickCropImage(
      context: context,
      cropAspectRatio: const CropAspectRatio(
        ratioX: 16,
        ratioY: 9,
      ),
      imageSource: ImageSource.camera,
    );

    if (pickedFile != null) {
      if (isFrontImage) {
        _cnicFrontImage = pickedFile;
      } else {
        _cnicBackImage = pickedFile;
      }

      checkCNICFormValidity();
    }
  }

  Future<void> pickAndCropVehicleRegistrationImages(
    BuildContext context,
    bool isFrontImage,
  ) async {
    final ImagePickerService imagePickerService =
        ImagePickerService();

    final XFile? pickedFile =
        await imagePickerService.pickCropImage(
      context: context,
      cropAspectRatio: const CropAspectRatio(
        ratioX: 16,
        ratioY: 12,
      ),
      imageSource: ImageSource.camera,
    );

    if (pickedFile != null) {
      if (isFrontImage) {
        _vehicleRegistrationFrontImage =
            pickedFile;
      } else {
        _vehicleRegistrationBackImage =
            pickedFile;
      }
    }

    notifyListeners();
  }

  Future<void> pickAndCropDrivingLicenseImage(
    BuildContext context,
    bool isFrontImage,
  ) async {
    final ImagePickerService imagePickerService =
        ImagePickerService();

    final XFile? pickedFile =
        await imagePickerService.pickCropImage(
      context: context,
      cropAspectRatio: const CropAspectRatio(
        ratioX: 16,
        ratioY: 9,
      ),
      imageSource: ImageSource.camera,
    );

    if (pickedFile != null) {
      if (isFrontImage) {
        _drivingLicenseFrontImage = pickedFile;
      } else {
        _drivingLicenseBackImage = pickedFile;
      }

      checkDrivingLicenseFormValidity();
    }
  }

  Future<void> pickCnincImageWithSelfie(
    BuildContext context,
  ) async {
    final ImagePickerService imagePickerService =
        ImagePickerService();

    final XFile? pickedFile =
        await imagePickerService.pickCropImage(
      context: context,
      cropAspectRatio: const CropAspectRatio(
        ratioX: 20,
        ratioY: 20,
      ),
      imageSource: ImageSource.camera,
    );

    if (pickedFile != null) {
      _cnicWithSelfieImage = pickedFile;
    }

    notifyListeners();
  }

  Future<String> uploadImageToFirebaseStorage(
    XFile? photo,
    String path,
    BuildContext context,
  ) async {
    if (photo == null) {
      throw Exception(
        tr(context, 'err_no_image_selected'),
      );
    }

    if (photo.path.startsWith('http')) {
      return photo.path;
    }

    const String cloudName = 'mhjpeymi';
    const String uploadPreset = 'safir_preset';

    final Uri url = Uri.parse(
      'https://api.cloudinary.com/v1_1/'
      '$cloudName/image/upload',
    );

    try {
      final http.MultipartRequest request =
          http.MultipartRequest(
        'POST',
        url,
      );

      request.fields['upload_preset'] =
          uploadPreset;

      final http.MultipartFile multipartFile =
          await http.MultipartFile.fromPath(
        'file',
        photo.path,
      );

      request.files.add(multipartFile);

      final http.StreamedResponse streamedResponse =
          await request.send();

      final http.Response response =
          await http.Response.fromStream(
        streamedResponse,
      );

      if (response.statusCode == 200 ||
          response.statusCode == 201) {
        final Map<String, dynamic> responseData =
            jsonDecode(response.body);

        return responseData['secure_url']
            .toString();
      }

      throw Exception(
        'Upload failed: ${response.statusCode}',
      );
    } catch (error) {
      debugPrint(
        'Cloudinary Upload Error: $error',
      );
      rethrow;
    }
  }

  Future<void> saveUserData(
    BuildContext context,
  ) async {
    if (!isFormValidBasic ||
        !isFormValidCninc ||
        !isFormValidDrivingLicnese ||
        !isVehicleBasicFormValid) {
      commonMethods.displaySnackBar(
        tr(context, 'err_fill_all_fields'),
        context,
      );
      return;
    }

    final User? currentUser =
        _auth.currentUser;

    if (currentUser == null) {
      debugPrint(
        'Error saving driver data: '
        'user is not signed in.',
      );
      return;
    }

    try {
      startLoading();

      final String profilePictureUrl =
          await uploadImageToFirebaseStorage(
        _profilePhoto,
        'ProfilePicture',
        context,
      );

      final String frontCnincImageUrl =
          await uploadImageToFirebaseStorage(
        _cnicFrontImage,
        'Cninc',
        context,
      );

      final String backCnincImageUrl =
          await uploadImageToFirebaseStorage(
        _cnicBackImage,
        'Cninc',
        context,
      );

      final String faceWithCnincImageUrl =
          await uploadImageToFirebaseStorage(
        _cnicWithSelfieImage,
        'SelfieWithCninc',
        context,
      );

      final String drivingLicenseFrontImageUrl =
          await uploadImageToFirebaseStorage(
        _drivingLicenseFrontImage,
        'DrivingLicenseImages',
        context,
      );

      final String drivingLicenseBackImageUrl =
          await uploadImageToFirebaseStorage(
        _drivingLicenseBackImage,
        'DrivingLicenseImages',
        context,
      );

      final String vehicleImageUrl =
          await uploadImageToFirebaseStorage(
        _vehicleImage,
        'VehicleImage',
        context,
      );

      final String vehicleRegistrationFrontImageUrl =
          await uploadImageToFirebaseStorage(
        _vehicleRegistrationFrontImage,
        'VehicleRegistrationImages',
        context,
      );

      final String vehicleRegistrationBackImageUrl =
          await uploadImageToFirebaseStorage(
        _vehicleRegistrationBackImage,
        'VehicleRegistrationImages',
        context,
      );

      final Driver driver = Driver(
        id: currentUser.uid,
        profilePicture: profilePictureUrl,
        firstName: firstNameController.text,
        secondName: lastNameController.text,
        phoneNumber: phoneController.text,
        address: addressController.text,
        dob: dobController.text,
        email: emailController.text,
        cnicNumber: cnicController.text,
        cnicFrontImage: frontCnincImageUrl,
        cnicBackImage: backCnincImageUrl,
        driverFaceWithCnic: faceWithCnincImageUrl,
        drivingLicenseNumber:
            drivingLicenseController.text,
        drivingLicenseFrontImage:
            drivingLicenseFrontImageUrl,
        drivingLicenseBackImage:
            drivingLicenseBackImageUrl,
        blockStatus: 'no',
        deviceToken: '',
        earnings: '0',
        driverRatings: '0',
        vehicleInfo: VehicleInfo(
          type: selectedVehicle.toString(),
          brand: brandController.text,
          color: colorController.text,
          vehiclePicture: vehicleImageUrl,
          productionYear:
              productionYearController.text,
          registrationPlateNumber:
              numberPlateController.text,
          plateProvince: _plateProvince,
          plateCategory: _plateCategory,
          plateType: _plateType,
          registrationCertificateFrontImage:
              vehicleRegistrationFrontImageUrl,
          registrationCertificateBackImage:
              vehicleRegistrationBackImageUrl,
        ),
      );

      final DocumentReference<Map<String, dynamic>>
          driverRef = _firestore
              .collection('drivers')
              .doc(currentUser.uid);

      await driverRef.set(
        driver.toMap(),
        SetOptions(merge: true),
      );

      final DocumentSnapshot<Map<String, dynamic>>
          currentDriverSnapshot =
          await driverRef.get();

      final Map<String, dynamic> currentDriverData =
          currentDriverSnapshot.data() ??
              <String, dynamic>{};

      final bool hasEarnings =
          currentDriverData.containsKey('earnings') ||
              currentDriverData.containsKey(
                'totalEarnings',
              );

      if (!hasEarnings) {
        await driverRef.set(
          {
            'earnings': 0.0,
            'totalEarnings': 0.0,
          },
          SetOptions(merge: true),
        );
      }

      await retrieveCurrentDriverInfo();
      await fetchDriverEarnings();
    } catch (error, stackTrace) {
      debugPrint(
        'Error saving driver data: $error',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );
    } finally {
      stopLoading();
    }
  }

  Future<void> fetchUserData() async {
    if (_isDataFetched ||
        _auth.currentUser == null) {
      return;
    }

    try {
      startFetchLoading();

      final DocumentSnapshot<Map<String, dynamic>>
          doc = await _firestore
              .collection('drivers')
              .doc(_auth.currentUser!.uid)
              .get();

      if (doc.exists && doc.data() != null) {
        final Map<String, dynamic> data =
            doc.data()!;

        firstNameController.text =
            data['firstName']?.toString() ?? '';

        lastNameController.text =
            data['secondName']?.toString() ?? '';

        phoneController.text =
            data['phoneNumber']?.toString() ?? '';

        addressController.text =
            data['address']?.toString() ?? '';

        dobController.text =
            data['dob']?.toString() ?? '';

        emailController.text =
            data['email']?.toString() ?? '';

        cnicController.text =
            data['cnicNumber']?.toString() ?? '';

        drivingLicenseController.text =
            data['drivingLicenseNumber']?.toString() ??
                '';

        final Map<String, dynamic> vehicleData =
            data['vehicleInfo'] is Map
                ? Map<String, dynamic>.from(
                    data['vehicleInfo'] as Map,
                  )
                : <String, dynamic>{};

        _selectedVehicle =
            vehicleData['type']?.toString() ?? '';

        brandController.text =
            vehicleData['brand']?.toString() ?? '';

        colorController.text =
            vehicleData['color']?.toString() ?? '';

        numberPlateController.text =
            vehicleData['registrationPlateNumber']
                    ?.toString() ??
                '';

        _plateProvince =
            vehicleData['plateProvince']?.toString() ??
                'کابل';

        _plateCategory =
            vehicleData['plateCategory']?.toString() ??
                'ش';

        _plateType =
            vehicleData['plateType']?.toString() ??
                'شخصی';

        productionYearController.text =
            vehicleData['productionYear']?.toString() ??
                '';

        _profilePhoto = await _fetchImageFromUrl(
          data['profilePicture']?.toString() ?? '',
        );

        _cnicFrontImage = await _fetchImageFromUrl(
          data['cnicFrontImage']?.toString() ?? '',
        );

        _cnicBackImage = await _fetchImageFromUrl(
          data['cnicBackImage']?.toString() ?? '',
        );

        _cnicWithSelfieImage =
            await _fetchImageFromUrl(
          data['driverFaceWithCnic']?.toString() ??
              '',
        );

        _drivingLicenseFrontImage =
            await _fetchImageFromUrl(
          data['drivingLicenseFrontImage']
                  ?.toString() ??
              '',
        );

        _drivingLicenseBackImage =
            await _fetchImageFromUrl(
          data['drivingLicenseBackImage']
                  ?.toString() ??
              '',
        );

        _vehicleImage = await _fetchImageFromUrl(
          vehicleData['vehiclePicture']?.toString() ??
              '',
        );

        _vehicleRegistrationFrontImage =
            await _fetchImageFromUrl(
          vehicleData[
                      'registrationCertificateFrontImage']
                  ?.toString() ??
              '',
        );

        _vehicleRegistrationBackImage =
            await _fetchImageFromUrl(
          vehicleData[
                      'registrationCertificateBackImage']
                  ?.toString() ??
              '',
        );

        _isDataFetched = true;
        stopFetchLoading();
        notifyListeners();
      } else {
        stopFetchLoading();
      }
    } catch (error, stackTrace) {
      debugPrint(
        'Error loading driver data: $error',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      stopFetchLoading();
    }
  }

  Future<XFile?> _fetchImageFromUrl(
    String url,
  ) async {
    if (url.isEmpty) {
      return null;
    }

    try {
      final http.Response response =
          await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        return null;
      }

      final Directory directory =
          await getTemporaryDirectory();

      final String filePath =
          '${directory.path}/'
          '${DateTime.now().millisecondsSinceEpoch}.jpg';

      final File file = File(filePath);

      await file.writeAsBytes(response.bodyBytes);

      return XFile(file.path);
    } catch (error) {
      debugPrint(
        'Error fetching image: $error',
      );

      return null;
    }
  }

  double _parseMoney(Object? value) {
    if (value == null) {
      return 0.0;
    }

    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      final String normalized = value
          .replaceAll(',', '')
          .replaceAll('؋', '')
          .replaceAll('افغانی', '')
          .trim();

      return double.tryParse(normalized) ?? 0.0;
    }

    return 0.0;
  }

  Object? _getEarningsValue(
    Map<String, dynamic> data,
  ) {
    return data['earnings'] ??
        data['totalEarnings'] ??
        data['totalEarning'] ??
        data['driverEarnings'] ??
        data['wallet'];
  }

  Future<void> fetchDriverEarnings() async {
    final String? uid = _auth.currentUser?.uid;

    if (uid == null || uid.isEmpty) {
      _driverEarnings = 0.0;
      notifyListeners();
      return;
    }

    _isFetchLoading = true;
    notifyListeners();

    try {
      final DocumentSnapshot<Map<String, dynamic>>
          doc = await _firestore
              .collection('drivers')
              .doc(uid)
              .get();

      if (!doc.exists || doc.data() == null) {
        _driverEarnings = 0.0;

        debugPrint(
          'EARNINGS: driver document not found',
        );

        return;
      }

      final Map<String, dynamic> data =
          doc.data()!;

      final Object? rawValue =
          _getEarningsValue(data);

      _driverEarnings =
          _parseMoney(rawValue);

      debugPrint(
        'EARNINGS: $_driverEarnings | '
        'RAW VALUE: $rawValue',
      );
    } catch (error, stackTrace) {
      debugPrint(
        'EARNINGS ERROR: $error',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      _driverEarnings = 0.0;
    } finally {
      _isFetchLoading = false;
      notifyListeners();
    }
  }

  Future<void> addDriverEarnings(
    String amount, {
    String? tripId,
  }) async {
    final String? uid = _auth.currentUser?.uid;

    if (uid == null || uid.isEmpty) {
      throw Exception(
        'Driver is not signed in.',
      );
    }

    final double amountToAdd =
        _parseMoney(amount);

    if (amountToAdd <= 0) {
      debugPrint(
        'EARNINGS: invalid amount: $amount',
      );
      return;
    }

    final DocumentReference<Map<String, dynamic>>
        driverRef = _firestore
            .collection('drivers')
            .doc(uid);

    bool alreadyAdded = false;

    await _firestore.runTransaction(
      (transaction) async {
        final DocumentSnapshot<
            Map<String, dynamic>> snapshot =
            await transaction.get(driverRef);

        final Map<String, dynamic> data =
            snapshot.data() ??
                <String, dynamic>{};

        final String cleanTripId =
            tripId?.trim() ?? '';

        if (cleanTripId.isNotEmpty &&
            data['lastEarningTripId'] ==
                cleanTripId) {
          alreadyAdded = true;
          return;
        }

        final double oldEarnings =
            _parseMoney(
          _getEarningsValue(data),
        );

        final double newEarnings =
            oldEarnings + amountToAdd;

        final Map<String, dynamic> updateData =
            <String, dynamic>{
          'earnings': newEarnings,
          'totalEarnings': newEarnings,
          'updatedAt':
              FieldValue.serverTimestamp(),
        };

        if (cleanTripId.isNotEmpty) {
          updateData['lastEarningTripId'] =
              cleanTripId;
        }

        transaction.set(
          driverRef,
          updateData,
          SetOptions(merge: true),
        );
      },
    );

    await fetchDriverEarnings();

    debugPrint(
      'EARNINGS UPDATED: $_driverEarnings | '
      'ALREADY ADDED: $alreadyAdded',
    );
  }

  Future<void> retrieveCurrentDriverInfo() async {
    try {
      if (_auth.currentUser == null) {
        return;
      }

      final DocumentSnapshot<Map<String, dynamic>>
          doc = await _firestore
              .collection('drivers')
              .doc(_auth.currentUser!.uid)
              .get();

      if (doc.exists && doc.data() != null) {
        final Map<String, dynamic> data =
            doc.data()!;

        driverName =
            data['firstName']?.toString() ?? '';

        driverSecondName =
            data['secondName']?.toString() ?? '';

        driverPhone =
            data['phoneNumber']?.toString() ?? '';

        driverEmail =
            data['email']?.toString() ?? '';

        address =
            data['address']?.toString() ?? '';

        rating =
            data['driverRatings']?.toString() ??
                data['driverRattings']?.toString() ??
                '';

        driverPhoto =
            data['profilePicture']?.toString() ?? '';

        final Map<String, dynamic> vehicleData =
            data['vehicleInfo'] is Map
                ? Map<String, dynamic>.from(
                    data['vehicleInfo'] as Map,
                  )
                : <String, dynamic>{};

        carModel =
            vehicleData['brand']?.toString() ?? '';

        carColor =
            vehicleData['color']?.toString() ?? '';

        final String rawNumber =
            vehicleData['registrationPlateNumber']
                    ?.toString() ??
                '';

        final String province =
            vehicleData['plateProvince']
                    ?.toString() ??
                '';

        final String category =
            vehicleData['plateCategory']
                    ?.toString() ??
                '';

        final String type =
            vehicleData['plateType']?.toString() ??
                '';

        if (province.isNotEmpty &&
            rawNumber.isNotEmpty) {
          carNumber =
              '$province - $category '
              '$rawNumber ($type)';
        } else {
          carNumber = rawNumber;
        }

        notifyListeners();
      }
    } catch (error, stackTrace) {
      debugPrint(
        'Error retrieving current driver profile: '
        '$error',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> updateBasicDriverInfo(
    BuildContext context,
  ) async {
    try {
      _isLoading = true;
      notifyListeners();

      final String newProfilePicture =
          await uploadImageToFirebaseStorage(
        _profilePhoto,
        'ProfilePicture',
        context,
      );

      final Map<String, dynamic> driverData =
          <String, dynamic>{
        'firstName': firstNameController.text,
        'secondName': lastNameController.text,
        'email': emailController.text,
        'address': addressController.text,
        'phoneNumber': phoneController.text,
        'dob': dobController.text,
        'profilePicture': newProfilePicture,
      };

      await _firestore
          .collection('drivers')
          .doc(_auth.currentUser!.uid)
          .set(
        driverData,
        SetOptions(merge: true),
      );

      await retrieveCurrentDriverInfo();
    } catch (error) {
      debugPrint(
        'Error updating basic driver info: $error',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateCnincInfo(
    BuildContext context,
  ) async {
    try {
      _isLoading = true;
      notifyListeners();

      final String frontCnincImageUrl =
          await uploadImageToFirebaseStorage(
        _cnicFrontImage,
        'Cninc',
        context,
      );

      final String backCnincImageUrl =
          await uploadImageToFirebaseStorage(
        _cnicBackImage,
        'Cninc',
        context,
      );

      final Map<String, dynamic> driverData =
          <String, dynamic>{
        'cnicFrontImage':
            frontCnincImageUrl,
        'cnicBackImage':
            backCnincImageUrl,
        'cnicNumber':
            cnicController.text,
      };

      await _firestore
          .collection('drivers')
          .doc(_auth.currentUser!.uid)
          .set(
        driverData,
        SetOptions(merge: true),
      );
    } catch (error) {
      debugPrint(
        'Error updating CNIC info: $error',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateSelfieWithCnincInfo(
    BuildContext context,
  ) async {
    try {
      _isLoading = true;
      notifyListeners();

      final String faceWithCnincImageUrl =
          await uploadImageToFirebaseStorage(
        _cnicWithSelfieImage,
        'SelfieWithCninc',
        context,
      );

      final Map<String, dynamic> driverData =
          <String, dynamic>{
        'driverFaceWithCnic':
            faceWithCnincImageUrl,
      };

      await _firestore
          .collection('drivers')
          .doc(_auth.currentUser!.uid)
          .set(
        driverData,
        SetOptions(merge: true),
      );
    } catch (error) {
      debugPrint(
        'Error updating selfie with CNIC: $error',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updatedriverLicenseInfo(
    BuildContext context,
  ) async {
    try {
      _isLoading = true;
      notifyListeners();

      final String drivingLicenseFrontImageUrl =
          await uploadImageToFirebaseStorage(
        _drivingLicenseFrontImage,
        'DrivingLicenseImages',
        context,
      );

      final String drivingLicenseBackImageUrl =
          await uploadImageToFirebaseStorage(
        _drivingLicenseBackImage,
        'DrivingLicenseImages',
        context,
      );

      final Map<String, dynamic> driverData =
          <String, dynamic>{
        'drivingLicenseFrontImage':
            drivingLicenseFrontImageUrl,
        'drivingLicenseBackImage':
            drivingLicenseBackImageUrl,
        'drivingLicenseNumber':
            drivingLicenseController.text,
      };

      await _firestore
          .collection('drivers')
          .doc(_auth.currentUser!.uid)
          .set(
        driverData,
        SetOptions(merge: true),
      );
    } catch (error) {
      debugPrint(
        'Error updating driver license info: $error',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateVehicleBasicInfo(
    BuildContext context,
  ) async {
    try {
      _isLoading = true;
      notifyListeners();

      final String uid =
          _auth.currentUser?.uid ?? '';

      if (uid.isEmpty) {
        throw Exception(
          'Driver is not signed in.',
        );
      }

      await _firestore
          .collection('drivers')
          .doc(uid)
          .set(
        {
          'vehicleInfo.type':
              selectedVehicle ?? '',
          'vehicleInfo.brand':
              brandController.text.trim(),
          'vehicleInfo.color':
              colorController.text.trim(),
          'vehicleInfo.productionYear':
              productionYearController.text.trim(),
          'vehicleInfo.registrationPlateNumber':
              numberPlateController.text.trim(),
          'vehicleInfo.plateProvince':
              _plateProvince,
          'vehicleInfo.plateCategory':
              _plateCategory,
          'vehicleInfo.plateType':
              _plateType,
        },
        SetOptions(merge: true),
      );

      await retrieveCurrentDriverInfo();
    } catch (error) {
      debugPrint(
        'Error updating vehicle basic info: $error',
      );

      commonMethods.displaySnackBar(
        'خطا در ذخیره اطلاعات وسیله',
        context,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateVehicleImage(
    BuildContext context,
  ) async {
    try {
      _isLoading = true;
      notifyListeners();

      final String uid =
          _auth.currentUser?.uid ?? '';

      if (uid.isEmpty) {
        throw Exception(
          'Driver is not signed in.',
        );
      }

      if (_vehicleImage == null) {
        throw Exception(
          'Vehicle image is not selected.',
        );
      }

      final String vehicleImageUrl =
          await uploadImageToFirebaseStorage(
        _vehicleImage,
        'VehicleImage',
        context,
      );

      await _firestore
          .collection('drivers')
          .doc(uid)
          .set(
        {
          'vehicleInfo.vehiclePicture':
              vehicleImageUrl,
        },
        SetOptions(merge: true),
      );

      await retrieveCurrentDriverInfo();
    } catch (error) {
      debugPrint(
        'Error updating vehicle image: $error',
      );

      commonMethods.displaySnackBar(
        'خطا در آپلود عکس وسیله',
        context,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateVehicleRegistraionImages(
    BuildContext context,
  ) async {
    try {
      _isLoading = true;
      notifyListeners();

      final String uid =
          _auth.currentUser?.uid ?? '';

      if (uid.isEmpty) {
        throw Exception(
          'Driver is not signed in.',
        );
      }

      if (_vehicleRegistrationFrontImage ==
              null ||
          _vehicleRegistrationBackImage ==
              null) {
        throw Exception(
          'Vehicle registration images '
          'are not selected.',
        );
      }

      final String frontImageUrl =
          await uploadImageToFirebaseStorage(
        _vehicleRegistrationFrontImage,
        'VehicleRegistrationImages',
        context,
      );

      final String backImageUrl =
          await uploadImageToFirebaseStorage(
        _vehicleRegistrationBackImage,
        'VehicleRegistrationImages',
        context,
      );

      await _firestore
          .collection('drivers')
          .doc(uid)
          .set(
        {
          'vehicleInfo.registrationCertificateFrontImage':
              frontImageUrl,
          'vehicleInfo.registrationCertificateBackImage':
              backImageUrl,
        },
        SetOptions(merge: true),
      );

      await retrieveCurrentDriverInfo();
    } catch (error) {
      debugPrint(
        'Error updating vehicle registration images: '
        '$error',
      );

      commonMethods.displaySnackBar(
        'خطا در آپلود عکس‌های سند وسیله',
        context,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
