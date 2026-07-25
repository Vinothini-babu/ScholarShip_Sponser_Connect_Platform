import 'package:flutter/material.dart';
import '../../services/scholarship_service.dart';
import '../../models/scholarship_model.dart';
import '../../services/application_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController searchController = TextEditingController();
  final ScholarshipService _service = ScholarshipService();
  final ApplicationService _applicationService = ApplicationService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Search Scholarships",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [

            TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: "Search Scholarship...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 20),

            Expanded(
              child: StreamBuilder<List<ScholarshipModel>>(
                stream: _service.getScholarships(),
                builder: (context, snapshot) {

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Text("No Scholarships Available"),
                    );
                  }

                  final scholarships = snapshot.data!;

                  return ListView.builder(
                    itemCount: scholarships.length,
                    itemBuilder: (context, index) {

                      final scholarship = scholarships[index];

                      return scholarshipCard(
                        id: scholarship.id,
                        title: scholarship.title,
                        amount: scholarship.amount,
                        deadline: scholarship.deadline,
                        icon: Icons.school,
                      );

                    },
                  );

                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget scholarshipCard({
    required String id,
    required String title,
    required String amount,
    required String deadline,
    required IconData icon,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 18),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Row(
              children: [

                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFFEFF6FF),
                  child: Icon(
                    icon,
                    color: const Color(0xFF2563EB),
                  ),
                ),

                const SizedBox(width: 15),

                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

              ],
            ),

            const SizedBox(height: 15),

            Text(
              "Amount : $amount",
              style: const TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 5),

            Text(
              "Deadline : $deadline",
              style: const TextStyle(
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 18),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  try {

                    await _applicationService.applyScholarship(
                      scholarshipId: id,
                      scholarshipTitle: title,
                    );

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Application Submitted Successfully 🎉"),
                      ),
                    );

                  } catch (e) {

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(e.toString()),
                      ),
                    );

                  }
                },                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text("Apply"),
              ),
            ),

          ],
        ),
      ),
    );
  }
}