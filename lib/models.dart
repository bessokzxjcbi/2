import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart'; // إضافة مكتبة استخراج روابط يوتيوب
import 'services/tmdb_service.dart';
import 'services/viewing_service.dart';

// نموذج لتخزين معلومات الفيديو
class VideoQuality {
  final String resolution;
  final String videoUrl;
  
  VideoQuality({required this.resolution, required this.videoUrl});
  
  // تحويل الدقة إلى رقم للمقارنة
  int get resolutionValue {
    // إزالة حرف p من نهاية الدقة وتحويلها إلى رقم
    return int.tryParse(resolution.replaceAll('p', '')) ?? 0;
  }
}

// نموذج لتخزين معلومات الممثل
class Actor {
  final String name;
  final String character;
  final String? profilePath;
  
  Actor({required this.name, required this.character, this.profilePath});
  
  String get profileUrl {
    if (profilePath != null && profilePath!.isNotEmpty) {
      return 'https://image.tmdb.org/t/p/w200$profilePath';
    }
    return ''; // صورة افتراضية أو فارغة
  }
}

// دالة للحصول على روابط فيديو مباشرة بناءً على معرف الفيلم
Future<List<VideoQuality>> getVideoQualities(String movieId) async {
  try {
    print("جاري البحث عن الفيلم بمعرف: $movieId باستخدام API المشاهدة");
    
    // استخدام خدمة المشاهدة المخصصة للحصول على بيانات الفيلم
    final movieData = await ViewingService.getMovieData(movieId);
    
    if (movieData.containsKey('error')) {
      print("خطأ في الحصول على بيانات الفيلم: ${movieData['error']}");
      
      // في حالة الفشل، نحاول استخدام الملفات المحلية كاحتياطي
      print("محاولة استخدام الملفات المحلية كاحتياطي...");
      
      // قراءة ملفات JSON المحلية للتحقق من وجود الفيلم
      String moviesJson = "";
      String movieLinksJson = "";
      String videosJson = "";
      
      try {
        moviesJson = await rootBundle.loadString('assets/movies.json');
        print("تم تحميل movies.json بنجاح");
      } catch (e) {
        print("خطأ في تحميل movies.json: $e");
        moviesJson = '[]';
      }
      
      try {
        movieLinksJson = await rootBundle.loadString('assets/movie_links.json');
        print("تم تحميل movie_links.json بنجاح");
      } catch (e) {
        print("خطأ في تحميل movie_links.json: $e");
        movieLinksJson = '[]';
      }
      
      try {
        videosJson = await rootBundle.loadString('assets/videos.json');
        print("تم تحميل videos.json بنجاح");
      } catch (e) {
        print("خطأ في تحميل videos.json: $e");
        videosJson = '[]';
      }
      
      // تحويل البيانات إلى كائنات Dart
      final localMoviesData = json.decode(moviesJson);
      final movieLinksData = json.decode(movieLinksJson);
      final videosData = json.decode(videosJson);
      
      // البحث عن الفيلم في قائمة الأفلام
      Map<String, dynamic>? movie;
      
      for (var item in localMoviesData) {
        if (item['id'] == movieId) {
          movie = item;
          break;
        }
      }
      
      if (movie == null) {
        print("الفيلم غير موجود في ملف movies.json");
        return [];
      }
      
      // البحث عن روابط الفيلم في ملف movie_links.json
      List<dynamic> movieLinks = [];
      for (var item in movieLinksData) {
        if (item['id'] == movieId) {
          movieLinks = item['links'] ?? [];
          break;
        }
      }
      
      if (movieLinks.isEmpty) {
        print("لا توجد روابط للفيلم في ملف movie_links.json");
        return [];
      }
      
      // تحويل الروابط إلى كائنات VideoQuality
      List<VideoQuality> qualities = [];
      for (var link in movieLinks) {
        qualities.add(
          VideoQuality(
            resolution: link['quality'] ?? '720p',
            videoUrl: link['url'] ?? '',
          ),
        );
      }
      
      // ترتيب الجودات تنازلياً
      qualities.sort((a, b) => b.resolutionValue.compareTo(a.resolutionValue));
      
      return qualities;
    } else {
      // استخدام الدالة الجديدة لاستخراج جودات الفيديو من بيانات الفيلم
      return ViewingService.extractVideoQualitiesFromData(movieData);
    }
  } catch (e) {
    print("خطأ في الحصول على روابط الفيديو: $e");
    return [];
  }
}

