import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isPrimary;
  final bool isLoading;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isPrimary = true,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isPrimary) {
      return ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        child: isLoading 
            ? const SizedBox(
                height: 20, 
                width: 20, 
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
              )
            : Text(text),
      );
    }

    // Secondary Button
    return TextButton(
      onPressed: isLoading ? null : onPressed,
      style: TextButton.styleFrom(
        backgroundColor: AppTheme.surfaceControl,
        foregroundColor: AppTheme.textPrimary,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppTheme.borderSubtle, width: 1),
        ),
      ),
      child: isLoading 
            ? const SizedBox(
                height: 20, 
                width: 20, 
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.textPrimary)
              )
            : Text(text),
    );
  }
}
