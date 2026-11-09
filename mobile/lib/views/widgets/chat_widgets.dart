import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/marketplace.dart';
import '../../theme/design_tokens.dart';

/// Localized inbox timestamp: today → h:mm a, yesterday → "Yesterday",
/// this week → weekday, older → d/M. UTC is converted to the device zone.
String conversationTimeLabel(DateTime sentAtUtc) {
  final local = sentAtUtc.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final diff = today.difference(day).inDays;
  if (diff <= 0) return DateFormat('h:mm a').format(local);
  if (diff == 1) return 'Yesterday';
  if (diff < 7) return DateFormat('E').format(local);
  return DateFormat('d/M').format(local);
}

/// Inbox row — participant-first: the counterparty's name is the title and
/// the job (title + human status) is the subtitle. Preview is the real last
/// message; [ConversationSummary.unreadCount] drives a real badge, never an
/// invented dot.
class ConversationTile extends StatelessWidget {
  final ConversationSummary conversation;
  final VoidCallback onTap;
  final bool selected;

  const ConversationTile({
    super.key,
    required this.conversation,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final c = conversation;
    final name = c.otherFirstName.isNotEmpty
        ? c.otherFirstName
        : 'Conversation';
    final hasUnread = c.unreadCount > 0;

    return Semantics(
      label: hasUnread
          ? '$name, ${c.jobTitle}, ${c.unreadCount} unread messages'
          : '$name, ${c.jobTitle}',
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(DesignTokens.radiusTile),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.symmetric(horizontal: Space.s3, vertical: Space.s2),
            decoration: BoxDecoration(
              color: selected
                  ? (isDark
                      ? DesignTokens.brand700.withValues(alpha: Alpha.border)
                      : DesignTokens.brand100Light)
                  : DesignTokens.surfaceCard(isDark),
              borderRadius: BorderRadius.circular(DesignTokens.radiusTile),
              border: Border.all(
                color: selected
                    ? DesignTokens.brand500
                    : (isDark
                        ? DesignTokens.paperLineDark
                        : DesignTokens.paperLineLight),
                width: selected ? 1.5 : 1.0,
              ),
              boxShadow: isDark || selected
                  ? null
                  : [
                      BoxShadow(
                        color: DesignTokens.shadowCard,
                        blurRadius: 6,
                        offset: const Offset(0, 1),
                      ),
                    ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _ConversationAvatar(
                  initial: c.otherFirstName.isNotEmpty
                      ? c.otherFirstName[0].toUpperCase()
                      : c.jobTitle.isNotEmpty
                      ? c.jobTitle[0].toUpperCase()
                      : '?',
                  isDark: isDark,
                  isActive: _isActiveStatus(c.status),
                ),
                const SizedBox(width: Space.s3),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(
                                fontFamily: DesignTokens.fontDisplay,
                                fontSize: DesignTokens.fontSizeH3,
                                fontWeight: FW.semibold,
                                color: DesignTokens.foregroundBrand(isDark),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (c.lastMessageAtUtc != null) ...[
                            const SizedBox(width: Space.s2),
                            Text(
                              conversationTimeLabel(c.lastMessageAtUtc!),
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: DesignTokens.fontSizeCaption,
                                fontWeight: FW.medium,
                                color: DesignTokens.inkSoft(isDark),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: Space.s0_5),
                      Text(
                        c.jobTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: DesignTokens.fontBody,
                          fontSize: DesignTokens.fontSizeCaption,
                          fontWeight: FW.medium,
                          color: DesignTokens.inkSoft(isDark),
                        ),
                      ),
                      const SizedBox(height: Space.s0_5),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _preview(c),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: DesignTokens.fontBody,
                                fontSize: DesignTokens.fontSizeSm,
                                fontWeight: hasUnread ? FW.medium : FW.regular,
                                color: c.lastMessage == null
                                    ? DesignTokens.inkSoft(isDark)
                                    : DesignTokens.foreground(isDark),
                                fontStyle: c.lastMessage == null
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                              ),
                            ),
                          ),
                          if (c.status == 'Disputed') ...[
                            const SizedBox(width: Space.s2),
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 16,
                              color: DesignTokens.inkDanger(isDark),
                            ),
                          ] else if (c.lastMessageMine) ...[
                            // Outgoing: small send arrow — no "You:" prefix needed.
                            const SizedBox(width: Space.s2),
                            Icon(
                              Icons.north_east_rounded,
                              size: 15,
                              color: DesignTokens.inkSoft(isDark),
                            ),
                          ] else if (hasUnread) ...[
                            const SizedBox(width: Space.s2),
                            _UnreadDot(),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _preview(ConversationSummary c) {
    final text = c.lastMessage;
    if (text == null || text.isEmpty) return 'No messages yet';
    // No "You:" prefix — the trailing arrow icon already signals it was sent by me.
    return text;
  }

  /// Active statuses: the job has a confirmed booking in progress.
  static bool _isActiveStatus(String status) =>
      status == 'Booked' ||
      status == 'InProgress' ||
      status == 'AwaitingConfirmation';
}

/// 8px brand-blue unread indicator dot — matches the mockup.
class _UnreadDot extends StatelessWidget {
  const _UnreadDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: DesignTokens.brand500,
      ),
    );
  }
}

