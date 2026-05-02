String toTitleCase(String raw) {
  final parts = raw
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ')
      .split(' ')
      .where((p) => p.isNotEmpty)
      .map((word) {
        if (word == word.toUpperCase() && word.length <= 4) return word;
        final first = word.substring(0, 1).toUpperCase();
        final rest = word.length > 1 ? word.substring(1).toLowerCase() : '';
        return '$first$rest';
      });
  return parts.join(' ');
}
