import 'package:go_router/go_router.dart';

import '../features/location/presentation/screens/map_screen.dart';
import '../features/onboarding/presentation/screens/welcome_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) {
        return const WelcomeScreen();
      },
    ),

    GoRoute(
      path: '/map',
      builder: (context, state) {
        return const MapScreen();
      },
    ),
  ],
);