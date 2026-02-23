// File: laporkita_dashboard/lib/screens/dashboard_screen.dart
// Main dashboard — stat cards now pass filters to ReportsFeed

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
  int _selectedIndex = 0;

  // Filters passed to ReportsFeed when a stat card is tapped
  String _reportsUrgencyFilter = 'ALL';
  String _reportsStatusFilter = 'ALL';

  // Called by StatsRow — switches tab and sets filter
  void _changeTab(int index, {String urgency = 'ALL', String status = 'ALL'}) {
    setState(() {
      _selectedIndex = index;
      _reportsUrgencyFilter = urgency;
      _reportsStatusFilter = status;
    });
  }

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
            Text(
              FirebaseAuth.instance.currentUser?.email ?? '',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
            const SizedBox(width: 16),
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
          // Sidebar
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() {
                _selectedIndex = index;
                // Reset filters when manually switching tabs
                if (index != 1) {
                  _reportsUrgencyFilter = 'ALL';
                  _reportsStatusFilter = 'ALL';
                }
              });
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

          const VerticalDivider(thickness: 1, width: 1),

          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return OverviewTab(onTabChange: _changeTab);
      case 1:
        // Key forces widget to rebuild when filters change
        return ReportsFeed(
          key: ValueKey('$_reportsUrgencyFilter-$_reportsStatusFilter'),
          initialUrgency: _reportsUrgencyFilter,
          initialStatus: _reportsStatusFilter,
        );
      case 2:
        return const ClustersList();
      case 3:
        return const MapScreen();
      default:
        return OverviewTab(onTabChange: _changeTab);
    }
  }
}

// =====================================================================
// OVERVIEW TAB
// =====================================================================
class OverviewTab extends StatelessWidget {
  final Function(int, {String urgency, String status}) onTabChange;

  const OverviewTab({super.key, required this.onTabChange});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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

          StatsRow(onTabChange: onTabChange),
          const SizedBox(height: 24),

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
