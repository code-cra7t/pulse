import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/features/external_context/models/shared_capture_payload.dart';

void main() {
  test('shared subject is included in capture text', () {
    final payload = SharedCapturePayload.fromMap({
      'text': 'Please review the attached role.',
      'subject': 'Werkstudent application',
      'mimeType': 'text/plain',
    });

    expect(
      payload.captureText,
      'Werkstudent application\n\nPlease review the attached role.',
    );
    expect(payload.mimeType, 'text/plain');
  });

  test('subject is not duplicated when shared text already starts with it', () {
    final payload = SharedCapturePayload.fromMap({
      'text': 'HPC deadline\nSubmit report by Sep 30',
      'subject': 'HPC deadline',
    });

    expect(payload.captureText, 'HPC deadline\nSubmit report by Sep 30');
  });
}
