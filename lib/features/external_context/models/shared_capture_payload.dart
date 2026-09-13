class SharedCapturePayload {
  const SharedCapturePayload({required this.text, this.subject, this.mimeType});

  final String text;
  final String? subject;
  final String? mimeType;

  String get captureText {
    final cleanSubject = subject?.trim();
    if (cleanSubject == null || cleanSubject.isEmpty) {
      return text;
    }
    if (text.toLowerCase().startsWith(cleanSubject.toLowerCase())) {
      return text;
    }
    return '$cleanSubject\n\n$text';
  }

  factory SharedCapturePayload.fromMap(Map<Object?, Object?> raw) {
    final text = raw['text']?.toString().trim() ?? '';
    if (text.isEmpty) {
      throw const FormatException('Shared text is empty.');
    }
    final subject = raw['subject']?.toString().trim();
    final mimeType = raw['mimeType']?.toString().trim();
    return SharedCapturePayload(
      text: text,
      subject: subject == null || subject.isEmpty ? null : subject,
      mimeType: mimeType == null || mimeType.isEmpty ? null : mimeType,
    );
  }
}
