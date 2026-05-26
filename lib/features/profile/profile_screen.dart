import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:namma_bingo/features/auth/auth_service.dart';

import '../../data/models/user_model.dart';
import '../../data/repositories/user_repository.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_spacing.dart';
import '../../shared/theme/app_typography.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_skeleton.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/profile_avatar.dart';
import '../auth/auth_providers.dart';
import '../onboarding/validators.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _company = TextEditingController();
  final _designation = TextEditingController();
  final _linkedin = TextEditingController();

  bool _saving = false;
  bool _hydrated = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _company.dispose();
    _designation.dispose();
    _linkedin.dispose();
    super.dispose();
  }

  void _hydrate(UserModel u) {
    if (_hydrated) return;
    _name.text = u.name;
    _email.text = u.email;
    _company.text = u.company ?? '';
    _designation.text = u.designation ?? '';
    _linkedin.text = u.linkedinUrl ?? '';
    _hydrated = true;
  }

  Future<void> _save(UserModel current) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final updated = current.copyWith(
      name: _name.text.trim(),
      email: _email.text.trim(),
      company: _orNull(_company.text),
      designation: _orNull(_designation.text),
      linkedinUrl: _orNull(_linkedin.text),
    );

    final result =
        await ref.read(userRepositoryProvider).upsertProfile(updated);
    if (!mounted) return;
    setState(() => _saving = false);

    result.when(
      ok: (_) => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      ),
      err: (e) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      ),
    );
  }

  String? _orNull(String value) {
    final t = value.trim();
    return t.isEmpty ? null : t;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Profile')),
      body: user.when(
        loading: () => const _SkeletonForm(),
        error: (e, _) => Center(
          child: Text(e.toString(), style: AppTypography.bodyMuted),
        ),
        data: (u) {
          if (u == null) {
            return const Center(
              child: Text('No profile yet', style: AppTypography.bodyMuted),
            );
          }
          _hydrate(u);
          return _ProfileForm(
            formKey: _formKey,
            user: u,
            name: _name,
            email: _email,
            company: _company,
            designation: _designation,
            linkedin: _linkedin,
            onSave: () => _save(u),
            saving: _saving,
            onSignOut: () async {
              await ref.read(authServiceProvider).signOut();
            },
          );
        },
      ),
    );
  }
}

class _ProfileForm extends StatelessWidget {
  const _ProfileForm({
    required this.formKey,
    required this.user,
    required this.name,
    required this.email,
    required this.company,
    required this.designation,
    required this.linkedin,
    required this.onSave,
    required this.saving,
    required this.onSignOut,
  });

  final GlobalKey<FormState> formKey;
  final UserModel user;
  final TextEditingController name;
  final TextEditingController email;
  final TextEditingController company;
  final TextEditingController designation;
  final TextEditingController linkedin;
  final VoidCallback onSave;
  final bool saving;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: ProfileAvatar(
                  name: user.name,
                  size: 120,
                  borderWidth: 2,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppTextField(
                label: 'Name',
                controller: name,
                prefixIcon: Icons.person_outline,
                textInputAction: TextInputAction.next,
                required: true,
                validator: (v) => Validators.required(v, field: 'Name'),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Email',
                controller: email,
                prefixIcon: Icons.mail_outline,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                required: true,
                validator: Validators.email,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Company',
                controller: company,
                prefixIcon: Icons.business_outlined,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Designation',
                controller: designation,
                prefixIcon: Icons.badge_outlined,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'LinkedIn URL',
                controller: linkedin,
                prefixIcon: Icons.link,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                validator: Validators.linkedinUrl,
              ),
              const SizedBox(height: AppSpacing.xxl),
              AppButton(
                label: saving ? 'Saving…' : 'Save changes',
                icon: Icons.check,
                onPressed: saving ? null : onSave,
                loading: saving,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'Sign out',
                icon: Icons.logout,
                variant: AppButtonVariant.tertiary,
                onPressed: onSignOut,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkeletonForm extends StatelessWidget {
  const _SkeletonForm();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: AppSkeleton.circle(size: 120)),
          const SizedBox(height: AppSpacing.xl),
          for (var i = 0; i < 5; i++) ...[
            const AppSkeleton(width: 80),
            const SizedBox(height: AppSpacing.xs),
            const AppSkeleton(height: 48),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}
