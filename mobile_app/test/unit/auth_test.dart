import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localspotify/data/models/user_session.dart';
import 'package:localspotify/ui/core_widgets/google_auth_button.dart';

void main() {
  group('Auth & UserSession Tests', () {
    test('creates UserSession with clean authQueryParams', () {
      final session = UserSession(
        serverUrl: 'http://100.92.248.49:6767',
        username: 'ahmed',
        token: 'test_token',
        salt: 'test_salt',
      );

      expect(session.serverUrl, equals('http://100.92.248.49:6767'));
      expect(session.username, equals('ahmed'));
      expect(session.authQueryParams['u'], equals('ahmed'));
      expect(session.authQueryParams['t'], equals('test_token'));
      expect(session.authQueryParams['s'], equals('test_salt'));
      expect(session.authQueryParams['f'], equals('json'));
      expect(session.authQueryParams['c'], equals('LocalSpotify-Flutter'));
    });

    test('serializes and deserializes UserSession to/from JSON', () {
      final session = UserSession(
        serverUrl: 'https://vault.example.com',
        username: 'gaith',
        token: 'tok123',
        salt: 'slt456',
      );

      final json = session.toJson();
      final restored = UserSession.fromJson(json);

      expect(restored.serverUrl, equals('https://vault.example.com'));
      expect(restored.username, equals('gaith'));
      expect(restored.token, equals('tok123'));
      expect(restored.salt, equals('slt456'));
    });

    testWidgets('GoogleAuthButton renders with Google logo and text', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GoogleAuthButton(
              text: 'Continue with Google',
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.byType(GoogleLogo), findsOneWidget);

      await tester.tap(find.byType(GoogleAuthButton));
      expect(tapped, isTrue);
    });
  });
}
