import '../../theme/gabay_typography.dart';
import '../../widgets/shared/gabay_glass_surface.dart';
import '../../widgets/shared/gabay_accent_icon.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../models/pairing.dart';
import '../../services/app_session_service.dart';
import '../../services/pairing_service.dart';
import '../../theme/gabay_theme.dart';
import '../../widgets/shared/gabay_detail_page_scaffold.dart';
import '../../widgets/shared/dashboard_pairing_card.dart';

class LinkedNavigatorCanePage extends StatefulWidget {
  const LinkedNavigatorCanePage({super.key, this.service});
  final PairingService? service;
  @override
  State<LinkedNavigatorCanePage> createState() =>
      _LinkedNavigatorCanePageState();
}

class _LinkedNavigatorCanePageState extends State<LinkedNavigatorCanePage> {
  late final PairingService _service;
  late final int _revision;
  StreamSubscription<List<PairingConnection>>? _subscription;
  List<PairingConnection>? _rows;
  String? _error, _removing;
  bool get _valid => _revision == AppSessionService.instance.identityRevision;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? PairingService.instance;
    _revision = AppSessionService.instance.identityRevision;
    AppSessionService.instance.addListener(_accountChanged);
    _listen();
  }

  void _accountChanged() {
    if (_valid) return;
    unawaited(_subscription?.cancel());
    if (mounted) {
      setState(() {
        _rows = null;
        _error = 'Account changed. Reopen this page.';
      });
    }
  }

  Completer<void>? _refreshing;
  Future<void> _refresh() {
    if (_refreshing != null) return _refreshing!.future;
    if (!_valid || _removing != null) return Future.value();
    final pending = _refreshing = Completer<void>();
    _listen();
    return pending.future
        .timeout(const Duration(seconds: 25), onTimeout: () {})
        .whenComplete(() {
          if (identical(_refreshing, pending)) _refreshing = null;
        });
  }

  Future<void> _listen() async {
    if (!_valid) return;
    await _subscription?.cancel();
    if (!mounted || !_valid) return;
    setState(() {
      _error = null;
      if (_refreshing == null) _rows = null;
    });
    _subscription = _service.watchConnections().listen(
      (rows) {
        if (_refreshing?.isCompleted == false) _refreshing!.complete();
        if (!mounted || !_valid) return;
        setState(() {
          _rows = rows
              .where((row) => row.status == 'active' || row.status == 'pending')
              .toList();
          _error = null;
        });
      },
      onError: (Object error) {
        if (_refreshing?.isCompleted == false) _refreshing!.complete();
        if (!mounted || !_valid) return;
        setState(() {
          if (_refreshing == null) _rows = null;
          _error = 'Could not load linked navigators. Please try again.';
        });
      },
    );
  }

  Future<void> _remove(PairingConnection row) async {
    if (!_valid || _removing != null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove linked navigator?'),
        content: Text(
          'Disconnect from ${row.navigatorName}? Your monitoring access will end. Their account and saved information will remain.',
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: GabayTheme.destructiveButtonStyle(context),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || !_valid || _removing != null) return;
    setState(() => _removing = row.id);
    try {
      await _service.revoke(row.id);
      if (!mounted || !_valid) return;
      setState(() => _rows?.removeWhere((item) => item.id == row.id));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Navigator disconnected.')));
    } catch (_) {
      if (mounted && _valid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not remove this connection. Please try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _removing = null);
    }
  }

  @override
  void dispose() {
    AppSessionService.instance.removeListener(_accountChanged);
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;
    final rows = _rows;
    return GabayDetailPageScaffold(
      title: 'Linked Navigator',
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            if (rows != null && rows.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your connections',
                            style: TextStyle(
                              color: g.textPrimary,
                              fontSize: GabayTypography.cardTitle,
                              fontWeight: GabayTypography.semibold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Manage your linked navigators.',
                            style: TextStyle(
                              color: g.textSecondary,
                              fontSize: GabayTypography.caption,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: g.accentTint,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        '${rows.length}',
                        style: TextStyle(
                          color: g.accent,
                          fontSize: GabayTypography.cardTitle,
                          fontWeight: GabayTypography.semibold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_error != null)
              GabayContentCard(
                child: Column(
                  children: [
                    Icon(
                      Icons.cloud_off_rounded,
                      color: g.textSecondary,
                      size: 28,
                    ),
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: g.textSecondary,
                          fontSize: GabayTypography.body,
                        ),
                      ),
                    ),
                    if (_valid)
                      TextButton(
                        onPressed: _listen,
                        child: const Text('Retry'),
                      ),
                  ],
                ),
              )
            else if (rows == null)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: CircularProgressIndicator(
                    semanticsLabel: 'Loading linked navigators',
                  ),
                ),
              )
            else if (rows.isEmpty)
              GabayGlassSurface(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  child: Column(
                    children: [
                      GabayAccentIcon(
                        Icons.people_outline_rounded,
                        size: 44,
                        color: g.accent,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No linked navigators yet',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: g.textPrimary,
                          fontSize: GabayTypography.sectionTitle,
                          fontWeight: GabayTypography.semibold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pair with a navigator using their code or QR to see them here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: g.textSecondary,
                          fontSize: GabayTypography.supporting,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              for (final row in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _navigatorCard(row),
                ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'Add a navigator',
                style: TextStyle(
                  color: g.textPrimary,
                  fontSize: GabayTypography.cardTitle,
                  fontWeight: GabayTypography.semibold,
                ),
              ),
            ),
            DashboardPairingCard(
              caregiver: true,
              pairingOnly: true,
              service: _service,
            ),
          ],
        ),
      ),
    );
  }

  Widget _navigatorCard(PairingConnection row) {
    final g = context.gabay;
    final connected = row.status == 'active';
    final statusColor = connected ? g.success : g.warning;
    return GabayGlassSurface(
      radius: 24,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _NavigatorAvatar(
                  name: row.navigatorName,
                  picture: row.navigatorPicture,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.navigatorName,
                        style: TextStyle(
                          color: g.textPrimary,
                          fontSize: GabayTypography.cardTitle,
                          fontWeight: GabayTypography.semibold,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Navigator',
                        style: TextStyle(
                          color: g.textSecondary,
                          fontSize: GabayTypography.caption,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        'User ID: ${row.navigatorUserId ?? row.navigatorUid}',
                        style: TextStyle(
                          color: g.textSecondary,
                          fontSize: GabayTypography.caption,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                if (_removing == row.id)
                  const SizedBox(
                    width: 48,
                    height: 48,
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          semanticsLabel: 'Removing connection',
                        ),
                      ),
                    ),
                  )
                else
                  IconButton(
                    tooltip: 'Remove ${row.navigatorName}',
                    onPressed: _removing != null || !_valid
                        ? null
                        : () => _remove(row),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      foregroundColor: g.danger,
                      backgroundColor: g.danger.withValues(alpha: .08),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 21),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text.rich(
                TextSpan(
                  children: [
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Icon(
                        connected
                            ? Icons.check_circle_outline_rounded
                            : Icons.schedule_rounded,
                        color: statusColor,
                        size: 15,
                      ),
                    ),
                    TextSpan(
                      text: connected ? ' Connected' : ' Pending approval',
                      style: TextStyle(
                        color: g.textPrimary,
                        fontSize: GabayTypography.caption,
                        fontWeight: GabayTypography.medium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavigatorAvatar extends StatelessWidget {
  const _NavigatorAvatar({required this.name, this.picture});
  final String name;
  final String? picture;
  @override
  Widget build(BuildContext context) {
    final g = context.gabay;
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .take(2);
    final initials = words
        .map((word) => word.characters.first)
        .join()
        .toUpperCase();
    final fallback = Center(
      child: Text(
        initials,
        style: TextStyle(
          color: g.accent,
          fontSize: 21,
          fontWeight: GabayTypography.medium,
        ),
      ),
    );
    Widget photo = fallback;
    if (picture?.isNotEmpty == true) {
      try {
        if (picture!.startsWith('data:image/')) {
          photo = Image.memory(
            base64Decode(picture!.split(',').last),
            fit: BoxFit.cover,
            errorBuilder: (_, error, stack) => fallback,
          );
        } else if (Uri.tryParse(picture!)?.scheme == 'https') {
          photo = Image.network(
            picture!,
            fit: BoxFit.cover,
            errorBuilder: (_, error, stack) => fallback,
          );
        }
      } catch (_) {
        photo = fallback;
      }
    }
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 54,
          height: 58,
          color: g.accentTint,
          child: photo,
        ),
      ),
    );
  }
}
