// File: app/laporkita_dashboard/lib/widgets/critical_alerts.dart
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
          .where('urgency', whereIn: ['CRITICAL', 'HIGH'])  // Only critical/high
          .where('status', whereIn: ['pending', 'analyzed']) // Only unresolved
          .orderBy('timestamp', descending: true)            // Newest first
          .limit(10)                                         // Max 10 alerts
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Card(
            color: Colors.green[50],
            child: const ListTile(
              leading: Icon(Icons.check_circle, color: Colors.green),
              title: Text('No critical alerts right now! 🎉'),
              subtitle: Text('All urgent complaints have been addressed.'),
            ),
          );
        }
        
        // Show a card for each critical/high alert
        return Column(
          children: snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return AlertCard(
              reportId: doc.id,
              data: data,
            );
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
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            // Show the summary if available, otherwise the raw message
            Text(
              data['summary'] ?? data['message'] ?? 'No message',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            if (data['recommended_action'] != null)
              Text(
                '💡 ${data['recommended_action']}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: () => _markInProgress(reportId),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
          ),
          child: const Text('Take Action'),
        ),
        isThreeLine: true,
      ),
    );
  }
  
  // Update report status to "in_progress"
  Future<void> _markInProgress(String id) async {
    await FirebaseFirestore.instance
        .collection('reports')
        .doc(id)
        .update({'status': 'in_progress'});
  }
}