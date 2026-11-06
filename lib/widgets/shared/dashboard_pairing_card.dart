import '../../theme/gabay_typography.dart';
import 'gabay_accent_icon.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/pairing.dart';
import '../../models/pairing_code.dart';
import '../../pages/shared/pairing_management_page.dart';
import '../../pages/shared/pairing_scanner_page.dart';
import '../../services/app_session_service.dart';
import '../../services/gabay_tts_service.dart';
import '../../services/pairing_service.dart';
import '../../theme/gabay_theme.dart';
import 'gabay_card.dart';
import 'pairing_qr_image.dart';

class DashboardPairingCard extends StatefulWidget {
  const DashboardPairingCard({
    super.key,
    required this.caregiver,
    this.profilePresentation = false,
    this.service,
    this.scanCode,
    this.uploadCode,
    this.pairingOnly = false,
    this.showManageConnections = true,
    this.allowDisconnect = false,
  });
  final bool caregiver;
  final bool profilePresentation;
  final bool pairingOnly;
  final bool showManageConnections, allowDisconnect;
  final PairingService? service;
  final Future<String?> Function(BuildContext)? scanCode;
  final Future<String?> Function()? uploadCode;
  @override
  State<DashboardPairingCard> createState() => DashboardPairingCardState();
}

class DashboardPairingCardState extends State<DashboardPairingCard> {
  late final PairingService _service;
  late final int _revision;
  StreamSubscription<List<PairingConnection>>? _subscription;
  Timer? _clock;
  List<PairingConnection>? _rows;
  Map<String, String> _statuses = {};
  String? _code, _error, _notice;
  DateTime? _expires;
  bool _busy = false;
  bool _authorized = false;
  String _method = 'alphanumeric';
  bool get _valid => _revision == AppSessionService.instance.identityRevision;
  String get profileTitle => widget.profilePresentation
      ? 'Caregiver Connections'
      : 'Connect with a Caregiver';
  bool get _expired => _expires == null || !DateTime.now().isBefore(_expires!);
  @override
  void initState() {
    super.initState();
    _service = widget.service ?? PairingService.instance;
    _revision = AppSessionService.instance.identityRevision;
    AppSessionService.instance.addListener(_accountChanged);
    _listen();
    _clock = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && _code != null) setState(() {});
    });
  }

  void _accountChanged() {
    if (!_valid) {
      unawaited(_subscription?.cancel());
      if (mounted) {
        setState(() {
          _rows = null;
          _code = null;
          _notice = null;
          _error = 'Account changed. Reopen this page.';
        });
      }
    }
  }

  Completer<void>? _refresh;
  Future<void> refresh() {
    if (_refresh != null) return _refresh!.future;
    if (!_valid || _busy) return Future.value();
    final pending = _refresh = Completer<void>();
    _listen();
    return pending.future
        .timeout(const Duration(seconds: 25), onTimeout: () {})
        .whenComplete(() {
          if (identical(_refresh, pending)) _refresh = null;
        });
  }

  Future<void> _listen() async {
    await _subscription?.cancel();
    if (!mounted || !_valid) return;
    _subscription = _service.watchConnections().listen(
      _received,
      onError: (Object error) {
        if (_refresh?.isCompleted == false) _refresh!.complete();
        if (mounted && _valid) {
          setState(() {
            _error = error.toString();
          });
        }
      },
    );
  }

  void _received(List<PairingConnection> rows) {
    if (_refresh?.isCompleted == false) _refresh!.complete();
    if (!mounted || !_valid) return;
    String? paired;
    if (_rows != null) {
      for (final row in rows) {
        if (row.status == 'active' && _statuses[row.id] != 'active') {
          paired =
              'Successfully paired with ${widget.caregiver ? row.navigatorName : row.caregiverName}';
        }
      }
    }
    setState(() {
      _rows = rows;
      _statuses = {for (final row in rows) row.id: row.status};
      _error = null;
      if (paired != null) {
        _notice = paired;
        _code = null;
      }
    });
    if (paired != null && ModalRoute.of(context)?.isCurrent == true) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(paired)));
    }
  }

  @override
  void dispose() {
    AppSessionService.instance.removeListener(_accountChanged);
    unawaited(_subscription?.cancel());
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy || !_valid) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted && _valid) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _generate() => _run(() async {
    final result = await _service.generatePairing(_method);
    if (!mounted || !_valid) return;
    final code = parsePairingCode(result['code']?.toString() ?? '');
    final expires = DateTime.tryParse(result['expires_at']?.toString() ?? '');
    if (code == null || expires == null) {
      throw StateError(
        'Pairing code unavailable. Update the backend and try again.',
      );
    }
    setState(() {
      _code = code;
      _expires = expires;
      _notice = null;
    });
  });
  Future<void> _disconnect(PairingConnection row) async {
    if (_busy || !_valid) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect caregiver?'),
        content: Text(
          'Remove monitoring access for ${row.caregiverName}? Your account, saved tracks and cane ownership will remain.',
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: GabayTheme.destructiveButtonStyle(context),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || !_valid) return;
    await _run(() async {
      await _service.revoke(row.id);
      if (!mounted || !_valid) return;
      setState(() => _rows?.removeWhere((item) => item.id == row.id));
    });
  }

  Future<void> _pair() async {
    final submission = await showDialog<_PairSubmission>(
      context: context,
      builder: (_) => _PairCodeDialog(
        scanCode: widget.scanCode,
        uploadCode: widget.uploadCode,
      ),
    );
    if (submission == null || !mounted || !_valid) return;
    await _run(() async {
      await _service.redeemPairing(submission.code, submission.method);
      if (!mounted || !_valid) return;
      setState(
        () => _notice = 'Pairing completed. Updating connected Navigators…',
      );
      _received(await _service.connections());
    });
  }

  Future<void> _decide(PairingConnection row, bool accept) async {
    if (accept) {
      final approved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Pair with ${row.caregiverName}?'),
          content: const Text(
            'This caregiver can view your profile, location history, cane readings and alerts until you remove access. You can remove access at any time.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Allow caregiver'),
            ),
          ],
        ),
      );
      if (approved != true || !mounted) return;
    }
    await _run(() async {
      await _service.decide(row.id, accept);
      _received(await _service.connections());
    });
  }

  @override
  Widget build(BuildContext context) {
    final visible = (_rows ?? [])
        .where((row) => row.status == 'active' || row.status == 'pending')
        .toList();
    final pairingControls = <Widget>[
      const SizedBox(height: 8),
      Text(
        widget.caregiver
            ? 'Add a Navigator using the code or QR they authorize. Access starts when the code is accepted.'
            : 'Choose code or QR. Only share it with the caregiver you want to authorize.',
      ),
      if (!widget.caregiver) ...[
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Alphanumeric code'),
              labelStyle: TextStyle(
                fontSize: GabayTypography.caption,
                fontWeight: GabayTypography.regular,
                color: context.gabay.textPrimary,
              ),
              selectedColor: context.gabay.accentTint,
              checkmarkColor: context.gabay.accent,
              selected: _method == 'alphanumeric',
              onSelected: _busy
                  ? null
                  : (_) => setState(() => _method = 'alphanumeric'),
            ),
            ChoiceChip(
              label: const Text('QR code'),
              labelStyle: TextStyle(
                fontSize: GabayTypography.caption,
                fontWeight: GabayTypography.regular,
                color: context.gabay.textPrimary,
              ),
              selectedColor: context.gabay.accentTint,
              checkmarkColor: context.gabay.accent,
              selected: _method == 'qr_code',
              onSelected: _busy
                  ? null
                  : (_) => setState(() => _method = 'qr_code'),
            ),
          ],
        ),
        Material(
          color: Colors.transparent,
          child: CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _authorized,
            onChanged: _busy
                ? null
                : (value) => setState(() => _authorized = value ?? false),
            title: const Text(
              'I authorize the caregiver who uses this code to view my profile, location history, cane readings and alerts until I remove access.',
              style: TextStyle(
                fontSize: GabayTypography.supporting,
                fontWeight: GabayTypography.regular,
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
      const SizedBox(height: 12),
      FilledButton.icon(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 44),
          iconSize: 18,
          textStyle: const TextStyle(
            fontSize: GabayTypography.supporting,
            fontWeight: GabayTypography.regular,
          ),
        ),
        onPressed: _busy || !_valid || (!widget.caregiver && !_authorized)
            ? null
            : widget.caregiver
            ? _pair
            : _generate,
        icon: GabayAccentIcon(
          widget.caregiver ? Icons.person_add_alt_1 : Icons.qr_code,
        ),
        label: Text(
          widget.caregiver
              ? 'Add / Pair New Navigator'
              : _code == null
              ? 'Show my pairing code'
              : 'Create a new code',
        ),
      ),
      if (_busy)
        const LinearProgressIndicator(semanticsLabel: 'Updating pairing'),
      if (_code != null && !_expired && _valid) ...[
        const SizedBox(height: 12),
        if (_method == 'alphanumeric')
          Semantics(
            label: 'Pairing code ${_code!.split('').join(' ')}',
            excludeSemantics: true,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              decoration: BoxDecoration(
                color: context.gabay.accentTint,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _code!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.gabay.heading,
                  fontSize: GabayTypography.hero,
                  fontWeight: GabayTypography.medium,
                  letterSpacing: 4,
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),
        if (_method == 'qr_code')
          Center(
            child: Semantics(
              label:
                  'QR for this pairing code. Caregiver: use Scan QR in AKAY.',
              excludeSemantics: true,
              image: true,
              child: QrImageView(
                data: 'akay://pair?code=$_code',
                size: 200,
                backgroundColor: Colors.white,
              ),
            ),
          ),
        Text(
          'Expires in ${_expires!.difference(DateTime.now()).inMinutes + 1} minute(s). One use only. Whoever uses it receives access immediately.',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => _run(() async {
                await Clipboard.setData(ClipboardData(text: _code!));
                if (mounted && _valid) {
                  setState(() => _notice = 'Pairing code copied.');
                }
              }),
              icon: const GabayAccentIcon(Icons.copy),
              label: const Text('Copy code'),
            ),
            OutlinedButton.icon(
              onPressed: () => _run(
                () => GabayTtsService.instance.speak(
                  'Your pairing code is ${_code!.split('').join(', ')}',
                ),
              ),
              icon: const GabayAccentIcon(Icons.volume_up),
              label: const Text('Read code aloud'),
            ),
          ],
        ),
      ],
      if (_code != null && _expired)
        const Text('Code expired. Create a new code to pair.'),
    ];
    return GabayCard(
      padding: const EdgeInsets.all(20),
      decoration: widget.profilePresentation
          ? GabayTheme.cardDecoration(context).copyWith(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  context.gabay.surface,
                  Color.alphaBlend(
                    context.gabay.accent.withValues(alpha: .06),
                    context.gabay.surface,
                  ),
                ],
              ),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.caregiver ? 'Your Navigators' : profileTitle,
            style: TextStyle(
              color: context.gabay.textPrimary,
              fontSize: GabayTypography.sectionTitle,
              fontWeight: GabayTypography.semibold,
            ),
          ),
          if (widget.profilePresentation)
            Material(
              color: Colors.transparent,
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(vertical: 8),
                shape: const Border(),
                collapsedShape: const Border(),
                leading: CircleAvatar(
                  backgroundColor: context.gabay.accentTint,
                  child: GabayAccentIcon(
                    Icons.person_add_alt_outlined,
                    color: context.gabay.accent,
                  ),
                ),
                title: Text(
                  'Invite a Caregiver',
                  style: TextStyle(
                    color: context.gabay.accent,
                    fontWeight: GabayTypography.regular,
                    fontSize: GabayTypography.body,
                  ),
                ),
                subtitle: const Text(
                  'Share your pairing code or QR.',
                  style: TextStyle(
                    fontSize: GabayTypography.caption,
                    fontWeight: GabayTypography.regular,
                  ),
                ),
                children: pairingControls,
              ),
            )
          else
            ...pairingControls,
          if (_notice != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _notice!,
                  style: const TextStyle(fontWeight: GabayTypography.regular),
                ),
              ),
            ),
          if (_error != null) ...[
            Semantics(
              liveRegion: true,
              child: Text(
                _error!,
                style: TextStyle(color: context.gabay.danger),
              ),
            ),
            TextButton(
              onPressed: _valid ? _listen : null,
              child: const Text('Retry connections'),
            ),
          ],
          if (_rows == null && _error == null)
            const Text('Loading connections…'),
          if (!widget.pairingOnly && _rows != null && visible.isEmpty)
            const Text('No paired accounts yet.'),
          for (final row
              in widget.pairingOnly ? <PairingConnection>[] : visible)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: context.gabay.border),
                  color: context.gabay.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: context.gabay.shadow,
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 23,
                            backgroundColor: context.gabay.accentTint,
                            child: GabayAccentIcon(
                              Icons.person_outline,
                              color: context.gabay.accent,
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.caregiver
                                      ? row.navigatorName
                                      : row.caregiverName,
                                  style: TextStyle(
                                    color: context.gabay.textPrimary,
                                    fontSize: GabayTypography.cardBody,
                                    fontWeight: GabayTypography.medium,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  row.status == 'active'
                                      ? 'Paired'
                                      : widget.caregiver
                                      ? 'Awaiting Navigator approval'
                                      : 'Approval needed',
                                  style: TextStyle(
                                    color: row.status == 'active'
                                        ? context.gabay.success
                                        : context.gabay.textSecondary,
                                    fontSize: GabayTypography.caption,
                                    fontWeight: GabayTypography.regular,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (widget.allowDisconnect && !widget.caregiver)
                            IconButton(
                              tooltip: 'Disconnect ${row.caregiverName}',
                              onPressed: _busy ? null : () => _disconnect(row),
                              icon: GabayAccentIcon(
                                Icons.link_off_rounded,
                                color: context.gabay.danger,
                                size: 22,
                              ),
                            ),
                        ],
                      ),
                      if (row.status == 'pending' && !widget.caregiver)
                        Wrap(
                          spacing: 8,
                          children: [
                            FilledButton(
                              onPressed: _busy
                                  ? null
                                  : () => _decide(row, true),
                              child: const Text('Review and allow'),
                            ),
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _decide(row, false),
                              child: const Text('Decline'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          if (widget.profilePresentation) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.gabay.accentTint,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  GabayAccentIcon(
                    Icons.verified_user_outlined,
                    color: context.gabay.accent,
                    size: 30,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Why add caregivers?',
                          style: TextStyle(
                            color: context.gabay.accent,
                            fontWeight: GabayTypography.regular,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Caregivers can monitor your location and help you during emergencies.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (widget.showManageConnections)
            TextButton(
              onPressed: !_valid
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PairingManagementPage(
                          caregiver: widget.caregiver,
                          service: _service,
                        ),
                      ),
                    ),
              child: const Text('Manage connections and access'),
            ),
        ],
      ),
    );
  }
}

