import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fyp_civic_connect/themes/app_theme.dart';

class CustomNavBarCurved extends StatefulWidget {
  const CustomNavBarCurved({super.key});

  @override
  CustomNavBarCurvedState createState() => CustomNavBarCurvedState();
}

class CustomNavBarCurvedState extends State<CustomNavBarCurved> {
  // Track selected index
  int _selectedIndex = 0;

  // Update index when an item is tapped
  void _onNavBarItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    // Navigate to different pages based on the tapped index
    switch (index) {
      case 0:
        Navigator.pushNamed(context, "/dashboard");
        break;
      case 1:
        Navigator.pushNamed(context, "/profile");

        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    double height = 56;

    const primaryColor = AppTheme.themePurple;
    const secondaryColor = AppTheme.themeWhite;
    const backgroundColor = Color(0xFFE7E7E7);

    return BottomAppBar(
      color: Colors.transparent,
      elevation: 0,
      child: Stack(
        children: [
          CustomPaint(
            size: Size(size.width, height + 7),
            painter: BottomNavCurvePainter(backgroundColor: backgroundColor),
          ),
          Center(
            heightFactor: 0.6,
            child: FloatingActionButton(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100.0)),
              backgroundColor: primaryColor,
              elevation: 0.1,
              onPressed: () {
                Navigator.pushNamed(context, "/report_issue");
              },
              child: const Icon(
                Icons.add_rounded,
                color: AppTheme.themeWhite,
              ),
            ),
          ),
          SizedBox(
            height: height,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                NavBarIcon(
                  text: "Home",
                  icon: CupertinoIcons.home,
                  selected: _selectedIndex == 0,
                  onPressed: () => _onNavBarItemTapped(0),
                  defaultColor: secondaryColor,
                  selectedColor: primaryColor,
                ),
                NavBarIcon(
                  text: "Calendar",
                  icon: CupertinoIcons.person,
                  selected: _selectedIndex == 1,
                  onPressed: () => _onNavBarItemTapped(1),
                  selectedColor: primaryColor,
                  defaultColor: secondaryColor,
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BottomNavCurvePainter extends CustomPainter {
  BottomNavCurvePainter(
      {this.backgroundColor = Colors.black, this.insetRadius = 38});

  Color backgroundColor;
  double insetRadius;
  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    Path path = Path()..moveTo(0, 12);

    double insetCurveBeginnningX = size.width / 2 - insetRadius;
    double insetCurveEndX = size.width / 2 + insetRadius;
    double transitionToInsetCurveWidth = size.width * .05;
    path.quadraticBezierTo(size.width * 0.20, 0,
        insetCurveBeginnningX - transitionToInsetCurveWidth, 0);
    path.quadraticBezierTo(
        insetCurveBeginnningX, 0, insetCurveBeginnningX, insetRadius / 2);

    path.arcToPoint(Offset(insetCurveEndX, insetRadius / 2),
        radius: const Radius.circular(10.0), clockwise: false);

    path.quadraticBezierTo(
        insetCurveEndX, 0, insetCurveEndX + transitionToInsetCurveWidth, 0);
    path.quadraticBezierTo(size.width * 0.80, 0, size.width, 12);
    path.lineTo(size.width, size.height + 56);
    path.lineTo(
        0,
        size.height +
            56); //+56 here extends the navbar below app bar to include extra space on some screens (iphone 11)
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return false;
  }
}

class NavBarIcon extends StatelessWidget {
  const NavBarIcon(
      {super.key,
      required this.text,
      required this.icon,
      required this.selected,
      required this.onPressed,
      this.selectedColor = const Color(0xffFF8527),
      this.defaultColor = Colors.black54});
  final String text;
  final IconData icon;
  final bool selected;
  final Function() onPressed;
  final Color defaultColor;
  final Color selectedColor;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      icon: CircleAvatar(
        backgroundColor: selected ? Colors.white : Colors.transparent,
        child: Icon(
          icon,
          size: 25,
          color: Colors.black,
        ),
      ),
    );
  }
}