import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/photo_upload_service.dart';

final photoUploadServiceProvider = Provider<PhotoUploadService>((ref) {
  return PhotoUploadService(Supabase.instance.client);
});
