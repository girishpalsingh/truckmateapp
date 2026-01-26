import 'package:flutter/material.dart';
import '../../data/models/rate_con_model.dart';
import '../../data/models/stop.dart';
import '../themes/app_theme.dart';
import '../../services/rate_con_service.dart';

class RateConSummaryScreen extends StatelessWidget {
  final RateCon rateCon;

  const RateConSummaryScreen({super.key, required this.rateCon});

  @override
  Widget build(BuildContext context) {
    // Sort stops
    final stops = List<Stop>.from(rateCon.stops)
      ..sort((a, b) => a.sequenceNumber.compareTo(b.sequenceNumber));

    return Scaffold(
      appBar: AppBar(
        title: const DualLanguageText(
          primaryText: 'Loading Summary',
          subtitleText: 'ਲੋਡਿੰਗ ਸੰਖੇਪ',
          primaryStyle: TextStyle(color: Colors.white),
          subtitleStyle: TextStyle(color: Colors.white70, fontSize: 10),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 1. Big Rate & Status Card
            _buildMainCard(context),
            const SizedBox(height: 16),

            // 2. Map-like Timeline of Stops
            _buildTimelineCard(context, stops),
            const SizedBox(height: 16),

            // 3. Broker Quick Contact
            _buildQuickContactCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildMainCard(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Load #${rateCon.loadId ?? rateCon.rcId ?? rateCon.id.substring(0, 5)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              rateCon.displayTotalRate,
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            _buildRiskBadge(context),
          ],
        ),
      ),
    );
  }

  Widget _buildRiskBadge(BuildContext context) {
    Color color;
    String text;
    switch (rateCon.riskScore) {
      case RateConTrafficLight.green:
        color = Colors.green;
        text = 'Low Risk';
        break;
      case RateConTrafficLight.yellow:
        color = Colors.orange;
        text = 'Medium Risk';
        break;
      case RateConTrafficLight.red:
        color = Colors.red;
        text = 'High Risk';
        break;
      default:
        color = Colors.grey;
        text = 'Unknown Risk';
    }

    return divContainer(
      color: color.withOpacity(0.1),
      child: Text(
        '${rateCon.trafficLightEmoji} $text',
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget divContainer({required Color color, required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }

  Widget _buildTimelineCard(BuildContext context, List<Stop> stops) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const DualLanguageText(
              primaryText: 'Route Plan',
              subtitleText: 'ਰੂਟ ਪਲਾਨ',
              primaryStyle:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: stops.length,
              itemBuilder: (context, index) => _buildStopRow(
                  context, stops[index],
                  isLast: index == stops.length - 1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStopRow(BuildContext context, Stop stop,
      {required bool isLast}) {
    final isPickup = stop.stopType == StopType.pickup;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline Line
          Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isPickup ? Colors.blue : Colors.green,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: Icon(
                    isPickup ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 14,
                    color: Colors.white),
              ),
              if (!isLast)
                Expanded(
                    child: Container(
                        width: 2,
                        color: Colors.grey[300],
                        margin: const EdgeInsets.symmetric(vertical: 4))),
            ],
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        stop.displayType,
                        style: TextStyle(
                          color:
                              isPickup ? Colors.blue[700] : Colors.green[700],
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        stop.dateRaw ?? 'No Date',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    stop.address ?? 'Address ???',
                    style: const TextStyle(fontSize: 16),
                  ),
                  if (stop.commodities.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${stop.commodities.length} Items • ${stop.commodities.first.description ?? 'Freight'}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickContactCard(BuildContext context) {
    if (rateCon.brokerPhone == null && rateCon.brokerEmail == null)
      return const SizedBox.shrink();

    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            if (rateCon.brokerPhone != null)
              _buildContactAction(Icons.phone, 'Call', rateCon.brokerPhone!),
            if (rateCon.brokerEmail != null)
              _buildContactAction(Icons.email, 'Email', rateCon.brokerEmail!),
          ],
        ),
      ),
    );
  }

  Widget _buildContactAction(IconData icon, String label, String value) {
    return InkWell(
      onTap: () {
        // Implement launch url
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.blue),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  color: Colors.blue, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
