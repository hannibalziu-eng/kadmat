import 'package:flutter/material.dart';
import 'package:flutter_scalify/flutter_scalify.dart';
import 'package:go_router/go_router.dart';

class EditTechnicianProfileScreen extends StatefulWidget {
  const EditTechnicianProfileScreen({super.key});

  @override
  State<EditTechnicianProfileScreen> createState() => _EditTechnicianProfileScreenState();
}

class _EditTechnicianProfileScreenState extends State<EditTechnicianProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: 'عبدالله المنصور');
  final _titleController = TextEditingController(text: 'سباك محترف');
  final _bioController = TextEditingController(text: 'سباك محترف بخبرة تمتد لأكثر من 8 سنوات...');
  final _locationController = TextEditingController(text: 'الرياض، المملكة العربية السعودية');

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
              // Avatar Edit
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
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      // TODO: Implement save logic
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم حفظ التغييرات بنجاح')),
                      );
                      context.pop();
                    }
                  },
                  child: const Text('حفظ التغييرات'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
