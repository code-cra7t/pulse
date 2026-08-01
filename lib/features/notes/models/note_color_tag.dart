import 'package:flutter/material.dart';

class NoteColorTag {
  const NoteColorTag({
    required this.color,
    required this.label,
    required this.accent,
  });

  final int color;
  final String label;
  final Color accent;

  static const tags = <NoteColorTag>[
    NoteColorTag(color: 0xFFFFF8E1, label: 'Sand', accent: Color(0xFFB88A24)),
    NoteColorTag(color: 0xFFE1F5FE, label: 'Sky', accent: Color(0xFF157CB1)),
    NoteColorTag(color: 0xFFE8F5E9, label: 'Mint', accent: Color(0xFF2E7D4F)),
    NoteColorTag(color: 0xFFFCE4EC, label: 'Rose', accent: Color(0xFFB24C72)),
    NoteColorTag(color: 0xFFF3E5F5, label: 'Lilac', accent: Color(0xFF7F56A5)),
  ];

  static NoteColorTag fromColor(int color) {
    return tags.firstWhere(
      (tag) => tag.color == color,
      orElse: () => tags.first,
    );
  }
}
