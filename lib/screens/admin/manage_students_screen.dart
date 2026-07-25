import 'package:flutter/material.dart';

class ManageStudentsScreen extends StatelessWidget {
  const ManageStudentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      appBar: AppBar(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          "Manage Students",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),

      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [

          const Text(
            "Registered Students",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            "View and manage all registered students.",
            style: TextStyle(
              color: Colors.grey,
            ),
          ),

          const SizedBox(height: 25),

          _buildStudentCard(
            context,
            name: "Vinothini",
            email: "vinothini@gmail.com",
            college: "P.K.R Arts College",
          ),

          const SizedBox(height: 18),

          _buildStudentCard(
            context,
            name: "Rahul",
            email: "rahul@gmail.com",
            college: "ABC Engineering College",
          ),

          const SizedBox(height: 18),

          _buildStudentCard(
            context,
            name: "Priya",
            email: "priya@gmail.com",
            college: "XYZ College",
          ),

        ],
      ),
    );
  }

  Widget _buildStudentCard(
      BuildContext context, {
        required String name,
        required String email,
        required String college,
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
            name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          Text("📧 Email : $email"),

          const SizedBox(height: 6),

          Text("🏫 College : $college"),

          const SizedBox(height: 20),
          Row(
            children: [

              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Viewing $name Profile 👤"),
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
                        content: Text("$name Removed Successfully 🗑️"),
                      ),
                    );
                  },
                  icon: const Icon(Icons.delete),
                  label: const Text("Remove"),
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