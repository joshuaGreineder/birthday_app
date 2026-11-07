import 'package:flutter/material.dart';

import '../theme/app_space.dart';

/// Loading, empty, and error states. [title] is a sentence, never an exception.
class ScreenStatus extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool busy;

  const ScreenStatus({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.actionLabel,
    this.onAction,
    this.busy = false,
  });

  factory ScreenStatus.loading([String title = 'Loading events...']) {
    return ScreenStatus(
      busy: true,
      icon: Icons.hourglass_top_rounded,
      title: title,
    );
  }

  factory ScreenStatus.error({
    required String title,
    String? body,
    VoidCallback? onRetry,
  }) {
    return ScreenStatus(
      icon: Icons.error_outline_rounded,
      title: title,
      body: body,
      actionLabel: onRetry == null ? null : 'Try again',
      onAction: onRetry,
    );
  }

  factory ScreenStatus.empty({
    required IconData icon,
    required String title,
    String? body,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return ScreenStatus(
      icon: icon,
      title: title,
      body: body,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (busy)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.md),
            child: CircularProgressIndicator(color: scheme.primary),
          )
        else
          Container(
            width: AppSpace.touch + AppSpace.lg,
            height: AppSpace.touch + AppSpace.lg,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: AppSpace.xl, color: scheme.onPrimaryContainer),
          ),
        const SizedBox(height: AppSpace.md),
        Text(title, textAlign: TextAlign.center, style: text.headlineSmall),
        if (body != null) ...[
          const SizedBox(height: AppSpace.xs),
          Text(
            body!,
            textAlign: TextAlign.center,
            style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
        if (actionLabel != null) ...[
          const SizedBox(height: AppSpace.lg),
          FilledButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final padded = Padding(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: content,
        );
        if (!constraints.maxHeight.isFinite) return padded;
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: padded,
          ),
        );
      },
    );
  }
}