// دالة مساعدة لاستخراج معرف فيديو YouTube من الرابط
String? extractYoutubeId(String url) {
  // أنماط روابط YouTube المختلفة
  RegExp regExp1 = RegExp(
    r'^https?:\/\/(?:www\.)?youtube\.com\/watch\?(?=.*v=([a-zA-Z0-9_-]+)).*$',
    caseSensitive: false,
  );
  RegExp regExp2 = RegExp(
    r'^https?:\/\/(?:www\.)?youtu\.be\/([a-zA-Z0-9_-]+).*$',
    caseSensitive: false,
  );
  RegExp regExp3 = RegExp(
    r'^https?:\/\/(?:www\.)?youtube\.com\/embed\/([a-zA-Z0-9_-]+).*$',
    caseSensitive: false,
  );
  
  // محاولة استخراج معرف الفيديو من الأنماط المختلفة
  Match? match = regExp1.firstMatch(url);
  if (match != null && match.groupCount >= 1) return match.group(1);
  
  match = regExp2.firstMatch(url);
  if (match != null && match.groupCount >= 1) return match.group(1);
  
  match = regExp3.firstMatch(url);
  if (match != null && match.groupCount >= 1) return match.group(1);
  
  // إذا لم يتم العثور على معرف الفيديو
  return null;
}

// دالة للحصول على تفاصيل الفيلم من TMDB
Future<Map<String, dynamic>> getMovieDetails(String movieId) async {
  try {
    // محاولة الحصول على تفاصيل الفيلم من TMDB
    final tmdbDetails = await TMDBService.getMovieDetails(movieId);
    
    if (tmdbDetails.isNotEmpty) {
      // تحويل بيانات TMDB إلى تنسيق متوافق مع التطبيق
      return TMDBService.convertTMDBMovieToAppFormat(tmdbDetails);
    }
    
    // في حالة الفشل، نحاول استخدام الملفات المحلية كاحتياطي
    print("محاولة استخدام الملفات المحلية للحصول على تفاصيل الفيلم...");
    
    String moviesJson = "";
    try {
      moviesJson = await rootBundle.loadString('assets/movies.json');
    } catch (e) {
      print("خطأ في تحميل movies.json: $e");
      return {};
    }
    
    final localMoviesData = json.decode(moviesJson);
    
    // البحث عن الفيلم في قائمة الأفلام
    for (var movie in localMoviesData) {
      if (movie['id'] == movieId) {
        return movie;
      }
    }
    
    return {};
  } catch (e) {
    print("خطأ في الحصول على تفاصيل الفيلم: $e");
    return {};
  }
}

// دالة للحصول على قائمة الممثلين للفيلم
Future<List<Actor>> getMovieCast(String movieId) async {
  try {
    // محاولة الحصول على قائمة الممثلين من TMDB
    final castData = await TMDBService.getMovieCast(movieId);
    
    if (castData.isNotEmpty) {
      // تحويل بيانات TMDB إلى قائمة ممثلين
      return castData.map((actor) => Actor(
        name: actor['name'] ?? '',
        character: actor['character'] ?? '',
        profilePath: actor['profile_path'],
      )).toList();
    }
    
    // في حالة الفشل، نرجع قائمة فارغة
    return [];
  } catch (e) {
    print("خطأ في الحصول على قائمة الممثلين: $e");
    return [];
  }
}

