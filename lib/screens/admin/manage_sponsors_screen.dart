import 'package:flutter/material.dart';

class ManageSponsorsScreen extends StatelessWidget {
  const ManageSponsorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      appBar: AppBar(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          "Manage Sponsors",
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [

          const Text(
            "Registered Sponsors",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            "View and manage all sponsors.",
            style: TextStyle(
              color: Colors.grey,
            ),
          ),

          const SizedBox(height: 25),

          _buildSponsorCard(
            context,
            sponsorName: "ABC Foundation",
            email: "abcfoundation@gmail.com",
            scholarships: "12",
          ),

          const SizedBox(height: 18),

          _buildSponsorCard(
            context,
            sponsorName: "Bright Future Trust",
            email: "brightfuture@gmail.com",
            scholarships: "8",
          ),

          const SizedBox(height: 18),

          _buildSponsorCard(
            context,
            sponsorName: "Helping Hands",
            email: "helpinghands@gmail.com",
            scholarships: "15",
          ),

        ],
      ),
    );
  }

  Widget _buildSponsorCard(
      BuildContext context, {
        required String sponsorName,
        required String email,
        required String scholarships,
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
            sponsorName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          Text("📧 Email : $email"),

          const SizedBox(height: 6),

          Text("🎓 Scholarships : $scholarships"),

          const SizedBox(height: 20),
          Row(
            children: [

              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Viewing $sponsorName Profile 👤"),
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
                        content: Text("$sponsorName Removed Successfully 🗑️"),
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