// File: laporkita_dashboard/lib/widgets/reports_feed.dart
// Scrollable list of all reports with filtering
// Accepts initialUrgency and initialStatus so stat cards can pre-filter

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReportsFeed extends StatefulWidget {
  final String initialUrgency;
  final String initialStatus;

  const ReportsFeed({
    super.key,
    this.initialUrgency = 'ALL',
    this.initialStatus = 'ALL',
  });

  @override
  State<ReportsFeed> createState() => _ReportsFeedState();
}

class _ReportsFeedState extends State<ReportsFeed> {
  late String _filterUrgency;
  late String _filterStatus;

  @override
  void initState() {
    super.initState();
    _filterUrgency = widget.initialUrgency;
    _filterStatus = widget.initialStatus;
  }

  // ─────────────────────────────────────────────
  // KEY FIX: Never combine orderBy with where() filters
  // Firestore requires a composite index for that combination
  // which causes infinite loading on web.
  // Instead: fetch all reports and filter/sort client-side.
  // ─────────────────────────────────────────────
  Stream<QuerySnapshot> _buildQuery() {
    // Always fetch all reports — filter client-side to avoid index issues
    return FirebaseFirestore.instance
        .collection('reports')
        .limit(100)
        .snapshots();
  }

  // Apply filters and sorting client-side
  List<QueryDocumentSnapshot> _applyFilters(List<QueryDocumentSnapshot> docs) {
    var filtered = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;

      if (_filterUrgency != 'ALL' && data['urgency'] != _filterUrgency) {
        return false;
      }

      if (_filterStatus != 'ALL' && data['status'] != _filterStatus) {
        return false;
      }

      return true;
    }).toList();

    // Sort by timestamp descending client-side
    filtered.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;
      final aTime = aData['timestamp'];
      final bTime = bData['timestamp'];
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return (bTime as Timestamp).compareTo(aTime as Timestamp);
    });

    return filtered;
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

              // Urgency filter
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

              // Status filter
              DropdownButton<String>(
                value: _filterStatus,
                onChanged: (val) => setState(() => _filterStatus = val!),
                items: ['ALL', 'pending', 'in_progress', 'resolved']
                    .map(
                      (s) =>
                          DropdownMenuItem(value: s, child: Text('Status: $s')),
                    )
                    .toList(),
              ),

              // Clear filters button
              const SizedBox(width: 8),
              if (_filterUrgency != 'ALL' || _filterStatus != 'ALL')
                TextButton.icon(
                  onPressed: () => setState(() {
                    _filterUrgency = 'ALL';
                    _filterStatus = 'ALL';
                  }),
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Clear'),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Reports list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _buildQuery(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = _applyFilters(snapshot.data!.docs);

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        const Text('No reports found with these filters.'),
                        if (_filterUrgency != 'ALL' || _filterStatus != 'ALL')
                          TextButton(
                            onPressed: () => setState(() {
                              _filterUrgency = 'ALL';
                              _filterStatus = 'ALL';
                            }),
                            child: const Text('Clear filters'),
                          ),
                      ],
                    ),
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
            if (urgency != null && urgency != 'ANALYZING')
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
            if (data['cluster_id'] != null && data['cluster_id'] != '')
              const Tooltip(
                message: 'Part of a cluster',
                child: Icon(Icons.link, size: 16, color: Colors.purple),
              ),
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
        title: Text('Report: ${reportId.substring(0, 8).toUpperCase()}'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
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
                  'Action Suggested',
                  data['action_suggested'] ?? 'N/A',
                ),
                _detailRow('Status', data['status'] ?? 'pending'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              FirebaseFirestore.instance
                  .collection('reports')
                  .doc(reportId)
                  .update({'status': 'in_progress'});
              Navigator.of(context).pop();
            },
            child: const Text(
              'Mark In Progress',
              style: TextStyle(color: Colors.blue),
            ),
          ),
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
