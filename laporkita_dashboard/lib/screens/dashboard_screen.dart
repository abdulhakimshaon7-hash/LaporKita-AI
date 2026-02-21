// The main dashboard screen — shows stats, alerts, clusters, and reports

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/stats_card.dart';
import '../widgets/critical_alerts.dart';
import '../widgets/clusters_list.dart';
import '../widgets/reports_feed.dart';
import 'map_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Currently selected section in the sidebar
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        title: Row(
          children: [
            const Icon(Icons.location_city, color: Colors.white),
            const SizedBox(width: 8),
            const Text('LaporKita AI Dashboard'),
            const Spacer(),
            // Current user email
            Text(
              FirebaseAuth.instance.currentUser?.email ?? '',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
            const SizedBox(width: 16),
            // Logout button
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: () => FirebaseAuth.instance.signOut(),
              tooltip: 'Logout',
            ),
          ],
        ),
      ),

      body: Row(
        children: [
          // ===== SIDEBAR =====
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() => _selectedIndex = index);
            },
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard),
                label: Text('Overview'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.list_alt),
                label: Text('Reports'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.bubble_chart),
                label: Text('Clusters'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.map),
                label: Text('Map'),
              ),
            ],
          ),

          // Vertical divider between sidebar and content
          const VerticalDivider(thickness: 1, width: 1),

          // ===== MAIN CONTENT =====
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  // Build the appropriate content based on selected sidebar item
  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return const OverviewTab();
      case 1:
        return const ReportsFeed();
      case 2:
        return const ClustersList();
      case 3:
        return const MapScreen();
      default:
        return const OverviewTab();
    }
  }
}

// =====================================================================
// OVERVIEW TAB
// Shows stats cards + critical alerts at the top
// =====================================================================
class OverviewTab extends StatelessWidget {
  const OverviewTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section title
          const Text(
            'Dashboard Overview',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Real-time community complaint management',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),

          // Stats cards row
          const StatsRow(),
          const SizedBox(height: 24),

          // Critical alerts
          const Text(
            '🚨 Critical & High Priority Alerts',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const CriticalAlerts(),
        ],
      ),
    );
  }
}
