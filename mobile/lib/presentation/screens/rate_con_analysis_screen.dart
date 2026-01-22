import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/rate_con_service.dart';
import '../themes/app_theme.dart';
import 'rate_con_clauses_screen.dart';
import 'rate_con_review_screen.dart';

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
  String? _trafficLight; // RED, YELLOW, GREEN
  String? _brokerName;

  @override
  void initState() {
    super.initState();
    _fetchAnalysis();
  }

  Future<void> _fetchAnalysis() async {
    try {
      final rateCon = await _service.getRateCon(widget.rateConId);
      setState(() {
        _trafficLight =
            rateCon.overallTrafficLight ?? 'YELLOW'; // Default to caution
        _brokerName = rateCon.brokerName;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching analysis: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final color = _getStatusColor(_trafficLight);

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
                _getStatusIcon(_trafficLight),
                size: 64,
                color: color,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _trafficLight?.toUpperCase() ?? 'UNKNOWN',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'For ${_brokerName ?? "Broker"} Load',
              style: TextStyle(color: Colors.grey.shade600),
            ),

            const Spacer(),

            // Action 1: View Clauses
            ElevatedButton.icon(
              onPressed: () async {
                // Fetch clauses and navigate
                try {
                  final clauses = await _service.getClauses(widget.rateConId);
                  if (!mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          RateConClausesScreen(clauses: clauses),
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to load clauses: $e')));
                }
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
                backgroundColor: color, // Theme the button with status
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 80),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 16),

            // Action 2: Review Information
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        RateConReviewScreen(rateConId: widget.rateConId),
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
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toUpperCase()) {
      case 'RED':
        return Colors.red;
      case 'YELLOW':
        return Colors.orange;
      case 'GREEN':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status?.toUpperCase()) {
      case 'RED':
        return Icons.warning;
      case 'YELLOW':
        return Icons.info;
      case 'GREEN':
        return Icons.check_circle;
      default:
        return Icons.help;
    }
  }
}