// دالة للحصول على قائمة الأفلام الشائعة
Future<List<Map<String, dynamic>>> getPopularMovies() async {
  try {
    // محاولة الحصول على قائمة الأفلام الشائعة من TMDB
    final tmdbMovies = await TMDBService.getPopularMovies(); // تم التصحيح: إزالة معامل page
    
    if (tmdbMovies.isNotEmpty) {
      // تحويل بيانات TMDB إلى تنسيق متوافق مع التطبيق
      return tmdbMovies.map((movie) => TMDBService.convertTMDBMovieToAppFormat(movie)).toList();
    }
    
    // في حالة الفشل، نحاول استخدام الملفات المحلية كاحتياطي
    print("محاولة استخدام الملفات المحلية للحصول على قائمة الأفلام...");
    
    String moviesJson = "";
    try {
      moviesJson = await rootBundle.loadString('assets/movies.json');
    } catch (e) {
      print("خطأ في تحميل movies.json: $e");
      return [];
    }
    
    final localMoviesData = json.decode(moviesJson);
    return List<Map<String, dynamic>>.from(localMoviesData);
  } catch (e) {
    print("خطأ في الحصول على قائمة الأفلام الشائعة: $e");
    return [];
  }
}

// دالة للحصول على قائمة أفلام الأنيمي
Future<List<Map<String, dynamic>>> getAnimeMovies() async {
  try {
    // محاولة الحصول على قائمة أفلام الأنيمي من TMDB
    final tmdbMovies = await TMDBService.getAnimeMovies(); // تم التصحيح: إزالة معامل page
    
    if (tmdbMovies.isNotEmpty) {
      // تحويل بيانات TMDB إلى تنسيق متوافق مع التطبيق
      return tmdbMovies.map((movie) => TMDBService.convertTMDBMovieToAppFormat(movie)).toList();
    }
    
    return [];
  } catch (e) {
    print("خطأ في الحصول على قائمة أفلام الأنيمي: $e");
    return [];
  }
}

// دالة للحصول على قائمة الأفلام الرومانسية
Future<List<Map<String, dynamic>>> getRomanticMovies() async {
  try {
    // محاولة الحصول على قائمة الأفلام الرومانسية من TMDB
    final tmdbMovies = await TMDBService.getRomanticMovies(); // تم التصحيح: إزالة معامل page
    
    if (tmdbMovies.isNotEmpty) {
      // تحويل بيانات TMDB إلى تنسيق متوافق مع التطبيق
      return tmdbMovies.map((movie) => TMDBService.convertTMDBMovieToAppFormat(movie)).toList();
    }
    
    return [];
  } catch (e) {
    print("خطأ في الحصول على قائمة الأفلام الرومانسية: $e");
    return [];
  }
}

// دالة للحصول على قائمة أفلام الحركة
Future<List<Map<String, dynamic>>> getActionMovies() async {
  try {
    // محاولة الحصول على قائمة أفلام الحركة من TMDB
    final tmdbMovies = await TMDBService.getActionMovies(); // تم التصحيح: إزالة معامل page
    
    if (tmdbMovies.isNotEmpty) {
      // تحويل بيانات TMDB إلى تنسيق متوافق مع التطبيق
      return tmdbMovies.map((movie) => TMDBService.convertTMDBMovieToAppFormat(movie)).toList();
    }
    
    return [];
  } catch (e) {
    print("خطأ في الحصول على قائمة أفلام الحركة: $e");
    return [];
  }
}

// دالة للحصول على قائمة المسلسلات الرومانسية
Future<List<Map<String, dynamic>>> getRomanticTVShows() async {
  try {
    // محاولة الحصول على قائمة المسلسلات الرومانسية من TMDB
    final tmdbShows = await TMDBService.getRomanticTVShows(); // تم التصحيح: إزالة معامل page
    
    if (tmdbShows.isNotEmpty) {
      // تحويل بيانات TMDB إلى تنسيق متوافق مع التطبيق
      return tmdbShows.map((show) => TMDBService.convertTMDBMovieToAppFormat(show)).toList();
    }
    
    return [];
  } catch (e) {
    print("خطأ في الحصول على قائمة المسلسلات الرومانسية: $e");
    return [];
  }
}

// --- إضافة الدوال الناقصة التي ظهرت في الأخطاء ---

Future<List<Map<String, dynamic>>> getComedyMovies() async {
  try {
    final tmdbMovies = await TMDBService.getComedyMovies(); // تم التصحيح: إزالة معامل page
    if (tmdbMovies.isNotEmpty) {
      return tmdbMovies.map((movie) => TMDBService.convertTMDBMovieToAppFormat(movie)).toList();
    }
    return [];
  } catch (e) {
    print("خطأ في الحصول على قائمة أفلام الكوميديا: $e");
    return [];
  }
}