class _ConversationAvatar extends StatelessWidget {
  final String initial;
  final bool isDark;
  /// True when the job is in an active state (Booked / InProgress / AwaitingConfirmation).
  /// Shows a filled brand-500 circle with white initials and a verified badge.
  final bool isActive;

  const _ConversationAvatar({
    required this.initial,
    required this.isDark,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final circle = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive
            ? DesignTokens.brand500
            : (isDark ? DesignTokens.brand100Dark : DesignTokens.brand100Light),
        border: isActive
            ? null
            : Border.all(
                color: isDark
                    ? DesignTokens.paperLineDark
                    : DesignTokens.paperLineLight,
              ),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontFamily: DesignTokens.fontDisplay,
            fontSize: DesignTokens.fontSizeH3,
            fontWeight: FW.bold,
            color: isActive
                ? Colors.white
                : (isDark ? DesignTokens.brand300 : DesignTokens.brand700),
          ),
        ),
      ),
    );

    if (!isActive) return circle;

    // Verified badge — small green checkmark overlaid on the bottom-right.
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          circle,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: DesignTokens.green,
                border: Border.all(
                  color: isDark
                      ? DesignTokens.paperDark
                      : DesignTokens.paperLight,
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.check,
                size: 9,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Centred timestamp divider between message groups — e.g. "Today 1:47 pm".
/// Matches the mockup's muted small-caps grey label.
class ChatDateSeparator extends StatelessWidget {
  final DateTime timestampUtc;

  const ChatDateSeparator({super.key, required this.timestampUtc});

  String _label() {
    final local = timestampUtc.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final diff = today.difference(day).inDays;
    final time = DateFormat('h:mm a').format(local);
    if (diff <= 0) return 'Today $time';
    if (diff == 1) return 'Yesterday $time';
    if (diff < 7) return '${DateFormat('EEEE').format(local)} $time';
    return DateFormat('d MMM').format(local);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.s4),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 0.5,
              color: DesignTokens.paperLine(isDark),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.s3),
            child: Text(
              _label(),
              style: TextStyle(
                fontFamily: DesignTokens.fontBody,
                fontSize: DesignTokens.fontSizeCaption,
                fontWeight: FW.medium,
                color: DesignTokens.inkSoft(isDark),
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 0.5,
              color: DesignTokens.paperLine(isDark),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single chat bubble: sender name (incoming only), body, localized time.
/// [isGrouped] = true when the previous message was from the same sender
/// within the same minute — tightens the vertical gap and hides the sender name.
/// When [failed] is true the bubble shows a truthful "Not sent" state with a
/// ≥48px retry affordance wired to [onRetry].
class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool failed;
  final bool isGrouped;
  final VoidCallback? onRetry;

  const ChatBubble({
    super.key,
    required this.message,
    this.failed = false,
    this.isGrouped = false,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final m = message;

    // Colours from mockup:
    //   outgoing — brand900 navy (#193957) both themes
    //   incoming — white on light / card surface on dark
    final Color bubbleBg = m.sentByMe
        ? DesignTokens.brand900
        : DesignTokens.surfaceCard(isDark);

    final Color bubbleText = m.sentByMe
        ? Colors.white
        : DesignTokens.foreground(isDark);

    // Tail: the corner closest to the tail is tighter (4px),
    // the rest are fully round (20px) for a modern bubble shape.
    const double fullR = 20.0;
    const double tailR = 4.0;
    final BorderRadius radius = m.sentByMe
        ? const BorderRadius.only(
            topLeft:     Radius.circular(fullR),
            topRight:    Radius.circular(fullR),
            bottomLeft:  Radius.circular(fullR),
            bottomRight: Radius.circular(tailR),
          )
        : const BorderRadius.only(
            topLeft:     Radius.circular(tailR),
            topRight:    Radius.circular(fullR),
            bottomLeft:  Radius.circular(fullR),
            bottomRight: Radius.circular(fullR),
          );

    return Align(
      alignment: m.sentByMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            m.sentByMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Sender name (incoming only, first in a group)
          if (!m.sentByMe && m.senderName.isNotEmpty && !isGrouped)
            Padding(
              padding: const EdgeInsets.only(left: Space.s2, bottom: Space.s1),
              child: Text(
                m.senderName,
                style: TextStyle(
                  fontFamily: DesignTokens.fontBody,
                  fontSize: DesignTokens.fontSizeCaption,
                  fontWeight: FW.semibold,
                  color: DesignTokens.foregroundBrand(isDark),
                ),
              ),
            ),

          // Bubble
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: Space.s4,
              vertical: Space.s3,
            ),
            decoration: BoxDecoration(
              color: bubbleBg,
              borderRadius: radius,
              border: m.sentByMe
                  ? null
                  : Border.all(
                      color: isDark
                          ? DesignTokens.paperLineDark
                          : DesignTokens.paperLineLight,
                    ),
              boxShadow: m.sentByMe
                  ? null
                  : DesignTokens.cardShadow(isDark),
            ),
            child: Text(
              m.text ?? '',
              style: TextStyle(
                fontFamily: DesignTokens.fontBody,
                fontSize: DesignTokens.fontSizeSm,
                fontWeight: FW.regular,
                height: 1.45,
                color: bubbleText,
              ),
            ),
          ),

          // Timestamp or failed state
          if (failed)
            InkWell(
              onTap: onRetry,
              borderRadius: BorderRadius.circular(DesignTokens.radiusControl),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.s1,
                  vertical: Space.s3,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 14,
                      color: DesignTokens.inkDanger(isDark),
                    ),
                    const SizedBox(width: Space.s1),
                    Flexible(
                      child: Text(
                        'Not sent — tap to retry',
                        style: TextStyle(
                          fontFamily: DesignTokens.fontBody,
                          fontSize: DesignTokens.fontSizeCaption,
                          fontWeight: FW.semibold,
                          color: DesignTokens.inkDanger(isDark),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Padding(
              padding: EdgeInsets.only(
                top: Space.s1,
                left: m.sentByMe ? 0 : Space.s2,
                right: m.sentByMe ? Space.s2 : 0,
              ),
              child: Text(
                DateFormat('h:mm a').format(m.sentAtUtc.toLocal()),
                style: TextStyle(
                  fontFamily: DesignTokens.fontBody,
                  fontSize: DesignTokens.fontSizeCaption,
                  color: DesignTokens.inkSoft(isDark),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Message composer: optional role-appropriate [quickReplies] that populate
/// the field for editing (never auto-send), an attach action, the text field
/// and a ≥48px send button. Explicit send still goes through [onSend].
class ChatComposer extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final VoidCallback onSend;
  final VoidCallback? onAttach;
  final List<String> quickReplies;
  final String? hintText;

  const ChatComposer({
    super.key,
    required this.controller,
    required this.onSend,
    this.focusNode,
    this.onAttach,
    this.quickReplies = const [],
    this.hintText,
  });

  void _applyQuickReply(String text) {
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    focusNode?.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Quick-reply chips ───────────────────────────────────────────
        if (quickReplies.isNotEmpty) ...[
          SizedBox(
            height: Sizes.chipVisual,
            child: ShaderMask(
              shaderCallback: (Rect bounds) {
                return const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Colors.white, Colors.white, Colors.transparent],
                  stops: [0.0, 0.88, 1.0],
                ).createShader(bounds);
              },
              blendMode: BlendMode.dstIn,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(vertical: Space.s1),
                itemCount: quickReplies.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: Space.s2),
                itemBuilder: (_, i) {
                  final reply = quickReplies[i];
                  return GestureDetector(
                    onTap: () => _applyQuickReply(reply),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Space.s4,
                        vertical: Space.s1_5,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? DesignTokens.cardDark
                            : DesignTokens.surfaceCard(isDark),
                        borderRadius:
                            BorderRadius.circular(DesignTokens.radiusPill),
                        border: Border.all(
                          color: isDark
                              ? DesignTokens.paperLineDark
                              : DesignTokens.paperLineLight,
                        ),
                      ),
                      child: Text(
                        reply,
                        style: TextStyle(
                          fontFamily: DesignTokens.fontBody,
                          fontSize: DesignTokens.fontSizeSecondary,
                          fontWeight: FW.medium,
                          color: DesignTokens.foreground(isDark),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: Space.s2),
        ],

        // ── Input row ───────────────────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Attach / image button
            if (onAttach != null)
              IconButton(
                tooltip: 'Attach photo',
                onPressed: onAttach,
                icon: Icon(
                  Icons.image_outlined,
                  size: 22,
                  color: DesignTokens.inkSoft(isDark),
                ),
              ),
            // Text field — pill shaped
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: Sizes.input),
                decoration: BoxDecoration(
                  color: DesignTokens.surfaceCard(isDark),
                  borderRadius:
                      BorderRadius.circular(DesignTokens.radiusPill),
                  border: Border.all(
                    color: isDark
                        ? DesignTokens.paperLineDark
                        : DesignTokens.paperLineLight,
                  ),
                ),
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  minLines: 1,
                  maxLines: 4,
                  style: TextStyle(
                    fontFamily: DesignTokens.fontBody,
                    fontSize: DesignTokens.fontSizeSm,
                    color: DesignTokens.foreground(isDark),
                  ),
                  decoration: InputDecoration(
                    hintText: hintText ?? 'Message…',
                    hintStyle: TextStyle(
                      fontFamily: DesignTokens.fontBody,
                      fontSize: DesignTokens.fontSizeSm,
                      color: DesignTokens.inkSoft(isDark),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: Space.s5,
                      vertical: Space.s3,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                ),
              ),
            ),
            const SizedBox(width: Space.s2_5),

            // Send button — amber circle with arrow icon
            GestureDetector(
              onTap: onSend,
              child: Container(
                width: Sizes.fab - Space.s2,  // 48px
                height: Sizes.fab - Space.s2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: DesignTokens.amber,
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x40E38B29),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: DesignTokens.onAmber,
                  size: Space.s6,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
