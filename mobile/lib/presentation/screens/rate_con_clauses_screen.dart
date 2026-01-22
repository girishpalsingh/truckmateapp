import 'package:flutter/material.dart';
import '../../data/models/rate_con_clause.dart';
import '../themes/app_theme.dart';

class RateConClausesScreen extends StatelessWidget {
  final List<RateConClause> clauses;

  const RateConClausesScreen({super.key, required this.clauses});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const DualLanguageText(
          primaryText: 'Clause Analysis',
          subtitleText: 'ਸ਼ਰਤਾਂ ਦਾ ਵਿਸ਼ਲੇਸ਼ਣ',
          primaryStyle: TextStyle(color: Colors.white),
          subtitleStyle: TextStyle(color: Colors.white70, fontSize: 10),
        ),
      ),
      body: clauses.isEmpty
          ? const Center(child: Text('No flagged clauses found.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: clauses.length,
              itemBuilder: (context, index) {
                final clause = clauses[index];
                return _buildClauseCard(context, clause);
              },
            ),
    );
  }

  Widget _buildClauseCard(BuildContext context, RateConClause clause) {
    Color color;
    IconData icon;

    switch (clause.trafficLight?.toUpperCase()) {
      case 'RED':
        color = Colors.red;
        icon = Icons.warning_amber_rounded;
        break;
      case 'YELLOW':
        color = Colors.orange;
        icon = Icons.info_outline;
        break;
      case 'GREEN':
        color = Colors.green;
        icon = Icons.check_circle_outline;
        break;
      default:
        color = Colors.grey;
        icon = Icons.help_outline;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withOpacity(0.5), width: 1),
      ),
      child: ExpansionTile(
        leading: Icon(icon, color: color, size: 32),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Clause Type Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Text(
                clause.clauseType?.toUpperCase() ?? 'UNKNOWN',
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // Title
            DualLanguageText(
              primaryText:
                  clause.clauseTitle ?? clause.dangerSimpleLanguage ?? 'Clause',
              subtitleText: clause.clauseTitlePunjabi,
              primaryStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: DualLanguageText(
            primaryText: clause.dangerSimpleLanguage ?? '',
            subtitleText: clause.dangerSimplePunjabi,
            primaryStyle: TextStyle(
              color: Colors.grey.shade800,
              fontSize: 14,
            ),
          ),
        ),
        childrenPadding: const EdgeInsets.all(16),
        children: [
          if (clause.originalText != null) ...[
            const SizedBox(height: 12),
            const Text(
              'Original Text:',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                clause.originalText!,
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
          ],
          if (clause.warningEn != null) ...[
            const SizedBox(height: 12),
            _buildDetailRow('Warning', clause.warningEn!),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.grey),
          ),
        ),
        Expanded(
          child: Text(value),
        ),
      ],
    );
  }
}
