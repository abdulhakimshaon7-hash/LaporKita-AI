// Shows summary numbers: total reports, critical count, clusters, etc.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Row of 4 stats cards
class StatsRow extends StatelessWidget {
  const StatsRow({super.key});
  
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      // Listen to ALL reports in real-time
      stream: FirebaseFirestore.instance.collection('reports').snapshots(),
      builder: (context, reportsSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          // Also listen to clusters
          stream: FirebaseFirestore.instance.collection('clusters').snapshots(),
          builder: (context, clustersSnapshot) {
            
            if (!reportsSnapshot.hasData || !clustersSnapshot.hasData) {
              return const Row(
                children: [
                  Expanded(child: _StatsSkeleton()),
                  SizedBox(width: 16),
                  Expanded(child: _StatsSkeleton()),
                  SizedBox(width: 16),
                  Expanded(child: _StatsSkeleton()),
                  SizedBox(width: 16),
                  Expanded(child: _StatsSkeleton()),
                ],
              );
            }
            
            final reports = reportsSnapshot.data!.docs;
            final clusters = clustersSnapshot.data!.docs;
            
            // Calculate stats
            final totalReports = reports.length;
            
            final criticalReports = reports.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return data['urgency'] == 'CRITICAL' && data['status'] != 'resolved';
            }).length;
            
            final pendingReports = reports.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return data['status'] == 'pending' || data['status'] == 'analyzed';
            }).length;
            
            final activeClusters = clusters.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return data['status'] == 'open';
            }).length;
            
            return Row(
              children: [
                Expanded(
                  child: StatsCard(
                    icon: Icons.inbox,
                    color: Colors.blue,
                    title: 'Total Reports',
                    value: totalReports.toString(),
                    subtitle: 'All time',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatsCard(
                    icon: Icons.warning_amber,
                    color: Colors.red,
                    title: 'Critical Alerts',
                    value: criticalReports.toString(),
                    subtitle: 'Unresolved',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatsCard(
                    icon: Icons.pending,
                    color: Colors.orange,
                    title: 'Pending Review',
                    value: pendingReports.toString(),
                    subtitle: 'Awaiting action',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatsCard(
                    icon: Icons.bubble_chart,
                    color: Colors.purple,
                    title: 'Active Clusters',
                    value: activeClusters.toString(),
                    subtitle: 'Grouped issues',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// Single stats card widget
class StatsCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final String subtitle;
  
  const StatsCard({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.subtitle,
  });
  
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                Icon(icon, color: color, size: 20),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

// Skeleton loading placeholder
class _StatsSkeleton extends StatelessWidget {
  const _StatsSkeleton();
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        height: 100,
        padding: const EdgeInsets.all(20),
        child: const CircularProgressIndicator(),
      ),
    );
  }
}