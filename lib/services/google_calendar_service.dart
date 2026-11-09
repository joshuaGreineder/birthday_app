import 'dart:async';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as cal;

import '../app_config.dart';
import 'calendar_sync_plan.dart';
import 'storage_service.dart';

/// Outcome of a sync, phrased for a snackbar.
class CalendarSyncResult {
  const CalendarSyncResult({
    this.created = 0,
    this.updated = 0,
    this.deleted = 0,
    this.failed = 0,
    this.error,
    this.needsReconnect = false,
  });

  final int created;
  final int updated;
  final int deleted;
  final int failed;
  final String? error;
  final bool needsReconnect;

  bool get ok => error == null && failed == 0;

  String get message {
    if (needsReconnect) return 'Reconnect Google Calendar in Settings to keep syncing.';
    if (error != null) return error!;
    final changes = created + updated + deleted;
    final base = changes == 0
        ? 'Google Calendar is up to date.'
        : 'Google Calendar synced: $created added, $updated updated, $deleted removed.';
    return failed == 0 ? base : '$base $failed could not be synced.';
  }
}

/// Keeps a dedicated "Happaroo Birthdays" calendar in the user's Google account
/// in step with the events saved in Happaroo.
///
/// Uses only the `calendar.app.created` scope: Happaroo can create its own
/// calendar and manage events on it, and cannot see the user's other calendars.
class GoogleCalendarService {
  static GoogleCalendarService? _instance;
  factory GoogleCalendarService() => _instance ??= GoogleCalendarService._internal();
  GoogleCalendarService._internal();

  static const List<String> scopes = ['https://www.googleapis.com/auth/calendar.app.created'];
  static const String calendarName = 'Happaroo Birthdays';

  static const _kConnected = 'googleCalendarConnected';
  static const _kAccount = 'googleCalendarAccount';
  static const _kCalendarId = 'googleCalendarId';
  static const _kLastSync = 'googleCalendarLastSync';

  Future<void>? _initFuture;
  cal.CalendarApi? _api;
  String? _accessToken;
  Future<CalendarSyncResult> _queue = Future.value(const CalendarSyncResult());
  Timer? _debounce;

  /// The build carries an OAuth web client ID (see README, Google Calendar setup).
  bool get isConfigured => kCalendarSyncEnabled && kGoogleServerClientId.isNotEmpty;

  bool get isConnected => _storage.getSetting(_kConnected, defaultValue: false) == true;

  String? get accountEmail => _storage.getSetting(_kAccount) as String?;

  DateTime? get lastSync {
    final raw = _storage.getSetting(_kLastSync) as String?;
    return raw == null ? null : DateTime.tryParse(raw)?.toLocal();
  }

  StorageService get _storage => StorageService();

  Future<void> _ensureInitialized() {
    return _initFuture ??= GoogleSignIn.instance.initialize(serverClientId: kGoogleServerClientId);
  }

