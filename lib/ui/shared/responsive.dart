import 'package:flutter/widgets.dart';

class Breakpoints {
  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;
}

bool isMobile(BuildContext context) =>
    MediaQuery.sizeOf(context).width < Breakpoints.mobile;

bool isTablet(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  return w >= Breakpoints.mobile && w < Breakpoints.desktop;
}

bool isDesktop(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= Breakpoints.desktop;

bool useVerticalNav(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= Breakpoints.mobile;

int gridCrossAxisCount(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  if (w >= 1600) return 8;
  if (w >= Breakpoints.desktop) return 7;
  if (w >= Breakpoints.tablet) return 5;
  if (w >= Breakpoints.mobile) return 4;
  return 2;
}

double horizontalPadding(BuildContext context) {
  if (isDesktop(context)) return 32;
  if (isTablet(context)) return 24;
  return 16;
}

double gridSpacing(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  if (w >= 1600) return 16;
  if (w >= Breakpoints.desktop) return 14;
  if (w >= Breakpoints.tablet) return 12;
  if (w >= Breakpoints.mobile) return 10;
  return 8;
}

double gridChildAspectRatio(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  if (w < 380) return 0.59;
  if (w < Breakpoints.mobile) return 0.57;
  return 0.55;
}

double landscapeCardAspectRatio(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  if (w < Breakpoints.mobile) return 1.65;
  if (w < Breakpoints.tablet) return 2.0;
  if (w < Breakpoints.desktop) return 2.2;
  return 2.4;
}
