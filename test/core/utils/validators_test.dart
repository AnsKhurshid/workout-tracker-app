import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/core/utils/validators.dart';

void main() {
  group('email', () {
    test('accepts valid addresses (trimmed)', () {
      expect(Validators.email('sam@example.com'), isNull);
      expect(Validators.email('  first.last+gym@sub.example.co.uk '), isNull);
    });
    test('rejects empty and malformed addresses', () {
      expect(Validators.email(''), 'Enter your email address.');
      expect(Validators.email(null), isNotNull);
      for (final bad in ['sam', 'sam@', '@example.com', 'sam@example', 'sam @example.com']) {
        expect(Validators.email(bad), 'Enter a valid email address.', reason: bad);
      }
    });
  });

  group('new password', () {
    test('requires length, a letter and a number', () {
      expect(Validators.newPassword(''), 'Enter a password.');
      expect(Validators.newPassword('abc123'), contains('at least 8'));
      expect(Validators.newPassword('abcdefgh'), contains('letter and one number'));
      expect(Validators.newPassword('12345678'), contains('letter and one number'));
      expect(Validators.newPassword('a' * 72 + '1'), contains('at most 72'));
      expect(Validators.newPassword('liftHeavy1'), isNull);
    });
  });

  test('existing password only checks presence', () {
    expect(Validators.existingPassword(''), isNotNull);
    expect(Validators.existingPassword('x'), isNull);
  });

  test('confirm password must match the original', () {
    var original = 'liftHeavy1';
    final validate = Validators.confirmPassword(() => original);
    expect(validate(''), 'Confirm your password.');
    expect(validate('liftHeavy2'), "Passwords don't match.");
    expect(validate('liftHeavy1'), isNull);
    original = 'changed1';
    expect(validate('liftHeavy1'), "Passwords don't match.");
  });

  test('display name is required and limited to 50 characters', () {
    expect(Validators.displayName('   '), 'Enter your name.');
    expect(Validators.displayName('x' * 51), contains('at most 50'));
    expect(Validators.displayName(' Sam '), isNull);
  });
}
