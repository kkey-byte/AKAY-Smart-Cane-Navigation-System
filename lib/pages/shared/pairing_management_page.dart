import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/pairing.dart';
import '../../services/app_session_service.dart';
import '../../services/pairing_service.dart';
import '../../widgets/shared/gabay_detail_page_scaffold.dart';
import '../../widgets/shared/navigator_data_card.dart';

class PairingManagementPage extends StatefulWidget {
  const PairingManagementPage({
    super.key,
    required this.caregiver,
    this.service,
  });
  final bool caregiver;
  final PairingService? service;
  @override
  State<PairingManagementPage> createState() => _PairingManagementPageState();
}

class _PairingManagementPageState extends State<PairingManagementPage> {
  late final PairingService _service;
  StreamSubscription<List<PairingConnection>>? _subscription;
  List<PairingConnection>? _connections;
  List<RegisteredCane>? _devices;
  String? _error;
  String? _deviceError;
  String? _selectedUid;
  bool _busy = false;
  late final int _revision;
  @override
  void initState() {
    super.initState();
    _service = widget.service ?? PairingService.instance;
    _revision = AppSessionService.instance.identityRevision;
    AppSessionService.instance.addListener(_sessionChanged);
    _listen();
  }

  void _sessionChanged() {
    if (_revision != AppSessionService.instance.identityRevision) {
      unawaited(_subscription?.cancel());
      if (mounted) {
        setState(() {
          _connections = null;
          _devices = null;
          _error = 'Account changed. Close this page and sign in again.';
        });
      }
    }
  }

  void _listen() {
    if (mounted) {
      setState(() {
        _connections = null;
        _devices = null;
        _error = null;
      });
    }
    unawaited(_subscription?.cancel());
    _subscription = _service.watchConnections().listen(
      (rows) {
        if (!mounted ||
            _revision != AppSessionService.instance.identityRevision) {
          return;
        }
        setState(() {
          _connections = rows;
          _error = null;
        });
        if (!widget.caregiver) unawaited(_refreshDevices());
      },
      onError: (Object error) {
        if (mounted) {
          setState(() {
            _connections = null;
            _devices = null;
            _error = error.toString();
          });
        }
      },
    );
    if (!widget.caregiver) unawaited(_refreshDevices());
  }

