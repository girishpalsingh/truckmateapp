import 'package:flutter/material.dart';
import '../../data/models/risk_clause.dart';
import '../../data/models/rate_con_model.dart';
import '../../services/rate_con_service.dart';
import '../themes/app_theme.dart';
import '../widgets/rate_con_action_buttons.dart';

import '../screens/trip_screens.dart'; // Import CreateTripScreen

class RateConClausesScreen extends StatefulWidget {
  final String rateConId;
  final List<RiskClause> clauses;

  const RateConClausesScreen({
    super.key,
    required this.rateConId,
    required this.clauses,
  });

  @override
  State<RateConClausesScreen> createState() => _RateConClausesScreenState();
}

class _RateConClausesScreenState extends State<RateConClausesScreen> {
  final RateConService _service = RateConService();
  bool _isLoading = false;

  Future<void> _handleAccept() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const DualLanguageText(
          primaryText: 'Accept Rate Con?',
          subtitleText: 'ਰੇਟ ਕੋਨ ਸਵੀਕਾਰ ਕਰੋ?',
          primaryStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        content: const DualLanguageText(
          primaryText:
              'You have reviewed the risk clauses and want to accept this rate confirmation.',
          subtitleText:
              'ਤੁਸੀਂ ਜੋਖਮ ਧਾਰਾਵਾਂ ਦੀ ਸਮੀਖਿਆ ਕੀਤੀ ਹੈ ਅਤੇ ਇਸ ਰੇਟ ਕਨਫਰਮੇਸ਼ਨ ਨੂੰ ਸਵੀਕਾਰ ਕਰਨਾ ਚਾਹੁੰਦੇ ਹੋ।',
          primaryStyle: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Accept'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Ask to create trip
    if (!mounted) return;
    final createTrip = await showCreateTripDialog(context);
    if (createTrip == null) return; // User cancelled the trip dialog

    setState(() => _isLoading = true);

    try {
      final newLoadId = await _service.approveRateCon(widget.rateConId, {});

      if (!mounted) return;

      if (createTrip == true) {
        // Fetch RateCon to get addresses for pre-filling
        RateCon? rateCon;
        try {
          rateCon = await _service.getRateCon(widget.rateConId);
        } catch (e) {
          // Ignore fetch error, proceed with empty addresses
          debugPrint('Failed to fetch rate con for addresses: $e');
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => CreateTripScreen(
              originAddress: rateCon?.originAddress,
              destinationAddress: rateCon?.destinationAddress,
              loadId: newLoadId,
              brokerName: rateCon?.brokerName,
              rate: rateCon?.totalRate, // Updated field
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rate Confirmation Accepted'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleReject() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const DualLanguageText(
          primaryText: 'Reject Rate Con?',
          subtitleText: 'ਰੇਟ ਕੋਨ ਰੱਦ ਕਰੋ?',
          primaryStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        content: const DualLanguageText(
          primaryText:
              'The clauses are too risky. Reject this rate confirmation.',
          subtitleText: 'ਧਾਰਾਵਾਂ ਬਹੁਤ ਖਤਰਨਾਕ ਹਨ। ਇਸ ਰੇਟ ਕਨਫਰਮੇਸ਼ਨ ਨੂੰ ਰੱਦ ਕਰੋ।',
          primaryStyle: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      await _service.rejectRateCon(widget.rateConId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rate Confirmation Rejected'),
          backgroundColor: Colors.orange,
        ),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sort clauses by traffic light severity (RED first, then YELLOW, then GREEN)
    final sortedClauses = List<RiskClause>.from(widget.clauses)
      ..sort((a, b) {
        final order = {
          TrafficLight.red: 0,
          TrafficLight.yellow: 1,
          TrafficLight.green: 2
        };
        return (order[a.trafficLight] ?? 3)
            .compareTo(order[b.trafficLight] ?? 3);
      });

    return Scaffold(
      appBar: AppBar(
        title: const DualLanguageText(
          primaryText: 'Risk Clauses',
          subtitleText: 'ਜੋਖਮ ਧਾਰਾਵਾਂ',
          primaryStyle: TextStyle(color: Colors.white),
          subtitleStyle: TextStyle(color: Colors.white70, fontSize: 10),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Summary Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .errorContainer
                        .withOpacity(0.3),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildSummaryChip(
                          '🔴',
                          sortedClauses
                              .where((c) => c.trafficLight == TrafficLight.red)
                              .length),
                      _buildSummaryChip(
                          '🟡',
                          sortedClauses
                              .where(
                                  (c) => c.trafficLight == TrafficLight.yellow)
                              .length),
                      _buildSummaryChip(
                          '🟢',
                          sortedClauses
                              .where(
                                  (c) => c.trafficLight == TrafficLight.green)
                              .length),
                    ],
                  ),
                ),

                // Clauses List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: sortedClauses.length,
                    itemBuilder: (context, index) {
                      return _buildClauseCard(context, sortedClauses[index]);
                    },
                  ),
                ),

                // Action Buttons
                RateConActionButtons(
                  onAccept: _handleAccept,
                  onReject: _handleReject,
                  isLoading: _isLoading,
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryChip(String emoji, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Text(
            count.toString(),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildClauseCard(BuildContext context, RiskClause clause) {
    Color borderColor;
    Color bgColor;

    switch (clause.trafficLight) {
      case TrafficLight.red:
        borderColor = Colors.red;
        bgColor = Colors.red.withOpacity(0.05);
        break;
      case TrafficLight.yellow:
        borderColor = Colors.orange;
        bgColor = Colors.orange.withOpacity(0.05);
        break;
      case TrafficLight.green:
        borderColor = Colors.green;
        bgColor = Colors.green.withOpacity(0.05);
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: 2),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Text(
            clause.trafficLightDisplay,
            style: const TextStyle(fontSize: 28),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Clause Type Badge
              if (clause.clauseType != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: borderColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    clause.clauseType!.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: borderColor,
                    ),
                  ),
                ),
              // Clause Title
              Text(
                clause.titleEn ?? 'Clause', // Updated field
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              // Punjabi Title
              if (clause.titlePunjabi != null) // Updated field
                Text(
                  clause.titlePunjabi!, // Updated field
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              clause.explanationEn ?? '', // Updated field
              style: const TextStyle(fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          children: [
            // Punjabi Explanation
            if (clause.explanationPunjabi != null) ...[
              // Updated field
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ਪੰਜਾਬੀ:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      clause.explanationPunjabi!, // Updated field
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Original Text
            if (clause.originalText != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Original Clause:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      clause.originalText!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Notification Info
            if (clause.notification != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_active,
                        color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            clause.notification!.title ?? 'Reminder',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          if (clause.notification!.description != null)
                            Text(
                              clause.notification!.description!,
                              style: const TextStyle(fontSize: 12),
                            ),
                          Text(
                            clause.notification!.displayTiming,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
