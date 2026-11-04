import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:safir_drivers/pages/chat_page.dart';

class DriverTripChatOverlay extends StatefulWidget {
  const DriverTripChatOverlay({
    super.key,
    required this.tripId,
    required this.passengerName,
    required this.passengerPhone,
    required this.child,
  });

  final String tripId;
  final String passengerName;
  final String passengerPhone;
  final Widget child;

  static final Set<String> _openTrips = <String>{};

  static Future<void> openChat(
    BuildContext context, {
    required String tripId,
    required String passengerName,
    required String passengerPhone,
  }) async {
    if (!context.mounted ||
        tripId.trim().isEmpty ||
        _openTrips.contains(tripId)) {
      return;
    }

    _openTrips.add(tripId);

    try {
      await showDialog<void>(
        context: context,
        useRootNavigator: true,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 24,
            ),
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: SizedBox(
              width: 520,
              height: MediaQuery.sizeOf(dialogContext).height * 0.78,
              child: Column(
                children: <Widget>[
                  Container(
                    color: const Color(0xFF12304F),
                    padding: const EdgeInsetsDirectional.only(
                      start: 16,
                      end: 4,
                    ),
                    child: Row(
                      children: <Widget>[
                        const Expanded(
                          child: Text(
                            'گفتگو با مسافر',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'بستن چت',
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                          },
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ChatPage(
                      tripId: tripId,
                      passengerName: passengerName,
                      passengerPhone: passengerPhone,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } finally {
      _openTrips.remove(tripId);
    }
  }

  @override
  State<DriverTripChatOverlay> createState() =>
      _DriverTripChatOverlayState();
}

class _DriverTripChatOverlayState extends State<DriverTripChatOverlay>
    with WidgetsBindingObserver {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;

  final Set<String> _knownMessageIds = <String>{};

  bool _receivedServerSnapshot = false;
  bool _openScheduled = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listen();
  }

  @override
  void didUpdateWidget(covariant DriverTripChatOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.tripId != widget.tripId) {
      _listen();
    }
  }

  void _listen() {
    _subscription?.cancel();
    final int generation = ++_generation;

    _knownMessageIds.clear();
    _receivedServerSnapshot = false;
    _openScheduled = false;

    if (widget.tripId.trim().isEmpty) return;

    _subscription = FirebaseFirestore.instance
        .collection('rides')
        .doc(widget.tripId)
        .collection('chats')
        .snapshots(includeMetadataChanges: true)
        .listen(
      (QuerySnapshot<Map<String, dynamic>> snapshot) {
        if (!mounted || generation != _generation) return;

        // پیام‌های موجود در اولین پاسخ سرور، اعلان جدید نیستند.
        if (!_receivedServerSnapshot) {
          for (final document in snapshot.docs) {
            _knownMessageIds.add(document.id);
          }

          if (!snapshot.metadata.isFromCache) {
            _receivedServerSnapshot = true;
          }
          return;
        }

        final String currentUid =
            FirebaseAuth.instance.currentUser?.uid ?? '';

        if (currentUid.isEmpty) return;

        bool hasNewIncomingMessage = false;

        for (final document in snapshot.docs) {
          if (!_knownMessageIds.add(document.id)) continue;

          final Map<String, dynamic> data = document.data();

          final String senderId =
              data['senderId']?.toString().trim() ?? '';

          final String senderType =
              data['senderType']?.toString().trim().toLowerCase() ?? '';

          final String message =
              data['message']?.toString().trim() ?? '';

          if (message.isEmpty ||
              senderId.isEmpty ||
              senderId == currentUid ||
              senderType == 'driver' ||
              document.metadata.hasPendingWrites) {
            continue;
          }

          hasNewIncomingMessage = true;
        }

        if (hasNewIncomingMessage) {
          _scheduleOpen(generation);
        }
      },
      onError: (Object error) {
        debugPrint('Driver chat listener error: $error');
      },
    );
  }

  void _scheduleOpen(int generation) {
    if (_openScheduled ||
        WidgetsBinding.instance.lifecycleState !=
            AppLifecycleState.resumed) {
      return;
    }

    _openScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _generation) return;

      _openScheduled = false;

      if (WidgetsBinding.instance.lifecycleState !=
          AppLifecycleState.resumed) {
        return;
      }

      unawaited(
        DriverTripChatOverlay.openChat(
          context,
          tripId: widget.tripId,
          passengerName: widget.passengerName,
          passengerPhone: widget.passengerPhone,
        ),
      );
    });

    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    ++_generation;
    _subscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
