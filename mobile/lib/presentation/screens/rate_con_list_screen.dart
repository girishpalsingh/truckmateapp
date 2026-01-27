import 'package:flutter/material.dart';
import '../../services/rate_con_service.dart';
import '../../data/models/rate_con_model.dart';
import 'rate_con_review_screen.dart';
import '../themes/app_theme.dart';

class RateConListScreen extends StatefulWidget {
  const RateConListScreen({super.key});

  @override
  State<RateConListScreen> createState() => _RateConListScreenState();
}

class _RateConListScreenState extends State<RateConListScreen> {
  final RateConService _service = RateConService();
  List<RateCon>? _rateCons;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRateCons();
  }

  Future<void> _loadRateCons() async {
    try {
      final rateCons = await _service.listRateCons();
      if (mounted) {
        setState(() {
          _rateCons = rateCons;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading rate cons: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const DualLanguageText(
          primaryText: 'Rate Confirmations',
          subtitleText: 'ਰੇਟ ਪੁਸ਼ਟੀਕਰਣ',
          primaryStyle: TextStyle(color: Colors.white),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _rateCons == null || _rateCons!.isEmpty
              ? const Center(child: Text('No rate confirmations found'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _rateCons!.length,
                  itemBuilder: (context, index) {
                    final rc = _rateCons![index];
                    return Card(
                      child: ListTile(
                        leading: _buildStatusIcon(rc.status),
                        title: Text('Load #${rc.loadId ?? "N/A"}'),
                        subtitle: Text('${rc.brokerName}\n${rc.status}'),
                        trailing: Text(
                          rc.displayTotalRate,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        isThreeLine: true,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  RateConReviewScreen(rateConId: rc.id),
                            ),
                          ).then((_) => _loadRateCons());
                        },
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildStatusIcon(String status) {
    IconData icon;
    Color color;

    switch (status.toLowerCase()) {
      case 'approved':
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case 'rejected':
        icon = Icons.cancel;
        color = Colors.red;
        break;
      default:
        icon = Icons.hourglass_empty;
        color = Colors.orange;
    }

    return Icon(icon, color: color);
  }
}
