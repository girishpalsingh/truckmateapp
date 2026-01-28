import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/rate_con_model.dart';
import '../../data/models/stop.dart';
import '../../services/rate_con_service.dart';
import '../themes/app_theme.dart';
import 'rate_con_clauses_screen.dart';
import 'rate_con_review_screen.dart';

import 'package:url_launcher/url_launcher.dart';

class RateConAnalysisScreen extends ConsumerStatefulWidget {
  final String rateConId;

  const RateConAnalysisScreen({super.key, required this.rateConId});

  @override
  ConsumerState<RateConAnalysisScreen> createState() =>
      _RateConAnalysisScreenState();
}

class _RateConAnalysisScreenState extends ConsumerState<RateConAnalysisScreen> {
  final RateConService _service = RateConService();
  bool _isLoading = true;
  RateCon? _rateCon;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    debugPrint(
        'RateConAnalysisScreen: Loading rate con with ID: ${widget.rateConId}');
    _fetchAnalysis();
  }

  Future<void> _fetchAnalysis() async {
    try {
      debugPrint('Fetching rate con: ${widget.rateConId}');
      final rateCon = await _service.getRateCon(widget.rateConId);
      debugPrint('Rate con fetched successfully: ${rateCon.id}');
      setState(() {
        _rateCon = rateCon;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching analysis: $e');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _showSummary() {
    if (_rateCon == null) return;

    final rc = _rateCon!;
    final buffer = StringBuffer();

    // Header
    buffer.writeln('📄 RATE CONFIRMATION SUMMARY');
    buffer.writeln('📄 ਰੇਟ ਕਨਫਰਮੇਸ਼ਨ ਦਾ ਸੰਖੇਪ (Rate Confirmation Summary)\n');

    buffer.writeln('📌 Load Details (ਲੋਡ ਵੇਰਵੇ):');
    buffer.writeln('• Broker (ਬ੍ਰੋਕਰ): ${rc.brokerName ?? "Unknown (ਅਣਜਾਣ)"}');
    buffer.writeln('• Load ID (ਲੋਡ ਨੰਬਰ): ${rc.loadId ?? "N/A"}');
    buffer.writeln('');

    // Financials
    buffer.writeln('💰 Commercial Info (ਵਪਾਰਕ ਜਾਣਕਾਰੀ):');
    buffer.writeln(
        '• Total Rate (ਕੁੱਲ ਰੇਟ): ${rc.displayTotalRate} ${rc.currency}');
    if (rc.paymentTerms != null && rc.paymentTerms!.isNotEmpty) {
      buffer
          .writeln('• Payment Terms (ਭੁਗਤਾਨ ਦੀਆਂ ਸ਼ਰਤਾਂ): ${rc.paymentTerms}');
    }
    if (rc.charges.isNotEmpty) {
      buffer.writeln('• Items (ਵੇਰਵਾ):');
      for (var charge in rc.charges) {
        final amount = charge.amount?.toStringAsFixed(2) ?? "0.00";
        buffer.writeln('  - ${charge.description ?? "Charge"}: \$$amount');
      }
    }
    buffer.writeln('');

    // Stops
    buffer.writeln('🚚 Route (ਰੂਟ):');
    for (var stop in rc.stops) {
      final type = stop.stopType == StopType.pickup
          ? 'Pickup (ਚੁੱਕਣਾ)'
          : 'Delivery (ਨਾਮਾ)';
      final location = stop.address ?? 'Unknown';
      final time = stop.displaySchedule;
      buffer.writeln('• $type: $location');
      if (time.isNotEmpty) buffer.writeln('  🕒 $time');
    }
    buffer.writeln('');

    // Risk Clauses
    if (rc.riskClauses.isNotEmpty) {
      buffer.writeln('⚠️ Risk Analysis (ਖਤਰੇ ਦਾ ਵਿਸ਼ਲੇਸ਼ਣ):');
      for (var clause in rc.riskClauses) {
        final emoji = clause.trafficLightDisplay;
        final title = clause.clauseTitle ?? 'Clause';
        final titlePa = clause.clauseTitlePunjabi ?? '';
        final desc = clause.dangerSimpleLanguageEnglish ?? '';
        final descPa = clause.dangerSimpleLanguagePunjabi ?? '';

        buffer.writeln('$emoji $title');
        if (titlePa.isNotEmpty) buffer.writeln('   $titlePa');
        if (desc.isNotEmpty) buffer.writeln('   📝 $desc');
        if (descPa.isNotEmpty) buffer.writeln('   📝 $descPa');
        buffer.writeln('');
      }
    } else {
      buffer.writeln('✅ No significant risks found.');
      buffer.writeln('✅ ਕੋਈ ਵੱਡਾ ਖਤਰਾ ਨਹੀਂ ਲੱਭਿਆ।');
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Document Summary'),
        content: SingleChildScrollView(
          child: Text(
            buffer.toString(),
            style: const TextStyle(fontSize: 16),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              // Implement Copy to Clipboard if needed, or just close for now
              Navigator.pop(context);
            },
            child: const Text('OK'),
          )
        ],
      ),
    );
  }

  Future<void> _viewOriginalDocument() async {
    if (_rateCon?.documentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No document linked to this analysis')),
      );
      return;
    }

    try {
      final url = await _service.getDocumentUrl(_rateCon!.documentId!);
      if (url != null) {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          throw 'Could not launch $url';
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Document URL not found')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening document: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Analysis Result'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Could not load rate confirmation',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final trafficLight = _rateCon?.riskScore ?? RateConTrafficLight.unknown;
    final brokerName = _rateCon?.brokerName;
    final color = _getStatusColor(trafficLight);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analysis Result'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Traffic Light Indicator
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 4),
              ),
              child: Icon(
                _getStatusIcon(trafficLight),
                size: 64,
                color: color,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              trafficLight.name.toUpperCase(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'For ${brokerName ?? "Broker"} Load',
              style: TextStyle(color: Colors.grey.shade600),
            ),

            const Spacer(),

            // Action 1: View Clauses
            ElevatedButton.icon(
              onPressed: () async {
                if (_rateCon == null) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RateConClausesScreen(
                      clauses: _rateCon!.riskClauses,
                      rateConId: widget.rateConId,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.list_alt),
              label: const DualLanguageText(
                primaryText: 'View Clauses',
                subtitleText: 'ਸ਼ਰਤਾਂ ਦੇਖੋ',
                primaryStyle:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                alignment: CrossAxisAlignment.center,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 80),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 16),

            // Action 2: Review Information
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RateConReviewScreen(
                      rateConId: widget.rateConId,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.edit_document),
              label: const DualLanguageText(
                primaryText: 'Review Information',
                subtitleText: 'ਜਾਣਕਾਰੀ ਦੀ ਸਮੀਖਿਆ ਕਰੋ',
                primaryStyle:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                alignment: CrossAxisAlignment.center,
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 80),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 16),

            // Action 3: View Original Document
            OutlinedButton.icon(
              onPressed: _viewOriginalDocument,
              icon: const Icon(Icons.description),
              label: const DualLanguageText(
                primaryText: 'View Original Document',
                subtitleText: 'ਅਸਲੀ ਦਸਤਾਵੇਜ਼ ਦੇਖੋ',
                primaryStyle:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                alignment: CrossAxisAlignment.center,
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 80),
                padding: const EdgeInsets.symmetric(vertical: 12),
                foregroundColor: Colors.blue.shade700,
                side: BorderSide(color: Colors.blue.shade700, width: 2),
              ),
            ),
            const SizedBox(height: 16),

            // Action 4: View Summary
            OutlinedButton.icon(
              onPressed: _showSummary,
              icon: const Icon(Icons.summarize),
              label: const DualLanguageText(
                primaryText: 'View Summary',
                subtitleText: 'ਸੰਖੇਪ ਦੇਖੋ',
                primaryStyle:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                alignment: CrossAxisAlignment.center,
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 80),
                padding: const EdgeInsets.symmetric(vertical: 12),
                foregroundColor: Colors.purple.shade700,
                side: BorderSide(color: Colors.purple.shade700, width: 2),
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(RateConTrafficLight status) {
    switch (status) {
      case RateConTrafficLight.red:
        return Colors.red;
      case RateConTrafficLight.yellow:
        return Colors.orange;
      case RateConTrafficLight.green:
        return Colors.green;
      case RateConTrafficLight.unknown:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(RateConTrafficLight status) {
    switch (status) {
      case RateConTrafficLight.red:
        return Icons.warning;
      case RateConTrafficLight.yellow:
        return Icons.info;
      case RateConTrafficLight.green:
        return Icons.check_circle;
      case RateConTrafficLight.unknown:
        return Icons.help;
    }
  }
}
