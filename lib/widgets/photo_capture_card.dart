import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../utils/app_colors.dart';

/// کارت مشترک «گرفتن عکس با دوربین»: عنوان، راهنما، پیش‌نمایش، و دکمه.
/// - با لمس عکس گرفته‌شده، تمام‌صفحه و قابل بزرگ‌نمایی باز می‌شود تا راننده
///   مطمئن شود نوشته‌های سند خوانا است.
/// - همین ویجت برای بقیهٔ مدارک (کارت ملی، گواهینامه، سلفی) هم قابل استفاده است.
class PhotoCaptureCard extends StatelessWidget {
  const PhotoCaptureCard({
    super.key,
    required this.label,
    required this.image,
    required this.buttonText,
    required this.retakeText,
    required this.placeholderIcon,
    required this.onPressed,
    this.hint,
    this.previewHeight = 170,
  });

  final String label;
  final String? hint;
  final XFile? image;
  final String buttonText;
  final String retakeText;
  final IconData placeholderIcon;
  final VoidCallback onPressed;
  final double previewHeight;

  void _zoom(BuildContext context) {
    final XFile? file = image;
    if (file == null) return;
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Image.file(File(file.path), fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.cardBackground,
                  foregroundColor: AppColors.textPrimary,
                ),
                onPressed: () => Navigator.pop(dialogContext),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool has = image != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: AppColors.cardBackground,
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          if (hint != null && hint!.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              hint!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.6,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 14),
          GestureDetector(
            onTap: has ? () => _zoom(context) : onPressed,
            child: Container(
              height: previewHeight,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.fieldBorder),
              ),
              child: has
                  ? Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        Image.file(
                          File(image!.path),
                          fit: BoxFit.cover,
                          // حافظه: نیازی به رمزگشایی تصویر در اندازهٔ کامل نیست
                          cacheWidth: 900,
                        ),
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBrand,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: AppColors.buttonText,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Center(
                      child: Icon(
                        placeholderIcon,
                        size: 64,
                        color: AppColors.handle,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 46,
            child: OutlinedButton.icon(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryBrand,
                side: BorderSide(color: AppColors.primaryBrand),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: Icon(
                has ? Icons.refresh_rounded : Icons.camera_alt_outlined,
                size: 20,
              ),
              label: Text(
                has ? retakeText : buttonText,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
