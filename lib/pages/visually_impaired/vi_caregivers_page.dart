import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/gabay_theme.dart';
import '../../widgets/shared/gabay_detail_page_scaffold.dart';

class LinkedCaregiver {
  const LinkedCaregiver({
    required this.name,
    required this.relationship,
    required this.phone,
    required this.isPrimary,
    this.isOnline = true,
  });

  final String name;
  final String relationship;
  final String phone;
  final bool isPrimary;
  final bool isOnline;
}

class ViCaregiversPage extends StatelessWidget {
  const ViCaregiversPage({super.key});

  static const _caregivers = [
    LinkedCaregiver(
      name: 'Mariel Regine Glaisa',
      relationship: 'Primary Caregiver',
      phone: '+63 998 877 6655',
      isPrimary: true,
    ),
    LinkedCaregiver(
      name: 'Regine Kris Cadiao',
      relationship: 'Secondary Caregiver',
      phone: '+63 912 345 6789',
      isPrimary: false,
    ),
  ];

  static const _pairingCode = 'GABAY-4829';

  void _openInviteSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _InviteCaregiverSheet(pairingCode: _pairingCode),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GabayDetailPageScaffold(
      title: 'Caregivers',
      subtitle: 'People linked to your navigator account.',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          GabayContentCard(
            child: Row(
              children: [
                _SummaryItem(
                  icon: Icons.group_rounded,
                  label: 'Linked',
                  value: '${_caregivers.length}',
                  color: context.gabay.accent,
                ),
                Container(
                  width: 1,
                  height: 48,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  color: context.gabay.border.withValues(alpha: 0.6),
                ),
                _SummaryItem(
                  icon: Icons.visibility_rounded,
                  label: 'Monitoring',
                  value: '1',
                  color: context.gabay.accent,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const GabaySectionLabel(label: 'Your Caregivers'),
          ..._caregivers.map(
            (caregiver) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _CaregiverCard(caregiver: caregiver),
            ),
          ),
          const SizedBox(height: 8),
          _InviteCaregiverCard(onTap: () => _openInviteSheet(context)),
          const SizedBox(height: 12),
          const _WhyAddCaregiversCard(),
        ],
      ),
    );
  }
}

class _InviteCaregiverCard extends StatelessWidget {
  const _InviteCaregiverCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    return Semantics(
      button: true,
      label: 'Invite a Caregiver. Send an invitation link or pairing code.',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: CustomPaint(
            painter: _DashedRoundedBorderPainter(
              color: g.accent.withValues(alpha: 0.75),
              radius: 20,
              strokeWidth: 1.5,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: g.accentTint,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.person_add_alt_1_rounded, color: g.accent, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Invite a Caregiver',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: g.heading,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Send an invitation link or pairing code to add a new caregiver',
                          style: TextStyle(
                            fontSize: 13,
                            color: g.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: g.textSecondary, size: 22),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WhyAddCaregiversCard extends StatelessWidget {
  const _WhyAddCaregiversCard();

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      container: true,
      label:
          'Why add caregivers? Caregivers can monitor your location and help you during emergencies.',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark
              ? g.accent.withValues(alpha: 0.12)
              : const Color(0xFFEEF4FF),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: g.accentTint,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.verified_user_rounded, color: g.accent, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Why add caregivers?',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: g.heading,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Caregivers can monitor your location and help you during emergencies',
                    style: TextStyle(
                      fontSize: 13,
                      color: g.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InviteCaregiverSheet extends StatelessWidget {
  const _InviteCaregiverSheet({required this.pairingCode});

  final String pairingCode;

  void _copyCode(BuildContext context) {
    Clipboard.setData(ClipboardData(text: pairingCode));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pairing code copied'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _shareInvite(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Invitation link shared with code $pairingCode'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: BoxDecoration(
          color: g.surfaceElevated,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: g.border.withValues(alpha: 0.45)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: g.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Text(
              'Invite a Caregiver',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: g.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Share this pairing code or invitation link so a caregiver can connect to your account.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: g.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 22),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                color: g.accentTint,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: g.accent.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  Text(
                    'Pairing Code',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: g.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    pairingCode,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                      color: g.accent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _copyCode(context),
                icon: const Icon(Icons.copy_rounded, size: 20),
                label: const Text('Copy Code'),
                style: FilledButton.styleFrom(
                  backgroundColor: g.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _shareInvite(context),
                icon: Icon(Icons.share_rounded, size: 20, color: g.accent),
                label: Text(
                  'Share Invitation Link',
                  style: TextStyle(
                    color: g.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: g.accent.withValues(alpha: 0.45)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedRoundedBorderPainter extends CustomPainter {
  const _DashedRoundedBorderPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
  });

  final Color color;
  final double radius;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        strokeWidth / 2,
        strokeWidth / 2,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rect);
    const dashWidth = 6.0;
    const dashSpace = 4.0;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRoundedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.radius != radius ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: context.gabay.textPrimary,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: context.gabay.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CaregiverCard extends StatelessWidget {
  const _CaregiverCard({required this.caregiver});

  final LinkedCaregiver caregiver;

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    return GabayContentCard(
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: g.accentTint,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person_rounded, color: g.accent, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  caregiver.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: g.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  caregiver.relationship,
                  style: TextStyle(fontSize: 13, color: g.textSecondary),
                ),
                const SizedBox(height: 6),
                Text(
                  caregiver.phone,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: g.accent,
                  ),
                ),
              ],
            ),
          ),
          if (caregiver.isPrimary)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: g.accentTint,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Primary',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: g.accent,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
