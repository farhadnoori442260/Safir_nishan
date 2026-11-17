import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:safir_drivers/pages/auth/register_screen.dart';
import 'package:safir_drivers/utils/app_colors.dart';
import 'package:safir_drivers/utils/lang_helper.dart';

class BlockedScreen extends StatefulWidget {
  const BlockedScreen({super.key});

  @override
  State<BlockedScreen> createState() => _BlockedScreenState();
}

class _BlockedScreenState extends State<BlockedScreen> {
  static const String _supportEmail = 'farhadnoori442@gmail.com';

  Future<void> _copyEmail() async {
    await Clipboard.setData(const ClipboardData(text: _supportEmail));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'کپی شد',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        backgroundColor: AppColors.cardBackground,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.block_rounded,
                  color: AppColors.danger,
                  size: 80,
                ),
                const SizedBox(height: 24),
                Text(
                  tr(context, 'account_blocked_msg'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'IranYekan',
                    fontSize: 15,
                    color: AppColors.textPrimary,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 12),
                // ایمیل پشتیبانی؛ با لمس کپی می‌شود
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: _copyEmail,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _supportEmail,
                          textDirection: TextDirection.ltr,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.copy_rounded,
                            size: 16, color: AppColors.iconSecondary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.6,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryButton,
                      foregroundColor: AppColors.buttonText,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (c) => const RegisterScreen(),
                        ),
                      );
                    },
                    child: Text(
                      tr(context, 'btn_got_it'),
                      style: const TextStyle(
                        fontFamily: 'IranYekan',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
