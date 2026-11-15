// Cloud account and sync (Supabase). The app keeps working offline; when a lifter
// is signed in, changes are uploaded about 20 seconds after they stop editing,
// and when the app goes to the background.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';
import 'store.dart';

const kAppVersion = '2.6.0';

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
      _sub = _db.auth.onAuthStateChange.listen((e) {
        if (e.event == AuthChangeEvent.signedIn || e.event == AuthChangeEvent.initialSession) {
          unawaited(refreshCoach());
        } else if (e.event == AuthChangeEvent.signedOut) {
          _clearCoach();
        }
        notifyListeners();
      });
      store.addListener(_onStoreChanged);
      unawaited(refreshStanding());
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

  /// Downloads the competition percentile tables (public, no sign-in needed).
  Future<bool> refreshStanding() async {
    if (!ready) return false;
    try {
      final rows = await _db.from('competition_percentiles').select();
      final list = [for (final r in rows) Percentiles.fromJson(r)];
      store.setStanding(list);
      return list.isNotEmpty;
    } catch (_) {
      return false;
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
    _clearCoach();
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

  // ======================================================================
  // coach mode
  // ======================================================================

  /// This account coaches (shows the Coach tab).
  bool isCoach = false;
  String? coachCode;

  /// Links where this account is the coach.
  List<CoachLink> athletes = [];

  /// Links where this account is the athlete.
  List<CoachLink> coaches = [];

  /// Programs coaches sent to this account that are waiting for an answer.
  List<ProgramAssignment> inbox = [];

  /// Programs this account sent as a coach (any status).
  List<ProgramAssignment> sent = [];

  /// Comments written by someone else that this account hasn't opened yet.
  List<CoachComment> unread = [];

  bool coachLoading = false;

  String? get myId => user?.id;

  void _clearCoach() {
    isCoach = false;
    coachCode = null;
    athletes = [];
    coaches = [];
    inbox = [];
    sent = [];
    unread = [];
  }

  /// Unread comments on one workout (or on any of one athlete's workouts).
  int unreadFor({String? athleteId, String? programId, String? workoutId}) => unread
      .where((c) =>
          (athleteId == null || c.athleteId == athleteId) &&
          (programId == null || c.programId == programId) &&
          (workoutId == null || c.workoutId == workoutId))
      .length;

  /// Unread comments from coaches on this account's own workouts.
  int get unreadFromCoach => myId == null ? 0 : unreadFor(athleteId: myId);

  /// Reloads coach status, links, programs waiting for an answer and unread comments.
  Future<void> refreshCoach() async {
    final me = myId;
    if (me == null) {
      _clearCoach();
      notifyListeners();
      return;
    }
    coachLoading = true;
    notifyListeners();
    try {
      final prof = await _db.from('profiles').select('is_coach, coach_code').eq('id', me).maybeSingle();
      isCoach = prof?['is_coach'] == true;
      coachCode = prof?['coach_code'] as String?;
      final links = [for (final r in await _db.from('v_coach_links').select()) CoachLink.fromJson(r)];
      athletes = links.where((l) => l.coachId == me).toList()
        ..sort((a, b) => a.athleteName.toLowerCase().compareTo(b.athleteName.toLowerCase()));
      coaches = links.where((l) => l.athleteId == me).toList();
      final asg = [
        for (final r in await _db.from('program_assignments').select().order('created_at', ascending: false))
          ProgramAssignment.fromJson(r)
      ];
      inbox = asg.where((a) => a.athleteId == me && a.status == 'sent').toList();
      sent = asg.where((a) => a.coachId == me).toList();
      unread = [
        for (final r in await _db.from('coach_comments').select().isFilter('read_at', null).neq('author_id', me))
          CoachComment.fromJson(r)
      ];
    } catch (_) {
      // Keep what we had; the coach tables may not be set up yet.
    } finally {
      coachLoading = false;
      notifyListeners();
    }
  }

  String _err(Object e) {
    if (e is PostgrestException) {
      if (e.code == 'PGRST202' || e.code == '42P01') {
        return 'Coach mode is not set up on the server yet. Run supabase/migrations/0006_coach_mode.sql in the Supabase SQL editor.';
      }
      return e.message;
    }
    return 'Could not reach the server. Check your internet connection.';
  }

  /// Turns on coaching. Returns null on success, or a message.
  Future<String?> enableCoaching() async {
    if (!signedIn) return 'Sign in first.';
    try {
      coachCode = '${await _db.rpc('enable_coaching')}';
      isCoach = true;
      notifyListeners();
      unawaited(push());
      return null;
    } catch (e) {
      return _err(e);
    }
  }

  /// Hides the Coach tab. Athletes stay linked; turning coaching back on keeps the same code.
  Future<String?> disableCoaching() async {
    if (!signedIn) return 'Sign in first.';
    try {
      await _db.from('profiles').update({'is_coach': false}).eq('id', myId!);
      isCoach = false;
      notifyListeners();
      return null;
    } catch (e) {
      return _err(e);
    }
  }

  /// Links this athlete to the coach with this code. Returns null on success, or a message.
  Future<String?> connectCoach(String code) async {
    if (!signedIn) return 'Sign in first.';
    final c = code.trim().toUpperCase();
    if (c.length != 6) return 'A coach code has 6 letters and numbers.';
    try {
      await _db.rpc('connect_coach', params: {'code': c});
      // Make sure the coach sees up-to-date data straight away.
      await push();
      await refreshCoach();
      return null;
    } on PostgrestException catch (e) {
      if (e.code == 'P0002') return 'No coach has that code. Check it with your coach.';
      if (e.code == '22023') return 'That is your own coach code.';
      return _err(e);
    } catch (e) {
      return _err(e);
    }
  }

  /// Removes a link (either side can). Returns null on success, or a message.
  Future<String?> removeLink(String linkId) async {
    try {
      await _db.from('coach_links').delete().eq('id', linkId);
      await refreshCoach();
      return null;
    } catch (e) {
      return _err(e);
    }
  }

  /// The athlete's latest synced data, for a coach.
  Future<CloudBackup?> athleteSnapshot(String athleteId) async {
    final row = await _db.from('app_snapshots').select('data, synced_at').eq('user_id', athleteId).maybeSingle();
    if (row == null || row['data'] is! Map) return null;
    return (
      data: Map<String, dynamic>.from(row['data'] as Map),
      syncedAt: DateTime.tryParse('${row['synced_at']}')?.toLocal(),
    );
  }

  /// Comments on one workout, oldest first.
  Future<List<CoachComment>> comments(String athleteId, String programId, String workoutId) async {
    final rows = await _db
        .from('coach_comments')
        .select()
        .eq('athlete_id', athleteId)
        .eq('program_id', programId)
        .eq('workout_id', workoutId)
        .order('created_at', ascending: true);
    return [for (final r in rows) CoachComment.fromJson(r)];
  }

  Future<String?> addComment(String athleteId, String programId, String workoutId, String body) async {
    final text = body.trim();
    if (text.isEmpty) return 'Write something first.';
    try {
      await _db.from('coach_comments').insert({
        'athlete_id': athleteId,
        'author_id': myId,
        'program_id': programId,
        'workout_id': workoutId,
        'body': text,
      });
      return null;
    } catch (e) {
      return _err(e);
    }
  }

  Future<String?> deleteComment(String id) async {
    try {
      await _db.from('coach_comments').delete().eq('id', id);
      return null;
    } catch (e) {
      return _err(e);
    }
  }

  /// Marks other people's comments on this workout as read.
  Future<void> markRead(String athleteId, String programId, String workoutId) async {
    final me = myId;
    if (me == null || unreadFor(athleteId: athleteId, programId: programId, workoutId: workoutId) == 0) return;
    try {
      await _db
          .from('coach_comments')
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('athlete_id', athleteId)
          .eq('program_id', programId)
          .eq('workout_id', workoutId)
          .neq('author_id', me)
          .isFilter('read_at', null);
      unread.removeWhere((c) => c.athleteId == athleteId && c.programId == programId && c.workoutId == workoutId);
      notifyListeners();
    } catch (_) {}
  }

  /// Sends a program (plan only) to a linked athlete.
  Future<String?> sendProgram(String athleteId, Program program, String note) async {
    try {
      await _db.from('program_assignments').insert({
        'coach_id': myId,
        'athlete_id': athleteId,
        'program': program.toJson(),
        'note': note.trim(),
      });
      await refreshCoach();
      return null;
    } catch (e) {
      return _err(e);
    }
  }

  /// Takes back a program the athlete hasn't answered yet.
  Future<String?> withdrawProgram(String assignmentId) async {
    try {
      await _db.from('program_assignments').delete().eq('id', assignmentId);
      await refreshCoach();
      return null;
    } catch (e) {
      return _err(e);
    }
  }

  /// Accepts (adds the program on this phone) or declines a program from a coach.
  Future<String?> answerProgram(ProgramAssignment a, {required bool accept, bool makeActive = true}) async {
    try {
      await _db.from('program_assignments').update({
        'status': accept ? 'accepted' : 'declined',
        'responded_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', a.id);
      if (accept) store.addAssignedProgram(a.program, makeActive: makeActive);
      inbox.removeWhere((x) => x.id == a.id);
      notifyListeners();
      return null;
    } catch (e) {
      return _err(e);
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
