import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ApplicationDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> data;
  final String applicationId;

  const ApplicationDetailsScreen({
    super.key,
    required this.data,
    required this.applicationId,
  });

  @override
  Widget build(BuildContext context) {
    final String status = data["status"] ?? "Pending";

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

    String appliedDate = "Date not available";

    if (data["appliedAt"] != null &&
        data["appliedAt"] is Timestamp) {
      final timestamp = data["appliedAt"] as Timestamp;
      final date = timestamp.toDate();

      appliedDate =
      "${date.day.toString().padLeft(2, '0')}/"
          "${date.month.toString().padLeft(2, '0')}/"
          "${date.year}";
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      appBar: AppBar(
        title: const Text(
          "Application Details",
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Scholarship Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  Row(
                    children: [

                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(15),
                        ),

                        child: const Icon(
                          Icons.school_rounded,
                          color: Colors.blue,
                          size: 27,
                        ),
                      ),

                      const SizedBox(width: 14),

                      Expanded(
                        child: Text(
                          data["scholarshipTitle"] ??
                              "Scholarship",
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  const Divider(),

                  const SizedBox(height: 16),

                  _InfoRow(
                    icon: Icons.currency_rupee_rounded,
                    label: "Scholarship Amount",
                    value: data["amount"] ??
                        "Amount not available",
                  ),

                  const SizedBox(height: 14),

                  _InfoRow(
                    icon: Icons.calendar_today_rounded,
                    label: "Applied Date",
                    value: appliedDate,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Student Information
            const Text(
              "Student Information",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),

              child: Column(
                children: [

                  _InfoRow(
                    icon: Icons.person_outline_rounded,
                    label: "Name",
                    value: data["studentName"] ??
                        "Name not available",
                  ),

                  const SizedBox(height: 16),

                  _InfoRow(
                    icon: Icons.email_outlined,
                    label: "Email",
                    value: data["studentEmail"] ??
                        "Email not available",
                  ),

                  const SizedBox(height: 16),

                  _InfoRow(
                    icon: Icons.account_balance_rounded,
                    label: "College",
                    value: data["studentCollege"] ??
                        "College not available",
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Application Status
            const Text(
              "Application Status",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: statusColor.withOpacity(0.25),
                ),
              ),

              child: Row(
                children: [

                  Icon(
                    status == "Approved"
                        ? Icons.check_circle
                        : status == "Rejected"
                        ? Icons.cancel
                        : Icons.access_time_rounded,
                    color: statusColor,
                    size: 28,
                  ),

                  const SizedBox(width: 14),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [

                        Text(
                          status,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 4),

                        Text(
                          status == "Approved"
                              ? "Your application has been approved."
                              : status == "Rejected"
                              ? "Your application has been rejected."
                              : "Your application is under review.",
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Application ID
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
              ),

              child: Row(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [

                  const Icon(
                    Icons.fingerprint_rounded,
                    color: Colors.grey,
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [

                        const Text(
                          "Application ID",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),

                        const SizedBox(height: 4),

                        Text(
                          applicationId,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        Icon(
          icon,
          size: 20,
          color: Colors.grey,
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [

              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 3),

              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}