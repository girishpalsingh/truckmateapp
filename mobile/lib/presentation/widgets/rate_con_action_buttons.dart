import 'package:flutter/material.dart';
import '../themes/app_theme.dart';

/// Reusable action buttons for Rate Con Accept/Reject flow
class RateConActionButtons extends StatelessWidget {
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final bool isLoading;

  const RateConActionButtons({
    super.key,
    required this.onAccept,
    required this.onReject,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Reject Button
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isLoading ? null : onReject,
                icon: const Icon(Icons.arrow_back, color: Colors.red),
                label: const DualLanguageText(
                  primaryText: 'Send Back',
                  subtitleText: 'ਵਾਪਸ ਭੇਜੋ',
                  primaryStyle: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.red,
                  ),
                  subtitleStyle: TextStyle(fontSize: 10, color: Colors.red),
                  alignment: CrossAxisAlignment.center,
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Accept Button
            Expanded(
              child: FilledButton.icon(
                onPressed: isLoading ? null : onAccept,
                icon: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle),
                label: const DualLanguageText(
                  primaryText: 'Accept',
                  subtitleText: 'ਮਨਜ਼ੂਰ ਕਰੋ',
                  primaryStyle: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                  subtitleStyle: TextStyle(fontSize: 10, color: Colors.white70),
                  alignment: CrossAxisAlignment.center,
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper function to show trip creation dialog
Future<bool?> showCreateTripDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const DualLanguageText(
        primaryText: 'Create Trip',
        subtitleText: 'ਟ੍ਰਿਪ ਬਣਾਓ',
        primaryStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
      ),
      content: const DualLanguageText(
        primaryText:
            'Do you want to create a trip using this rate confirmation?',
        subtitleText: 'ਕੀ ਤੁਸੀਂ ਇਸ ਰੇਟ ਕੋਨ ਨਾਲ ਟ੍ਰਿਪ ਬਣਾਉਣਾ ਚਾਹੁੰਦੇ ਹੋ?',
        primaryStyle: TextStyle(fontSize: 16),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const DualLanguageText(
            primaryText: 'No',
            subtitleText: 'ਨਹੀਂ',
            alignment: CrossAxisAlignment.center,
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const DualLanguageText(
            primaryText: 'Yes, Create Trip',
            subtitleText: 'ਹਾਂ, ਟ੍ਰਿਪ ਬਣਾਓ',
            primaryStyle: TextStyle(color: Colors.white),
            subtitleStyle: TextStyle(color: Colors.white70, fontSize: 10),
            alignment: CrossAxisAlignment.center,
          ),
        ),
      ],
    ),
  );
}