Future<List<Map<String, dynamic>>> getHorrorMovies() async {
  try {
    final tmdbMovies = await TMDBService.getHorrorMovies(); // تم التصحيح: إزالة معامل page
    if (tmdbMovies.isNotEmpty) {
      return tmdbMovies.map((movie) => TMDBService.convertTMDBMovieToAppFormat(movie)).toList();
    }
    return [];
  } catch (e) {
    print("خطأ في الحصول على قائمة أفلام الرعب: $e");
    return [];
  }
}

Future<List<Map<String, dynamic>>> getScienceFictionMovies() async {
  try {
    final tmdbMovies = await TMDBService.getScienceFictionMovies(); // تم التصحيح: إزالة معامل page
    if (tmdbMovies.isNotEmpty) {
      return tmdbMovies.map((movie) => TMDBService.convertTMDBMovieToAppFormat(movie)).toList();
    }
    return [];
  } catch (e) {
    print("خطأ في الحصول على قائمة أفلام الخيال العلمي: $e");
    return [];
  }
}

Future<List<Map<String, dynamic>>> getThrillerMovies() async {
  try {
    final tmdbMovies = await TMDBService.getThrillerMovies(); // تم التصحيح: إزالة معامل page
    if (tmdbMovies.isNotEmpty) {
      return tmdbMovies.map((movie) => TMDBService.convertTMDBMovieToAppFormat(movie)).toList();
    }
    return [];
  } catch (e) {
    print("خطأ في الحصول على قائمة أفلام الإثارة: $e");
    return [];
  }
}

Future<List<Map<String, dynamic>>> getMysteryMovies() async {
  try {
    final tmdbMovies = await TMDBService.getMysteryMovies(); // تم التصحيح: إزالة معامل page
    if (tmdbMovies.isNotEmpty) {
      return tmdbMovies.map((movie) => TMDBService.convertTMDBMovieToAppFormat(movie)).toList();
    }
    return [];
  } catch (e) {
    print("خطأ في الحصول على قائمة أفلام الغموض: $e");
    return [];
  }
}

Future<List<Map<String, dynamic>>> getAdventureMovies() async {
  try {
    final tmdbMovies = await TMDBService.getAdventureMovies(); // تم التصحيح: إزالة معامل page
    if (tmdbMovies.isNotEmpty) {
      return tmdbMovies.map((movie) => TMDBService.convertTMDBMovieToAppFormat(movie)).toList();
    }
    return [];
  } catch (e) {
    print("خطأ في الحصول على قائمة أفلام المغامرات: $e");
    return [];
  }
}

Future<List<Map<String, dynamic>>> getFamilyMovies() async {
  try {
    final tmdbMovies = await TMDBService.getFamilyMovies(); // تم التصحيح: إزالة معامل page
    if (tmdbMovies.isNotEmpty) {
      return tmdbMovies.map((movie) => TMDBService.convertTMDBMovieToAppFormat(movie)).toList();
    }
    return [];
  } catch (e) {
    print("خطأ في الحصول على قائمة الأفلام العائلية: $e");
    return [];
  }
}

Future<List<Map<String, dynamic>>> getDramaMovies() async {
  try {
    final tmdbMovies = await TMDBService.getDramaMovies(); // تم التصحيح: إزالة معامل page
    if (tmdbMovies.isNotEmpty) {
      return tmdbMovies.map((movie) => TMDBService.convertTMDBMovieToAppFormat(movie)).toList();
    }
    return [];
  } catch (e) {
    print("خطأ في الحصول على قائمة أفلام الدراما: $e");
    return [];
  }
}

Future<List<Map<String, dynamic>>> getPopularTVShows() async {
  try {
    final tmdbShows = await TMDBService.getPopularTVShows(); // تم التصحيح: إزالة معامل page
    if (tmdbShows.isNotEmpty) {
      return tmdbShows.map((show) => TMDBService.convertTMDBMovieToAppFormat(show)).toList();
    }
    return [];
  } catch (e) {
    print("خطأ في الحصول على قائمة المسلسلات الشائعة: $e");
    return [];
  }
}

