import 'package:flutter/material.dart';
import 'app_theme.dart';

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.index, this.inset = true});
  final int index;
  final bool inset;
  static const routes = [
    '/home',
    '/monitor',
    '/analytics',
    '/sos',
    '/settings',
  ];
  static const labels = ['Home', 'Monitor', 'Analytics', 'SOS', 'Settings'];
  static const icons = [
    Icons.home_rounded,
    Icons.visibility_rounded,
    Icons.bar_chart_rounded,
    Icons.sos_rounded,
    Icons.settings_rounded,
  ];

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      margin: inset
          ? const EdgeInsets.fromLTRB(16, 8, 16, 12)
          : EdgeInsets.zero,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.line),
        boxShadow: [
          BoxShadow(
            color: AppTheme.ink.withValues(alpha: .06),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: List.generate(
          5,
          (i) => Expanded(
            child: Semantics(
              selected: i == index,
              button: true,
              label: labels[i],
              child: Tooltip(
                message: labels[i],
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: i == index
                      ? null
                      : () =>
                            Navigator.pushReplacementNamed(context, routes[i]),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: i == index
                          ? const Color(0xFFEAF0FF)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          icons[i],
                          size: 23,
                          color: i == index ? AppTheme.blue : AppTheme.muted,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          labels[i],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: i == index
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: i == index ? AppTheme.blue : AppTheme.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
