// Account: sign in or create an account, see sync status, restore from the cloud, sign out.
import 'package:flutter/material.dart';

import '../../core/cloud.dart';
import '../../core/store.dart';
import '../theme.dart';
import '../widgets.dart';
import '../../l10n/l10n.dart';

String timeAgo(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inSeconds < 60) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  return '${d.inDays} d ago';
}

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool creating = false;
  bool busy = false;
  bool hide = true;
  String? message;
  final email = TextEditingController();
  final password = TextEditingController();
  final name = TextEditingController();

  @override
  void initState() {
    super.initState();
    name.text = StoreScope.read(context).profile.name;
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final cloud = CloudScope.read(context);
    FocusScope.of(context).unfocus();
    if (!email.text.contains('@') || password.text.length < 6) {
      setState(() => message = 'Enter your email and a password of at least 6 characters.');
      return;
    }
    setState(() {
      busy = true;
      message = null;
    });
    final err = creating
        ? await cloud.signUp(email.text, password.text, name.text)
        : await cloud.signIn(email.text, password.text);
    if (!mounted) return;
    setState(() {
      busy = false;
      message = err;
    });
    if (err == null && !creating) await _afterSignIn(cloud);
  }

  /// On sign-in, decide between the cloud backup and the data on this phone.
  Future<void> _afterSignIn(CloudSync cloud) async {
    CloudBackup? backup;
    try {
      backup = await cloud.fetchBackup();
    } catch (_) {
      backup = null;
    }
    if (!mounted) return;
    if (backup == null) {
      await cloud.push();
      if (mounted) toast(context, 'Signed in. This phone\'s data is now backed up.');
      return;
    }
    final when = backup.syncedAt == null ? 'earlier' : timeAgo(backup.syncedAt!);
    final useCloud = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const T('You have a cloud backup'),
        content: Text('Your account was last synced $when. Which data do you want to keep?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const T('Keep this phone\'s data')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const T('Use the cloud backup')),
        ],
      ),
    );
    if (useCloud == true) {
      final err = await cloud.restore();
      if (mounted) toast(context, err ?? 'Cloud backup restored on this phone.');
    } else {
      final ok = await cloud.push();
      if (mounted) toast(context, ok ? 'This phone\'s data was uploaded.' : (cloud.lastError ?? 'Sync failed.'));
    }
  }

  Future<void> _forgot() async {
    final cloud = CloudScope.read(context);
    if (!email.text.contains('@')) {
      setState(() => message = 'Enter your email first.');
      return;
    }
    final err = await cloud.resetPassword(email.text);
    if (mounted) setState(() => message = err ?? 'We emailed a link to reset your password.');
  }

  @override
  Widget build(BuildContext context) {
    final cloud = CloudScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const T('Account')),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [cloud.signedIn ? _signedIn(context, cloud) : _signedOut(context, cloud)],
        ),
      ),
    );
  }

  Widget _signedOut(BuildContext context, CloudSync cloud) {
    final p = Palette.of(context);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(creating ? 'CREATE ACCOUNT' : 'SIGN IN', style: headingStyle(context, size: 20)),
          const SizedBox(height: 4),
          Text(
            'An account backs up your programs, logs and body data, and moves them to a new phone. '
            'The app works the same without one.',
            style: TextStyle(color: p.muted, fontSize: 13),
          ),
          const SizedBox(height: 14),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: T('Sign in')),
              ButtonSegment(value: true, label: T('Create account')),
            ],
            selected: {creating},
            onSelectionChanged: (s) => setState(() {
              creating = s.first;
              message = null;
            }),
          ),
          const SizedBox(height: 12),
          if (creating) ...[
            TextField(
              controller: name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(label: T('Name')),
            ),
            const SizedBox(height: 10),
          ],
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(label: T('Email')),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: password,
            obscureText: hide,
            decoration: InputDecoration(
              label: T('Password'),
              helperText: creating ? 'At least 6 characters' : null,
              suffixIcon: IconButton(
                tooltip: hide ? 'Show password' : 'Hide password',
                icon: Icon(hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => hide = !hide),
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
          if (message != null) ...[
            const SizedBox(height: 10),
            Text(message!, style: TextStyle(color: p.warn, fontWeight: FontWeight.w600, fontSize: 13)),
          ],
          const SizedBox(height: 14),
          FilledButton(
            onPressed: busy ? null : _submit,
            child: busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(creating ? 'Create account' : 'Sign in'),
          ),
          if (!creating)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(onPressed: _forgot, child: const T('Forgot password?')),
            ),
        ],
      ),
    );
  }

  Widget _signedIn(BuildContext context, CloudSync cloud) {
    final p = Palette.of(context);
    final status = cloud.syncing
        ? 'Syncing…'
        : (cloud.lastSynced == null ? 'Not synced on this phone yet' : 'Last synced ${timeAgo(cloud.lastSynced!)}');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              T('SIGNED IN', style: eyebrowStyle(context)),
              const SizedBox(height: 4),
              Text(cloud.user?.email ?? '', style: headingStyle(context, size: 18)),
              const SizedBox(height: 8),
              Row(children: [
                Icon(cloud.lastError == null ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                    size: 18, color: cloud.lastError == null ? p.ok : p.warn),
                const SizedBox(width: 6),
                Expanded(child: Text(status, style: const TextStyle(fontWeight: FontWeight.w600))),
              ]),
              if (cloud.lastError != null) ...[
                const SizedBox(height: 6),
                Text(cloud.lastError!, style: TextStyle(color: p.warn, fontSize: 13)),
              ],
              const SizedBox(height: 6),
              T('Changes upload about 20 seconds after you stop editing, and when you leave the app.',
                  style: TextStyle(color: p.muted, fontSize: 12.5)),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                FilledButton.icon(
                  icon: const Icon(Icons.sync, size: 18),
                  label: const T('Sync now'),
                  onPressed: cloud.syncing
                      ? null
                      : () async {
                          final ok = await cloud.push();
                          if (context.mounted) toast(context, ok ? 'Synced.' : (cloud.lastError ?? 'Sync failed.'));
                        },
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.cloud_download_outlined, size: 18),
                  label: const T('Restore from cloud'),
                  onPressed: () async {
                    final ok = await confirmDialog(context,
                        title: 'Restore from the cloud?',
                        body: 'The data on this phone is replaced with your last cloud backup.',
                        action: 'Restore',
                        danger: true);
                    if (!ok) return;
                    final err = await cloud.restore();
                    if (context.mounted) toast(context, err ?? 'Cloud backup restored.');
                  },
                ),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () async {
            final ok = await confirmDialog(context,
                title: 'Sign out?',
                body: 'Your data stays on this phone. Sign in again any time to keep syncing.',
                action: 'Sign out');
            if (!ok) return;
            await cloud.flush();
            await cloud.signOut();
          },
          child: const T('Sign out'),
        ),
      ],
    );
  }
}
