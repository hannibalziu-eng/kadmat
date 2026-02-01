// lib/src/core/services/photo_upload_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Service for handling photo uploads to Supabase Storage
/// Includes compression, retry logic, and error handling
class PhotoUploadService {
  final SupabaseClient _supabase;
  final String _bucketName = 'job-photos';
  final _uuid = const Uuid();

  PhotoUploadService(this._supabase);

  /// Upload a single photo to Supabase Storage
  /// Returns the public URL of the uploaded photo
  Future<String> uploadPhoto(
    XFile photo,
    String folder, {
    int maxRetries = 3,
  }) async {
    int attempts = 0;
    Exception? lastError;

    // Compress photo before upload
    // On Web, standard compression might be limited or require different handling.
    // For now, we skip compression on Web or handle it differently if needed.
    XFile fileToUpload = photo;

    if (!kIsWeb) {
      try {
        final compressed = await _compressFile(File(photo.path));
        // Convert File to XFile for uniformity
        fileToUpload = XFile(compressed.path);
      } catch (e) {
        debugPrint('⚠️ Compression failed, using original file: $e');
      }
    }

    while (attempts < maxRetries) {
      try {
        attempts++;
        debugPrint('📤 Uploading photo (attempt $attempts/$maxRetries)...');

        // Generate unique filename
        final extension = path.extension(fileToUpload.path);
        // Fallback for web if path is empty/blob
        final ext = extension.isEmpty ? '.jpg' : extension;

        final fileName = '${_uuid.v4()}$ext';
        final filePath = '$folder/$fileName';

        // Upload to Supabase Storage
        final bytes = await fileToUpload.readAsBytes();
        await _supabase.storage
            .from(_bucketName)
            .uploadBinary(
              filePath,
              bytes,
              fileOptions: FileOptions(
                contentType: _getContentType(ext),
                upsert: false,
              ),
            );

        // Get public URL
        final publicUrl = _supabase.storage
            .from(_bucketName)
            .getPublicUrl(filePath);

        debugPrint('✅ Photo uploaded successfully: $publicUrl');
        return publicUrl;
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        debugPrint('⚠️ Upload attempt $attempts failed: $e');

        if (attempts < maxRetries) {
          // Wait before retry (exponential backoff)
          await Future.delayed(Duration(seconds: attempts * 2));
        }
      }
    }

    throw Exception('فشل رفع الصورة بعد $maxRetries محاولات: $lastError');
  }

  /// Compress file to reduce size (Mobile only for now)
  Future<File> _compressFile(File file) async {
    final filePath = file.absolute.path;
    final lastIndex = filePath.lastIndexOf(Platform.pathSeparator);
    final newPath =
        '${filePath.substring(0, lastIndex)}/compressed_${DateTime.now().millisecondsSinceEpoch}.webp';

    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      newPath,
      quality: 85,
      minWidth: 1920,
      minHeight: 1920,
      format: CompressFormat.webp,
    );

    if (result == null) {
      throw Exception('Compression returned null');
    }

    final originalSize = await file.length();
    final compressedSize = await result.length();
    debugPrint(
      '📉 Compressed: ${(originalSize / 1024).toStringAsFixed(0)}KB -> ${(compressedSize / 1024).toStringAsFixed(0)}KB',
    );

    return File(result.path);
  }

  /// Upload multiple photos with progress callback
  /// Returns list of public URLs
  Future<List<String>> uploadMultiplePhotos(
    List<XFile> photos,
    String folder, {
    Function(int current, int total)? onProgress,
  }) async {
    final urls = <String>[];

    for (int i = 0; i < photos.length; i++) {
      try {
        final url = await uploadPhoto(photos[i], folder);
        urls.add(url);

        // Report progress
        if (onProgress != null) {
          onProgress(i + 1, photos.length);
        }
      } catch (e) {
        debugPrint('❌ Failed to upload photo ${i + 1}: $e');
        rethrow;
      }
    }

    return urls;
  }

  /// Delete a photo from Supabase Storage
  Future<void> deletePhoto(String photoUrl) async {
    try {
      // Extract file path from URL
      final uri = Uri.parse(photoUrl);
      final pathSegments = uri.pathSegments;

      // Find the bucket name and file path
      final bucketIndex = pathSegments.indexOf(_bucketName);
      if (bucketIndex == -1) {
        throw Exception('Invalid photo URL');
      }

      final filePath = pathSegments.sublist(bucketIndex + 1).join('/');

      await _supabase.storage.from(_bucketName).remove([filePath]);
      debugPrint('🗑️ Photo deleted: $filePath');
    } catch (e) {
      debugPrint('⚠️ Failed to delete photo: $e');
      throw Exception('فشل حذف الصورة');
    }
  }

  /// Pick photos from camera or gallery
  Future<List<XFile>> pickPhotos({
    required ImageSource source,
    int maxPhotos = 5,
  }) async {
    final picker = ImagePicker();
    final photos = <XFile>[];

    try {
      if (source == ImageSource.camera) {
        // Single photo from camera
        final XFile? photo = await picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 85,
        );

        if (photo != null) {
          photos.add(photo);
        }
      } else {
        // Multiple photos from gallery
        final List<XFile> pickedPhotos = await picker.pickMultiImage(
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 85,
        );

        // Limit to maxPhotos
        photos.addAll(pickedPhotos.take(maxPhotos));
      }

      debugPrint('📸 Picked ${photos.length} photos');
      return photos;
    } catch (e) {
      debugPrint('❌ Failed to pick photos: $e');
      throw Exception('فشل اختيار الصور');
    }
  }

  /// Get content type based on file extension
  String _getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  /// Validate photo file
  bool isValidPhoto(XFile photo) {
    final extension = path.extension(photo.path).toLowerCase();
    final validExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];
    return validExtensions.contains(extension);
  }

  /// Get photo file size in MB
  Future<double> getPhotoSizeMB(XFile photo) async {
    final bytes = await photo.length();
    return bytes / (1024 * 1024);
  }
}
