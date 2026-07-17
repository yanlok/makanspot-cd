import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class SupabaseStorageService {
  final SupabaseClient _supabase;

  SupabaseStorageService(this._supabase);

  Future<String> uploadImage({
    required String bucket,
    required File file,
    String? customPath,
  }) async {
    final fileExt = file.path.split('.').last;
    final fileName = '${const Uuid().v4()}.$fileExt';
    final filePath = customPath != null ? '$customPath/$fileName' : fileName;

    await _supabase.storage.from(bucket).upload(
          filePath,
          file,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
        );

    return _supabase.storage.from(bucket).getPublicUrl(filePath);
  }

  Future<List<String>> uploadMultipleImages({
    required String bucket,
    required List<File> files,
    String? customPath,
  }) async {
    List<String> urls = [];
    for (var file in files) {
      final url = await uploadImage(bucket: bucket, file: file, customPath: customPath);
      urls.add(url);
    }
    return urls;
  }
}
