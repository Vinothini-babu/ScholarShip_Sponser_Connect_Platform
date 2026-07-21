import 'package:flutter/material.dart';

class StudentDashboard extends StatelessWidget {
  const StudentDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      appBar: AppBar(
        title: const Text("Student Dashboard"),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 18,
          mainAxisSpacing: 18,

          children: [

            dashboardCard(
              Icons.school,
              "Scholarships",
              Colors.blue,
            ),

            dashboardCard(
              Icons.assignment,
              "My Applications",
              Colors.orange,
            ),

            dashboardCard(
              Icons.person,
              "Profile",
              Colors.green,
            ),

            dashboardCard(
              Icons.notifications,
              "Notifications",
              Colors.red,
            ),

            dashboardCard(
              Icons.logout,
              "Logout",
              Colors.purple,
            ),
          ],
        ),
      ),
    );
  }

  Widget dashboardCard(
      IconData icon,
      String title,
      Color color,
      ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),

      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,

        children: [

          CircleAvatar(
            radius: 32,
            backgroundColor: color.withOpacity(.1),

            child: Icon(
              icon,
              color: color,
              size: 35,
            ),
          ),

          const SizedBox(height: 15),

          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
        ],
      ),
    );
  }
}