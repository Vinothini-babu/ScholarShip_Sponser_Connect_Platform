import 'package:flutter/material.dart';

class ManageScholarshipsScreen extends StatelessWidget {
  const ManageScholarshipsScreen({super.key});

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
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [

          const Text(
            "Available Scholarships",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            "View and manage all scholarships.",
            style: TextStyle(
              color: Colors.grey,
            ),
          ),

          const SizedBox(height: 25),

          _buildScholarshipCard(
            context,
            title: "Government Scholarship",
            sponsor: "ABC Foundation",
            amount: "₹25,000",
          ),

          const SizedBox(height: 18),

          _buildScholarshipCard(
            context,
            title: "Merit Scholarship",
            sponsor: "Bright Future Trust",
            amount: "₹50,000",
          ),

          const SizedBox(height: 18),

          _buildScholarshipCard(
            context,
            title: "Sports Scholarship",
            sponsor: "Helping Hands",
            amount: "₹30,000",
          ),

        ],
      ),
    );
  }

  Widget _buildScholarshipCard(
      BuildContext context, {
        required String title,
        required String sponsor,
        required String amount,
      }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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

          Text("🏢 Sponsor : $sponsor"),

          const SizedBox(height: 6),

          Text("💰 Amount : $amount"),

          const SizedBox(height: 20),
          Row(
            children: [

              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Editing $title ✏️"),
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
                      SnackBar(
                        content: Text("$title Deleted Successfully 🗑️"),
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