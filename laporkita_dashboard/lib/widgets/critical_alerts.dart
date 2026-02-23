// File: laporkita_dashboard/lib/widgets/critical_alerts.dart
// Shows CRITICAL and HIGH urgency unresolved reports prominently

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CriticalAlerts extends StatelessWidget {
  const CriticalAlerts({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reports')
          .where('urgency', whereIn: ['CRITICAL', 'HIGH'])
          // No orderBy — avoids composite index requirement that causes flickering
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Text('Error loading alerts: ${snapshot.error}');
        }

        // Filter out resolved reports client-side
        final alerts = snapshot.hasData
            ? snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['status'] != 'resolved';
              }).toList()
            : <QueryDocumentSnapshot>[];

        // Sort newest first client-side
        alerts.sort((a, b) {
          final aTime = (a.data() as Map<String, dynamic>)['timestamp'];
          final bTime = (b.data() as Map<String, dynamic>)['timestamp'];
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return (bTime as Timestamp).compareTo(aTime as Timestamp);
        });

        if (alerts.isEmpty) {
          return Card(
            color: Colors.green[50],
            child: const ListTile(
              leading: Icon(Icons.check_circle, color: Colors.green),
              title: Text('No critical alerts right now! 🎉'),
              subtitle: Text('All urgent complaints have been addressed.'),
            ),
          );
        }

        return Column(
          children: alerts.take(10).map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return AlertCard(reportId: doc.id, data: data);
          }).toList(),
        );
      },
    );
  }
}

class AlertCard extends StatelessWidget {
  final String reportId;
  final Map<String, dynamic> data;

  const AlertCard({super.key, required this.reportId, required this.data});

  @override
  Widget build(BuildContext context) {
    final isCritical = data['urgency'] == 'CRITICAL';
    final color = isCritical ? Colors.red : Colors.orange;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isCritical ? Colors.red[50] : Colors.orange[50],
      child: ListTile(
        leading: Icon(
          isCritical ? Icons.emergency : Icons.warning_amber,
          color: color,
          size: 32,
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                data['urgency'] ?? 'UNKNOWN',
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
                data['category'].toString().toUpperCase(),
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            const Spacer(),
            if (data['location'] != null && data['location'] != '')
              Row(
                children: [
                  Icon(Icons.location_on, size: 12, color: Colors.grey[500]),
                  const SizedBox(width: 2),
                  Text(
                    data['location'],
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
                ],
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              data['summary'] ?? data['message'] ?? 'No message',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            // Fixed: was 'recommended_action', now correctly 'action_suggested'
            if (data['action_suggested'] != null)
              Text(
                '💡 ${data['action_suggested']}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: () => _markResolved(reportId),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
          ),
          child: const Text('Resolve'),
        ),
        isThreeLine: true,
      ),
    );
  }

  Future<void> _markResolved(String id) async {
    await FirebaseFirestore.instance.collection('reports').doc(id).update({
      'status': 'resolved',
    });
  }
}
