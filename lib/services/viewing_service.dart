import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models.dart'; // Assuming models.dart defines VideoQuality

class ViewingService {
  static const String apiBaseUrl = 'https://besso.top/api/index.php';
  static const String apiKey = 'c9e9e6f3494be2ba7843259ee2b29f48';

  // الحصول على بيانات الفيلم (بما في ذلك روابط المشاهدة) بواسطة معرف الفيلم
  static Future<Map<String, dynamic>> getMovieData(String movieId) async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl?id=$movieId&key=$apiKey'),
      );

      if (response.statusCode == 200) {
        try {
          // تحليل استجابة JSON
          final decodedBody = json.decode(response.body);

          // التحقق مما إذا كانت الاستجابة عبارة عن مصفوفة تحتوي على عنصر واحد
          if (decodedBody is List && decodedBody.isNotEmpty) {
            // التحقق من أن العنصر الأول هو خريطة
            if (decodedBody[0] is Map<String, dynamic>) {
              print('تم استلام بيانات الفيلم بنجاح من API.');
              return decodedBody[0]; // إرجاع كائن الفيلم
            } else {
              print('العنصر الأول في استجابة API ليس خريطة.');
              return {'error': 'تنسيق بيانات API غير متوقع (العنصر ليس خريطة)'};
            }
          }
          // التحقق مما إذا كانت الاستجابة خريطة مباشرة (احتياطي)
          else if (decodedBody is Map<String, dynamic>) {
             print('تم استلام بيانات الفيلم بنجاح من API (تنسيق خريطة).');
             return decodedBody;
          }
          else {
            print('استجابة API ليست مصفوفة أو خريطة متوقعة.');
            return {'error': 'تنسيق بيانات API غير متوقع'}; 
          }
        } catch (e) {
          print('خطأ في تحليل استجابة API المشاهدة: $e');
          print('محتوى الاستجابة: ${response.body}'); // طباعة المحتوى للمساعدة في التصحيح
          return {'error': 'فشل في تحليل البيانات'};
        }
      } else {
        print('فشل في الحصول على بيانات الفيلم: ${response.statusCode}');
        print('محتوى الاستجابة: ${response.body}');
        return {'error': 'فشل في الاتصال بالخادم (${response.statusCode})'};
      }
    } catch (e) {
      print('خطأ في الحصول على بيانات الفيلم: $e');
      return {'error': 'خطأ في الاتصال'};
    }
  }

  // تحويل بيانات الفيلم المستلمة من API إلى قائمة جودات الفيديو
  // هذه الدالة تفترض أن movieData هو Map<String, dynamic> يمثل الفيلم
  static List<VideoQuality> extractVideoQualitiesFromData(Map<String, dynamic> movieData) {
    List<VideoQuality> qualities = [];
    print('محاولة استخراج جودات الفيديو من: $movieData'); // Debug print

    try {
      // التحقق من وجود مفتاح 'videos' وأن قيمته عبارة عن قائمة
      if (movieData.containsKey('videos') && movieData['videos'] is List) {
        List<dynamic> videos = movieData['videos'];

        // إضافة كل جودة فيديو إلى القائمة مع التحقق من النوع والقيم
        for (var video in videos) {
          if (video is Map<String, dynamic> &&
              video.containsKey('url') && video['url'] is String && video['url'].isNotEmpty &&
              video.containsKey('quality') && video['quality'] is String && video['quality'].isNotEmpty) 
          {
            qualities.add(
              VideoQuality(
                resolution: video['quality'],
                videoUrl: video['url'],
              ),
            );
          } else {
             print('تم تخطي عنصر فيديو غير صالح: $video');
          }
        }

        // ترتيب الجودات تنازلياً
        qualities.sort((a, b) => b.resolutionValue.compareTo(a.resolutionValue));

        print('تم استخراج ${qualities.length} جودة فيديو بنجاح.');

      } else {
         print('لم يتم العثور على مفتاح "videos" أو أنه ليس قائمة في بيانات الفيلم.');
      }
    } catch (e) {
      print('خطأ في استخراج جودات الفيديو من بيانات الفيلم: $e');
    }

    return qualities;
  }

  // --- الدوال القديمة (يمكن إزالتها أو تعديلها إذا لم تعد مستخدمة) ---
  /*
  // الحصول على رابط المشاهدة بواسطة معرف الفيلم
  static Future<Map<String, dynamic>> getMovieStreamUrl(String movieId) async {
    // ... (الكود القديم)
  }

  // تحويل استجابة API المشاهدة إلى تنسيق متوافق مع التطبيق
  static Future<List<VideoQuality>> convertApiResponseToVideoQualities(Map<String, dynamic> apiResponse) async {
    // ... (الكود القديم)
  }
  */
  // --- نهاية الدوال القديمة ---
}

