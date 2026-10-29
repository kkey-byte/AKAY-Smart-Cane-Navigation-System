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

class DashboardPairingCard extends StatefulWidget {
  const DashboardPairingCard({
    super.key,
    required this.caregiver,
    this.profilePresentation = false,
    this.service,
    this.scanCode,
  });
  final bool caregiver;
  final bool profilePresentation;
  final PairingService? service;
  final Future<String?> Function(BuildContext)? scanCode;
  @override
  State<DashboardPairingCard> createState() => _DashboardPairingCardState();
}

class _DashboardPairingCardState extends State<DashboardPairingCard> {
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

  void _listen() {
    unawaited(_subscription?.cancel());
    _subscription = _service.watchConnections().listen(
      _received,
      onError: (Object error) {
        if (mounted && _valid) {
          setState(() {
            _rows = null;
            _error = error.toString();
          });
        }
      },
    );
  }

  void _received(List<PairingConnection> rows) {
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
  Future<void> _pair() async {
    final submission = await showDialog<_PairSubmission>(
      context: context,
      builder: (_) => _PairCodeDialog(scanCode: widget.scanCode),
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
              selected: _method == 'alphanumeric',
              onSelected: _busy
                  ? null
                  : (_) => setState(() => _method = 'alphanumeric'),
            ),
            ChoiceChip(
              label: const Text('QR code'),
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
            ),
          ),
        ),
      ],
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: _busy || !_valid || (!widget.caregiver && !_authorized)
            ? null
            : widget.caregiver
            ? _pair
            : _generate,
        icon: Icon(widget.caregiver ? Icons.person_add_alt_1 : Icons.qr_code),
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
              color: Colors.black,
              child: Text(
                _code!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
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
              icon: const Icon(Icons.copy),
              label: const Text('Copy code'),
            ),
            OutlinedButton.icon(
              onPressed: () => _run(
                () => GabayTtsService.instance.speak(
                  'Your pairing code is ${_code!.split('').join(', ')}',
                ),
              ),
              icon: const Icon(Icons.volume_up),
              label: const Text('Read code aloud'),
            ),
          ],
        ),
      ],
      if (_code != null && _expired)
        const Text('Code expired. Create a new code to pair.'),
    ];
    return GabayCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.caregiver ? 'Your Navigators' : profileTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (widget.profilePresentation)
            Material(
              color: Colors.transparent,
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(vertical: 12),
                leading: CircleAvatar(
                  backgroundColor: context.gabay.accentTint,
                  child: Icon(
                    Icons.person_add_alt_outlined,
                    color: context.gabay.accent,
                  ),
                ),
                title: Text(
                  'Invite a Caregiver',
                  style: TextStyle(
                    color: context.gabay.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: const Text(
                  'Share a pairing code or QR to add a new caregiver',
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
                  style: const TextStyle(fontWeight: FontWeight.bold),
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
          if (_rows != null && visible.isEmpty)
            const Text('No paired accounts yet.'),
          for (final row in visible)
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
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: context.gabay.accentTint,
                            child: Icon(
                              Icons.person_outline,
                              color: context.gabay.accent,
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              widget.caregiver
                                  ? row.navigatorName
                                  : row.caregiverName,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        row.status == 'active'
                            ? '✓ Paired · Access active'
                            : widget.caregiver
                            ? 'Awaiting Navigator approval'
                            : 'Pairing request · Your approval needed',
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
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.gabay.accentTint,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(
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
                            fontWeight: FontWeight.w600,
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
  const _PairCodeDialog({this.scanCode});
  final Future<String?> Function(BuildContext)? scanCode;
  @override
  State<_PairCodeDialog> createState() => _PairCodeDialogState();
}

class _PairCodeDialogState extends State<_PairCodeDialog> {
  final _input = TextEditingController();
  String? _error;
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

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Pair a Navigator'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Ask the Navigator to show their pairing code or QR in Profile → Caregiver Connections.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _input,
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
                !kIsWeb &&
                    (defaultTargetPlatform == TargetPlatform.windows ||
                        defaultTargetPlatform == TargetPlatform.linux) &&
                    widget.scanCode == null
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
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan Navigator QR'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => _submit(_input.text),
        child: const Text('Pair Navigator'),
      ),
    ],
  );
}
