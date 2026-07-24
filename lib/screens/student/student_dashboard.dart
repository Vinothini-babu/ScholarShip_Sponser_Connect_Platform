import 'package:flutter/material.dart';

import '../../widgets/dashboard_header.dart';
import '../../widgets/dashboard_stat_card.dart';
import '../../widgets/dashboard_banner.dart';

class StudentDashboard extends StatelessWidget {
  const StudentDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      body: SingleChildScrollView(
        child: Column(
          children: [

            const DashboardHeader(userName: "Vino"),

            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                childAspectRatio: 1.2,
                children: const [
                  DashboardStatCard(
                    icon: Icons.school,
                    title: "Scholarships",
                    value: "120",
                    color: Colors.blue,
                  ),
                  DashboardStatCard(
                    icon: Icons.assignment,
                    title: "Applied",
                    value: "08",
                    color: Colors.green,
                  ),
                  DashboardStatCard(
                    icon: Icons.favorite,
                    title: "Saved",
                    value: "15",
                    color: Colors.red,
                  ),
                  DashboardStatCard(
                    icon: Icons.workspace_premium,
                    title: "Eligible",
                    value: "35",
                    color: Colors.orange,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            const DashboardBanner(),

            const SizedBox(height: 30),

          ],
        ),
      ),
    );
  }
}