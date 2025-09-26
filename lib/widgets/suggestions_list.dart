// lib/widgets/suggestions_list.dart

import 'package:flutter/material.dart';
import '../screens/stock_detail_screen.dart';
import '../utils/constants.dart';
import 'package:intl/intl.dart';

class SuggestionsList extends StatelessWidget {
  final List<Map<String, dynamic>> picks;
  final DateTime lastUpdated;
  const SuggestionsList({super.key, required this.picks, required this.lastUpdated});

  @override
  Widget build(BuildContext context) {
    if (picks.isEmpty) {
      return const SizedBox.shrink(); // Don't show anything if no picks
    }

    return Card(
      margin: const EdgeInsets.all(12),
      color: AppColors.card,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Today\'s Top Picks', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('Updated: ${DateFormat.jm().format(lastUpdated)}', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
              ],
            ),
            const Divider(height: 16, color: Colors.white24),
            ...picks.map((pick) => _buildSuggestionTile(context, pick)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionTile(BuildContext context, Map<String, dynamic> pick) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(pick['ticker'], style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(pick['reason'], maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[400])),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (ctx) => StockDetailScreen(stockSymbol: pick['ticker']),
          ),
        );
      },
    );
  }
}