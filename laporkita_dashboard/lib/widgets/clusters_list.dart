// Shows groups of related complaints

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ClustersList extends StatelessWidget {
  const ClustersList({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🔗 Issue Clusters',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const Text(
            'Groups of related complaints detected by AI',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('clusters')
                  .orderBy('updated_at', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bubble_chart, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No clusters yet.'),
                        Text(
                          'Clusters appear when 3+ similar complaints are received.',
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return ClusterCard(clusterId: doc.id, data: data);
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

class ClusterCard extends StatefulWidget {
  final String clusterId;
  final Map<String, dynamic> data;

  const ClusterCard({super.key, required this.clusterId, required this.data});

  @override
  State<ClusterCard> createState() => _ClusterCardState();
}

class _ClusterCardState extends State<ClusterCard> {
  bool _expanded = false;

  Color _urgencyColor(String? urgency) {
    switch (urgency) {
      case 'CRITICAL':
        return Colors.red;
      case 'HIGH':
        return Colors.orange;
      case 'MEDIUM':
        return Colors.amber;
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final urgency = data['urgency'] as String?;
    final color = _urgencyColor(urgency);
    final reportCount = data['report_count'] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          // Cluster header (always visible)
          ListTile(
            leading: Stack(
              children: [
                Icon(Icons.bubble_chart, color: color, size: 40),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$reportCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            title: Text(
              data['title'] ?? 'Untitled Cluster',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              data['summary'] ?? 'No summary available',
              maxLines: _expanded ? null : 2,
              overflow: _expanded
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    urgency ?? 'UNKNOWN',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
                IconButton(
                  icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                  onPressed: () => setState(() => _expanded = !_expanded),
                ),
              ],
            ),
          ),

          // Expanded details
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (data['recommended_action'] != null) ...[
                    const Text(
                      'Recommended Action:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('💡 ${data['recommended_action']}'),
                    const SizedBox(height: 8),
                  ],
                  Text('Category: ${data['category'] ?? 'N/A'}'),
                  Text('Reports in cluster: $reportCount'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _updateStatus('in_progress'),
                        icon: const Icon(Icons.play_arrow, size: 16),
                        label: const Text('Start Work'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => _updateStatus('resolved'),
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Resolve All'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _updateStatus(String status) async {
    await FirebaseFirestore.instance
        .collection('clusters')
        .doc(widget.clusterId)
        .update({'status': status});
  }
}
