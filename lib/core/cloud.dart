// Cloud account and sync (Supabase). The app keeps working offline; when a lifter
// is signed in, changes are uploaded about 20 seconds after they stop editing,
// and when the app goes to the background.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'store.dart';

const kAppVersion = '2.3.0';

/// The project URL and the public (anon) key. Both are safe to ship in the app:
/// row level security on the server limits every lifter to their own rows.
class CloudConfig {
  static const url = 'https://czjbqrirvxxwmgzwoxdo.supabase.co';
  static const anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN6amJxcmlydnh4d21nendveGRvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTQ3Mjc4OTQsImV4cCI6MjExMDMwMzg5NH0.Gp628Z5MSp749Dsut4q5ZCtCLyT6Z8e2iKuXPFZ7OgI';
}

typedef CloudBackup = ({Map<String, dynamic> data, DateTime? syncedAt});

class CloudSync extends ChangeNotifier {
  final AppStore store;
  CloudSync(this.store);

  bool ready = false;
  bool syncing = false;
  String? lastError;
  DateTime? lastSynced;
  Timer? _debounce;
  StreamSubscription<AuthState>? _sub;

  SupabaseClient get _db => Supabase.instance.client;

  User? get user => ready ? _db.auth.currentUser : null;
  bool get signedIn => user != null;

  Future<void> init() async {
    try {
      await Supabase.initialize(url: CloudConfig.url, anonKey: CloudConfig.anonKey);
      ready = true;
      _sub = _db.auth.onAuthStateChange.listen((_) => notifyListeners());
      store.addListener(_onStoreChanged);
    } catch (e) {
      lastError = 'The cloud is not available right now. Everything still saves on this phone.';
    }
    notifyListeners();
  }

  void _onStoreChanged() {
    if (!signedIn) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 20), push);
  }

  /// Upload now if a change is waiting (called when the app goes to the background).
  Future<void> flush() async {
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
      await push();
    }
  }

  // ---------- account ----------

  /// Returns null on success, or a message to show.
  Future<String?> signUp(String email, String password, String name) async {
    if (!ready) return lastError ?? 'The cloud is not available right now.';
    try {
      final r = await _db.auth.signUp(email: email.trim(), password: password, data: {'name': name.trim()});
      if (r.session == null) {
        return 'Account created. Open the link we emailed to ${email.trim()}, then sign in here.';
      }
      await push();
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not reach the server. Check your internet connection.';
    }
  }

  Future<String?> signIn(String email, String password) async {
    if (!ready) return lastError ?? 'The cloud is not available right now.';
    try {
      await _db.auth.signInWithPassword(email: email.trim(), password: password);
      notifyListeners();
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not reach the server. Check your internet connection.';
    }
  }

  Future<String?> resetPassword(String email) async {
    if (!ready) return lastError;
    try {
      await _db.auth.resetPasswordForEmail(email.trim());
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not reach the server. Check your internet connection.';
    }
  }

  /// Signs out. The data on this phone stays.
  Future<void> signOut() async {
    _debounce?.cancel();
    if (ready) await _db.auth.signOut();
    lastSynced = null;
    notifyListeners();
  }

  // ---------- sync ----------

  /// Uploads everything on this phone. Returns true when it worked.
  Future<bool> push() async {
    if (!signedIn || syncing) return false;
    syncing = true;
    lastError = null;
    notifyListeners();
    try {
      final res = await _db.rpc('sync_snapshot', params: {'payload': store.toJson(), 'app_version': kAppVersion});
      lastSynced = DateTime.tryParse('$res')?.toLocal() ?? DateTime.now();
      return true;
    } on PostgrestException catch (e) {
      lastError = e.code == 'PGRST202'
          ? 'Sync is not set up on the server yet. Run supabase/migrations/0003_sync_snapshot.sql in the Supabase SQL editor.'
          : 'Sync failed: ${e.message}';
      return false;
    } catch (_) {
      lastError = 'Sync failed. Check your internet connection; it will retry after your next change.';
      return false;
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  /// The backup stored in the cloud for this account, if any.
  Future<CloudBackup?> fetchBackup() async {
    if (!signedIn) return null;
    final row = await _db.from('app_snapshots').select('data, synced_at').maybeSingle();
    if (row == null || row['data'] is! Map) return null;
    return (
      data: Map<String, dynamic>.from(row['data'] as Map),
      syncedAt: DateTime.tryParse('${row['synced_at']}')?.toLocal(),
    );
  }

  /// Replaces this phone's data with the cloud backup. Returns null on success.
  Future<String?> restore() async {
    try {
      final b = await fetchBackup();
      if (b == null) return 'There is no cloud backup for this account yet.';
      final ok = store.importJson(jsonEncode(b.data));
      if (!ok) return 'The cloud backup could not be read.';
      lastSynced = b.syncedAt;
      _debounce?.cancel();
      notifyListeners();
      return null;
    } catch (_) {
      return 'Could not reach the server. Check your internet connection.';
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _sub?.cancel();
    store.removeListener(_onStoreChanged);
    super.dispose();
  }
}

class CloudScope extends InheritedNotifier<CloudSync> {
  const CloudScope({super.key, required CloudSync cloud, required super.child}) : super(notifier: cloud);

  static CloudSync of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<CloudScope>()!.notifier!;

  static CloudSync read(BuildContext context) => context.getInheritedWidgetOfExactType<CloudScope>()!.notifier!;
}
