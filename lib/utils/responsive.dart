import 'package:flutter/material.dart';

class Breakpoints {
  static const double mobile = 600;
  static const double tablet = 1024;
  static const double desktop = 1024;
}

class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= Breakpoints.desktop) {
          return desktop;
        } else if (constraints.maxWidth >= Breakpoints.mobile) {
          return tablet ?? mobile;
        } else {
          return mobile;
        }
      },
    );
  }
}

extension ResponsiveExtension on BuildContext {
  bool get isMobile => MediaQuery.of(this).size.width < Breakpoints.mobile;
  bool get isTablet =>
      MediaQuery.of(this).size.width >= Breakpoints.mobile &&
      MediaQuery.of(this).size.width < Breakpoints.desktop;
  bool get isDesktop => MediaQuery.of(this).size.width >= Breakpoints.desktop;

  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;

  T responsive<T>({
    required T mobile,
    T? tablet,
    required T desktop,
  }) {
    if (isDesktop) {
      return desktop;
    } else if (isTablet) {
      return tablet ?? mobile;
    } else {
      return mobile;
    }
  }
}
