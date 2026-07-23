import 'package:flutter/material.dart';

import '../../widgets/dashboard_header.dart';
import '../../widgets/feature_banner.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/scholarship_card.dart';
import '../../widgets/quick_action_card.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {

  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      body: SingleChildScrollView(
        child: Column(
          children: [

          const DashboardHeader(
          userName: "Vino",
        ),

        const SizedBox(height: 20),

        const FeatureBanner(),

        const SizedBox(height: 25),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    "Trending Scholarships",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "See All",
                    style: TextStyle(
                      color: Color(0xFF2563EB),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            SizedBox(
              height: 260,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  ScholarshipCard(
                    title: "Government Scholarship",
                    amount: "₹25,000",
                    lastDate: "30 Aug 2026",
                    icon: Icons.account_balance,
                    onTap: () {},
                  ),

                  ScholarshipCard(
                    title: "Merit Scholarship",
                    amount: "₹50,000",
                    lastDate: "15 Sep 2026",
                    icon: Icons.workspace_premium,
                    onTap: () {},
                  ),

                  ScholarshipCard(
                    title: "Sports Scholarship",
                    amount: "₹30,000",
                    lastDate: "05 Oct 2026",
                    icon: Icons.sports_soccer,
                    onTap: () {},
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    "Quick Actions",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(
                    Icons.flash_on,
                    color: Colors.amber,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                childAspectRatio: 1.2,
                children: [
                  QuickActionCard(
                    icon: Icons.assignment,
                    title: "My Applications",
                    color: Colors.blue,
                    onTap: () {},
                  ),

                  QuickActionCard(
                    icon: Icons.person,
                    title: "My Profile",
                    color: Colors.green,
                    onTap: () {},
                  ),

                  QuickActionCard(
                    icon: Icons.favorite,
                    title: "Saved",
                    color: Colors.red,
                    onTap: () {},
                  ),

                  QuickActionCard(
                    icon: Icons.support_agent,
                    title: "Support",
                    color: Colors.orange,
                    onTap: () {},
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

          ],
        ),
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        selectedItemColor: const Color(0xFF2563EB),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: "Search",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: "Applications",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: "Profile",
          ),
        ],
      ),
    );
  }
}