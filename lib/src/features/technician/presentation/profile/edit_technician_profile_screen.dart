import 'package:flutter/material.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/technician_repository.dart';
import '../../../auth/data/auth_repository.dart';

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
    final userProfile = ref.read(authRepositoryProvider).userProfile;
    if (userProfile != null) {
      if (mounted) {
        setState(() {
          _nameController.text = userProfile['full_name'] ?? '';
          _titleController.text = userProfile['title'] ?? '';
          _bioController.text = userProfile['bio'] ?? '';
          _locationController.text = userProfile['location'] ?? '';
        });
      }
    }
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
              // Avatar Edit (Simplified for now)
              Stack(
                children: [
                  CircleAvatar(
                    radius: 50.r,
                    backgroundImage: const NetworkImage(
                      'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400',
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: EdgeInsets.all(6.w),
                      decoration: const BoxDecoration(
                        color: Color(0xFF13b6ec),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 16.s,
                      ),
                    ),
                  ),
                ],
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
                              await ref
                                  .read(technicianRepositoryProvider)
                                  .updateProfile({
                                    'full_name': _nameController.text,
                                    'title': _titleController.text,
                                    'location': _locationController.text,
                                    'bio': _bioController.text,
                                  });

                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('تم حفظ التغييرات بنجاح'),
                                  ),
                                );
                                context.pop();
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('خطأ: $e')),
                                );
                              }
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
