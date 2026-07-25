import 'package:flutter/material.dart';

class ViewApplicationsScreen extends StatelessWidget {
  const ViewApplicationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      appBar: AppBar(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          "View Applications",
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [

          const Text(
            "Student Applications",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            "Review all scholarship applications.",
            style: TextStyle(
              color: Colors.grey,
            ),
          ),

          const SizedBox(height: 25),

          _buildApplicationCard(
            context,
            student: "Vinothini",
            scholarship: "Government Scholarship",
            sponsor: "ABC Foundation",
            status: "Pending",
          ),

          const SizedBox(height: 18),

          _buildApplicationCard(
            context,
            student: "Rahul",
            scholarship: "Merit Scholarship",
            sponsor: "Bright Future Trust",
            status: "Approved",
          ),

          const SizedBox(height: 18),

          _buildApplicationCard(
            context,
            student: "Priya",
            scholarship: "Sports Scholarship",
            sponsor: "Helping Hands",
            status: "Rejected",
          ),

        ],
      ),
    );
  }

  Widget _buildApplicationCard(
      BuildContext context, {
        required String student,
        required String scholarship,
        required String sponsor,
        required String status,
      }) {
    Color statusColor;

    switch (status) {
      case "Approved":
        statusColor = Colors.green;
        break;
      case "Rejected":
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.orange;
    }

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
            student,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          Text("🎓 Scholarship : $scholarship"),

          const SizedBox(height: 6),

          Text("🏢 Sponsor : $sponsor"),

          const SizedBox(height: 12),

          Chip(
            label: Text(status),
            backgroundColor: statusColor.withOpacity(0.15),
            labelStyle: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 20),
          Row(
            children: [

              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          "Viewing $student Application 👀",
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.visibility),
                  label: const Text("View"),
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
                        content: Text(
                          "$student Application Removed 🗑️",
                        ),
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