  /// Signs in, asks for calendar access, creates the calendar and runs the first sync.
  /// Call only from a button tap: it shows Google's account and consent screens.
  Future<CalendarSyncResult> connect() async {
    if (!isConfigured) {
      return const CalendarSyncResult(error: 'Google Calendar sync is not set up in this build.');
    }
    try {
      await _ensureInitialized();
      final account = await GoogleSignIn.instance.authenticate(scopeHint: scopes);
      final authorization = await account.authorizationClient.authorizeScopes(scopes);
      _useAuthorization(authorization);
      await _storage.saveSetting(_kConnected, true);
      await _storage.saveSetting(_kAccount, account.email);
    } on GoogleSignInException catch (e) {
      debugPrint('Google sign-in failed: ${e.code} ${e.description}');
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return const CalendarSyncResult(
          error: 'Google sign-in was canceled. If you did not cancel it, the app\'s Google setup '
              'may not match this build.',
        );
      }
      return CalendarSyncResult(error: 'Google sign-in failed (${e.code.name}).');
    } catch (e) {
      debugPrint('Google sign-in failed: $e');
      return const CalendarSyncResult(error: 'Could not connect to Google. Check your connection.');
    }
    return syncNow();
  }

  /// Revokes Happaroo's access. With [removeCalendar], deletes the Happaroo calendar first.
  Future<String?> disconnect({required bool removeCalendar}) async {
    String? problem;
    if (removeCalendar) {
      final calendarId = _storage.getSetting(_kCalendarId) as String?;
      if (calendarId != null) {
        try {
          final api = await _silentApi();
          if (api == null) {
            problem = 'Could not reach Google to remove the calendar. Delete it in Google Calendar.';
          } else {
            await api.calendars.delete(calendarId);
          }
        } catch (e) {
          if (!_isGone(e)) {
            debugPrint('Could not delete Happaroo calendar: $e');
            problem = 'Could not remove the calendar. Delete it in Google Calendar.';
          }
        }
      }
    }
    try {
      await _ensureInitialized();
      await GoogleSignIn.instance.disconnect();
    } catch (e) {
      debugPrint('Google disconnect: $e');
    }
    _api = null;
    _accessToken = null;
    await _storage.saveSetting(_kConnected, false);
    await _storage.saveSetting(_kAccount, null);
    if (removeCalendar) await _storage.saveSetting(_kCalendarId, null);
    return problem;
  }

  /// Syncs a few seconds after the last change, so a batch of edits is one sync.
  void syncInBackground() {
    if (!isConfigured || !isConnected) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 3), () {
      syncNow().then((r) {
        if (!r.ok) debugPrint('Background calendar sync: ${r.message}');
      });
    });
  }

  /// Makes the Google calendar match Happaroo. Runs one sync at a time.
  Future<CalendarSyncResult> syncNow() {
    final run = _queue.then((_) => _sync(retryOnAuthError: true));
    _queue = run.catchError((Object _) => const CalendarSyncResult());
    return run;
  }

  Future<CalendarSyncResult> _sync({required bool retryOnAuthError}) async {
    if (!isConfigured || !isConnected) {
      return const CalendarSyncResult(error: 'Google Calendar is not connected.');
    }
    final api = await _silentApi();
    if (api == null) return const CalendarSyncResult(needsReconnect: true);

    try {
      final calendarId = await _ensureCalendar(api);
      final typeNames = {for (final t in _storage.getAllCustomEventTypes()) t.id: t.name};
      final local = _storage
          .getAllEvents()
          .map((e) => buildCalendarEntry(e, customTypeName: typeNames[e.customEventTypeId]))
          .toList();
      final remote = await _listManaged(api, calendarId);
      final plan = planSync(local, remote);

      var created = 0, updated = 0, deleted = 0, failed = 0;
      for (final entry in plan.create) {
        try {
          await api.events.insert(_toGoogle(entry), calendarId);
          created++;
        } catch (e) {
          if (_isAuthError(e)) rethrow;
          debugPrint('Calendar insert failed for ${entry.happarooId}: $e');
          failed++;
        }
      }
      for (final change in plan.update.entries) {
        try {
          await api.events.update(_toGoogle(change.value), calendarId, change.key);
          updated++;
        } catch (e) {
          if (_isAuthError(e)) rethrow;
          debugPrint('Calendar update failed for ${change.value.happarooId}: $e');
          failed++;
        }
      }
      for (final remoteId in plan.delete) {
        try {
          await api.events.delete(calendarId, remoteId);
          deleted++;
        } catch (e) {
          if (_isAuthError(e)) rethrow;
          if (_isGone(e)) {
            deleted++;
          } else {
            debugPrint('Calendar delete failed for $remoteId: $e');
            failed++;
          }
        }
      }

      await _storage.saveSetting(_kLastSync, DateTime.now().toUtc().toIso8601String());
      return CalendarSyncResult(created: created, updated: updated, deleted: deleted, failed: failed);
    } catch (e) {
      if (_isAuthError(e) && retryOnAuthError) {
        // Access tokens last about an hour. Drop the cached one and try once more.
        await _dropToken();
        return _sync(retryOnAuthError: false);
      }
      if (_isAuthError(e)) return const CalendarSyncResult(needsReconnect: true);
      debugPrint('Calendar sync failed: $e');
      return const CalendarSyncResult(error: 'Could not sync with Google Calendar. Try again later.');
    }
  }

  /// Calendar client without any UI. Null when the user must reconnect.
  Future<cal.CalendarApi?> _silentApi() async {
    if (_api != null) return _api;
    try {
      await _ensureInitialized();
      final account = await GoogleSignIn.instance.attemptLightweightAuthentication();
      final client = account?.authorizationClient ?? GoogleSignIn.instance.authorizationClient;
      final authorization = await client.authorizationForScopes(scopes);
      if (authorization == null) return null;
      _useAuthorization(authorization);
      return _api;
    } catch (e) {
      debugPrint('Silent Google authorization failed: $e');
      return null;
    }
  }

  void _useAuthorization(GoogleSignInClientAuthorization authorization) {
    _accessToken = authorization.accessToken;
    _api = cal.CalendarApi(authorization.authClient(scopes: scopes));
  }

  Future<void> _dropToken() async {
    final token = _accessToken;
    _api = null;
    _accessToken = null;
    if (token == null) return;
    try {
      await GoogleSignIn.instance.authorizationClient.clearAuthorizationToken(accessToken: token);
    } catch (e) {
      debugPrint('Could not clear Google token: $e');
    }
  }

  /// Returns the Happaroo calendar's id, creating the calendar if it is missing.
  Future<String> _ensureCalendar(cal.CalendarApi api) async {
    final saved = _storage.getSetting(_kCalendarId) as String?;
    if (saved != null) {
      try {
        await api.calendars.get(saved);
        return saved;
      } catch (e) {
        if (_isAuthError(e)) rethrow;
        if (!_isGone(e)) rethrow;
      }
    }

    // After a reinstall the id is gone; reuse the calendar Happaroo made before if Google lists it.
    try {
      String? pageToken;
      do {
        final page = await api.calendarList.list(pageToken: pageToken, minAccessRole: 'owner');
        for (final c in page.items ?? const <cal.CalendarListEntry>[]) {
          if (c.summary == calendarName && c.id != null) {
            await _storage.saveSetting(_kCalendarId, c.id);
            return c.id!;
          }
        }
        pageToken = page.nextPageToken;
      } while (pageToken != null);
    } catch (e) {
      if (_isAuthError(e)) rethrow;
      debugPrint('Calendar list not available with this scope: $e');
    }

    final created = await api.calendars.insert(
      cal.Calendar(
        summary: calendarName,
        description: 'Birthdays and anniversaries from the Happaroo app. Edit them in Happaroo.',
      ),
    );
    await _storage.saveSetting(_kCalendarId, created.id);
    return created.id!;
  }

  Future<List<RemoteEntry>> _listManaged(cal.CalendarApi api, String calendarId) async {
    final result = <RemoteEntry>[];
    String? pageToken;
    do {
      final page = await api.events.list(
        calendarId,
        pageToken: pageToken,
        maxResults: 2500,
        showDeleted: false,
        singleEvents: false,
      );
      for (final item in page.items ?? const <cal.Event>[]) {
        final private = item.extendedProperties?.private;
        final happarooId = private?['happarooId'];
        if (item.id != null && happarooId != null) {
          result.add(RemoteEntry(
            remoteId: item.id!,
            happarooId: happarooId,
            fingerprint: private?['happarooFp'],
          ));
        }
      }
      pageToken = page.nextPageToken;
    } while (pageToken != null);
    return result;
  }

  cal.Event _toGoogle(CalendarEntry entry) {
    return cal.Event(
      summary: entry.title,
      description: entry.description,
      start: cal.EventDateTime(date: entry.start),
      end: cal.EventDateTime(date: entry.endExclusive),
      recurrence: [entry.recurrence],
      // Birthdays should not show you as busy.
      transparency: 'transparent',
      // Happaroo sends its own reminders, so the calendar copy adds none.
      reminders: cal.EventReminders(useDefault: false, overrides: const []),
      extendedProperties: cal.EventExtendedProperties(
        private: {'happarooId': entry.happarooId, 'happarooFp': entry.fingerprint},
      ),
    );
  }

  bool _isAuthError(Object e) => e is cal.DetailedApiRequestError && e.status == 401;

  bool _isGone(Object e) =>
      e is cal.DetailedApiRequestError && (e.status == 404 || e.status == 410);
}
