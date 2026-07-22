import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../controllers/journey_controller.dart';
import '../../../../shared/widgets/async_widget.dart';

class JourneyScreen extends ConsumerWidget {
  const JourneyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(userStatsProvider);
    final leaderboardAsync = ref.watch(leaderboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discovery Journey', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.refresh(userStatsProvider);
          ref.refresh(leaderboardProvider);
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AsyncWidget(
                value: statsAsync,
                builder: (stats) => _buildStatGrid(context, stats),
              ),
              const SizedBox(height: 32),
              Text('Leaderboard', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              AsyncWidget(
                value: leaderboardAsync,
                builder: (leaderboard) => _buildLeaderboardList(leaderboard),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatGrid(BuildContext context, Map<String, dynamic> stats) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(context, 'Restaurants', stats['restaurants_visited'].toString(), Icons.restaurant, Colors.orange),
        _buildStatCard(context, 'Cities', stats['cities_explored'].toString(), Icons.location_city, Colors.blue),
        _buildStatCard(context, 'Reviews', stats['reviews_written'].toString(), Icons.rate_review, Colors.green),
        _buildStatCard(context, 'Distance', '${stats['distance_travelled']}km', Icons.directions_walk, Colors.purple),
      ],
    );
  }

  Widget _buildStatCard(BuildContext context, String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildLeaderboardList(List<Map<String, dynamic>> leaderboard) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: leaderboard.length,
      separatorBuilder: (_, _) => const Divider(),
      itemBuilder: (context, index) {
        final user = leaderboard[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: index < 3 ? AppTheme.primaryColor : AppTheme.secondaryColor,
            child: Text('${index + 1}', 
                 style: TextStyle(
                   color: index < 3 ? Colors.white : AppTheme.primaryColor, 
                   fontWeight: FontWeight.bold
                 )),
          ),
          title: Text(user['username'], style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Text('Food Explorer • Level 3'),
          trailing: Text('${user['community_score']} pts', 
                  style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
        );
      },
    );
  }
}
