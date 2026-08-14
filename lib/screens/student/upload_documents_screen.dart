import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class UploadDocumentsScreen extends StatefulWidget {
  const UploadDocumentsScreen({super.key});

  @override
  State<UploadDocumentsScreen> createState() =>
      _UploadDocumentsScreenState();
}

class _UploadDocumentsScreenState
    extends State<UploadDocumentsScreen> {

  // =============================================================
  // DOCUMENT FILE NAMES
  // =============================================================

  String? _marksheetName;
  String? _idProofName;
  String? _incomeCertificateName;
  String? _collegeIdName;

  // =============================================================
  // UPLOAD STATUS
  // =============================================================

  bool _isUploading = false;

  // =============================================================
  // PICK DOCUMENT
  // =============================================================
  Future<void> _pickDocument(String documentType) async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: [
          "pdf",
          "jpg",
          "jpeg",
          "png",
        ],
      );

      if (file == null) {
        return;
      }

      if (!mounted) return;

      setState(() {
        switch (documentType) {
          case "marksheet":
            _marksheetName = file.name;
            break;

          case "idProof":
            _idProofName = file.name;
            break;

          case "income":
            _incomeCertificateName = file.name;
            break;

          case "collegeId":
            _collegeIdName = file.name;
            break;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("${file.name} selected"),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Unable to select document: $e"),
        ),
      );
    }
  }

  // =============================================================
  // BUILD
  // =============================================================

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text("Please login again"),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,

        iconTheme: IconThemeData(
          color: AppColors.textPrimary,
        ),

        title: Text(
          "Upload Documents",
          style: AppTextStyles.title.copyWith(
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            Text(
              "Required Documents",
              style: AppTextStyles.title.copyWith(
                fontSize: 20,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              "Upload the documents required for your scholarship application.",
              style: AppTextStyles.subtitle,
            ),

            const SizedBox(height: 24),

            // PART 2 CONTINUES HERE            // =====================================================
            // MARKSHEET
            // =====================================================

            _buildDocumentCard(
              title: "Marksheet",
              subtitle: "Upload your latest academic marksheet",
              icon: Icons.description_rounded,
              fileName: _marksheetName,
              onTap: () {
                _pickDocument("marksheet");
              },
            ),

            const SizedBox(height: 16),

            // =====================================================
            // ID PROOF
            // =====================================================

            _buildDocumentCard(
              title: "ID Proof",
              subtitle: "Upload Aadhaar / valid ID proof",
              icon: Icons.badge_rounded,
              fileName: _idProofName,
              onTap: () {
                _pickDocument("idProof");
              },
            ),

            const SizedBox(height: 16),

            // =====================================================
            // INCOME CERTIFICATE
            // =====================================================

            _buildDocumentCard(
              title: "Income Certificate",
              subtitle: "Upload your latest income certificate",
              icon: Icons.account_balance_wallet_rounded,
              fileName: _incomeCertificateName,
              onTap: () {
                _pickDocument("income");
              },
            ),

            const SizedBox(height: 16),

            // =====================================================
            // COLLEGE ID
            // =====================================================

            _buildDocumentCard(
              title: "College ID",
              subtitle: "Upload your valid college ID",
              icon: Icons.school_rounded,
              fileName: _collegeIdName,
              onTap: () {
                _pickDocument("collegeId");
              },
            ),

            const SizedBox(height: 30),

            // =====================================================
            // UPLOAD / CONTINUE BUTTON
            // =====================================================

            SizedBox(
              width: double.infinity,

              child: ElevatedButton(
                onPressed: _isUploading
                    ? null
                    : () {
                  _submitDocuments();
                },

                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,

                  padding: const EdgeInsets.symmetric(
                    vertical: 15,
                  ),

                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),

                  elevation: 0,
                ),

                child: _isUploading
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Text(
                  "Continue",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // =============================================================
  // DOCUMENT CARD
  // =============================================================

  Widget _buildDocumentCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required String? fileName,
    required VoidCallback onTap,
  }) {
    final bool selected = fileName != null;

    return Container(
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),

        border: Border.all(
          color: selected
              ? AppColors.success.withOpacity(0.35)
              : AppColors.textSecondary.withOpacity(0.12),
        ),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),

      child: Row(
        children: [

          // =====================================================
          // ICON
          // =====================================================

          Container(
            width: 48,
            height: 48,

            decoration: BoxDecoration(
              color: selected
                  ? AppColors.success.withOpacity(0.12)
                  : AppColors.primary.withOpacity(0.10),

              borderRadius: BorderRadius.circular(14),
            ),

            child: Icon(
              selected
                  ? Icons.check_circle_rounded
                  : icon,

              color: selected
                  ? AppColors.success
                  : AppColors.primary,

              size: 24,
            ),
          ),

          const SizedBox(width: 14),

          // =====================================================
          // TEXT
          // =====================================================

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Text(
                  title,
                  style: AppTextStyles.subtitle.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  selected
                      ? fileName!
                      : subtitle,

                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,

                  style: AppTextStyles.subtitle.copyWith(
                    fontSize: 12,
                    color: selected
                        ? AppColors.success
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // =====================================================
          // PICK BUTTON
          // =====================================================

          OutlinedButton(
            onPressed: onTap,

            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,

              side: BorderSide(
                color: AppColors.primary,
              ),

              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 9,
              ),

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            child: Text(
              selected ? "Change" : "Upload",
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =============================================================
  // SUBMIT DOCUMENTS
  // =============================================================

  Future<void> _submitDocuments() async {
    if (_marksheetName == null ||
        _idProofName == null ||
        _incomeCertificateName == null ||
        _collegeIdName == null) {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Please upload all required documents",
          ),
        ),
      );

      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      // ---------------------------------------------------------
      // TEMPORARY SUCCESS
      // ---------------------------------------------------------
      //
      // Firebase Storage upload will be connected in the
      // next step.
      //

      await Future.delayed(
        const Duration(seconds: 1),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Documents selected successfully",
          ),
        ),
      );

    } catch (e) {

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Unable to process documents: $e",
          ),
        ),
      );

    } finally {

      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }
}