import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../models/pairing.dart';
import '../../services/pairing_service.dart';
import 'gabay_detail_page_scaffold.dart';

class NavigatorDataCard extends StatefulWidget {
  const NavigatorDataCard({
    super.key,
    required this.navigatorUid,
    this.service,
  });
  final String navigatorUid;
  final PairingService? service;
  @override
  State<NavigatorDataCard> createState() => _NavigatorDataCardState();
}

class _NavigatorDataCardState extends State<NavigatorDataCard> {
  late Stream<Map<String, dynamic>> _stream;
  Timer? _clock;
  @override
  void initState() {
    super.initState();
    _reload();
    _clock = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
    });
  }

  void _reload() {
    _stream = (widget.service ?? PairingService.instance).watchSnapshot(
      widget.navigatorUid,
    );
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(NavigatorDataCard old) {
    super.didUpdateWidget(old);
    if (old.navigatorUid != widget.navigatorUid) _reload();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<Map<String, dynamic>>(
    key: ValueKey(widget.navigatorUid),
    stream: _stream,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Column(
          children: [
            const Text(
              'Monitoring unavailable or access revoked. Previous readings hidden.',
            ),
            TextButton(
              onPressed: () => setState(_reload),
              child: const Text('Retry'),
            ),
          ],
        );
      }
      if (!snapshot.hasData) {
        return const LinearProgressIndicator(
          semanticsLabel: 'Loading navigator readings',
        );
      }
      final data = snapshot.data!;
      final navigator = Map<String, dynamic>.from(data['navigator'] as Map);
      final devices = (data['devices'] as List).map(
        (d) => CaneReading.fromJson(Map<String, dynamic>.from(d as Map)),
      );
      final phone = data['phoneLocation'] as Map?;
      final phoneTime = DateTime.tryParse(phone?['time']?.toString() ?? '');
      final phoneRecent =
          phone?['fresh'] == true &&
          phoneTime != null &&
          DateTime.now().difference(phoneTime).inSeconds >= -30 &&
          DateTime.now().difference(phoneTime) <= const Duration(seconds: 45);
      final picture = navigator['profile_picture'] as String?;
      Widget avatar = const Icon(Icons.person_outline);
      try {
        if (picture != null &&
            picture.startsWith('data:image/') &&
            picture.contains(',')) {
          avatar = Image.memory(
            base64Decode(picture.split(',').last),
            width: 48,
            height: 48,
            errorBuilder: (_, _, _) => const Icon(Icons.person_outline),
          );
        } else if (picture != null &&
            Uri.tryParse(picture)?.scheme == 'https') {
          avatar = Image.network(
            picture,
            width: 48,
            height: 48,
            errorBuilder: (_, _, _) => const Icon(Icons.person_outline),
          );
        }
      } catch (_) {
        /* Invalid picture falls back to the neutral icon. */
      }
      return GabayContentCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: avatar,
              title: Text(navigator['name']?.toString() ?? 'Name not provided'),
              subtitle: const Text('Authorized navigator data'),
            ),
            const Text('Phone GPS location'),
            if (phone == null)
              const Text('Unavailable')
            else
              Text(
                '${phone['latitude']}, ${phone['longitude']}\nSource: phone GPS • Last update: ${phone['time']} • ${phoneRecent ? 'Recent' : 'Stale / last known'}',
              ),
            if (devices.isEmpty) const Text('No assigned canes.'),
            for (final d in devices)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cane: ${d.serial}'),
                    SelectableText('Device ID: ${d.id}'),
                    Text(
                      'Last update: ${d.time?.toLocal().toString() ?? 'Unavailable'}',
                    ),
                    Text(
                      d.fresh(DateTime.now())
                          ? 'Recent cane reading'
                          : 'Stale / unavailable cane reading',
                    ),
                    Text(
                      'Cane battery: ${d.battery == null ? 'Unavailable' : '${d.battery}%'}',
                    ),
                    Text('Device status: ${d.status ?? 'Unavailable'}'),
                    Text(
                      d.latitude == null || d.longitude == null
                          ? 'Cane GPS unavailable'
                          : 'Cane GPS: ${d.latitude}, ${d.longitude}',
                    ),
                  ],
                ),
              ),
            const Text('Device alerts (latest 50)'),
            if ((data['alerts'] as List).isEmpty)
              const Text('No recorded device alerts.'),
            for (final a in data['alerts'] as List)
              Text(
                '${a['kind']} • Device ${a['device_id']}\nAssignment ${a['assignment_id']} • ${a['created_at']}',
              ),
          ],
        ),
      );
    },
  );
}
