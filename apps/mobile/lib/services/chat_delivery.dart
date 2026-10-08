/// Presentation only: the original response, receipt and stored history remain
/// one message. Never rewrite, shorten or invent the provider's answer here.
List<String> chatReplyParts(String text) {
  final parts = <String>[];
  for (final paragraph in text.split(RegExp(r'\n+'))) {
    final raw = paragraph.split(RegExp(r'(?<=[.!?।])\s+'));
    final sentences = <String>[];
    for (var i = 0; i < raw.length; i++) {
      if (i + 1 < raw.length &&
          RegExp(r'^(?:\d{1,2}|Dr|Mr|Mrs|Ms|Prof|St)\.$')
              .hasMatch(raw[i].trim())) {
        sentences.add('${raw[i]} ${raw[++i]}');
      } else {
        sentences.add(raw[i]);
      }
    }
    for (final sentence in sentences) {
      // A complete thought belongs in one message. Cutting at a fixed character
      // count made Tamil clauses and longer explanations feel fragmented.
      final thought = sentence.trim();
      if (thought.isNotEmpty) parts.add(thought);
    }
  }
  return parts;
}

Duration chatPartPause(String part, int count) {
  // Each thought gets its own readable pace. More thoughts must not make the
  // pauses shorter; there is no global delivery budget or billing clock here.
  return Duration(
    milliseconds: (900 + part.runes.length * 9).clamp(1400, 3000),
  );
}
