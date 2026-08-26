import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:makanspot/core/router/not_migrated_screen.dart';
import 'package:makanspot/features/admin/views/admin_action_log_screen.dart';
import 'package:makanspot/features/admin/views/admin_shell.dart';
import 'package:makanspot/features/admin/views/edit_user_screen.dart';
import 'package:makanspot/features/admin/views/moderation_details_screen.dart';
import 'package:makanspot/features/admin/views/moderation_screen.dart';
import 'package:makanspot/features/admin/views/restaurant_details_screen.dart'
    as admin;
import 'package:makanspot/features/admin/views/restaurant_information_screen.dart';
import 'package:makanspot/features/admin/views/restaurant_management_screen.dart';
import 'package:makanspot/features/admin/views/user_details_screen.dart';
import 'package:makanspot/features/admin/views/user_management_screen.dart';
import 'package:makanspot/features/admin/views/data_scraper_screen.dart';
import 'package:makanspot/features/auth/controllers/auth_controller.dart';
import 'package:makanspot/features/auth/controllers/auth_state.dart';
import 'package:makanspot/features/auth/views/change_password_screen.dart';
import 'package:makanspot/features/auth/views/forgot_password_screen.dart';
import 'package:makanspot/features/auth/views/login_screen.dart';
import 'package:makanspot/features/auth/views/register_screen.dart';
import 'package:makanspot/features/auth/views/reset_password_screen.dart';
import 'package:makanspot/features/community/views/community_screen.dart';
import 'package:makanspot/features/community/views/my_posts_screen.dart';
import 'package:makanspot/features/community/views/post_details_screen.dart';
import 'package:makanspot/features/community/views/review_editor_screen.dart';
import 'package:makanspot/features/community/views/saved_posts_screen.dart';
import 'package:makanspot/features/discover/controllers/discover_state.dart';
import 'package:makanspot/features/discover/views/discover_screen.dart';
import 'package:makanspot/features/discover/views/restaurant_details_screen.dart';
import 'package:makanspot/features/discover/views/saved_restaurant_screen.dart';
import 'package:makanspot/features/home/views/home_screen.dart';
import 'package:makanspot/features/journey/views/achievements_progress_screen.dart';
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
  static const changePassword = '/profile/change-password';
  static const adminUsers = '/admin/users';
  static const adminActionLog = '/admin/action-log';
  static const adminRestaurants = '/admin/restaurants';
  static const adminNewRestaurant = '/admin/restaurants/new';
  static const adminModeration = '/admin/moderation';
  static const adminScraper = '/admin/scraper';
}

/// Routes that can be visited without signing in.
const _publicRoutes = {
  AppRoutes.login,
  AppRoutes.register,
  AppRoutes.forgotPassword,
  AppRoutes.resetPassword,
};

GoRouter createAppRouter({
  required WidgetRef ref,
  String initialLocation = AppRoutes.login,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    // Re-evaluated by the app whenever the auth state changes
    // (see MakanSpotApp), so login, logout, and session restore drive the
    // navigation.
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final location = state.matchedLocation;
      if (authState.status == AuthStatus.restoring) {
        // Hold on the login screen until the saved session is restored.
        return location == AppRoutes.login ? null : AppRoutes.login;
      }
      final session = authState.session;
      if (session == null) {
        if (_publicRoutes.contains(location)) {
          return null;
        }
        return AppRoutes.login;
      }
      if (_publicRoutes.contains(location)) {
        // Allow /reset-password during password recovery (session is temporary).
        if (location == AppRoutes.resetPassword) return null;
        return session.isAdmin ? AppRoutes.adminScraper : AppRoutes.home;
      }
      if (location.startsWith('/admin') && !session.isAdmin) {
        return AppRoutes.home;
      }
      return null;
    },
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
            path: '/saved-restaurants',
            builder: (context, state) => const SavedRestaurantScreen(),
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
            path: '/saved-posts',
            builder: (context, state) => const SavedPostsScreen(),
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
            builder: (context, state) => const AchievementsProgressScreen(),
          ),
          GoRoute(
            path: AppRoutes.profile,
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/profile/edit',
            builder: (context, state) => const EditProfileScreen(),
          ),
          GoRoute(
            path: AppRoutes.changePassword,
            builder: (context, state) => const ChangePasswordScreen(),
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
          return const ResetPasswordScreen();
        },
      ),
      ShellRoute(
        builder: (context, state, child) {
          return AdminShell(path: state.uri.path, child: child);
        },
        routes: [
          GoRoute(
            path: AppRoutes.adminScraper,
            builder: (context, state) => const V2DataScraperScreen(),
          ),
          GoRoute(
            path: AppRoutes.adminUsers,
            builder: (context, state) => const UserManagementScreen(),
          ),
          GoRoute(
            path: AppRoutes.adminActionLog,
            builder: (context, state) => const AdminActionLogScreen(),
          ),
          GoRoute(
            path: '/admin/users/:id',
            builder: (context, state) =>
                UserDetailsScreen(userId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/admin/users/:id/edit',
            builder: (context, state) =>
                EditUserScreen(userId: state.pathParameters['id']!),
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
            path: '/admin/restaurants/:id/edit',
            builder: (context, state) => admin.RestaurantDetailsScreen(
              restaurantId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/admin/restaurants/:id',
            builder: (context, state) => RestaurantInformationScreen(
              restaurantId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: AppRoutes.adminModeration,
            builder: (context, state) => const ContentModerationScreen(),
          ),
          GoRoute(
            path: '/admin/moderation/:id',
            builder: (context, state) => ModerationDetailsScreen(
              contentId: state.pathParameters['id']!,
              contentType: ModerationDetailsScreen.contentTypeFromQuery(
                state.uri.queryParameters['type'],
              ),
            ),
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
