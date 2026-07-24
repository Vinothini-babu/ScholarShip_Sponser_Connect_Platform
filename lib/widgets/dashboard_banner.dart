import 'package:flutter/material.dart';

class DashboardBanner extends StatelessWidget {
  const DashboardBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Featured Scholarship",
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Merit Scholarship 2026",
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Get up to ₹50,000 financial support.",
            style: TextStyle(
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 15),
          ElevatedButton(
            onPressed: () {},
            child: const Text("Apply Now"),
          ),
        ],
      ),
    );
  }
}