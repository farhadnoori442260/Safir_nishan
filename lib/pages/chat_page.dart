import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:safir_drivers/utils/app_colors.dart';

class ChatPage extends StatefulWidget {
  final String tripId;
  final String passengerName;
  final String passengerPhone;

  const ChatPage({
    super.key,
    required this.tripId,
    required this.passengerName,
    required this.passengerPhone,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController =
      TextEditingController();

  final FocusNode _messageFocusNode = FocusNode();

  final ScrollController _messagesScrollController =
      ScrollController();

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isSending = false;

  /// استریم فقط یک‌بار ساخته می‌شود. اگر در build ساخته شود، با هر بازسازی
  /// (مثلاً هر فریم انیمیشن کیبورد) StreamBuilder دوباره subscribe می‌کند
  /// و لیست پیام‌ها چشمک می‌زند.
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>? _messagesStream;

  int _lastMessageCount = 0;

  CollectionReference<Map<String, dynamic>> get _chatCollection {
    return _firestore
        .collection('rides')
        .doc(widget.tripId)
        .collection('chats');
  }

  String get _currentDriverId {
    return _auth.currentUser?.uid ?? '';
  }

  @override
  void initState() {
    super.initState();

    if (widget.tripId.trim().isNotEmpty) {
      // عمداً orderBy استفاده نشده تا پیام‌های قدیمی بدون timestamp نیز
      // نمایش داده شوند؛ مرتب‌سازی یک‌بار برای هر snapshot انجام می‌شود.
      _messagesStream = _chatCollection.snapshots().map(
        (QuerySnapshot<Map<String, dynamic>> snapshot) {
          return _sortMessages(snapshot.docs);
        },
      );
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _messageFocusNode.dispose();
    _messagesScrollController.dispose();
    super.dispose();
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final String phone = phoneNumber.trim();

    if (phone.isEmpty) {
      return;
    }

    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phone,
    );

    try {
      final bool canCall = await canLaunchUrl(launchUri);

      if (!canCall) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('امکان برقراری تماس وجود ندارد'),
          ),
        );

        return;
      }

      await launchUrl(launchUri);
    } catch (error) {
      debugPrint('Phone call error: $error');
    }
  }

  void _scrollToLatestMessage() {
    if (!_messagesScrollController.hasClients) {
      return;
    }

    _messagesScrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  /// فقط وقتی تعداد پیام‌ها تغییر کرد و کاربر نزدیک آخرین پیام است اسکرول می‌کند.
  void _onMessagesCountChanged(int count) {
    if (count == _lastMessageCount) {
      return;
    }

    final bool isFirstLoad = _lastMessageCount == 0;
    _lastMessageCount = count;

    if (isFirstLoad) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_messagesScrollController.hasClients) {
        return;
      }

      if (_messagesScrollController.offset < 250) {
        _scrollToLatestMessage();
      }
    });
  }

  Future<void> sendMessage() async {
    final String text = _messageController.text.trim();
    final String driverId = _currentDriverId;

    if (text.isEmpty ||
        driverId.isEmpty ||
        widget.tripId.trim().isEmpty ||
        _isSending) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      await _chatCollection.add(<String, dynamic>{
        'senderId': driverId,
        'senderType': 'driver',
        'message': text,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (!mounted) {
        return;
      }

      _messageController.clear();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToLatestMessage();
      });
    } on FirebaseException catch (error) {
      debugPrint(
        'Driver chat Firebase error: '
        '${error.code} - ${error.message}',
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message ?? 'ارسال پیام انجام نشد. دوباره تلاش کنید.',
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } catch (error) {
      debugPrint('Driver chat send error: $error');

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ارسال پیام انجام نشد. دوباره تلاش کنید.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSending = false;
      });
    }
  }

  DateTime _getMessageDate(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data = document.data();
    final Object? value = data['timestamp'];

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value) ??
          DateTime.fromMillisecondsSinceEpoch(0);
    }

    if (document.metadata.hasPendingWrites) {
      return DateTime.now();
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _sortMessages(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
  ) {
    final List<QueryDocumentSnapshot<Map<String, dynamic>>>
        sortedDocuments =
        List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(documents);

    sortedDocuments.sort(
      (
        QueryDocumentSnapshot<Map<String, dynamic>> first,
        QueryDocumentSnapshot<Map<String, dynamic>> second,
      ) {
        return _getMessageDate(first).compareTo(
          _getMessageDate(second),
        );
      },
    );

    return sortedDocuments;
  }

  String _formatTimestamp(Object? value) {
    DateTime? date;

    if (value is Timestamp) {
      date = value.toDate();
    } else if (value is DateTime) {
      date = value;
    } else if (value is String) {
      date = DateTime.tryParse(value);
    }

    if (date == null) {
      return 'اکنون';
    }

    return DateFormat('HH:mm').format(date);
  }

  bool _isMyMessage(Map<String, dynamic> data) {
    final String senderId =
        data['senderId']?.toString().trim() ?? '';

    final String senderType =
        data['senderType']?.toString().trim().toLowerCase() ??
            '';

    return senderId == _currentDriverId ||
        senderType == 'driver';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // کیبورد فقط یک‌بار و نرم در _KeyboardAwareBody مدیریت می‌شود.
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: _KeyboardAwareBody(
        child: Column(
          children: <Widget>[
            Expanded(
              child: _buildMessages(),
            ),
            _buildMessageComposer(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final String displayName = widget.passengerName.trim().isNotEmpty
        ? widget.passengerName.trim()
        : 'passenger'.tr();

    return AppBar(
      backgroundColor: AppColors.primaryBrand,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleSpacing: 0,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 20,
        ),
      ),
      title: Row(
        children: <Widget>[
          const CircleAvatar(
            radius: 21,
            backgroundColor: Colors.white24,
            child: Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: 25,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      actions: <Widget>[
        IconButton(
          tooltip: 'تماس',
          onPressed: () {
            _makePhoneCall(widget.passengerPhone);
          },
          icon: const Icon(
            Icons.phone_enabled_rounded,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 5),
      ],
    );
  }

  Widget _buildMessages() {
    final Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>? stream =
        _messagesStream;

    if (stream == null) {
      return _buildErrorState(
        'شناسه سفر برای چت موجود نیست',
      );
    }

    return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      stream: stream,
      builder: (
        BuildContext context,
        AsyncSnapshot<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
            snapshot,
      ) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppColors.primaryBrand,
            ),
          );
        }

        if (snapshot.hasError) {
          debugPrint(
            'Driver chat stream error: ${snapshot.error}',
          );

          return _buildErrorState('خطا در دریافت پیام‌ها');
        }

        final List<QueryDocumentSnapshot<Map<String, dynamic>>> messages =
            snapshot.data ??
                const <QueryDocumentSnapshot<Map<String, dynamic>>>[];

        if (messages.isEmpty) {
          return _buildEmptyState();
        }

        _onMessagesCountChanged(messages.length);

        // reverse: آخرین پیام همیشه پایین و کنار کامپوزر می‌ماند؛
        // با کوچک/بزرگ شدن صفحه توسط کیبورد نیازی به اسکرول نیست.
        return ListView.builder(
          controller: _messagesScrollController,
          reverse: true,
          keyboardDismissBehavior:
              ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          itemCount: messages.length,
          itemBuilder: (
            BuildContext context,
            int index,
          ) {
            final QueryDocumentSnapshot<Map<String, dynamic>> document =
                messages[messages.length - 1 - index];

            return KeyedSubtree(
              key: ValueKey<String>(document.id),
              child: _buildMessageBubble(document.data()),
            );
          },
        );
      },
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> data) {
    final String message =
        data['message']?.toString().trim() ?? '';

    if (message.isEmpty) {
      return const SizedBox.shrink();
    }

    final bool isMe = _isMyMessage(data);

    return Align(
      alignment: isMe
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.fromLTRB(14, 10, 12, 8),
        decoration: BoxDecoration(
          color: isMe
              ? AppColors.primaryBrand
              : AppColors.cardBackground,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              message,
              textDirection: ui.TextDirection.rtl,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: isMe
                    ? Colors.white
                    : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  _formatTimestamp(data['timestamp']),
                  style: TextStyle(
                    fontSize: 10,
                    color: isMe
                        ? Colors.white70
                        : AppColors.textSecondary,
                  ),
                ),
                if (isMe) ...<Widget>[
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.done_all_rounded,
                    size: 13,
                    color: Colors.white70,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Text(
        'no_chat_messages'.tr(),
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.cloud_off_rounded,
              size: 54,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageComposer() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      color: AppColors.cardBackground,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: _messageController,
              focusNode: _messageFocusNode,
              minLines: 1,
              maxLines: 4,
              textDirection: ui.TextDirection.rtl,
              textInputAction: TextInputAction.newline,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'chat_type_hint'.tr(),
                hintTextDirection: ui.TextDirection.rtl,
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                fillColor: AppColors.background,
                filled: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              onSubmitted: (_) {
                if (!_isSending) {
                  sendMessage();
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: _isSending
                ? Colors.grey
                : AppColors.primaryBrand,
            child: IconButton(
              onPressed: _isSending ? null : sendMessage,
              icon: _isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// فضای کیبورد و نوار پایین سیستم را یک‌بار و با انیمیشن کوتاه حساب می‌کند.
/// فقط همین ویجت به viewInsets گوش می‌دهد؛ [child] هر فریم دوباره ساخته نمی‌شود.
class _KeyboardAwareBody extends StatelessWidget {
  const _KeyboardAwareBody({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final double keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final EdgeInsets safe = MediaQuery.paddingOf(context);

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(
        left: safe.left,
        right: safe.right,
        bottom: keyboard > safe.bottom ? keyboard : safe.bottom,
      ),
      child: child,
    );
  }
}
