import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:makanspot/core/router/not_migrated_screen.dart';
import 'package:makanspot/features/admin/views/admin_dashboard_screen.dart';
import 'package:makanspot/features/admin/views/admin_login_screen.dart';
import 'package:makanspot/features/admin/views/admin_shell.dart';
import 'package:makanspot/features/admin/views/moderation_details_screen.dart';
import 'package:makanspot/features/admin/views/moderation_screen.dart';
import 'package:makanspot/features/admin/views/restaurant_details_screen.dart'
    as admin;
import 'package:makanspot/features/admin/views/restaurant_management_screen.dart';
import 'package:makanspot/features/admin/views/user_details_screen.dart';
import 'package:makanspot/features/admin/views/user_management_screen.dart';
import 'package:makanspot/features/auth/views/forgot_password_screen.dart';
import 'package:makanspot/features/auth/views/login_screen.dart';
import 'package:makanspot/features/auth/views/register_screen.dart';
import 'package:makanspot/features/auth/views/reset_password_screen.dart';
import 'package:makanspot/features/community/views/community_screen.dart';
import 'package:makanspot/features/community/views/my_posts_screen.dart';
import 'package:makanspot/features/community/views/post_details_screen.dart';
import 'package:makanspot/features/community/views/review_editor_screen.dart';
import 'package:makanspot/features/discover/controllers/discover_state.dart';
import 'package:makanspot/features/discover/views/discover_screen.dart';
import 'package:makanspot/features/discover/views/restaurant_details_screen.dart';
import 'package:makanspot/features/home/views/home_screen.dart';
import 'package:makanspot/features/journey/views/achievements_screen.dart';
import 'package:makanspot/features/journey/views/exploration_map_screen.dart';
import 'package:makanspot/features/journey/views/journey_screen.dart';
import 'package:makanspot/features/journey/views/visit_history_screen.dart';
import 'package:makanspot/features/profile/views/edit_profile_screen.dart';
import 'package:makanspot/features/profile/views/profile_screen.dart';
import 'package:makanspot/shared/widgets/makan_bottom_navigation.dart';
import 'package:makanspot/shared/widgets/mobile_app_frame.dart';

abstract final class AppRoutes {
  static const home = '/';
  static const discover = '/discover';
  static const community = '/community';
  static const journey = '/journey';
  static const profile = '/profile';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';
  static const adminLogin = '/admin/login';
  static const adminDashboard = '/admin';
  static const adminUsers = '/admin/users';
  static const adminRestaurants = '/admin/restaurants';
  static const adminNewRestaurant = '/admin/restaurants/new';
  static const adminModeration = '/admin/moderation';
}

GoRouter createAppRouter({String? initialLocation = AppRoutes.login}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          return _CustomerShell(path: state.uri.path, child: child);
        },
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: AppRoutes.discover,
            builder: (context, state) {
              return DiscoverScreen(
                arguments: DiscoverArguments(
                  query: state.uri.queryParameters['q'] ?? '',
                  filter: state.uri.queryParameters['filter'] ?? '',
                  section: state.uri.queryParameters['section'] ?? '',
                ),
              );
            },
          ),
          GoRoute(
            path: '/restaurant/:id',
            builder: (context, state) {
              return RestaurantDetailsScreen(
                restaurantId: state.pathParameters['id']!,
              );
            },
          ),
          GoRoute(
            path: AppRoutes.community,
            builder: (context, state) => const CommunityScreen(),
          ),
          GoRoute(
            path: '/review/create',
            builder: (context, state) => CreateReviewScreen(
              restaurantId: state.uri.queryParameters['restaurant'],
            ),
          ),
          GoRoute(
            path: '/post/:id/edit',
            builder: (context, state) =>
                EditPostScreen(postId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/post/:id',
            builder: (context, state) =>
                PostDetailsScreen(postId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/my-posts',
            builder: (context, state) => const MyPostsScreen(),
          ),
          GoRoute(
            path: AppRoutes.journey,
            builder: (context, state) => const JourneyScreen(),
          ),
          GoRoute(
            path: '/visit-history',
            builder: (context, state) => const VisitHistoryScreen(),
          ),
          GoRoute(
            path: '/exploration-map',
            builder: (context, state) => const ExplorationMapScreen(),
          ),
          GoRoute(
            path: '/achievements',
            builder: (context, state) => const AchievementsScreen(),
          ),
          GoRoute(
            path: AppRoutes.profile,
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/profile/edit',
            builder: (context, state) => const EditProfileScreen(),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (context, state) {
          return ResetPasswordScreen(token: state.uri.queryParameters['token']);
        },
      ),
      GoRoute(
        path: AppRoutes.adminLogin,
        builder: (context, state) => const AdminLoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return AdminShell(path: state.uri.path, child: child);
        },
        routes: [
          GoRoute(
            path: AppRoutes.adminDashboard,
            builder: (context, state) => const AdminDashboardScreen(),
          ),
          GoRoute(
            path: AppRoutes.adminUsers,
            builder: (context, state) => const UserManagementScreen(),
          ),
          GoRoute(
            path: '/admin/users/:id',
            builder: (context, state) =>
                UserDetailsScreen(userId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: AppRoutes.adminRestaurants,
            builder: (context, state) => const RestaurantManagementScreen(),
          ),
          GoRoute(
            path: AppRoutes.adminNewRestaurant,
            builder: (context, state) =>
                const admin.RestaurantDetailsScreen(restaurantId: 'new'),
          ),
          GoRoute(
            path: '/admin/restaurants/:id',
            builder: (context, state) => admin.RestaurantDetailsScreen(
              restaurantId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: AppRoutes.adminModeration,
            builder: (context, state) => const ContentModerationScreen(),
          ),
          GoRoute(
            path: '/admin/moderation/:id',
            builder: (context, state) =>
                ModerationDetailsScreen(reportId: state.pathParameters['id']!),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) {
      return const _StandalonePlaceholder(title: 'Page not found');
    },
  );
}

class _CustomerShell extends StatelessWidget {
  const _CustomerShell({required this.path, required this.child});

  final String path;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MobileAppFrame(
      bottomNavigationBar: MakanBottomNavigation(
        currentIndex: _selectedIndex(path),
        onDestinationSelected: (index) {
          const destinations = [
            AppRoutes.home,
            AppRoutes.discover,
            AppRoutes.community,
            AppRoutes.journey,
            AppRoutes.profile,
          ];
          context.go(destinations[index]);
        },
      ),
      child: child,
    );
  }

  int _selectedIndex(String location) {
    if (location.startsWith('/discover') ||
        location.startsWith('/restaurant')) {
      return 1;
    }
    if (location.startsWith('/community') ||
        location.startsWith('/review') ||
        location.startsWith('/post') ||
        location.startsWith('/my-posts')) {
      return 2;
    }
    if (location.startsWith('/journey') ||
        location.startsWith('/visit-history') ||
        location.startsWith('/exploration-map') ||
        location.startsWith('/achievements')) {
      return 3;
    }
    if (location.startsWith('/profile')) {
      return 4;
    }
    return 0;
  }
}

class _StandalonePlaceholder extends StatelessWidget {
  const _StandalonePlaceholder({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: NotMigratedScreen(title: title));
  }
}
