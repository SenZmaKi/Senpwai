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
  if (w >= 1600) return 7;
  if (w >= Breakpoints.desktop) return 6;
  if (w >= Breakpoints.tablet) return 4;
  if (w >= Breakpoints.mobile) return 3;
  return 2;
}

double horizontalPadding(BuildContext context) {
  if (isDesktop(context)) return 32;
  if (isTablet(context)) return 24;
  return 16;
}
