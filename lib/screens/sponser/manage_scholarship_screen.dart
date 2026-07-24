import 'package:flutter/material.dart';

class ManageScholarshipScreen extends StatelessWidget {
  const ManageScholarshipScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      appBar: AppBar(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          "Manage Scholarships",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),

      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [

          const Text(
            "My Scholarships",
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            "Manage your published scholarships",
            style: TextStyle(
              color: Colors.grey,
              fontSize: 15,
            ),
          ),

          const SizedBox(height: 25),

          _buildScholarshipCard(
            context,
            title: "Government Scholarship",
            amount: "₹25,000",
            deadline: "30 Aug 2026",
          ),

          const SizedBox(height: 20),

          _buildScholarshipCard(
            context,
            title: "Merit Scholarship",
            amount: "₹50,000",
            deadline: "15 Sep 2026",
          ),

          const SizedBox(height: 20),

          _buildScholarshipCard(
            context,
            title: "Sports Scholarship",
            amount: "₹30,000",
            deadline: "05 Oct 2026",
          ),

        ],
      ),
    );
  }

  Widget _buildScholarshipCard(
      BuildContext context, {
        required String title,
        required String amount,
        required String deadline,
      }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          Text(
            "Amount : $amount",
            style: const TextStyle(
              fontSize: 16,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            "Deadline : $deadline",
            style: const TextStyle(
              color: Colors.grey,
            ),
          ),

          const SizedBox(height: 20),

          Row(
            children: [

              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Edit Feature Coming Soon ✏️"),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text("Edit"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    side: const BorderSide(
                      color: Color(0xFF2563EB),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 15),

              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Delete Feature Coming Soon 🗑️"),
                      ),
                    );
                  },
                  icon: const Icon(Icons.delete),
                  label: const Text("Delete"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

            ],
          ),

        ],
      ),
    );
  }
}