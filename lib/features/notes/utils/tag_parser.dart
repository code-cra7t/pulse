class TagParser {
  static final RegExp _tagPattern = RegExp(r'(?<!\w)#([A-Za-z0-9_]+)');

  static List<String> extractTags(String text) {
    final tags = <String>{};

    for (final match in _tagPattern.allMatches(text)) {
      final tag = match.group(1)?.trim().toLowerCase();
      if (tag == null || tag.isEmpty) {
        continue;
      }

      tags.add(tag);
    }

    return tags.toList();
  }
}
