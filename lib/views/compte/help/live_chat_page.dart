import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_marketplace/localization/app_localizations.dart';

class LiveChatPage extends StatefulWidget {
  const LiveChatPage({super.key});

  @override
  State<LiveChatPage> createState() => _LiveChatPageState();
}

class _LiveChatPageState extends State<LiveChatPage> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late AnimationController _typingController;

  String? _chatId;
  bool _isLoading = true;
  bool _isSending = false;
  bool _adminTyping = false;

  // Reply
  Map<String, dynamic>? _replyingTo;
  String? _replyingToId;

  String _t(String key) => AppLocalizations.get(key);
  User? get _currentUser => FirebaseAuth.instance.currentUser;

  final List<String> _availableReactions = ['❤️', '👍', '😂', '😮', '😢', '🔥'];

  @override
  void initState() {
    super.initState();
    _typingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _initChat();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingController.dispose();
    super.dispose();
  }

  // ── Init Chat ────────────────────────────────────────────────
  Future<void> _initChat() async {
    final user = _currentUser;
    if (user == null) return;

    final existing = await _firestore
        .collection('support_chats')
        .where('userId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'open')
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      setState(() {
        _chatId = existing.docs.first.id;
        _isLoading = false;
      });
    } else {
      final doc = await _firestore.collection('support_chats').add({
        'userId': user.uid,
        'userEmail': user.email,
        'userName': user.displayName ?? 'User',
        'status': 'open',
        'createdAt': Timestamp.now(),
        'lastMessage': '',
        'lastMessageAt': Timestamp.now(),
        'adminTyping': false,
        'unreadByAdmin': 0,
      });

      await _firestore
          .collection('support_chats')
          .doc(doc.id)
          .collection('messages')
          .add({
        'text': _t('chat_welcome_message'),
        'senderId': 'admin',
        'senderName': 'Support',
        'timestamp': Timestamp.now(),
        'isRead': false,
        'reactions': {},
        'replyTo': null,
      });

      setState(() {
        _chatId = doc.id;
        _isLoading = false;
      });
    }
    _markAdminMessagesAsRead();
  }

  Future<void> _markAdminMessagesAsRead() async {
    if (_chatId == null) return;
    final unread = await _firestore
        .collection('support_chats')
        .doc(_chatId)
        .collection('messages')
        .where('senderId', isEqualTo: 'admin')
        .where('isRead', isEqualTo: false)
        .get();
    for (final doc in unread.docs) {
      doc.reference.update({'isRead': true});
    }
  }

  // ── Envoyer message ──────────────────────────────────────────
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _chatId == null || _isSending) return;

    setState(() => _isSending = true);
    _messageController.clear();

    final replyData = _replyingTo != null
        ? {
      'text': _replyingTo!['text'],
      'senderId': _replyingTo!['senderId'],
      'senderName': _replyingTo!['senderName'],
      'messageId': _replyingToId,
    }
        : null;

    setState(() {
      _replyingTo = null;
      _replyingToId = null;
    });

    try {
      final user = _currentUser!;
      await _firestore
          .collection('support_chats')
          .doc(_chatId)
          .collection('messages')
          .add({
        'text': text,
        'senderId': user.uid,
        'senderName': user.displayName ?? 'User',
        'timestamp': Timestamp.now(),
        'isRead': false,
        'reactions': {},
        'replyTo': replyData,
      });

      await _firestore.collection('support_chats').doc(_chatId).update({
        'lastMessage': text,
        'lastMessageAt': Timestamp.now(),
        'unreadByAdmin': FieldValue.increment(1),
      });

      _scrollToBottom();
    } catch (_) {}

    setState(() => _isSending = false);
  }

  // ── Réactions ────────────────────────────────────────────────
  Future<void> _toggleReaction(String messageId, String emoji) async {
    if (_chatId == null) return;
    final uid = _currentUser!.uid;
    final ref = _firestore
        .collection('support_chats')
        .doc(_chatId)
        .collection('messages')
        .doc(messageId);

    final doc = await ref.get();
    final reactions =
    Map<String, dynamic>.from(doc.data()?['reactions'] ?? {});

    if (reactions[emoji] != null &&
        (reactions[emoji] as List).contains(uid)) {
      reactions[emoji] = (reactions[emoji] as List)..remove(uid);
      if ((reactions[emoji] as List).isEmpty) reactions.remove(emoji);
    } else {
      reactions[emoji] = [...(reactions[emoji] as List? ?? []), uid];
    }

    await ref.update({'reactions': reactions});
  }

  // ── Popup réactions (long press) ─────────────────────────────
  void _showReactionPicker(
      BuildContext context, String messageId, Offset globalPos) {
    HapticFeedback.mediumImpact();

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Calculer la position optimale du picker
    double left = globalPos.dx - 140;
    double top = globalPos.dy - 80;

    // Garder dans l'écran
    if (left < 8) left = 8;
    if (left + 280 > screenWidth) left = screenWidth - 288;
    if (top < 8) top = globalPos.dy + 20;
    if (top + 60 > screenHeight) top = globalPos.dy - 80;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.2),
      builder: (_) {
        return Stack(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(color: Colors.transparent),
            ),
            Positioned(
              top: top,
              left: left,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: _availableReactions.asMap().entries.map((entry) {
                      final i = entry.key;
                      final emoji = entry.value;
                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          _toggleReaction(messageId, emoji);
                          HapticFeedback.lightImpact();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.3, end: 1.0),
                            duration:
                            Duration(milliseconds: 200 + i * 50),
                            curve: Curves.elasticOut,
                            builder: (_, val, child) =>
                                Transform.scale(scale: val, child: child),
                            child: Text(emoji,
                                style: const TextStyle(fontSize: 30)),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _listenAdminTyping() {
    if (_chatId == null) return;
    _firestore
        .collection('support_chats')
        .doc(_chatId)
        .snapshots()
        .listen((doc) {
      if (doc.exists && mounted) {
        final typing = doc.data()?['adminTyping'] ?? false;
        if (typing != _adminTyping) setState(() => _adminTyping = typing);
      }
    });
  }

  // ── BUILD ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection:
      AppLocalizations.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F4FF),
        body: _isLoading
            ? _buildLoadingState()
            : Column(
          children: [
            _buildHeader(context),
            Expanded(child: _buildMessagesList()),
            _buildTypingIndicator(),
            if (_replyingTo != null) _buildReplyPreview(),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() => const Center(
    child: CircularProgressIndicator(
      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
    ),
  );

  // ── Header ───────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6C63FF), Color(0xFF48CAE4)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 20),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(
                  AppLocalizations.isRtl
                      ? Icons.arrow_forward
                      : Icons.arrow_back,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 4),
              Stack(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withOpacity(0.5), width: 2),
                    ),
                    child: const Icon(Icons.support_agent,
                        color: Colors.white, size: 24),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4ADE80),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t('chat_support_name'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFF4ADE80),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _t('chat_online_status'),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  onPressed: _showCloseDialog,
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 20),
                  tooltip: _t('chat_close_chat'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Liste messages ───────────────────────────────────────────
  Widget _buildMessagesList() {
    if (_chatId == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('support_chats')
          .doc(_chatId)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        _listenAdminTyping();
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _scrollToBottom());

        if (docs.isEmpty) {
          return Center(
            child: Text(_t('chat_no_messages'),
                style: TextStyle(color: Colors.grey[400], fontSize: 14)),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final isMe = data['senderId'] != 'admin';
            final isAdmin = data['senderId'] == 'admin';
            final showAvatar = isAdmin &&
                (index == 0 ||
                    (docs[index - 1].data()
                    as Map<String, dynamic>)['senderId'] !=
                        'admin');

            return _buildSwipeableMessage(
                doc.id, data, isMe, isAdmin, showAvatar, index, docs.length);
          },
        );
      },
    );
  }

  // ── Swipeable message ────────────────────────────────────────
  Widget _buildSwipeableMessage(
      String messageId,
      Map<String, dynamic> data,
      bool isMe,
      bool isAdmin,
      bool showAvatar,
      int index,
      int total,
      ) {
    return Dismissible(
      key: ValueKey('swipe_${messageId}_$index'),
      direction: isMe
          ? DismissDirection.endToStart
          : DismissDirection.startToEnd,
      dismissThresholds: const {
        DismissDirection.startToEnd: 0.25,
        DismissDirection.endToStart: 0.25,
      },
      confirmDismiss: (_) async {
        HapticFeedback.lightImpact();
        // ✅ Copie les données AVANT le setState
        final replyData = Map<String, dynamic>.from(data);
        final replyId = messageId;
        if (mounted) {
          setState(() {
            _replyingTo = replyData;
            _replyingToId = replyId;
          });
        }
        return false;
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF6C63FF).withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.reply_rounded,
              color: Color(0xFF6C63FF), size: 22),
        ),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF6C63FF).withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.reply_rounded,
              color: Color(0xFF6C63FF), size: 22),
        ),
      ),
      child: GestureDetector(
        onLongPressStart: (details) {
          _showReactionPicker(context, messageId, details.globalPosition);
        },
        child: _buildMessageBubble(
            messageId, data, isMe, isAdmin, showAvatar, index, total),
      ),
    );
  }

  // ── Bulle de message ─────────────────────────────────────────
  Widget _buildMessageBubble(
      String messageId,
      Map<String, dynamic> data,
      bool isMe,
      bool isAdmin,
      bool showAvatar,
      int index,
      int total,
      ) {
    final text = data['text'] as String? ?? '';
    final timestamp = data['timestamp'] as Timestamp?;
    final time = timestamp != null
        ? TimeOfDay.fromDateTime(timestamp.toDate()).format(context)
        : '';
    final isRead = data['isRead'] as bool? ?? false;
    final reactions =
    Map<String, dynamic>.from(data['reactions'] ?? {});
    final replyTo = data['replyTo'] as Map<String, dynamic>?;

    return Padding(
      padding: EdgeInsets.only(
        bottom: index == total - 1 ? 8 : 6,
        top: showAvatar ? 10 : 2,
      ),
      child: Row(
        mainAxisAlignment:
        isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar admin
          if (isAdmin) ...[
            if (showAvatar)
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF48CAE4)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.support_agent,
                    color: Colors.white, size: 18),
              )
            else
              const SizedBox(width: 34),
            const SizedBox(width: 8),
          ],

          // Contenu
          Flexible(
            child: Column(
              crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // ── Bulle principale ──
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.72,
                  ),
                  decoration: BoxDecoration(
                    gradient: isMe
                        ? const LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFF8B5CF6)],
                    )
                        : null,
                    color: isMe ? null : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: isMe
                          ? const Radius.circular(18)
                          : const Radius.circular(4),
                      bottomRight: isMe
                          ? const Radius.circular(4)
                          : const Radius.circular(18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isMe
                            ? const Color(0xFF6C63FF).withOpacity(0.25)
                            : Colors.black.withOpacity(0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Aperçu réponse dans la bulle ──
                      if (replyTo != null)
                        Container(
                          margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isMe
                                ? Colors.white.withOpacity(0.2)
                                : const Color(0xFF6C63FF).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border(
                              left: BorderSide(
                                color: isMe
                                    ? Colors.white.withOpacity(0.7)
                                    : const Color(0xFF6C63FF),
                                width: 3,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                replyTo['senderName'] ?? '',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isMe
                                      ? Colors.white
                                      : const Color(0xFF6C63FF),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                replyTo['text'] ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isMe
                                      ? Colors.white.withOpacity(0.75)
                                      : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),

                      // ── Texte principal ──
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        child: Text(
                          text,
                          style: TextStyle(
                            color: isMe
                                ? Colors.white
                                : const Color(0xFF1E293B),
                            fontSize: 14.5,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Réactions ──
                if (reactions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: reactions.entries.map((entry) {
                        final emoji = entry.key;
                        final users = entry.value as List;
                        final iReacted =
                        users.contains(_currentUser?.uid ?? '');
                        return GestureDetector(
                          onTap: () => _toggleReaction(messageId, emoji),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: iReacted
                                  ? const Color(0xFF6C63FF).withOpacity(0.12)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: iReacted
                                    ? const Color(0xFF6C63FF)
                                    : Colors.grey.shade300,
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(emoji,
                                    style: const TextStyle(fontSize: 14)),
                                if (users.length > 1) ...[
                                  const SizedBox(width: 3),
                                  Text(
                                    '${users.length}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: iReacted
                                          ? const Color(0xFF6C63FF)
                                          : Colors.grey[600],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                // ── Heure + lu ──
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(time,
                        style: TextStyle(
                            color: Colors.grey[400], fontSize: 11)),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      Icon(
                        isRead ? Icons.done_all : Icons.done,
                        size: 14,
                        color: isRead
                            ? const Color(0xFF6C63FF)
                            : Colors.grey[400],
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }

  // ── Preview réponse au-dessus de l'input ─────────────────────
  Widget _buildReplyPreview() {
    if (_replyingTo == null) return const SizedBox.shrink();

    final senderName = _replyingTo!['senderName'] as String? ?? '';
    final text = _replyingTo!['text'] as String? ?? '';
    final isAdminReply = _replyingTo!['senderId'] == 'admin';
    final barColor = isAdminReply
        ? const Color(0xFF6C63FF)
        : const Color(0xFF48CAE4);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        // ✅ Pas de Border ici — on utilise un Stack à la place
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        child: Stack(
          children: [
            // ✅ Barre colorée à gauche via Stack (pas Border)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 3,
                color: barColor,
              ),
            ),
            // Contenu
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
              child: Row(
                children: [
                  const Icon(Icons.reply_rounded,
                      color: Color(0xFF6C63FF), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          senderName,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6C63FF),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() {
                      _replyingTo = null;
                      _replyingToId = null;
                    }),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded,
                          size: 16, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Typing indicator ─────────────────────────────────────────
  Widget _buildTypingIndicator() {
    if (!_adminTyping) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.only(left: 58, bottom: 6, right: 16),
      child: Row(
        children: [
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                return AnimatedBuilder(
                  animation: _typingController,
                  builder: (_, __) {
                    final val =
                    ((_typingController.value + i * 0.3) % 1.0);
                    final size = 6.0 + (val * 3);
                    return Container(
                      margin:
                      const EdgeInsets.symmetric(horizontal: 2),
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C63FF)
                            .withOpacity(0.4 + val * 0.6),
                        shape: BoxShape.circle,
                      ),
                    );
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ── Barre de saisie ──────────────────────────────────────────
  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Color(0x12000000),
              blurRadius: 12,
              offset: Offset(0, -4)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4FF),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                controller: _messageController,
                textDirection: AppLocalizations.isRtl
                    ? TextDirection.rtl
                    : TextDirection.ltr,
                maxLines: 4,
                minLines: 1,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: _t('chat_input_hint'),
                  hintStyle:
                  TextStyle(color: Colors.grey[400], fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: _messageController.text.trim().isNotEmpty
                  ? const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF48CAE4)],
              )
                  : null,
              color: _messageController.text.trim().isEmpty
                  ? const Color(0xFFE2E8F0)
                  : null,
              shape: BoxShape.circle,
              boxShadow: _messageController.text.trim().isNotEmpty
                  ? [
                BoxShadow(
                  color:
                  const Color(0xFF6C63FF).withOpacity(0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
                  : [],
            ),
            child: IconButton(
              onPressed:
              _messageController.text.trim().isNotEmpty && !_isSending
                  ? _sendMessage
                  : null,
              icon: _isSending
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                  AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : Icon(
                Icons.send_rounded,
                color: _messageController.text.trim().isNotEmpty
                    ? Colors.white
                    : Colors.grey[400],
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Dialog fermer le chat ────────────────────────────────────
  void _showCloseDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24)),
          elevation: 20,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFDC2626),
                  Color(0xFFEF4444),
                  Color(0xFFF87171),
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(28),
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withOpacity(0.3), width: 2),
                    ),
                    child: const Icon(Icons.chat_rounded,
                        color: Colors.white, size: 32),
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _t('chat_close_title'),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFDC2626),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _t('chat_close_subtitle'),
                        style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF64748B),
                            height: 1.4),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: OutlinedButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                      color: Color(0xFFDC2626),
                                      width: 1.5),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                      BorderRadius.circular(16)),
                                ),
                                child: Text(
                                  _t('cancel'),
                                  style: const TextStyle(
                                      color: Color(0xFFDC2626),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                onPressed: () async {
                                  Navigator.of(context).pop();
                                  if (_chatId != null) {
                                    await _firestore
                                        .collection('support_chats')
                                        .doc(_chatId)
                                        .update({'status': 'closed'});
                                  }
                                  if (mounted) {
                                    Navigator.of(context).pop();
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                  const Color(0xFFDC2626),
                                  foregroundColor: Colors.white,
                                  shadowColor: const Color(0xFFDC2626)
                                      .withOpacity(0.3),
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                      BorderRadius.circular(16)),
                                ),
                                child: FittedBox(
                                  child: Text(
                                    _t('chat_close_confirm'),
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}