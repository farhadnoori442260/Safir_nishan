import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class TripProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String currentDriverTotalTripsCompleted = '0';
  bool isLoading = false;

  List<Map<String, dynamic>> completedTrips = [];

  Future<void> fetchCompletedTrips() async {
    final User? currentUser = _auth.currentUser;

    if (currentUser == null) {
      completedTrips = [];
      currentDriverTotalTripsCompleted = '0';
      notifyListeners();
      return;
    }

    isLoading = true;
    notifyListeners();

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await _firestore
              .collection('rides')
              .where('driverid', isEqualTo: currentUser.uid)
              .get();

      final List<Map<String, dynamic>> trips = [];

      for (final QueryDocumentSnapshot<Map<String, dynamic>> document
          in snapshot.docs) {
        final Map<String, dynamic> data = document.data();

        final String status =
            (data['status'] ?? '').toString().toLowerCase().trim();

        if (status == 'completed' || status == 'ended') {
          trips.add({
            'id': document.id,
            ...data,
          });
        }
      }

      completedTrips = trips;
      currentDriverTotalTripsCompleted = trips.length.toString();

      debugPrint(
        'Completed trips loaded: ${completedTrips.length}',
      );
    } catch (error, stackTrace) {
      completedTrips = [];
      currentDriverTotalTripsCompleted = '0';

      debugPrint('Error loading completed trips: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> getCompletedTrips() async {
    await fetchCompletedTrips();
  }

  Future<void> getCurrentDriverTotalNumberOfTripsCompleted() async {
    await fetchCompletedTrips();
  }
}
