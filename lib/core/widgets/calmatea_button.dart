import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class CalmaTeaButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final bool isOutlined;
  final Color? backgroundColor;
  final Color? textColor;

  const CalmaTeaButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.isOutlined = false,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = isLoading ? null : onPressed;

    final childContent = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(
                isOutlined
                    ? (textColor ?? AppColors.primary)
                    : (textColor ?? AppColors.textOnPrimary),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Procesando...',
            style: TextStyle(
              color: isOutlined
                  ? (textColor ?? AppColors.primary)
                  : (textColor ?? AppColors.textOnPrimary),
            ),
          ),
        ] else ...[
          if (icon != null) ...[
            Icon(icon, size: 20),
            const SizedBox(width: 8),
          ],
          Text(text),
        ],
      ],
    );

    if (isOutlined) {
      return OutlinedButton(
        onPressed: effectiveOnPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: textColor ?? AppColors.primary,
          side: BorderSide(
            color: backgroundColor ?? AppColors.primary,
            width: 1.5,
          ),
        ),
        child: childContent,
      );
    }

    return ElevatedButton(
      onPressed: effectiveOnPressed,
      style: backgroundColor != null
          ? ElevatedButton.styleFrom(
              backgroundColor: backgroundColor,
              foregroundColor: textColor ?? AppColors.textOnPrimary,
            )
          : null,
      child: childContent,
    );
  }
}
