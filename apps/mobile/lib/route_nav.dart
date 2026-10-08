import 'bronze_theme.dart';
import 'services/user_journey.dart';

import 'package:flutter/material.dart';

final requestedMainTab = ValueNotifier<int?>(null);

/// Return to the existing shell rather than creating a second signed-in session.
class RouteNavigation extends StatelessWidget {
  const RouteNavigation({
    super.key,
    required this.selected,
    this.enabled = true,
  });
  final int selected;
  final bool enabled;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: BronzePalette.border, width: .6)),
    ),
    child: NavigationBar(
      height: 68,
      selectedIndex: selected,
      onDestinationSelected: enabled
          ? (index) {
              userJourney.event(
                'navigation.tab',
                metadata: {'control': 'tab', 'source': 'touch'},
              );
              userJourney.screen(
                const ['home', 'daily', 'explore', 'ask', 'profile'][index],
              );
              requestedMainTab.value = index;
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          : null,
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
        NavigationDestination(
          icon: Icon(Icons.wb_sunny_outlined),
          label: 'Daily',
        ),
        NavigationDestination(
          icon: Icon(Icons.explore_outlined),
          label: 'Explore',
        ),
        NavigationDestination(
          icon: Icon(Icons.chat_bubble_outline),
          label: 'Ask',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          label: 'Profile',
        ),
      ],
    ),
  );
}
