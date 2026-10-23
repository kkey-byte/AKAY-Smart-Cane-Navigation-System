import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/app_session_service.dart';
import '../../services/breadcrumb_service.dart';

/// Uses the existing server-enforced breadcrumb sharing indexes, not device pairing.
class AuthorizedUsersCard extends StatelessWidget {
  const AuthorizedUsersCard({super.key, required this.caregiver});
  final bool caregiver;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: AppSessionService.instance,
    builder: (context, _) {
      if (!AppSessionService.instance.isLoggedIn) {
        return const Text('Sign in to view shared users.');
      }
      return StreamBuilder<User?>(
        key: ValueKey(AppSessionService.instance.identityRevision),
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, auth) {
          final uid = auth.data?.uid;
          if (uid == null) {
            return const Text('Waiting for authenticated account.');
          }
          return _SharedUsers(
            key: ValueKey('$uid:$caregiver'),
            uid: uid,
            caregiver: caregiver,
          );
        },
      );
    },
  );
}

class _SharedUsers extends StatefulWidget {
  const _SharedUsers({super.key, required this.uid, required this.caregiver});
  final String uid;
  final bool caregiver;
  @override
  State<_SharedUsers> createState() => _SharedUsersState();
}

class _SharedUsersState extends State<_SharedUsers> {
  late Stream<Map<String, String>> _stream;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final repository = BreadcrumbService.instance.repository;
    _stream = widget.caregiver
        ? repository.watchLinks(widget.uid)
        : repository.watchShares(widget.uid);
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<Map<String, String>>(
    stream: _stream,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Column(
          children: [
            const Text(
              'Unable to load shared users. Check connection or sharing access.',
            ),
            TextButton(
              onPressed: () => setState(_reload),
              child: const Text('Retry'),
            ),
          ],
        );
      }
      if (snapshot.connectionState == ConnectionState.waiting) {
        return Semantics(
          label: 'Loading shared users',
          child: LinearProgressIndicator(),
        );
      }
      final users = snapshot.data ?? {};
      if (users.isEmpty) {
        return const Text(
          'No shared users. Manage sharing in Breadcrumb tracks.',
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.caregiver
                ? 'Shared navigators'
                : 'Caregivers with track access',
          ),
          for (final name in users.values)
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(name.trim().isEmpty ? 'Name unavailable' : name),
              subtitle: const Text('Track access • Device status unavailable'),
            ),
        ],
      );
    },
  );
}
