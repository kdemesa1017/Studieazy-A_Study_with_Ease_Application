import 'package:flutter/material.dart';

class ResponsiveBreakpoints {
  static const double mobileMax = 799.0;
  static const double tabletMax = 1099.0;

  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 800;
  }

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 800 && width < 1100;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= 800;
  }

  static bool isWideDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= 1200;
  }

  static int gridColumns(BuildContext context, {int mobile = 1, int tablet = 2, int desktop = 3, int wide = 4}) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1300) return wide;
    if (width >= 900) return desktop;
    if (width >= 600) return tablet;
    return mobile;
  }
}

class WebResponsiveWrapper extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const WebResponsiveWrapper({
    super.key,
    required this.child,
    this.maxWidth = 1280.0,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveBreakpoints.isDesktop(context);

    if (!isDesktop) {
      return child;
    }

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: padding != null ? Padding(padding: padding!, child: child) : child,
      ),
    );
  }
}
