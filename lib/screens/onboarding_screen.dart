import 'package:flutter/material.dart';

import '../theme/app_space.dart';

class _OnboardingPage {
  final IconData icon;
  final String title;
  final String body;

  const _OnboardingPage(this.icon, this.title, this.body);
}

const List<_OnboardingPage> _pages = [
  _OnboardingPage(
    Icons.celebration_rounded,
    'Never miss a day',
    'Save birthdays and anniversaries on this device. If you only know the month and day, leave the year off and the age stays hidden.',
  ),
  _OnboardingPage(
    Icons.notifications_active_rounded,
    'Reminders stay here',
    'Happaroo can remind you on this phone. Dates stay on the device. There is no account and nothing is uploaded.',
  ),
  _OnboardingPage(
    Icons.group_rounded,
    'Group people your way',
    'Use groups such as Family or Friends, then filter the list. Anyone without a group is Ungrouped.',
  ),
];

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;

  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _last => _page == _pages.length - 1;

  void _next() {
    if (_last) {
      widget.onDone();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: widget.onDone,
                child: const Text('Skip'),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (value) => setState(() => _page = value),
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(AppSpace.lg),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: AppSpace.touch + AppSpace.xl,
                                height: AppSpace.touch + AppSpace.xl,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: scheme.primaryContainer,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(page.icon, size: AppSpace.xl, color: scheme.onPrimaryContainer),
                              ),
                              const SizedBox(height: AppSpace.lg),
                              Text(page.title, textAlign: TextAlign.center, style: text.headlineMedium),
                              const SizedBox(height: AppSpace.sm),
                              Text(
                                page.body,
                                textAlign: TextAlign.center,
                                style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.xs, AppSpace.lg, AppSpace.lg),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _pages.length; i++)
                        Container(
                          width: i == _page ? AppSpace.lg : AppSpace.xs,
                          height: AppSpace.xs,
                          margin: const EdgeInsets.symmetric(horizontal: AppSpace.xxs),
                          decoration: BoxDecoration(
                            color: i == _page ? scheme.primary : scheme.outlineVariant,
                            borderRadius: BorderRadius.circular(AppSpace.xs),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.md),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _next,
                      child: Text(_last ? 'Get started' : 'Next'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
