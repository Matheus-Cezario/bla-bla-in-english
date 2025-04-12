import 'package:flutter/material.dart';

class ConditionalParentWidget extends StatelessWidget {
  final Widget child;
  final Widget Function(Widget child) buildParent;
  final bool wrapInParent;
  const ConditionalParentWidget(
      {super.key,
      required this.child,
      required this.buildParent,
      required this.wrapInParent});

  @override
  Widget build(BuildContext context) {
    return wrapInParent ? buildParent(child) : child;
  }
}
