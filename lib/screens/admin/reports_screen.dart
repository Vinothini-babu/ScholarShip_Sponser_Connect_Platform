import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Reports"),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            const Text(
              "Reports & Analytics",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 25),

            Row(
              children: [

                Expanded(
                  child: reportCard(
                    "Students",
                    Icons.people,
                    Colors.blue,
                    "students",
                  ),
                ),

                const SizedBox(width: 15),

                Expanded(
                  child: reportCard(
                    "Sponsors",
                    Icons.business,
                    Colors.green,
                    "sponsors",
                  ),
                ),

              ],
            ),

            const SizedBox(height: 15),

            Row(
              children: [

                Expanded(
                  child: reportCard(
                    "Scholarships",
                    Icons.school,
                    Colors.orange,
                    "scholarships",
                  ),
                ),

                const SizedBox(width: 15),

                Expanded(
                  child: reportCard(
                    "Applications",
                    Icons.assignment,
                    Colors.purple,
                    "applications",
                  ),
                ),

              ],
            ),

            const SizedBox(height: 25),

            const Text(
              "Application Status",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 15),

            statusCard(),

          ],
        ),
      ),
    );
  }

  Widget reportCard(
      String title,
      IconData icon,
      Color color,
      String collection,
      ) {
    return StreamBuilder<QuerySnapshot>(
      stream: collection == "students"
          ? FirebaseFirestore.instance
          .collection("users")
          .where("role", isEqualTo: "student")
          .snapshots()
          : collection == "sponsors"
          ? FirebaseFirestore.instance
          .collection("users")
          .where("role", isEqualTo: "sponsor")
          .snapshots()
          : FirebaseFirestore.instance
          .collection(collection)
          .snapshots(),
      builder: (context, snapshot) {

        int count = 0;

        if (snapshot.hasData) {
          count = snapshot.data!.docs.length;
        }

        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [

                CircleAvatar(
                  radius: 24,
                  backgroundColor: color.withOpacity(.15),
                  child: Icon(
                    icon,
                    color: color,
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  count.toString(),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                Text(title),

              ],
            ),
          ),
        );
      },
    );
  }

  Widget statusCard() {

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("applications")
          .snapshots(),
      builder: (context, snapshot) {

        int approved = 0;
        int pending = 0;
        int rejected = 0;

        if (snapshot.hasData) {

          for (var doc in snapshot.data!.docs) {

            final data = doc.data() as Map<String, dynamic>;

            if (data["status"] == "Approved") {
              approved++;
            } else if (data["status"] == "Rejected") {
              rejected++;
            } else {
              pending++;
            }
          }
        }

        return Column(
          children: [

            ListTile(
              leading: const Icon(
                Icons.check_circle,
                color: Colors.green,
              ),
              title: const Text("Approved"),
              trailing: Text(
                approved.toString(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            ListTile(
              leading: const Icon(
                Icons.hourglass_top,
                color: Colors.orange,
              ),
              title: const Text("Pending"),
              trailing: Text(
                pending.toString(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            ListTile(
              leading: const Icon(
                Icons.cancel,
                color: Colors.red,
              ),
              title: const Text("Rejected"),
              trailing: Text(
                rejected.toString(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          ],
        );
      },
    );
  }
}