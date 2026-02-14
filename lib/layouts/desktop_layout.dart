import 'package:flutter/material.dart';
import '../utils/responsive.dart';
import '../widgets/app_sidebar.dart';
import '../widgets/app_drawer.dart';

class DesktopLayout extends StatelessWidget {
  final Widget child;
  final String currentRoute;
  final String title;
  final bool showAppBar;
  
  const DesktopLayout({
    super.key,
    required this.child,
    required this.currentRoute,
    this.title = '',
    this.showAppBar = true,
  });

  @override
  Widget build(BuildContext context) {
    if (context.isDesktop) {
      // Desktop layout with sidebar
      return Scaffold(
        backgroundColor: Colors.white,
        body: Row(
          children: [
            // Fixed sidebar
            AppSidebar(currentRoute: currentRoute),
            
            // Main content area
            Expanded(
              child: Column(
                children: [
                  if (showAppBar && title.isNotEmpty)
                    Container(
                      height: 64,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          bottom: BorderSide(color: Color(0xFFE0E0E0), width: 1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF000000),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(child: child),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      // Mobile layout with drawer (original)
      return Scaffold(
        appBar: showAppBar && title.isNotEmpty
            ? AppBar(
                title: Text(title),
              )
            : null,
        drawer: const AppDrawer(),
        body: child,
      );
    }
  }
}
