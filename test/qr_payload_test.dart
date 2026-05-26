import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:namma_bingo/core/result.dart';
import 'package:namma_bingo/data/models/user_model.dart';
import 'package:namma_bingo/features/qr/qr_payload.dart';

void main() {
  setUpAll(() {
    // QrPayload reads the signature from .env via Env. Stub it for tests.
    dotenv.testLoad(fileInput: 'QR_SIGNATURE=BINGO_USER_V1');
  });

  test('round-trip: encode then decode preserves identity fields', () {
    final user = UserModel(
      id: 'uid-123',
      name: 'Jane Doe',
      email: 'jane@example.com',
      linkedinUrl: 'https://linkedin.com/in/jane',
    );

    final encoded = QrPayload.fromUser(user).encode();
    final decoded = QrPayload.decode(encoded);

    expect(decoded.isOk, isTrue);
    final payload = decoded.valueOrNull!;
    expect(payload.uid, 'uid-123');
    expect(payload.name, 'Jane Doe');
    expect(payload.linkedinUrl, 'https://linkedin.com/in/jane');
  });

  test('rejects QR with wrong signature', () {
    // Simulate a QR generated under a different signature.
    dotenv.testLoad(fileInput: 'QR_SIGNATURE=BINGO_USER_V2');
    final user = UserModel(id: 'u', name: 'x', email: 'x@x.com');
    final encoded = QrPayload.fromUser(user).encode();

    dotenv.testLoad(fileInput: 'QR_SIGNATURE=BINGO_USER_V1');
    final decoded = QrPayload.decode(encoded);
    expect(decoded.isErr, isTrue);
  });

  test('rejects payload missing required fields', () {
    final decoded = QrPayload.decode('not-a-valid-base64-or-json');
    expect(decoded.isErr, isTrue);
  });

  test('rejects QR from a different app', () {
    final decoded = QrPayload.decode('https://example.com/some-random-qr');
    expect(decoded.isErr, isTrue);
  });
}
