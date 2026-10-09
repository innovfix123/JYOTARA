part of 'main.dart';

class _MessageBubble extends StatefulWidget {
  const _MessageBubble({
    required this.message,
    this.onReport,
    this.animate = false,
    this.onPart,
    this.onDelivered,
  });
  final ChatMessage message;
  final VoidCallback? onReport, onPart, onDelivered;
  final bool animate;
  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble>
    with AutomaticKeepAliveClientMixin {
  late final List<String> _parts;
  late int _visible;
  Timer? _timer;
  bool _started = false;
  @override
  bool get wantKeepAlive => _visible < _parts.length;
  @override
  void initState() {
    _parts = widget.message.fromUser
        ? [widget.message.text]
        : chatReplyParts(widget.message.text);
    _visible = widget.animate ? 0 : _parts.length;
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) _visible = _parts.length;
    if (_visible < _parts.length) {
      _schedulePart();
    } else if (widget.animate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onDelivered?.call();
      });
    }
  }

  void _schedulePart() {
    _timer = Timer(chatPartPause(_parts[_visible], _parts.length), () {
      if (!mounted) return;
      setState(() => _visible++);
      widget.onPart?.call();
      if (_visible == _parts.length) {
        updateKeepAlive();
        widget.onDelivered?.call();
      } else {
        _schedulePart();
      }
    });
  }

  @override
  void didUpdateWidget(covariant _MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animate && !widget.animate && _visible < _parts.length) {
      _timer?.cancel();
      _visible = _parts.length;
      updateKeepAlive();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _visible; i++)
          _MessagePiece(
            message: ChatMessage(
              fromUser: widget.message.fromUser,
              text: _parts[i],
              label: i == 0 ? widget.message.label : null,
            ),
            onReport: i == _parts.length - 1 ? widget.onReport : null,
          ),
        if (_visible < _parts.length) const _TypingBubble(),
      ],
    );
  }
}

class _MessagePiece extends StatelessWidget {
  const _MessagePiece({required this.message, this.onReport});
  final ChatMessage message;
  final VoidCallback? onReport;
  @override
  Widget build(BuildContext context) => Align(
    alignment: message.fromUser ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * .88,
      ),
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: message.fromUser ? AskPalette.user : AskPalette.reply,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(17),
          topRight: const Radius.circular(17),
          bottomLeft: Radius.circular(message.fromUser ? 17 : 5),
          bottomRight: Radius.circular(message.fromUser ? 5 : 17),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.label != null) ...[
            Text(
              publicReadingText(message.label!),
              style: const TextStyle(
                color: AskPalette.action,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: .5,
              ),
            ),
            const SizedBox(height: 5),
          ],
          SelectionArea(
            child: Text(
              publicReadingText(message.text),
              style: const TextStyle(
                fontFamily: 'JyotaraChat',
                fontFamilyFallback: ['JyotaraTamil'],
                fontSize: 15,
                height: 1.55,
                color: AskPalette.ink,
              ),
            ),
          ),
          if (onReport != null)
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Report answer',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minHeight: 28, minWidth: 32),
                onPressed: onReport,
                icon: const Icon(
                  Icons.flag_outlined,
                  size: 14,
                  color: AskPalette.muted,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();
  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble> {
  Timer? _timer;
  int _dot = 0;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 350), (_) {
      if (mounted && !MediaQuery.disableAnimationsOf(context)) {
        setState(() => _dot = (_dot + 1) % 3);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: uiText(context, 'Typing…'),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Container(
        key: const Key('chatTypingIndicator'),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: AskPalette.reply,
          borderRadius: BorderRadius.circular(17),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: EdgeInsets.only(right: i == 2 ? 0 : 5),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AskPalette.action.withValues(
                      alpha: i == _dot ? .95 : .35,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
