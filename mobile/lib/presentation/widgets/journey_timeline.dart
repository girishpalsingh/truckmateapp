import 'package:flutter/material.dart';
import '../../data/models/stop.dart';
import '../themes/app_theme.dart';
import '../widgets/glass_container.dart';
import 'package:google_fonts/google_fonts.dart';

class JourneyTimeline extends StatelessWidget {
  final List<Stop> stops;
  final String origin;
  final String destination;

  const JourneyTimeline({
    super.key,
    required this.stops,
    required this.origin,
    required this.destination,
  });

  @override
  Widget build(BuildContext context) {
    if (stops.isEmpty) {
      return const SizedBox.shrink();
    }

    // Sort stops just in case, though they should be sorted by sequence
    final sortedStops = List<Stop>.from(stops)
      ..sort((a, b) => a.sequenceNumber.compareTo(b.sequenceNumber));

    return GlassContainer(
      color: Colors.white.withOpacity(0.8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Origin -> Destination
          Row(
            children: [
              const Icon(Icons.near_me, color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  origin,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.arrow_forward, color: Colors.grey, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  destination,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.location_on, color: Colors.red, size: 20),
            ],
          ),
          const SizedBox(height: 20),

          // Timeline
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sortedStops.length,
            itemBuilder: (context, index) {
              final stop = sortedStops[index];
              return _buildStopItem(context, stop, index, sortedStops.length);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStopItem(BuildContext context, Stop stop, int index, int total) {
    // Determine status color and style
    Color iconColor = Colors.grey;
    bool isCompleted = stop.status == 'COMPLETED' || stop.status == 'DEPARTED';
    bool isActive = stop.status == 'ARRIVED' ||
        stop.status ==
            'In Progress'; // Adjust based on your actual status strings
    // If not completed and not active, maybe it's next?
    // Simplified logic: Visited = Grey, Current = Green, Next = Highlighted/Default

    if (isCompleted) {
      iconColor = Colors.grey;
    } else if (isActive) {
      iconColor = Colors.white;
    } else {
      // Pending
      iconColor = Colors.white;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline Line & Dot
          SizedBox(
            width: 30,
            child: Column(
              children: [
                // Top Line
                Expanded(
                  child: index == 0
                      ? const SizedBox.shrink()
                      : Container(
                          width: 2,
                          color: Colors.grey.shade300,
                        ),
                ),
                // Dot/Icon
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isActive
                        ? null
                        : (isCompleted ? Colors.grey.shade200 : null),
                    gradient: isActive
                        ? const LinearGradient(colors: [
                            Color(0xFF10B981),
                            Color(0xFF34D399)
                          ]) // Green gradient
                        : (isCompleted ? null : AppTheme.primaryGradient),
                    shape: BoxShape.circle,
                    border: isActive
                        ? Border.all(color: Colors.green.shade200, width: 4)
                        : null,
                    boxShadow: isActive || !isCompleted
                        ? [
                            BoxShadow(
                                color: (isActive
                                        ? Colors.green
                                        : AppTheme.primaryColor)
                                    .withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4))
                          ]
                        : null,
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, size: 14, color: Colors.grey)
                        : Text(
                            (index + 1).toString(),
                            style: TextStyle(
                              color: iconColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                // Bottom Line
                Expanded(
                  child: index == total - 1
                      ? const SizedBox.shrink()
                      : Container(
                          width: 2,
                          color: Colors.grey.shade300,
                        ),
                ),
              ],
            ),
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
                        stop.displayType.toUpperCase(),
                        style: GoogleFonts.outfit(
                          color: isActive ? Colors.green : Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      if (isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'AT LOCATION',
                            style: TextStyle(
                                color: Colors.green,
                                fontSize: 10,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    stop.address ?? 'Unknown Address',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                      color: isCompleted ? Colors.grey : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (stop.displaySchedule != 'Not specified')
                    Row(
                      children: [
                        Icon(Icons.access_time,
                            size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          stop.displaySchedule,
                          style: GoogleFonts.outfit(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
