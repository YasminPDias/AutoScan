import 'package:flutter/material.dart';

/// Breakpoints para diferentes tamanhos de tela
class Breakpoints {
  // Mobile: < 600px
  static const double mobile = 600;
  
  // Tablet: 600px - 1024px
  static const double tablet = 1024;
  
  // Desktop: > 1024px
  static const double desktop = 1024;
}

/// Classe auxiliar para layouts responsivos
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

/// Extension para facilitar verificações de tamanho de tela
extension ResponsiveExtension on BuildContext {
  bool get isMobile => MediaQuery.of(this).size.width < Breakpoints.mobile;
  bool get isTablet => MediaQuery.of(this).size.width >= Breakpoints.mobile &&
      MediaQuery.of(this).size.width < Breakpoints.desktop;
  bool get isDesktop => MediaQuery.of(this).size.width >= Breakpoints.desktop;
  
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;
  
  /// Retorna um valor baseado no tamanho da tela
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
