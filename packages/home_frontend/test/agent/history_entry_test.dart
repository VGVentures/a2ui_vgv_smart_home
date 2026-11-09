import 'package:flutter_test/flutter_test.dart';
import 'package:home_frontend/home_frontend.dart';

void main() {
  group(HistoryEntry, () {
    test('a user entry goes on the wire as user', () {
      const entry = HistoryEntry.user('hi');

      expect(entry.role, HistoryRole.user);
      expect(entry.wireRole, 'user');
      expect(entry.content, 'hi');
    });

    test('a model entry goes on the wire as assistant', () {
      const entry = HistoryEntry.assistant('hello');

      expect(entry.role, HistoryRole.assistant);
      expect(entry.wireRole, 'assistant');
    });

    test('entries with the same role and content are equal', () {
      expect(const HistoryEntry.user('a'), const HistoryEntry.user('a'));
      expect(
        const HistoryEntry.user('a').hashCode,
        const HistoryEntry.user('a').hashCode,
      );
      expect(
        const HistoryEntry.user('a'),
        isNot(const HistoryEntry.assistant('a')),
      );
      expect(
        const HistoryEntry.user('a'),
        isNot(const HistoryEntry.user('b')),
      );
    });

    test('says who wrote it in its description', () {
      expect(const HistoryEntry.user('a').toString(), contains('user: a'));
    });
  });
}
