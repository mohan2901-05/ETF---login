import 'package:flutter/material.dart';

import 'package:etf_loans/theme/theme_config.dart';

class BrandCard extends StatelessWidget {
  const BrandCard({
    required this.child,
    this.color = ThemeConfig.cardBg,
    this.padding = const EdgeInsets.all(24),
    super.key,
  });

  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: ThemeConfig.ruleLight),
        borderRadius: BorderRadius.circular(ThemeConfig.radiusLarge),
      ),
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      child: Padding(padding: padding, child: child),
    );
  }
}