  Future<void> _refreshDevices() async {
    try {
      final rows = await _service.devices();
      if (mounted && _revision == AppSessionService.instance.identityRevision) {
        setState(() {
          _devices = rows;
          _deviceError = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _devices = null;
          _deviceError = error.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    AppSessionService.instance.removeListener(_sessionChanged);
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy || _revision != AppSessionService.instance.identityRevision) {
      return;
    }
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) _listen();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<List<String>?> _ask(
    String title,
    List<String> labels, {
    bool private = false,
  }) async {
    final controllers = [for (final _ in labels) TextEditingController()];
    final values = await showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < labels.length; i++)
                TextField(
                  controller: controllers[i],
                  obscureText: private && i == labels.length - 1,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(labelText: labels[i]),
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
            onPressed: () => Navigator.pop(
              context,
              controllers.map((c) => c.text.trim()).toList(),
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    // Wait for the closing route to release TextField controller references.
    unawaited(
      Future<void>.delayed(const Duration(seconds: 1), () {
        for (final c in controllers) {
          c.dispose();
        }
      }),
    );
    return values;
  }

  Future<bool> _confirm(String title, String explanation) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(explanation),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ) ??
      false;
  Future<void> _showCode(Map<String, dynamic> result, String title) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Share privately. This code can be redeemed once.'),
              SelectableText(result['code'] as String),
              Text('Expires: ${result['expires_at']}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = (_connections ?? [])
        .where((c) => c.status == 'active')
        .toList();
    final selected =
        active.where((c) => c.navigatorUid == _selectedUid).firstOrNull ??
        active.firstOrNull;
    final validAccount =
        _revision == AppSessionService.instance.identityRevision;
    return GabayDetailPageScaffold(
      title: 'Connections',
      subtitle:
          'Connections require navigator consent. Cane ownership is separate.',
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_busy)
            const LinearProgressIndicator(semanticsLabel: 'Saving changes'),
          if (_error != null) Semantics(liveRegion: true, child: Text(_error!)),
          if (_error != null && validAccount)
            TextButton(
              onPressed: _busy ? null : _listen,
              child: const Text('Retry'),
            ),
          if (_connections == null && _error == null)
            const Text('Loading connections...'),
          if (validAccount)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!widget.caregiver)
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                            await _showCode(
                              await _service.invite(),
                              'Navigator invitation',
                            );
                          }),
                    child: const Text('Create invitation'),
                  ),
                if (widget.caregiver)
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            final values = await _ask(
                              'Redeem navigator invitation',
                              ['Invitation code'],
                              private: true,
                            );
                            if (values != null) {
                              await _run(() => _service.redeem(values[0]));
                            }
                          },
                    child: const Text('Redeem invitation'),
                  ),
              ],
            ),
          if (_connections?.isEmpty == true) const Text('No connections yet.'),
          for (final c in _connections ?? <PairingConnection>[])
            GabayContentCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.caregiver ? c.navigatorName : c.caregiverName),
                  SelectableText(
                    'Account: ${widget.caregiver ? c.navigatorUid : c.caregiverUid}',
                  ),
                  Text('Connection: ${c.status}'),
                  if (c.status == 'pending' && !widget.caregiver) ...[
                    const Text(
                      'Accepting shares your name, profile photo, current and previous phone GPS tracks, assigned cane readings, and device alerts. Access lasts until revoked. This does not transfer cane ownership.',
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilledButton(
                          onPressed: _busy
                              ? null
                              : () async {
                                  if (await _confirm(
                                    'Allow ${c.caregiverName} to monitor you?',
                                    'This caregiver can view the information listed above until access is revoked.',
                                  )) {
                                    await _run(
                                      () => _service.decide(c.id, true),
                                    );
                                  }
                                },
                          child: const Text('Accept access'),
                        ),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => _run(() => _service.decide(c.id, false)),
                          child: const Text('Reject request'),
                        ),
                      ],
                    ),
                  ],
                  if (c.status == 'active' || c.status == 'pending')
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () async {
                              if (await _confirm(
                                'Revoke this connection?',
                                'Monitoring access ends. The navigator account, cane ownership and saved history are preserved.',
                              )) {
                                await _run(() => _service.revoke(c.id));
                              }
                            },
                      child: const Text('Revoke connection'),
                    ),
                ],
              ),
            ),
          if (widget.caregiver && selected != null) ...[
            DropdownButtonFormField<String>(
              key: ValueKey(selected.navigatorUid),
              initialValue: selected.navigatorUid,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Navigator to monitor',
              ),
              items: [
                for (final c in active)
                  DropdownMenuItem(
                    value: c.navigatorUid,
                    child: Text(c.navigatorName),
                  ),
              ],
              onChanged: (value) => setState(() => _selectedUid = value),
            ),
            NavigatorDataCard(
              key: ValueKey(selected.navigatorUid),
              navigatorUid: selected.navigatorUid,
              service: _service,
            ),
          ],
          if (!widget.caregiver && validAccount) ...[
            const SizedBox(height: 20),
            const Text('Smart Canes'),
            if (_deviceError != null) Text(_deviceError!),
            if (_deviceError != null)
              TextButton(
                onPressed: _busy ? null : _refreshDevices,
                child: const Text('Retry device list'),
              ),
            const Text(
              'The navigator who verifies physical possession is the registered custodian. Caregivers cannot claim or reassign canes. Multiple canes are supported.',
            ),
            Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          final values = await _ask('Register a cane', [
                            'Permanent Device ID',
                            'Private claim code',
                          ], private: true);
                          if (values != null) {
                            await _run(
                              () => _service.claim(values[0], values[1]),
                            );
                          }
                        },
                  child: const Text('Register cane'),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          final values = await _ask('Accept cane transfer', [
                            'Private transfer code',
                          ], private: true);
                          if (values != null) {
                            await _run(
                              () => _service.acceptTransfer(values[0]),
                            );
                          }
                        },
                  child: const Text('Accept transfer'),
                ),
              ],
            ),
            if (_devices == null && _error == null)
              const Text('Loading registered canes...'),
            if (_devices?.isEmpty == true) const Text('No registered canes.'),
            for (final d in _devices ?? <RegisteredCane>[])
              GabayContentCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.serial),
                    SelectableText('Device ID: ${d.id}'),
                    Text(
                      d.assignmentId == null
                          ? 'Not assigned'
                          : 'Assigned to your navigator account',
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => _run(
                                  () => d.assignmentId == null
                                      ? _service.assign(d.id)
                                      : _service.release(d.id),
                                ),
                          child: Text(
                            d.assignmentId == null
                                ? 'Assign to me'
                                : 'End assignment',
                          ),
                        ),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () async {
                                  final values = await _ask(
                                    'Transfer cane custody',
                                    ['Recipient navigator account code'],
                                  );
                                  if (values != null) {
                                    await _run(() async {
                                      await _showCode(
                                        await _service.transfer(
                                          d.id,
                                          values[0],
                                        ),
                                        'Private transfer code',
                                      );
                                    });
                                  }
                                },
                          child: const Text('Transfer custody'),
                        ),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () async {
                                  if (await _confirm(
                                    'Release cane ownership?',
                                    'This ends its assignment. Physical provisioning is required before it can be claimed again. History is retained.',
                                  )) {
                                    await _run(
                                      () => _service.release(
                                        d.id,
                                        ownership: true,
                                      ),
                                    );
                                  }
                                },
                          child: const Text('Release ownership'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            const Text('Navigator account code (identifier, not a secret):'),
            SelectableText(_service.currentUid ?? 'Sign in required'),
            if (_service.currentUid case final String uid)
              NavigatorDataCard(navigatorUid: uid, service: _service),
          ],
        ],
      ),
    );
  }
}
