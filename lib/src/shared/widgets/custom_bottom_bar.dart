import 'package:flutter/material.dart';

class CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final BuildContext context;

  const CustomBottomNav({super.key, required this.currentIndex, required this.context});

  void _onTabTapped(int index) {
    if (index == currentIndex) return;

    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/home');
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/events');
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/prayers');
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/emergency');
        break;
      case 4:
        Navigator.pushReplacementNamed(context, '/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: currentIndex,
      selectedItemColor: Color(0xFF36B37E),
      unselectedItemColor: Colors.grey,
      onTap: _onTabTapped,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.event),
          label: 'Events',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.mosque),
          label: 'Prayer',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.phone_in_talk),
          label: 'Emergency',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }
}
