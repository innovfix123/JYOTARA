/// Presentation only: the original response, receipt and stored history remain
/// one message. Never rewrite, shorten or invent the provider's answer here.
List<String> chatReplyParts(String text) {
  final paragraphs = text
      .split(RegExp(r'\n+'))
      .map((paragraph) => paragraph.trim())
      .where((paragraph) => paragraph.isNotEmpty)
      .toList();
  // Model paragraphs are complete thoughts. Splitting their sentences creates
  // extra pauses and delays the next question after the answer is ready.
  const maxParts = 5;
  if (paragraphs.length <= maxParts) return paragraphs;
  // Older answers may have more paragraphs. Keep their order and all text,
  // combining adjacent whole paragraphs into at most five presentation groups.
  return List.generate(maxParts, (index) {
    final start = index * paragraphs.length ~/ maxParts;
    final end = (index + 1) * paragraphs.length ~/ maxParts;
    return paragraphs.sublist(start, end).join('\n\n');
  });
}

Duration chatPartPause(String part, int count) {
  // Each thought gets its own readable pace. More thoughts must not make the
  // pauses shorter; there is no global delivery budget or billing clock here.
  return Duration(
    milliseconds: (5000 + part.runes.length * 8).clamp(5000, 7000),
  );
}