class _PairSubmission {
  const _PairSubmission(this.code, this.method);
  final String code, method;
}

class _PairCodeDialog extends StatefulWidget {
  const _PairCodeDialog({this.scanCode, this.uploadCode});
  final Future<String?> Function(BuildContext)? scanCode;
  final Future<String?> Function()? uploadCode;
  @override
  State<_PairCodeDialog> createState() => _PairCodeDialogState();
}

class _PairCodeDialogState extends State<_PairCodeDialog> {
  final _input = TextEditingController();
  String? _error;
  bool _readingImage = false;
  String? _imageError;
  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _submit(String value, {String method = 'alphanumeric'}) {
    final code = parsePairingCode(value);
    if (code == null) {
      setState(
        () => _error = 'Enter the six-character code shown by the Navigator.',
      );
      return;
    }
    Navigator.pop(context, _PairSubmission(code, method));
  }

  Future<void> _upload() async {
    if (_readingImage) return;
    setState(() {
      _readingImage = true;
      _imageError = null;
    });
    try {
      final code = await (widget.uploadCode ?? pickPairingQrImage)();
      if (mounted && code != null) _submit(code, method: 'qr_code');
    } catch (error) {
      if (mounted) {
        setState(
          () => _imageError = error is FormatException
              ? error.message
              : error is UnsupportedError
              ? error.message
              : 'Could not read the QR image. Try a clear image, check your connection, or enter the pairing code.',
        );
      }
    } finally {
      if (mounted) setState(() => _readingImage = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Pair a Navigator'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Ask the Navigator to show their pairing code or QR in Profile → Caregivers.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _input,
            enabled: !_readingImage,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            enableSuggestions: false,
            maxLength: 6,
            decoration: InputDecoration(
              labelText: 'Navigator pairing code',
              hintText: 'ABC234',
              errorText: _error,
            ),
            onSubmitted: _submit,
          ),
          OutlinedButton.icon(
            onPressed:
                _readingImage ||
                    (!kIsWeb &&
                        (defaultTargetPlatform == TargetPlatform.windows ||
                            defaultTargetPlatform == TargetPlatform.linux) &&
                        widget.scanCode == null)
                ? null
                : () async {
                    final code =
                        await (widget.scanCode?.call(context) ??
                            Navigator.of(context).push<String>(
                              MaterialPageRoute(
                                builder: (_) => const PairingScannerPage(),
                              ),
                            ));
                    if (code != null && mounted) {
                      _submit(code, method: 'qr_code');
                    }
                  },
            icon: const GabayAccentIcon(Icons.qr_code_scanner),
            label: const Text('Scan Navigator QR'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _readingImage ? null : _upload,
            icon: _readingImage
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.image_outlined, size: 20),
            label: Text(
              _readingImage ? 'Reading QR image…' : 'Upload QR image',
            ),
          ),
          if (_imageError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _imageError!,
                  style: TextStyle(
                    color: context.gabay.danger,
                    fontSize: GabayTypography.supporting,
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
    actions: [
      OutlinedButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _readingImage ? null : () => _submit(_input.text),
        child: const Text('Pair Navigator'),
      ),
    ],
  );
}
