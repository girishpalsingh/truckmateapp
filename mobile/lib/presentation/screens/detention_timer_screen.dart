import 'dart:async';
import 'package:flutter/material.dart';

class DetentionTimerScreen extends StatefulWidget {
  final DateTime arrivalTime;
  final int freeTimeMinutes; // e.g. 120 minutes
  final String stopAddress;

  const DetentionTimerScreen({
    super.key,
    required this.arrivalTime,
    this.freeTimeMinutes = 120,
    required this.stopAddress,
  });

  @override
  State<DetentionTimerScreen> createState() => _DetentionTimerScreenState();
}

class _DetentionTimerScreenState extends State<DetentionTimerScreen> {
  late Timer _timer;
  Duration _elapsed = Duration.zero;
  Duration _detention = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateTimer();
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _updateTimer();
    });
  }

  void _updateTimer() {
    final now = DateTime.now();
    setState(() {
      _elapsed = now.difference(widget.arrivalTime);
      final freeTime = Duration(minutes: widget.freeTimeMinutes);
      if (_elapsed > freeTime) {
        _detention = _elapsed - freeTime;
      } else {
        _detention = Duration.zero;
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final isDetention = _detention.inMinutes > 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Detention Timer')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.timer, size: 80, color: Colors.blue),
            const SizedBox(height: 24),
            Text(widget.stopAddress,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center),
            const SizedBox(height: 48),
            Text(
              'Time On Site',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            Text(
              _formatDuration(_elapsed),
              style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            if (isDetention) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red),
                ),
                child: Column(
                  children: [
                    Text(
                      'DETENTION STARTED',
                      style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatDuration(_detention),
                      style: const TextStyle(
                          fontSize: 32,
                          color: Colors.red,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green),
                ),
                child: Column(
                  children: [
                    Text(
                      'Free Time Remaining',
                      style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatDuration(
                          Duration(minutes: widget.freeTimeMinutes) - _elapsed),
                      style: const TextStyle(
                          fontSize: 32,
                          color: Colors.green,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
            const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Back to Trip'),
            ),
          ],
        ),
      ),
    );
  }
}
