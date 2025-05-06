import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class RequestService {
  static const String _requestedMoviesKey = 'requested_movies';

  // Function to add a movie to the request list.
  static Future<void> addMovieToRequests(Map<String, dynamic> movie) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final requestedJson = prefs.getString(_requestedMoviesKey);
      List<Map<String, dynamic>> currentRequests = [];
      if (requestedJson != null) {
        final List<dynamic> decoded = json.decode(requestedJson);
        currentRequests = decoded.map((item) => Map<String, dynamic>.from(item)).toList();
      }
      
      // Avoid adding duplicates
      final movieId = movie['id']?.toString();
      if (movieId != null && !currentRequests.any((m) => m['id']?.toString() == movieId)) {
          currentRequests.add(movie);
          final updatedJson = json.encode(currentRequests);
          await prefs.setString(_requestedMoviesKey, updatedJson);
          print("تمت إضافة الفيلم '${movie['ar_title'] ?? movie['en_title']}' إلى قائمة الطلبات.");
      } else {
          print("الفيلم موجود بالفعل في قائمة الطلبات أو لا يحتوي على معرف.");
      }

    } catch (e) {
      print("خطأ في إضافة الفيلم إلى قائمة الطلبات: $e");
    }
  }

  // Function to load requested movies (can be used by RequestScreen)
  static Future<List<Map<String, dynamic>>> loadRequestedMovies() async {
    List<Map<String, dynamic>> requestedMovies = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      final requestedJson = prefs.getString(_requestedMoviesKey);
      if (requestedJson != null) {
        final List<dynamic> decoded = json.decode(requestedJson);
        requestedMovies = decoded.map((item) => Map<String, dynamic>.from(item)).toList();
      }
    } catch (e) {
      print("خطأ في تحميل قائمة الأفلام المطلوبة: $e");
      // Handle error appropriately
    }
    return requestedMovies;
  }

  // Function to remove a movie from requests (can be used by RequestScreen)
  static Future<void> removeMovieFromRequests(String movieId) async {
     try {
      final prefs = await SharedPreferences.getInstance();
      final requestedJson = prefs.getString(_requestedMoviesKey);
      if (requestedJson != null) {
        List<Map<String, dynamic>> currentRequests = 
            List<Map<String, dynamic>>.from(json.decode(requestedJson));
        
        currentRequests.removeWhere((m) => m['id']?.toString() == movieId);
        
        final updatedJson = json.encode(currentRequests);
        await prefs.setString(_requestedMoviesKey, updatedJson);
        print("تمت إزالة الفيلم (ID: $movieId) من قائمة الطلبات.");
      }
    } catch (e) {
      print("خطأ في إزالة الفيلم من قائمة الطلبات: $e");
    }
  }

   // Function to check if a movie is requested (can be used by MovieDetailsScreen)
  static Future<bool> isMovieRequested(String movieId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final requestedJson = prefs.getString(_requestedMoviesKey);
      if (requestedJson != null) {
        final List<dynamic> decoded = json.decode(requestedJson);
        final List<Map<String, dynamic>> currentRequests = decoded.map((item) => Map<String, dynamic>.from(item)).toList();
        return currentRequests.any((m) => m['id']?.toString() == movieId);
      }
    } catch (e) {
      print("خطأ في التحقق من قائمة الطلبات: $e");
    }
    return false;
  }
}

