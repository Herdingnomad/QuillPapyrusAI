import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// Centralized motion tokens and physics specs for Quill & Papyrus AI,
/// synthesizing Apple Fluid Interface design and Emil Kowalski design engineering.
class AppMotion {
  // Apple WWDC 2018 Fluid Interface Spring Specs:
  // Critically Damped (damping ratio: 1.0) - settles smoothly without bounce or oscillation.
  // Ideal for layout repositions, panel expansion, and modal presentation.
  static const SpringDescription criticallyDamped = SpringDescription(
    mass: 1.0,
    stiffness: 180.0,
    damping: 26.83, // 2 * sqrt(1 * 180)
  );

  // Momentum / Gesture Spring (damping ratio: ~0.8) - carries velocity with a slight organic bounce.
  // Ideal for fling-to-dismiss, drawer releases, and gesture handoffs.
  static const SpringDescription momentumSpring = SpringDescription(
    mass: 1.0,
    stiffness: 220.0,
    damping: 23.73, // 0.8 * 2 * sqrt(1 * 220)
  );

  // Emil Kowalski Custom Easing Curves:
  // Punchy ease-out for instant responsive feedback on UI elements.
  static const Curve snappyEaseOut = Cubic(0.23, 1.0, 0.32, 1.0);

  // Dynamic ease-in-out for moving/morphing on-screen elements.
  static const Curve snappyEaseInOut = Cubic(0.77, 0.0, 0.175, 1.0);

  // iOS-style drawer curve for bottom sheets and edge panels.
  static const Curve drawerCurve = Cubic(0.32, 0.72, 0.0, 1.0);

  // Micro-interaction durations
  static const Duration pressFeedback = Duration(milliseconds: 140);
  static const Duration tooltipDelay = Duration(milliseconds: 350);
  static const Duration fastTransition = Duration(milliseconds: 180);
  static const Duration paneTransition = Duration(milliseconds: 240);
  static const Duration modalEnter = Duration(milliseconds: 240);
  static const Duration modalExit = Duration(milliseconds: 160); // Asymmetric: exit is faster
}
