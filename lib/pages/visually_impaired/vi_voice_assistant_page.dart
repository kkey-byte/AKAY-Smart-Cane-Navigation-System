import 'package:flutter/material.dart';

import '../../theme/gabay_theme.dart';
import '../../widgets/shared/gabay_detail_page_scaffold.dart';

class ViVoiceAssistantPage extends StatefulWidget {
  const ViVoiceAssistantPage({super.key});

  @override
  State<ViVoiceAssistantPage> createState() => _ViVoiceAssistantPageState();
}

class _ViVoiceAssistantPageState extends State<ViVoiceAssistantPage>
    with SingleTickerProviderStateMixin {
  bool _isListening = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _toggleListening() {
    setState(() => _isListening = !_isListening);
    if (_isListening) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.gabay;

    return GabayDetailPageScaffold(
      title: 'Voice Assistant',
      subtitle: 'Speak commands for hands-free navigation help.',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Center(
            child: ScaleTransition(
              scale: Tween<double>(begin: 1, end: 1.08).animate(
                CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
              ),
              child: Material(
                color: _isListening ? g.accent : g.surface,
                elevation: 6,
                shadowColor: g.accent.withValues(alpha: 0.3),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _toggleListening,
                  child: Container(
                    width: 120,
                    height: 120,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isListening ? g.accent : g.border,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                      size: 52,
                      color: _isListening ? Colors.white : g.accent,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              _isListening ? 'Listening...' : 'Tap to speak',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: g.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 28),
          const GabaySectionLabel(label: 'Try saying'),
          GabayContentCard(
            child: Column(
              children: [
                _CommandRow(text: '"Start navigation to City Hall"'),
                Divider(height: 20, color: g.border.withValues(alpha: 0.5)),
                _CommandRow(text: '"Where am I right now?"'),
                Divider(height: 20, color: g.border.withValues(alpha: 0.5)),
                _CommandRow(text: '"Share my location"'),
                Divider(height: 20, color: g.border.withValues(alpha: 0.5)),
                _CommandRow(text: '"Call my caregiver"'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommandRow extends StatelessWidget {
  const _CommandRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.format_quote_rounded, color: context.gabay.accent, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: context.gabay.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }
}
