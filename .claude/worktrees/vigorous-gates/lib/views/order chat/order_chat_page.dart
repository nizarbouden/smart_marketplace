import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../localization/app_localizations.dart';
import '../../models/sub_order_model.dart';

class OrderChatPage extends StatefulWidget {
  final SubOrderModel subOrder;
  final bool isSeller;

  const OrderChatPage({
    super.key,
    required this.subOrder,
    this.isSeller = false,
  });

  @override
  State<OrderChatPage> createState() => _OrderChatPageState();
}

class _OrderChatPageState extends State<OrderChatPage>
    with TickerProviderStateMixin {
  final _firestore  = FirebaseFirestore.instance;
  final _auth       = FirebaseAuth.instance;
  final _textCtrl   = TextEditingController();
  final _scrollCtrl = ScrollController();

  StreamSubscription<User?>? _authSub;
  bool _sending   = false;
  bool _chatReady = false;

  // ── Réponse ──────────────────────────────────────────────────
  Map<String, dynamic>? _replyingTo;
  String?               _replyingToId;

  // ── Réactions disponibles ─────────────────────────────────────
  final List<String> _reactions = ['❤️', '👍', '😂', '😮', '😢', '🔥'];

  String _t(String key) => AppLocalizations.get(key);
  String get _chatId   => widget.subOrder.subOrderId;
  String get _myUid    => _auth.currentUser?.uid ?? '';
  bool   get _isSeller => widget.isSeller;

  /// Le chat est en lecture seule quand la commande est livrée
  bool get _isDelivered => widget.subOrder.status == 'delivered';

  // ── Thème couleur selon rôle ──────────────────────────────────
  Color get _themeColor => _isSeller
      ? const Color(0xFF16A34A)
      : const Color(0xFF7C3AED);

  // ── Couleurs bulles ───────────────────────────────────────────
  static const _bubbleMeStart  = Color(0xFF7C3AED);
  static const _bubbleMeEnd    = Color(0xFF9F7AEA);
  static const _bubbleOther    = Colors.white;

  @override
  void initState() {
    super.initState();
    _ensureChatDocument().then((_) {
      if (mounted) {
        setState(() => _chatReady = true);
        _markAsRead();
      }
    });
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null && mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  //  FIRESTORE HELPERS
  // ─────────────────────────────────────────────────────────────

  Future<void> _ensureChatDocument() async {
    final s   = widget.subOrder;
    final ref = _firestore.collection('chats').doc(_chatId);
    try {
      await ref.set({
        'subOrderId':    s.subOrderId,
        'parentOrderId': s.parentOrderId,
        'buyerId':       s.userId,
        'sellerId':      s.sellerId,
        'productName':   s.name,
        'productImage':  s.images.isNotEmpty ? s.images.first : null,
        'storeName':     s.storeName,
        'lastMessage':   null,
        'lastMessageAt': null,
        'unreadBuyer':   0,
        'unreadSeller':  0,
        'createdAt':     Timestamp.now(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _markAsRead() async {
    try {
      await _firestore.collection('chats').doc(_chatId).update(
        _isSeller ? {'unreadSeller': 0} : {'unreadBuyer': 0},
      );
    } catch (_) {}
  }

  Future<void> _sendMessage() async {
    if (_isDelivered) return; // sécurité supplémentaire
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _sending || !_chatReady) return;

    setState(() => _sending = true);
    _textCtrl.clear();

    final replyData = _replyingTo != null
        ? {
      'text':       _replyingTo!['text'],
      'senderId':   _replyingTo!['senderId'],
      'senderName': _replyingTo!['senderName'],
      'messageId':  _replyingToId,
    }
        : null;

    setState(() { _replyingTo = null; _replyingToId = null; });

    try {
      final now   = Timestamp.now();
      final batch = _firestore.batch();

      final msgRef = _firestore
          .collection('chats').doc(_chatId)
          .collection('messages').doc();

      batch.set(msgRef, {
        'senderId':   _myUid,
        'senderName': _isSeller ? 'Vendeur' : 'Acheteur',
        'text':       text,
        'isRead':     false,
        'reactions':  {},
        'replyTo':    replyData,
        'createdAt':  now,
      });

      batch.update(_firestore.collection('chats').doc(_chatId), {
        'lastMessage':   text,
        'lastMessageAt': now,
        if (_isSeller) 'unreadBuyer':  FieldValue.increment(1)
        else           'unreadSeller': FieldValue.increment(1),
      });

      await batch.commit();
      _scrollToBottom();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_t('error')),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _toggleReaction(String messageId, String emoji) async {
    if (_isDelivered) return; // pas de réaction non plus si livré
    final uid = _myUid;
    final ref = _firestore
        .collection('chats').doc(_chatId)
        .collection('messages').doc(messageId);
    try {
      final doc       = await ref.get();
      final reactions = Map<String, dynamic>.from(
          doc.data()?['reactions'] ?? {});

      final list = List<String>.from(reactions[emoji] ?? []);
      if (list.contains(uid)) {
        list.remove(uid);
        if (list.isEmpty) reactions.remove(emoji);
        else reactions[emoji] = list;
      } else {
        list.add(uid);
        reactions[emoji] = list;
      }
      await ref.update({'reactions': reactions});
    } catch (_) {}
  }

  void _showReactionPicker(String messageId, Offset globalPos) {
    if (_isDelivered) return; // pas de picker si livré
    HapticFeedback.mediumImpact();

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.15),
      builder: (ctx) {
        final sh   = MediaQuery.of(context).size.height;
        final sw   = MediaQuery.of(context).size.width;
        double top = globalPos.dy + 12;
        if (top + 60 > sh - 100) top = globalPos.dy - 70;

        const pickerW = 300.0;
        double left = globalPos.dx - pickerW / 2;
        if (left < 12) left = 12;
        if (left + pickerW > sw - 12) left = sw - pickerW - 12;

        return Stack(children: [
          GestureDetector(
            onTap: () => Navigator.pop(ctx),
            child: Container(color: Colors.transparent),
          ),
          Positioned(
            top: top,
            left: left,
            width: pickerW,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 24,
                        offset: const Offset(0, 8)),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: _reactions.asMap().entries.map((e) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        _toggleReaction(messageId, e.value);
                        HapticFeedback.lightImpact();
                      },
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.3, end: 1.0),
                        duration: Duration(
                            milliseconds: 200 + e.key * 50),
                        curve: Curves.elasticOut,
                        builder: (_, val, child) =>
                            Transform.scale(scale: val, child: child),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Text(e.value,
                              style: const TextStyle(fontSize: 28)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ]);
      },
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ─────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final s = widget.subOrder;
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: Column(children: [
        _buildHeader(s),
        _buildOrderBanner(s),
        Expanded(
          child: !_chatReady
              ? Center(child: CircularProgressIndicator(
              color: _themeColor, strokeWidth: 2))
              : _buildMessagesList(),
        ),
        // Aperçu réponse uniquement si le chat est actif
        if (_replyingTo != null && !_isDelivered) _buildReplyPreview(),
        // Barre de saisie OU bandeau "chat fermé"
        _buildInputBar(),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  HEADER
  // ─────────────────────────────────────────────────────────────

  Widget _buildHeader(SubOrderModel s) {
    final gradColors = _isSeller
        ? [const Color(0xFF16A34A), const Color(0xFF22C55E)]
        : [const Color(0xFF7C3AED), const Color(0xFF9F7AEA)];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradColors,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft:  Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 20),
          child: Row(children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 4),
            Stack(children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withOpacity(0.5), width: 2),
                ),
                child: Icon(
                  _isSeller ? Icons.person_rounded : Icons.store_rounded,
                  color: Colors.white, size: 24,
                ),
              ),
              // Indicateur en ligne uniquement si le chat est actif
              if (!_isDelivered)
                Positioned(right: 0, bottom: 0,
                    child: Container(
                      width: 13, height: 13,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4ADE80),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    )),
            ]),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isSeller ? _t('chat_with_buyer') : s.storeName,
                  style: const TextStyle(color: Colors.white,
                      fontSize: 16, fontWeight: FontWeight.bold,
                      letterSpacing: 0.3),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(children: [
                  Container(
                    width: 7, height: 7,
                    decoration: BoxDecoration(
                      color: _isDelivered
                          ? Colors.white.withOpacity(0.4)
                          : const Color(0xFF4ADE80),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _isDelivered
                        ? _t('chat_order_delivered_closed')
                        : '#${_chatId.length >= 8
                        ? _chatId.substring(0, 8).toUpperCase()
                        : _chatId.toUpperCase()}',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 12),
                  ),
                ]),
              ],
            )),
          ]),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  BANDEAU COMMANDE
  // ─────────────────────────────────────────────────────────────

  Widget _buildOrderBanner(SubOrderModel s) {
    Widget img;
    if (s.images.isNotEmpty) {
      try {
        final bytes = base64Decode(s.images.first);
        img = ClipRRect(borderRadius: BorderRadius.circular(8),
            child: Image.memory(bytes, width: 44, height: 44,
                fit: BoxFit.cover));
      } catch (_) { img = _imgPlaceholder(); }
    } else { img = _imgPlaceholder(); }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.white,
      child: Row(children: [
        img,
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B))),
            const SizedBox(height: 2),
            Text('${s.price.toStringAsFixed(2)} TND × ${s.quantity}',
                style: TextStyle(fontSize: 11,
                    color: Colors.grey.shade500)),
          ],
        )),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _themeColor.withOpacity(0.10),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _themeColor.withOpacity(0.25)),
          ),
          child: Text(_t('status_${s.status}'),
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                  color: _themeColor)),
        ),
      ]),
    );
  }

  Widget _imgPlaceholder() => Container(
    width: 44, height: 44,
    decoration: BoxDecoration(
        color: _themeColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8)),
    child: Icon(Icons.image_outlined,
        color: _themeColor.withOpacity(0.4), size: 22),
  );

  // ─────────────────────────────────────────────────────────────
  //  LISTE MESSAGES
  // ─────────────────────────────────────────────────────────────

  Widget _buildMessagesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('chats').doc(_chatId)
          .collection('messages')
          .orderBy('createdAt', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(
              color: _themeColor, strokeWidth: 2));
        }
        final docs = snapshot.data?.docs ?? [];
        _markAsRead();

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollCtrl.hasClients) {
            _scrollCtrl.jumpTo(
                _scrollCtrl.position.maxScrollExtent);
          }
        });

        if (docs.isEmpty) {
          return Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline_rounded,
                    size: 56, color: Colors.grey.shade200),
                const SizedBox(height: 12),
                Text(_t('chat_empty'),
                    style: TextStyle(fontSize: 14,
                        color: Colors.grey.shade400,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(_t('chat_empty_sub'),
                    style: TextStyle(fontSize: 12,
                        color: Colors.grey.shade300)),
              ]));
        }

        return ListView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 12),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final data     = docs[i].data() as Map<String, dynamic>;
            final senderId = data['senderId'] as String? ?? '';
            final isMe     = senderId == _myUid;
            final showAvatar = !isMe && (i == 0 ||
                ((docs[i - 1].data() as Map<String, dynamic>)
                ['senderId'] as String? ?? '') == _myUid);

            bool showDate = i == 0;
            if (!showDate) {
              final prevTs = (docs[i - 1].data()
              as Map<String, dynamic>)['createdAt'] as Timestamp?;
              final currTs = data['createdAt'] as Timestamp?;
              if (prevTs != null && currTs != null) {
                final p = prevTs.toDate();
                final c = currTs.toDate();
                showDate = p.day != c.day ||
                    p.month != c.month || p.year != c.year;
              }
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showDate)
                  _buildDateSeparator(
                      (data['createdAt'] as Timestamp?)?.toDate()),
                _buildSwipeableMessage(
                    docs[i].id, data, isMe, showAvatar,
                    i, docs.length),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDateSeparator(DateTime? date) {
    if (date == null) return const SizedBox.shrink();
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d     = DateTime(date.year, date.month, date.day);
    String label;
    if (d == today)
      label = _t('chat_today');
    else if (d == today.subtract(const Duration(days: 1)))
      label = _t('chat_yesterday');
    else
      label = '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/${date.year}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Expanded(child: Divider(color: Colors.grey.shade200)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label, style: TextStyle(fontSize: 11,
              color: Colors.grey.shade400,
              fontWeight: FontWeight.w500)),
        ),
        Expanded(child: Divider(color: Colors.grey.shade200)),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  SWIPEABLE MESSAGE
  //  Le swipe pour répondre est désactivé si la commande est livrée
  // ─────────────────────────────────────────────────────────────

  Widget _buildSwipeableMessage(
      String msgId, Map<String, dynamic> data,
      bool isMe, bool showAvatar, int index, int total) {

    // Si livré : on désactive le swipe en ne retournant que la bulle
    if (_isDelivered) {
      return GestureDetector(
        // Pas de long press non plus (pas de réactions)
        child: _buildMessageBubble(
            msgId, data, isMe, showAvatar, index, total),
      );
    }

    return Dismissible(
      key: ValueKey('swipe_${msgId}_$index'),
      direction: isMe
          ? DismissDirection.endToStart
          : DismissDirection.startToEnd,
      dismissThresholds: const {
        DismissDirection.startToEnd: 0.25,
        DismissDirection.endToStart: 0.25,
      },
      confirmDismiss: (_) async {
        HapticFeedback.lightImpact();
        if (mounted) setState(() {
          _replyingTo   = Map<String, dynamic>.from(data);
          _replyingToId = msgId;
        });
        return false;
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: _themeColor.withOpacity(0.15),
              shape: BoxShape.circle),
          child: Icon(Icons.reply_rounded,
              color: _themeColor, size: 22),
        ),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: _themeColor.withOpacity(0.15),
              shape: BoxShape.circle),
          child: Icon(Icons.reply_rounded,
              color: _themeColor, size: 22),
        ),
      ),
      child: GestureDetector(
        onLongPressStart: (d) =>
            _showReactionPicker(msgId, d.globalPosition),
        child: _buildMessageBubble(
            msgId, data, isMe, showAvatar, index, total),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  BULLE MESSAGE
  // ─────────────────────────────────────────────────────────────

  Widget _buildMessageBubble(
      String msgId, Map<String, dynamic> data,
      bool isMe, bool showAvatar, int index, int total) {
    final text      = data['text']       as String? ?? '';
    final ts        = data['createdAt']  as Timestamp?;
    final isRead    = data['isRead']     as bool? ?? false;
    final reactions = Map<String, dynamic>.from(
        data['reactions'] ?? {});
    final replyTo   = data['replyTo']    as Map<String, dynamic>?;
    final senderName= data['senderName'] as String? ?? '';
    final time      = ts != null
        ? '${ts.toDate().hour.toString().padLeft(2, '0')}:${ts.toDate().minute.toString().padLeft(2, '0')}'
        : '';

    return Padding(
      padding: EdgeInsets.only(
          bottom: index == total - 1 ? 8 : 5,
          top: showAvatar ? 10 : 2),
      child: Row(
        mainAxisAlignment:
        isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            if (showAvatar)
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    _themeColor, _themeColor.withOpacity(0.7)
                  ]),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isSeller
                      ? Icons.person_rounded
                      : Icons.store_rounded,
                  color: Colors.white, size: 18,
                ),
              )
            else
              const SizedBox(width: 34),
            const SizedBox(width: 8),
          ],

          Flexible(child: Column(
            crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (showAvatar && !isMe)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 3),
                  child: Text(senderName,
                      style: TextStyle(fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _themeColor)),
                ),

              Container(
                constraints: BoxConstraints(
                    maxWidth:
                    MediaQuery.of(context).size.width * 0.72),
                decoration: BoxDecoration(
                  gradient: isMe
                      ? const LinearGradient(colors: [
                    _bubbleMeStart, _bubbleMeEnd
                  ]) : null,
                  color: isMe ? null : _bubbleOther,
                  borderRadius: BorderRadius.only(
                    topLeft:    const Radius.circular(18),
                    topRight:   const Radius.circular(18),
                    bottomLeft: Radius.circular(isMe ? 18 : 4),
                    bottomRight:Radius.circular(isMe ? 4  : 18),
                  ),
                  boxShadow: [BoxShadow(
                    color: isMe
                        ? _bubbleMeStart.withOpacity(0.25)
                        : Colors.black.withOpacity(0.06),
                    blurRadius: 8, offset: const Offset(0, 3),
                  )],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (replyTo != null)
                      Container(
                        margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isMe
                              ? Colors.white.withOpacity(0.2)
                              : _themeColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border(left: BorderSide(
                            color: isMe
                                ? Colors.white.withOpacity(0.7)
                                : _themeColor,
                            width: 3,
                          )),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(replyTo['senderName'] ?? '',
                                style: TextStyle(fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isMe
                                        ? Colors.white
                                        : _themeColor)),
                            const SizedBox(height: 2),
                            Text(replyTo['text'] ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12,
                                    color: isMe
                                        ? Colors.white.withOpacity(0.75)
                                        : Colors.grey[600])),
                          ],
                        ),
                      ),

                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      child: Text(text,
                          style: TextStyle(
                              fontSize: 14, height: 1.4,
                              color: isMe
                                  ? Colors.white
                                  : const Color(0xFF1E293B))),
                    ),
                  ],
                ),
              ),

              if (reactions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Wrap(spacing: 4, runSpacing: 4,
                      children: reactions.entries.map((e) {
                        final users   = e.value as List;
                        final iReacted= users.contains(_myUid);
                        return GestureDetector(
                          // Réactions désactivées si livré
                          onTap: _isDelivered
                              ? null
                              : () => _toggleReaction(msgId, e.key),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: iReacted
                                  ? _themeColor.withOpacity(0.12)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: iReacted
                                    ? _themeColor
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(e.key,
                                      style: const TextStyle(fontSize: 14)),
                                  if (users.length > 1) ...[
                                    const SizedBox(width: 3),
                                    Text('${users.length}',
                                        style: TextStyle(fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: iReacted
                                                ? _themeColor
                                                : Colors.grey[600])),
                                  ],
                                ]),
                          ),
                        );
                      }).toList()),
                ),

              const SizedBox(height: 4),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Text(time,
                    style: TextStyle(color: Colors.grey[400],
                        fontSize: 11)),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    isRead ? Icons.done_all : Icons.done,
                    size: 14,
                    color: isRead
                        ? _themeColor
                        : Colors.grey[400],
                  ),
                ],
              ]),
            ],
          )),

          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  PREVIEW RÉPONSE
  // ─────────────────────────────────────────────────────────────

  Widget _buildReplyPreview() {
    if (_replyingTo == null) return const SizedBox.shrink();
    final senderName = _replyingTo!['senderName'] as String? ?? '';
    final text       = _replyingTo!['text']       as String? ?? '';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16)),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16)),
        child: Stack(children: [
          Positioned(left: 0, top: 0, bottom: 0,
              child: Container(width: 3, color: _themeColor)),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            child: Row(children: [
              Icon(Icons.reply_rounded, color: _themeColor, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(senderName,
                      style: TextStyle(fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _themeColor)),
                  const SizedBox(height: 2),
                  Text(text, maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13,
                          color: Colors.grey[600])),
                ],
              )),
              GestureDetector(
                onTap: () => setState(() {
                  _replyingTo = null;
                  _replyingToId = null;
                }),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                      color: Colors.grey[100],
                      shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded,
                      size: 16, color: Colors.grey),
                ),
              ),
              const SizedBox(width: 4),
            ]),
          ),
        ]),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  BARRE DE SAISIE
  //  → Bandeau "chat fermé" si statut = delivered
  //  → Saisie normale pour paid, shipping, cancelled
  // ─────────────────────────────────────────────────────────────

  Widget _buildInputBar() {
    // ── Chat fermé (delivered) ───────────────────────────────────
    if (_isDelivered) {
      return Container(
        padding: EdgeInsets.fromLTRB(
            16, 14, 16,
            14 + MediaQuery.of(context).padding.bottom),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(
              color: Color(0x12000000),
              blurRadius: 12, offset: Offset(0, -4))],
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF86EFAC)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF16A34A), size: 18),
              const SizedBox(width: 10),
              Text(
                _t('chat_order_delivered_closed'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF15803D),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ── Saisie normale (paid, shipping, cancelled) ───────────────
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16,
          12 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(
            color: Color(0x12000000),
            blurRadius: 12, offset: Offset(0, -4))],
      ),
      child: Row(children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4FF),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: TextField(
              controller: _textCtrl,
              maxLines: 4,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              decoration: InputDecoration(
                hintText: _t('chat_type_message'),
                hintStyle: TextStyle(
                    color: Colors.grey.shade400, fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _textCtrl,
          builder: (_, value, __) {
            final hasText = value.text.trim().isNotEmpty;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48, height: 48,
              decoration: BoxDecoration(
                gradient: hasText
                    ? LinearGradient(colors: [
                  _themeColor,
                  _themeColor.withOpacity(0.7),
                ])
                    : null,
                color: hasText ? null : const Color(0xFFE2E8F0),
                shape: BoxShape.circle,
                boxShadow: hasText
                    ? [BoxShadow(
                    color: _themeColor.withOpacity(0.35),
                    blurRadius: 12, offset: const Offset(0, 4))]
                    : [],
              ),
              child: IconButton(
                onPressed: hasText && !_sending ? _sendMessage : null,
                icon: _sending
                    ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(
                            Colors.white)))
                    : Icon(Icons.send_rounded,
                    color: hasText
                        ? Colors.white
                        : Colors.grey[400],
                    size: 20),
              ),
            );
          },
        ),
      ]),
    );
  }
}