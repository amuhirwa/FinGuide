/*
 * Edit Profile Page
 * =================
 * Allows the user to update full name, Ubudehe category, and income frequency.
 */

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late String _ubudeheCategory;
  late String _incomeFrequency;

  static const _ubudeheOptions = [
    ('category_1', 'Category 1'),
    ('category_2', 'Category 2'),
    ('category_3', 'Category 3'),
    ('category_4', 'Category 4'),
  ];

  static const _incomeOptions = [
    ('daily', 'Daily'),
    ('weekly', 'Weekly'),
    ('bi_weekly', 'Bi-weekly'),
    ('monthly', 'Monthly'),
    ('irregular', 'Irregular'),
    ('seasonal', 'Seasonal'),
  ];

  @override
  void initState() {
    super.initState();
    final state = context.read<AuthBloc>().state;
    String name = '';
    String ubudehe = 'category_1';
    String income = 'monthly';
    if (state is AuthAuthenticated) {
      name = state.user.fullName;
      ubudehe = state.user.ubudeheCategory;
      income = state.user.incomeFrequency;
    }
    _nameController = TextEditingController(text: name);
    _ubudeheCategory = ubudehe;
    _incomeFrequency = income;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      context.read<AuthBloc>().add(
            AuthProfileUpdateRequested({
              'full_name': _nameController.text.trim(),
              'ubudehe_category': _ubudeheCategory,
              'income_frequency': _incomeFrequency,
            }),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthProfileUpdated) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context);
        } else if (state is AuthProfileUpdateError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            color: AppColors.textPrimary,
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Edit Profile',
            style: AppTypography.titleLarge.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar hint
                Center(
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                      boxShadow: AppShadows.medium,
                    ),
                    child: BlocBuilder<AuthBloc, AuthState>(
                      builder: (context, state) {
                        final name = state is AuthAuthenticated
                            ? state.user.fullName
                            : '';
                        return Center(
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'U',
                            style: AppTypography.displaySmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Full Name
                _label('Full Name'),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _nameController,
                  style: AppTypography.bodyLarge
                      .copyWith(color: AppColors.textPrimary),
                  decoration: _inputDecoration(
                    hint: 'Enter your full name',
                    icon: Icons.person_outline,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Name is required'
                      : null,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: AppSpacing.lg),

                // Ubudehe Category
                _label('Ubudehe Category'),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<String>(
                  value: _ubudeheCategory,
                  style: AppTypography.bodyLarge
                      .copyWith(color: AppColors.textPrimary),
                  decoration: _inputDecoration(
                    hint: 'Select category',
                    icon: Icons.category_outlined,
                  ),
                  items: _ubudeheOptions
                      .map((e) => DropdownMenuItem(
                            value: e.$1,
                            child: Text(e.$2),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _ubudeheCategory = v ?? _ubudeheCategory),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Income Frequency
                _label('Income Frequency'),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<String>(
                  value: _incomeFrequency,
                  style: AppTypography.bodyLarge
                      .copyWith(color: AppColors.textPrimary),
                  decoration: _inputDecoration(
                    hint: 'Select frequency',
                    icon: Icons.calendar_today_outlined,
                  ),
                  items: _incomeOptions
                      .map((e) => DropdownMenuItem(
                            value: e.$1,
                            child: Text(e.$2),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _incomeFrequency = v ?? _incomeFrequency),
                ),
                const SizedBox(height: AppSpacing.xxl),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, state) {
                      final isLoading = state is AuthProfileUpdating;
                      return ElevatedButton(
                        onPressed: isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.md),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          elevation: 2,
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : Text(
                                'Save Changes',
                                style: AppTypography.labelLarge.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: AppTypography.labelLarge.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      );

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) =>
      InputDecoration(
        hintText: hint,
        hintStyle:
            AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary),
        prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.md),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      );
}
