import 'package:flutter/material.dart';

import '../theme/app_space.dart';

class AppDestination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const AppDestination(this.icon, this.selectedIcon, this.label);
}

const List<AppDestination> kAppDestinations = [
  AppDestination(Icons.home_outlined, Icons.home_rounded, 'Home'),
  AppDestination(Icons.view_timeline_outlined, Icons.view_timeline_rounded, 'Timeline'),
  AppDestination(Icons.calendar_month_outlined, Icons.calendar_month_rounded, 'Calendar'),
  AppDestination(Icons.settings_outlined, Icons.settings_rounded, 'Settings'),
];

/// Bottom navigation whose labels wrap at large text sizes.
class AppBottomBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const AppBottomBar({
    super.key,
    required this.index,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Material(
      color: scheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < kAppDestinations.length; i++)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: index == i,
                  label: kAppDestinations[i].label,
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: () => onChanged(i),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: AppSpace.touch),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.xxs,
                          vertical: AppSpace.xs,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              index == i
                                  ? kAppDestinations[i].selectedIcon
                                  : kAppDestinations[i].icon,
                              color: index == i ? scheme.primary : scheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: AppSpace.xxs),
                            Text(
                              kAppDestinations[i].label,
                              textAlign: TextAlign.center,
                              style: text.labelMedium?.copyWith(
                                color: index == i ? scheme.primary : scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
