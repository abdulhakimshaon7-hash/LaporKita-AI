// File: laporkita_dashboard/lib/widgets/stats_card.dart
// Clickable stat cards that navigate to Reports/Clusters with correct filters

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StatsRow extends StatelessWidget {
  final Function(int, {String urgency, String status}) onTabChange;

  const StatsRow({super.key, required this.onTabChange});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('reports').snapshots(),
      builder: (context, reportsSnapshot) {
        return StreamBuilder<QuerySnapshot>(
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

            final totalReports = reports.length;

            final criticalReports = reports.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return (data['urgency'] == 'CRITICAL' ||
                      data['urgency'] == 'HIGH') &&
                  data['status'] != 'resolved';
            }).length;

            // Pending = anything not resolved
            final pendingReports = reports.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return data['status'] != 'resolved';
            }).length;

            final activeClusters = clusters.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return data['status'] != 'resolved';
            }).length;

            return Row(
              children: [
                // Total Reports → Reports tab, no filter
                Expanded(
                  child: StatsCard(
                    icon: Icons.inbox,
                    color: Colors.blue,
                    title: 'Total Reports',
                    value: totalReports.toString(),
                    subtitle: 'All time',
                    onTap: () => onTabChange(1, urgency: 'ALL', status: 'ALL'),
                  ),
                ),
                const SizedBox(width: 16),
                // Critical Alerts → Reports tab, filter CRITICAL only
                Expanded(
                  child: StatsCard(
                    icon: Icons.warning_amber,
                    color: Colors.red,
                    title: 'Critical Alerts',
                    value: criticalReports.toString(),
                    subtitle: 'Unresolved',
                    onTap: () =>
                        onTabChange(1, urgency: 'CRITICAL', status: 'ALL'),
                  ),
                ),
                const SizedBox(width: 16),
                // Pending Review → Reports tab, filter pending status
                Expanded(
                  child: StatsCard(
                    icon: Icons.pending,
                    color: Colors.orange,
                    title: 'Pending Review',
                    value: pendingReports.toString(),
                    subtitle: 'Awaiting action',
                    onTap: () =>
                        onTabChange(1, urgency: 'ALL', status: 'pending'),
                  ),
                ),
                const SizedBox(width: 16),
                // Active Clusters → Clusters tab
                Expanded(
                  child: StatsCard(
                    icon: Icons.bubble_chart,
                    color: Colors.purple,
                    title: 'Active Clusters',
                    value: activeClusters.toString(),
                    subtitle: 'Grouped issues',
                    onTap: () => onTabChange(2, urgency: 'ALL', status: 'ALL'),
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

class StatsCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final String subtitle;
  final VoidCallback? onTap;

  const StatsCard({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
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
              Row(
                children: [
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                  const Spacer(),
                  if (onTap != null)
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 10,
                      color: Colors.grey[400],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
