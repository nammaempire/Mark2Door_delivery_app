import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/config/env.dart';
import '../../core/providers.dart';
import '../orders/data/photo_shrink.dart';

/// What the store needs from a delivery partner before they start: date
/// of birth, permanent address, and their driving licence and Aadhaar
/// card (number and a photo of each).
///
/// Firestore: `rider_documents/{10-digit phone}`. Photos:
/// `rider_docs/{phone}/licence.jpg` and `aadhaar.jpg`. Only the rider and
/// the store's admins can read them.
@immutable
class RiderDocuments {
  const RiderDocuments({
    required this.dateOfBirth,
    required this.address,
    required this.licenceNumber,
    required this.aadhaarNumber,
    this.licenceUrl = '',
    this.aadhaarUrl = '',
    this.submittedAt,
  });

  final DateTime dateOfBirth;
  final String address;
  final String licenceNumber;
  final String aadhaarNumber;
  final String licenceUrl;
  final String aadhaarUrl;
  final DateTime? submittedAt;

  /// A rider has to be an adult.
  static const minimumAge = 18;

  /// Age in whole years on [today].
  static int ageOn(DateTime dob, DateTime today) {
    var age = today.year - dob.year;
    if (today.month < dob.month ||
        (today.month == dob.month && today.day < dob.day)) {
      age--;
    }
    return age;
  }

  /// Why [value] is not an Aadhaar number, or null when it is 12 digits.
  static String? aadhaarProblem(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\s'), '');
    return RegExp(r'^\d{12}$').hasMatch(digits)
        ? null
        : 'Enter the 12-digit Aadhaar number';
  }

  factory RiderDocuments.fromMap(Map<String, dynamic> map) => RiderDocuments(
        dateOfBirth: DateTime.tryParse(map['dateOfBirth'] as String? ?? '') ??
            DateTime(2000),
        address: map['address'] as String? ?? '',
        licenceNumber: map['licenceNumber'] as String? ?? '',
        aadhaarNumber: map['aadhaarNumber'] as String? ?? '',
        licenceUrl: map['licenceUrl'] as String? ?? '',
        aadhaarUrl: map['aadhaarUrl'] as String? ?? '',
        submittedAt: map['submittedAt'] is int
            ? DateTime.fromMillisecondsSinceEpoch(map['submittedAt'] as int)
            : null,
      );

  Map<String, dynamic> toMap() => {
        // Date only, as YYYY-MM-DD.
        'dateOfBirth': dateOfBirth.toIso8601String().substring(0, 10),
        'address': address,
        'licenceNumber': licenceNumber,
        'aadhaarNumber': aadhaarNumber,
        'licenceUrl': licenceUrl,
        'aadhaarUrl': aadhaarUrl,
        'submittedAt': (submittedAt ?? DateTime.now()).millisecondsSinceEpoch,
      };
}

abstract interface class RiderDocumentsRepository {
  /// The documents of the rider with [phone] (10 digits); null when they
  /// have not submitted any yet.
  Future<RiderDocuments?> fetch(String phone);

  /// Uploads the two photos saved on this phone and stores [documents].
  Future<void> submit(
    String phone,
    RiderDocuments documents, {
    required String licencePhotoPath,
    required String aadhaarPhotoPath,
  });

  /// Lets the rider take or choose a photo of a document; returns where it
  /// was saved on the phone, or null if they backed out.
  Future<String?> pickPhoto(String name, {required bool camera});
}

class FakeRiderDocumentsRepository implements RiderDocumentsRepository {
  /// Sample riders have already submitted, so the app opens on orders.
  FakeRiderDocumentsRepository({bool submitted = true})
      : _saved = submitted
            ? RiderDocuments(
                dateOfBirth: DateTime(1996, 4, 12),
                address: '18, 3rd Cross, Ejipura, Bengaluru 560047',
                licenceNumber: 'KA0120150012345',
                aadhaarNumber: '123412341234',
                licenceUrl: 'sample://licence',
                aadhaarUrl: 'sample://aadhaar',
                submittedAt: DateTime(2026, 10, 2),
              )
            : null;

  RiderDocuments? _saved;

  @override
  Future<RiderDocuments?> fetch(String phone) async => _saved;

  @override
  Future<void> submit(
    String phone,
    RiderDocuments documents, {
    required String licencePhotoPath,
    required String aadhaarPhotoPath,
  }) async {
    _saved = RiderDocuments(
      dateOfBirth: documents.dateOfBirth,
      address: documents.address,
      licenceNumber: documents.licenceNumber,
      aadhaarNumber: documents.aadhaarNumber,
      licenceUrl: licencePhotoPath,
      aadhaarUrl: aadhaarPhotoPath,
      submittedAt: DateTime.now(),
    );
  }

  @override
  Future<String?> pickPhoto(String name, {required bool camera}) async =>
      'sample://$name';
}

class FirebaseRiderDocumentsRepository implements RiderDocumentsRepository {
  FirebaseRiderDocumentsRepository(this._db, this._storage);

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  @override
  Future<RiderDocuments?> fetch(String phone) async {
    if (phone.isEmpty) return null;
    final doc = await _db.collection('rider_documents').doc(phone).get();
    final data = doc.data();
    return data == null ? null : RiderDocuments.fromMap(data);
  }

  Future<String> _upload(String phone, String name, String path) async {
    final ref = _storage.ref('rider_docs/$phone/$name.jpg');
    await ref
        .putFile(File(path), SettableMetadata(contentType: 'image/jpeg'))
        .timeout(const Duration(seconds: 90));
    return ref.getDownloadURL();
  }

  @override
  Future<void> submit(
    String phone,
    RiderDocuments documents, {
    required String licencePhotoPath,
    required String aadhaarPhotoPath,
  }) async {
    final licenceUrl = await _upload(phone, 'licence', licencePhotoPath);
    final aadhaarUrl = await _upload(phone, 'aadhaar', aadhaarPhotoPath);
    await _db.collection('rider_documents').doc(phone).set({
      ...documents.toMap(),
      'licenceUrl': licenceUrl,
      'aadhaarUrl': aadhaarUrl,
      'phone': phone,
    });
  }

  @override
  Future<String?> pickPhoto(String name, {required bool camera}) async {
    final shot = await ImagePicker().pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 75,
    );
    if (shot == null) return null;
    // Kept readable but small, off the main thread.
    final bytes = await compute(shrinkJpeg, await shot.readAsBytes());
    final file = File('${Directory.systemTemp.path}/m2d_doc_$name.jpg');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }
}

final riderDocumentsRepositoryProvider = Provider<RiderDocumentsRepository>(
  (ref) => Env.useFirebase
      ? FirebaseRiderDocumentsRepository(
          FirebaseFirestore.instance,
          FirebaseStorage.instance,
        )
      : FakeRiderDocumentsRepository(),
);

/// The signed-in rider's documents; null data means none submitted yet.
final riderDocumentsProvider = FutureProvider<RiderDocuments?>((ref) async {
  final phone = await ref.watch(riderPhoneProvider.future);
  return ref.watch(riderDocumentsRepositoryProvider).fetch(phone);
});
