import 'package:flutter/material.dart';
import '../../theme/gabay_theme.dart';

class ViSosButton extends StatefulWidget {
  final VoidCallback? onPressed;

  const ViSosButton({super.key, this.onPressed});

  @override
  State<ViSosButton> createState() => _ViSosButtonState();
}

class _ViSosButtonState extends State<ViSosButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final danger = context.gabay.danger;

    return Semantics(
      button: true,
      label: 'Emergency SOS. Double tap to send alert.',
      child: ScaleTransition(
        scale: _pulseAnimation,
        child: Material(
          color: danger,
          elevation: 8,
          shadowColor: danger.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(28),
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: widget.onPressed ??
                () => _confirmSos(context),
            child: Container(
              width: double.infinity,
              height: 88,
              alignment: Alignment.center,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.sos_rounded, color: Colors.white, size: 36),
                  SizedBox(width: 12),
                  Text(
                    'EMERGENCY SOS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmSos(BuildContext context) {
    final danger = context.gabay.danger;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.gabay.surface,
        title: Text(
          'Activate Emergency SOS?',
          style: TextStyle(color: context.gabay.textPrimary),
        ),
        content: Text(
          'Your caregiver and emergency contacts will be alerted immediately with your live location.',
          style: TextStyle(color: context.gabay.textSecondary, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: TextStyle(color: context.gabay.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Emergency SOS activated — help is on the way'),
                  backgroundColor: danger,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Text('Activate SOS', style: TextStyle(color: danger, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
