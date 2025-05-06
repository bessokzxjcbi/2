import 'dart:convert';
import 'package:http/http.dart' as http;

class TMDBService {
  static const String baseUrl = 'https://api.themoviedb.org/3';
  static const String imageBaseUrl = 'https://image.tmdb.org/t/p/w500';
  static const String apiKey = '0e7d507b7f5b457f280c422e896b555d';
  static const String bearerToken = 'eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiIwZTdkNTA3YjdmNWI0NTdmMjgwYzQyMmU4OTZiNTU1ZCIsIm5iZiI6MTc0NTY4MDI4Ny43MTI5OTk4LCJzdWIiOiI2ODBjZjc5ZjNjNzE4ZThjNTUzN2E4MjIiLCJzY29wZXMiOlsiYXBpX3JlYWQiXSwidmVyc2lvbiI6MX0.ROoa-HPmw3_8XAx8DHjr9MOtc0y2HQalRSO28dNwzOs';

  // --- دوال مساعدة خاصة ---

  // *** دالة جلب صفحات متعددة (للأجزاء القديمة من التطبيق) ***
  static Future<List<dynamic>> _fetchFromTMDB(String endpoint, {int maxPages = 10}) async {
    List<dynamic> allResults = [];
    try {
      for (int page = 1; page <= maxPages; page++) {
        final pageUrl = endpoint.contains('?') ? '$endpoint&page=$page' : '$endpoint?page=$page';
        
        final response = await http.get(
          Uri.parse(pageUrl),
          headers: {
            'Authorization': 'Bearer $bearerToken',
            'Content-Type': 'application/json',
          },
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final results = data['results'] ?? [];
          
          if (results.isEmpty) {
            break; // No more results
          }
          
          allResults.addAll(results);
          
          final totalPages = data['total_pages'] ?? 1;
          if (page >= totalPages) {
            break; // Reached the last page
          }
        } else {
          print('Failed to fetch from $pageUrl: ${response.statusCode}');
          break; // Stop fetching on error
        }
      }
      return allResults;
    } catch (e) {
      print('Error fetching from $endpoint: $e');
      return allResults; // Return whatever was fetched before the error
    }
  }

  // *** دالة جلب صفحة واحدة (للتحميل التدريجي) ***
  static Future<Map<String, dynamic>> _fetchSinglePageFromTMDB(String endpoint, int page) async {
    try {
      final pageUrl = endpoint.contains('?') ? '$endpoint&page=$page' : '$endpoint?page=$page';
      
      final response = await http.get(
        Uri.parse(pageUrl),
        headers: {
          'Authorization': 'Bearer $bearerToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'results': data['results'] ?? [],
          'page': data['page'] ?? page,
          'total_pages': data['total_pages'] ?? page, // Assume current page is last if total_pages is missing
        };
      } else {
        print('Failed to fetch single page from $pageUrl: ${response.statusCode}');
        throw Exception('Failed to load page $page from $endpoint');
      }
    } catch (e) {
      print('Error fetching single page from $endpoint: $e');
      throw Exception('Error fetching page $page: $e');
    }
  }

  // --- دوال جلب البيانات العامة --- 

