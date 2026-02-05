/*
 * Phone Input Field Widget
 * ========================
 * Rwandan phone number input with country code prefix
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';

/// Phone input field with Rwanda country code
class PhoneInputField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool enabled;

  const PhoneInputField({
    super.key,
    required this.controller,
    this.hintText = 'Phone number',
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.phone,
      enabled: enabled,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10),
        _RwandaPhoneFormatter(),
      ],
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Rwanda flag emoji
              const Text('🇷🇼', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                '+250',
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Container(width: 1, height: 24, color: AppColors.border),
            ],
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your phone number';
        }

        // Remove spaces and check length
        final cleaned = value.replaceAll(' ', '');
        if (cleaned.length != 10) {
          return 'Phone number must be 10 digits';
        }

        // Check if starts with valid prefix
        if (!cleaned.startsWith('07')) {
          return 'Phone number must start with 07';
        }

        return null;
      },
    );
  }
}

/// Custom formatter for Rwanda phone numbers (07X XXX XXXX)
class _RwandaPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(' ', '');
    final buffer = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      if (i == 3 || i == 6) {
        buffer.write(' ');
      }
      buffer.write(text[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
