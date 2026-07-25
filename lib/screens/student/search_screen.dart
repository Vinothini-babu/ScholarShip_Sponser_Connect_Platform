import 'package:flutter/material.dart';
import '../../services/scholarship_service.dart';
import '../../models/scholarship_model.dart';
import '../../services/application_service.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Search Scholarships",
          style: AppTextStyles.title.copyWith(fontSize: 18, color: AppColors.textPrimary),
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            TextField(
              controller: searchController,
              style: AppTextStyles.subtitle.copyWith(color: AppColors.textPrimary, fontSize: 15),
              decoration: InputDecoration(
                hintText: "Search Scholarship...",
                hintStyle: AppTextStyles.subtitle.copyWith(fontSize: 14),
                prefixIcon: Icon(Icons.search_rounded, color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.card,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.textSecondary.withOpacity(0.15)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.textSecondary.withOpacity(0.15)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.secondary, width: 1.6),
                ),
              ),
            ),

            const SizedBox(height: 20),

            Expanded(
              child: StreamBuilder<List<ScholarshipModel>>(
                stream: _service.getScholarships(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Text(
                        "No Scholarships Available",
                        style: AppTextStyles.subtitle,
                      ),
                    );
                  }

                  final scholarships = snapshot.data!;

                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 20),
                    itemCount: scholarships.length,
                    itemBuilder: (context, index) {
                      final scholarship = scholarships[index];

                      return _ScholarshipTile(
                        id: scholarship.id,
                        title: scholarship.title,
                        amount: scholarship.amount,
                        deadline: scholarship.deadline,
                        icon: Icons.school_rounded,
                        applicationService: _applicationService,
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
}

/// Same StatefulWidget-per-tile so each card can hold its own
/// "applying" loading state without rebuilding the whole list.
class _ScholarshipTile extends StatefulWidget {
  final String id;
  final String title;
  final String amount;
  final String deadline;
  final IconData icon;
  final ApplicationService applicationService;

  const _ScholarshipTile({
    required this.id,
    required this.title,
    required this.amount,
    required this.deadline,
    required this.icon,
    required this.applicationService,
  });

  @override
  State<_ScholarshipTile> createState() => _ScholarshipTileState();
}

class _ScholarshipTileState extends State<_ScholarshipTile> {
  bool _isApplying = false;

  Future<void> _handleApply() async {
    setState(() => _isApplying = true);
    try {
      await widget.applicationService.applyScholarship(
        scholarshipId: widget.id,
        scholarshipTitle: widget.title,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Application Submitted Successfully 🎉")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _isApplying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
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
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(widget.icon, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  widget.title,
                  style: AppTextStyles.subtitle.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Icon(Icons.currency_rupee_rounded, size: 15, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                widget.amount,
                style: AppTextStyles.subtitle.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 18),
              Icon(Icons.calendar_today_rounded, size: 13, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                widget.deadline,
                style: AppTextStyles.subtitle.copyWith(fontSize: 13),
              ),
            ],
          ),

          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isApplying ? null : _handleApply,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isApplying
                  ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
                  : const Text("Apply"),
            ),
          ),
        ],
      ),
    );
  }
}