  // *** الدوال القديمة (تجلب صفحات متعددة) - للحفاظ على التوافق ***
  static Future<List<dynamic>> getTrendingAll({String timeWindow = 'week'}) async {
    return _fetchFromTMDB('$baseUrl/trending/all/$timeWindow?language=ar');
  }
  static Future<List<dynamic>> getPopularMovies() async {
    return _fetchFromTMDB('$baseUrl/movie/popular?language=ar');
  }
  static Future<List<dynamic>> getMoviesByGenre(int genreId) async {
    return _fetchFromTMDB('$baseUrl/discover/movie?with_genres=$genreId&language=ar');
  }
  static Future<List<dynamic>> getAnimeMovies() async {
    return getMoviesByGenre(16); // Animation genre ID
  }
  static Future<List<dynamic>> getRomanticMovies() async {
    return getMoviesByGenre(10749); // Romance genre ID
  }
  static Future<List<dynamic>> getActionMovies() async {
    return getMoviesByGenre(28); // Action genre ID
  }
  static Future<List<dynamic>> getComedyMovies() async {
    return getMoviesByGenre(35); // Comedy genre ID
  }
  static Future<List<dynamic>> getHorrorMovies() async {
    return getMoviesByGenre(27); // Horror genre ID
  }
  static Future<List<dynamic>> getScienceFictionMovies() async {
    return getMoviesByGenre(878); // Sci-Fi genre ID
  }
  static Future<List<dynamic>> getThrillerMovies() async {
    return getMoviesByGenre(53); // Thriller genre ID
  }
  static Future<List<dynamic>> getMysteryMovies() async {
    return getMoviesByGenre(9648); // Mystery genre ID
  }
  static Future<List<dynamic>> getAdventureMovies() async {
    return getMoviesByGenre(12); // Adventure genre ID
  }
  static Future<List<dynamic>> getFamilyMovies() async {
    return getMoviesByGenre(10751); // Family genre ID
  }
  static Future<List<dynamic>> getDramaMovies() async {
    return getMoviesByGenre(18); // Drama genre ID
  }
  static Future<List<dynamic>> getPopularTVShows() async {
    final results = await _fetchFromTMDB('$baseUrl/tv/popular?language=ar');
    for (var show in results) {
      show['media_type'] = 'tv';
    }
    return results;
  }
  static Future<List<dynamic>> getTVShowsByGenre(int genreId) async {
    final results = await _fetchFromTMDB('$baseUrl/discover/tv?with_genres=$genreId&language=ar');
    for (var show in results) {
      show['media_type'] = 'tv';
    }
    return results;
  }
  static Future<List<dynamic>> getRomanticTVShows() async {
    return getTVShowsByGenre(10749); // Romance genre ID
  }
  static Future<List<dynamic>> searchMovies(String query) async {
    return _fetchFromTMDB('$baseUrl/search/movie?query=$query&language=ar');
  }

  // *** الدوال الجديدة (تجلب صفحة واحدة) - للتحميل التدريجي ***
  static Future<Map<String, dynamic>> getTrendingAllPaginated({String timeWindow = 'week', int page = 1}) async {
    return _fetchSinglePageFromTMDB('$baseUrl/trending/all/$timeWindow?language=ar', page);
  }
  static Future<Map<String, dynamic>> getPopularMoviesPaginated({int page = 1}) async {
    return _fetchSinglePageFromTMDB('$baseUrl/movie/popular?language=ar', page);
  }
  // Add more paginated functions as needed...

  // --- دوال أخرى --- 
  static Future<Map<String, dynamic>> getMovieDetails(String movieId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/movie/$movieId?language=ar'),
        headers: {
          'Authorization': 'Bearer $bearerToken',
          'Content-Type': 'application/json',
        },
      );
      return (response.statusCode == 200) ? json.decode(response.body) : {};
    } catch (e) {
      print('Error getting movie details: $e');
      return {};
    }
  }

  static Future<List<dynamic>> getMovieCast(String movieId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/movie/$movieId/credits?language=ar'),
        headers: {
          'Authorization': 'Bearer $bearerToken',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['cast'] ?? [];
      } else {
        return [];
      }
    } catch (e) {
      print('Error getting movie cast: $e');
      return [];
    }
  }

  // --- دالة تحويل البيانات --- 
  static Map<String, dynamic> convertTMDBMovieToAppFormat(Map<String, dynamic> tmdbItem) {
    final isMovie = tmdbItem['media_type'] == 'movie' || (tmdbItem['media_type'] == null && tmdbItem.containsKey('title'));
    final title = isMovie ? tmdbItem['title'] : tmdbItem['name'];
    final releaseDate = isMovie ? tmdbItem['release_date'] : tmdbItem['first_air_date'];
    final year = (releaseDate != null && releaseDate.length >= 4) ? releaseDate.substring(0, 4) : '';
    final posterPath = tmdbItem['poster_path'];
    final backdropPath = tmdbItem['backdrop_path'];

    return {
      'id': tmdbItem['id'].toString(),
      'en_title': title ?? '',
      'ar_title': title ?? '', // Assuming Arabic title is same as original for now
      'stars': (tmdbItem['vote_average'] ?? 0).toString(),
      'content': tmdbItem['overview'] ?? '',
      'trailer': '', // Placeholder
      'year': year,
      'duration': tmdbItem['runtime'] != null ? (tmdbItem['runtime'] * 60).toString() : '0', // Only available for movie details
      'img_url': posterPath != null ? '$imageBaseUrl$posterPath' : '',
      'backdrop_path': backdropPath, // Keep backdrop path for trending screen
      'genres': tmdbItem['genres'] ?? tmdbItem['genre_ids'] ?? [],
      'genre_ids': tmdbItem['genre_ids'] ?? [],
      'media_type': tmdbItem['media_type'] ?? (isMovie ? 'movie' : 'tv'),
      'popularity': tmdbItem['popularity'] ?? 0,
    };
  }
}

