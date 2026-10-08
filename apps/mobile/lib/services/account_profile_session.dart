import 'account_storage.dart';
import 'profile_session.dart';

/// Every verified login reloads that account's record, including the same phone
/// after logout. A stale/empty in-memory session must not bypass restoration.
Future<ProfileSession> restoreAccountProfile({
  required String account,
  required AccountStorage storage,
  required ProfileSession current,
  required ProfileSession Function() create,
}) async {
  if (current.calculating || current.answering) {
    throw StateError('Finish the current request before switching accounts.');
  }
  await current.flushStorage();
  await storage.migrateLegacy(account);
  storage.account = account;
  final restored = create();
  await restored.restore();
  return restored;
}
