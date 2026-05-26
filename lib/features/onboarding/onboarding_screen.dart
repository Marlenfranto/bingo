import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_spacing.dart';
import '../../shared/theme/app_typography.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_text_field.dart';
import 'onboarding_controller.dart';
import 'validators.dart';

/// Required first-run profile setup. The router guarantees the user
/// can't bypass this screen — `currentUserProvider` stays null until
/// `submit()` writes the doc.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _company = TextEditingController();
  final _designation = TextEditingController();
  final _linkedin = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _company.dispose();
    _designation.dispose();
    _linkedin.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final controller = ref.read(onboardingControllerProvider.notifier);
    final ok = await controller.submit(
      name: _name.text,
      email: _email.text,
      company: _company.text,
      designation: _designation.text,
      linkedinUrl: _linkedin.text,
    );
    // No manual navigation — the router observes currentUserProvider
    // and redirects automatically once the doc is written.
    if (!ok && mounted) {
      final err = ref.read(onboardingControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err?.toString() ?? 'Failed to save profile')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final submission = ref.watch(onboardingControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.lg),
                  Text("Let's set you up", style: AppTypography.headline),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Your profile is what other players see when they scan you.',
                    style: AppTypography.bodyMuted,
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  AppTextField(
                    label: 'Name',
                    controller: _name,
                    hint: 'Jane Doe',
                    prefixIcon: Icons.person_outline,
                    textInputAction: TextInputAction.next,
                    required: true,
                    validator: (v) => Validators.required(v, field: 'Name'),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  AppTextField(
                    label: 'Email',
                    controller: _email,
                    hint: 'jane@example.com',
                    prefixIcon: Icons.mail_outline,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    required: true,
                    validator: Validators.email,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  AppTextField(
                    label: 'Company',
                    controller: _company,
                    hint: 'Where you work (optional)',
                    prefixIcon: Icons.business_outlined,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  AppTextField(
                    label: 'Designation',
                    controller: _designation,
                    hint: 'Your role (optional)',
                    prefixIcon: Icons.badge_outlined,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  AppTextField(
                    label: 'LinkedIn URL',
                    controller: _linkedin,
                    hint: 'https://linkedin.com/in/… (optional)',
                    prefixIcon: Icons.link,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.done,
                    validator: Validators.linkedinUrl,
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  AppButton(
                    label: submission.isLoading ? 'Saving…' : 'Continue',
                    icon: Icons.arrow_forward,
                    onPressed: submission.isLoading ? null : _submit,
                    loading: submission.isLoading,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
