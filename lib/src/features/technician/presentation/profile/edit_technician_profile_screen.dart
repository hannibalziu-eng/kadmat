import 'package:flutter/material.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/technician_repository.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../../core/utils/error_handler.dart';

class EditTechnicianProfileScreen extends ConsumerStatefulWidget {
  const EditTechnicianProfileScreen({super.key});

  @override
  ConsumerState<EditTechnicianProfileScreen> createState() =>
      _EditTechnicianProfileScreenState();
}

class _EditTechnicianProfileScreenState
    extends ConsumerState<EditTechnicianProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _titleController;
  late TextEditingController _bioController;
  late TextEditingController _locationController;
  String? _avatarUrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // The original code had some comments about fetching user, which are now addressed by the new _loadProfile implementation.
    // Keeping the initialization of controllers here as per the instruction.
    _nameController = TextEditingController(text: '');
    _titleController = TextEditingController(text: '');
    _bioController = TextEditingController(text: '');
    _locationController = TextEditingController(text: '');

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfile());
  }

  Future<void> _loadProfile() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    Map<String, dynamic>? snapshot;
    try {
      final profile = await ref
          .read(technicianRepositoryProvider)
          .getTechnicianProfile(currentUser.id);
      snapshot = {
        'full_name': profile.fullName,
        'title': profile.title,
        'bio': profile.bio,
        'location': profile.location,
        'profile_image_url': profile.profileImageUrl,
      };
    } catch (_) {
      snapshot = ref.read(authRepositoryProvider).userProfile;
    }

    if (snapshot == null || !mounted) return;
    setState(() {
      _nameController.text = (snapshot!['full_name'] ?? '').toString();
      _titleController.text = (snapshot['title'] ?? '').toString();
      _bioController.text = (snapshot['bio'] ?? '').toString();
      _locationController.text = (snapshot['location'] ?? '').toString();
      _avatarUrl =
          snapshot['avatar_url'] as String? ??
          snapshot['profile_image_url'] as String?;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _titleController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تعديل الملف الشخصي'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward_ios),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              CircleAvatar(
                radius: 50.r,
                backgroundColor: Colors.grey.shade300,
                backgroundImage: _avatarUrl != null && _avatarUrl!.isNotEmpty
                    ? NetworkImage(_avatarUrl!)
                    : null,
                child: _avatarUrl == null || _avatarUrl!.isEmpty
                    ? Icon(Icons.person, color: Colors.white, size: 40.s)
                    : null,
              ),
              SizedBox(height: 32.h),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'الاسم الكامل',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value!.isEmpty ? 'مطلوب' : null,
              ),
              SizedBox(height: 16.h),

              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'المسمى الوظيفي',
                  prefixIcon: Icon(Icons.work_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16.h),

              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'الموقع',
                  prefixIcon: Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16.h),

              TextFormField(
                controller: _bioController,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'نبذة شخصية',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 32.h),

              SizedBox(
                width: double.infinity,
                height: 50.h,
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () async {
                          if (_formKey.currentState!.validate()) {
                            setState(() => _isLoading = true);
                            try {
                              final updates = {
                                'full_name': _nameController.text.trim(),
                                'title': _titleController.text.trim(),
                                'location': _locationController.text.trim(),
                                'bio': _bioController.text.trim(),
                              };
                              await ref
                                  .read(technicianRepositoryProvider)
                                  .updateProfile(updates);
                              ref
                                  .read(authRepositoryProvider)
                                  .mergeCachedUserProfile(updates);

                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('تم حفظ التغييرات بنجاح'),
                                ),
                              );
                              context.pop();
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(ErrorHandler.getMessage(e)),
                                ),
                              );
                            } finally {
                              if (mounted) setState(() => _isLoading = false);
                            }
                          }
                        },
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('حفظ التغييرات'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
