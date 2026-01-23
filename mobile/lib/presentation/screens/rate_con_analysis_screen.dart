import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/rate_con_model.dart';
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
  RateCon? _rateCon;

  @override
  void initState() {
    super.initState();
    _fetchAnalysis();
  }

  Future<void> _fetchAnalysis() async {
    try {
      final rateCon = await _service.getRateCon(widget.rateConId);
      setState(() {
        _rateCon = rateCon;
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

    final trafficLight =
        _rateCon?.overallTrafficLight ?? RateConTrafficLight.unknown;
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
