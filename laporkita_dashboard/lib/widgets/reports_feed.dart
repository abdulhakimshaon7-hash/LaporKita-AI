// Scrollable list of all reports with filtering

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReportsFeed extends StatefulWidget {
  const ReportsFeed({super.key});

  @override
  State<ReportsFeed> createState() => _ReportsFeedState();
}

class _ReportsFeedState extends State<ReportsFeed> {
  String _filterUrgency = 'ALL';
  String _filterStatus = 'ALL';

  // Build the Firestore query based on current filters
  Query<Map<String, dynamic>> _buildQuery() {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('reports')
        .orderBy('timestamp', descending: true)
        .limit(50); // Show only 50 most recent

    if (_filterUrgency != 'ALL') {
      query = query.where('urgency', isEqualTo: _filterUrgency);
    }

    if (_filterStatus != 'ALL') {
      query = query.where('status', isEqualTo: _filterStatus);
    }

    return query;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header + Filters
          Row(
            children: [
              const Text(
                'All Reports',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const Spacer(),

              // Urgency filter dropdown
              DropdownButton<String>(
                value: _filterUrgency,
                onChanged: (val) => setState(() => _filterUrgency = val!),
                items: ['ALL', 'CRITICAL', 'HIGH', 'MEDIUM', 'LOW']
                    .map(
                      (u) => DropdownMenuItem(
                        value: u,
                        child: Text('Urgency: $u'),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(width: 16),

              // Status filter dropdown
              DropdownButton<String>(
                value: _filterStatus,
                onChanged: (val) => setState(() => _filterStatus = val!),
                items: ['ALL', 'pending', 'analyzed', 'in_progress', 'resolved']
                    .map(
                      (s) =>
                          DropdownMenuItem(value: s, child: Text('Status: $s')),
                    )
                    .toList(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Reports list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _buildQuery().snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return const Center(
                    child: Text('No reports found with these filters.'),
                  );
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return ReportListItem(reportId: doc.id, data: data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Single report list item
class ReportListItem extends StatelessWidget {
  final String reportId;
  final Map<String, dynamic> data;

  const ReportListItem({super.key, required this.reportId, required this.data});

  // Map urgency level to color
  Color _urgencyColor(String? urgency) {
    switch (urgency) {
      case 'CRITICAL':
        return Colors.red;
      case 'HIGH':
        return Colors.orange;
      case 'MEDIUM':
        return Colors.amber;
      case 'LOW':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final urgency = data['urgency'] as String?;
    final color = _urgencyColor(urgency);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 4,
          height: double.infinity,
          color: color,
          margin: const EdgeInsets.symmetric(vertical: 4),
        ),
        title: Row(
          children: [
            if (urgency != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  urgency,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            if (data['category'] != null)
              Text(
                data['category'].toString(),
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            const Spacer(),
            if (data['cluster_id'] != null)
              const Icon(Icons.link, size: 16, color: Colors.purple),
          ],
        ),
        subtitle: Text(
          data['summary'] ?? data['message'] ?? 'No content',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: _statusChip(data['status']),
        onTap: () => _showReportDetails(context),
      ),
    );
  }

  Widget _statusChip(String? status) {
    Color chipColor;
    switch (status) {
      case 'resolved':
        chipColor = Colors.green;
        break;
      case 'in_progress':
        chipColor = Colors.blue;
        break;
      case 'analyzed':
        chipColor = Colors.purple;
        break;
      default:
        chipColor = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.15),
        border: Border.all(color: chipColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status ?? 'pending',
        style: TextStyle(color: chipColor, fontSize: 11),
      ),
    );
  }

  void _showReportDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Report Details: ${reportId.substring(0, 8).toUpperCase()}',
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailRow('Message', data['message'] ?? 'N/A'),
              _detailRow('Urgency', data['urgency'] ?? 'Processing...'),
              _detailRow('Category', data['category'] ?? 'Processing...'),
              _detailRow('Sentiment', data['sentiment'] ?? 'N/A'),
              _detailRow('Location', data['location'] ?? 'Not specified'),
              _detailRow('AI Summary', data['summary'] ?? 'Not yet analyzed'),
              _detailRow(
                'Recommended Action',
                data['recommended_action'] ?? 'N/A',
              ),
              _detailRow('Status', data['status'] ?? 'pending'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              FirebaseFirestore.instance
                  .collection('reports')
                  .doc(reportId)
                  .update({'status': 'resolved'});
              Navigator.of(context).pop();
            },
            child: const Text(
              'Mark Resolved',
              style: TextStyle(color: Colors.green),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
