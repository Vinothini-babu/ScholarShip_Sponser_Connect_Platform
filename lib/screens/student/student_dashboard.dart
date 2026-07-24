import 'package:flutter/material.dart';

import '../../widgets/dashboard_header.dart';
import '../../widgets/dashboard_banner.dart';
import '../../widgets/dashboard_stat_card.dart';
import '../../widgets/dashboard_scholarship_card.dart';
import '../../widgets/dashboard_quick_action_card.dart';
import 'search_screen.dart';
import 'application_screen.dart';
import 'profile_screen.dart';



class StudentDashboard extends StatelessWidget {
  const StudentDashboard({super.key});

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

            const DashboardBanner(),

            const SizedBox(height: 25),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                childAspectRatio: 1.05,
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

            const SizedBox(height: 30),

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
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            SizedBox(
              height: 270,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [

                  DashboardScholarshipCard(
                    title: "Government Scholarship",
                    amount: "₹25,000",
                    deadline: "30 Aug 2026",
                    icon: Icons.account_balance,
                    onTap: () {},
                  ),

                  DashboardScholarshipCard(
                    title: "Merit Scholarship",
                    amount: "₹50,000",
                    deadline: "15 Sep 2026",
                    icon: Icons.workspace_premium,
                    onTap: () {},
                  ),

                  DashboardScholarshipCard(
                    title: "Sports Scholarship",
                    amount: "₹30,000",
                    deadline: "05 Oct 2026",
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
                childAspectRatio: 1.15,
                children: [
                  DashboardQuickActionCard(
                    icon: Icons.assignment,
                    title: "My Applications",
                    color: Colors.blue,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ApplicationScreen(),
                        ),
                      );
                    },
                  ),
                  DashboardQuickActionCard(
                    icon: Icons.person,
                    title: "My Profile",
                    color: Colors.green,
                    onTap: () {},
                  ),
                  DashboardQuickActionCard(
                    icon: Icons.favorite,
                    title: "Saved",
                    color: Colors.red,
                    onTap: () {},
                  ),
                  DashboardQuickActionCard(
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
        currentIndex: 0,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF2563EB),
        unselectedItemColor: Colors.grey,

        onTap: (index) {
          if (index == 0) {
            return; // Already on Home
          }

          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SearchScreen(),
              ),
            );
          }

          if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ApplicationScreen(),
              ),
            );
          }

          if (index == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ProfileScreen(),
              ),
            );
          }
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