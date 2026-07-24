import 'package:flutter/material.dart';

class ApplicationsScreen extends StatelessWidget {
  const ApplicationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      appBar: AppBar(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          "Applications Received",
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
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            "Review applications submitted by students.",
            style: TextStyle(
              color: Colors.grey,
              fontSize: 15,
            ),
          ),

          const SizedBox(height: 25),

          _buildApplicationCard(
            context,
            studentName: "Vinothini",
            college: "P.K.R Arts College",
            course: "B.Sc Computer Science",
            scholarship: "Government Scholarship",
          ),

          const SizedBox(height: 20),

          _buildApplicationCard(
            context,
            studentName: "Rahul",
            college: "ABC Engineering College",
            course: "B.E Computer Science",
            scholarship: "Merit Scholarship",
          ),

          const SizedBox(height: 20),

          _buildApplicationCard(
            context,
            studentName: "Priya",
            college: "XYZ College",
            course: "BCA",
            scholarship: "Sports Scholarship",
          ),

        ],
      ),
    );
  }

  Widget _buildApplicationCard(
      BuildContext context, {
        required String studentName,
        required String college,
        required String course,
        required String scholarship,
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
            studentName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          Text("🎓 College : $college"),

          const SizedBox(height: 6),

          Text("📚 Course : $course"),

          const SizedBox(height: 6),

          Text("💰 Scholarship : $scholarship"),

          const SizedBox(height: 20),
          Row(
            children: [

              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          "$studentName Approved Successfully ✅",
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.check),
                  label: const Text("Approve"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
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
                          "$studentName Rejected ❌",
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.close),
                  label: const Text("Reject"),
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