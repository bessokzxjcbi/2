import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // إضافة استيراد لاستخدام rootBundle
import 'dart:convert';
import 'dart:async'; // إضافة استيراد للتعامل مع Timer و Debouncer
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'movie_details_screen.dart';
import 'services/tmdb_service.dart';
import 'trending_screen.dart'; // *** استيراد شاشة الجديد والرائج ***
import 'request_screen.dart'; // *** استيراد شاشة طلب الأفلام ***

// إضافة Debouncer للتحكم في استدعاءات API أثناء الكتابة
class Debouncer {
  final int milliseconds;
  VoidCallback? action;
  Timer? _timer;

  Debouncer({required this.milliseconds});

  run(VoidCallback action) {
    if (_timer != null) {
      _timer!.cancel();
    }
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }
}

class HomeScreen extends StatefulWidget {
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// تعديل MovieSearchDelegate لاستخدام TMDB API
class MovieSearchDelegate extends SearchDelegate<Map<String, dynamic>> {
  final Function(Map<String, dynamic>) onMovieSelected;
  final _debouncer = Debouncer(milliseconds: 500); // تأخير 500 مللي ثانية
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;

  MovieSearchDelegate(this.onMovieSelected);

  // دالة لاستدعاء TMDB API وتحديث النتائج
  void _performSearch(BuildContext context, String query) {
    if (query.isEmpty) {
      if (_searchResults.isNotEmpty || _isLoading) {
        (context as Element).markNeedsBuild();
        _searchResults = [];
        _isLoading = false;
      }
      return;
    }

    _debouncer.run(() async {
      if (!(context as Element).mounted) return; // Check if context is still valid
      (context as Element).markNeedsBuild();
      _isLoading = true;
      _searchResults = [];

      try {
        final resultsRaw = await TMDBService.searchMovies(query);
        final resultsFormatted = resultsRaw
            .map((movie) => TMDBService.convertTMDBMovieToAppFormat(movie))
            .toList();

        if (!(context as Element).mounted) return; // Check again after await
        (context as Element).markNeedsBuild();
        _searchResults = resultsFormatted;
        _isLoading = false;
      } catch (e) {
        print("خطأ في البحث عبر TMDB: $e");
        if (!(context as Element).mounted) return;
        (context as Element).markNeedsBuild();
        _isLoading = false;
      }
    });
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: Icon(Icons.clear),
        onPressed: () {
          query = '';
          _performSearch(context, query);
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back),
      onPressed: () {
        close(context, {});
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    // Trigger search immediately when results are shown
    // _performSearch(context, query); // Might cause issues if called repeatedly
    return _buildSearchResultsWidget(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    // Trigger search as user types (debounced)
    _performSearch(context, query);
    return _buildSearchResultsWidget(context);
  }

  Widget _buildSearchResultsWidget(BuildContext context) {
    if (query.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 80, color: Colors.grey),
            SizedBox(height: 20),
            Text('ابحث عن فيلم أو مسلسل', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center),
          ],
        ),
      );
    }

    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 80, color: Colors.grey),
            SizedBox(height: 20),
            Text('لا توجد نتائج لـ "$query"', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final movie = _searchResults[index];
        return ListTile(
          leading: movie['img_url'] != null && movie['img_url'].isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    movie['img_url'],
                    width: 50,
                    height: 75,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => Container(width: 50, height: 75, color: Colors.grey[800], child: Icon(Icons.broken_image, color: Colors.white54)),
                  ),
                )
              : Container(width: 50, height: 75, color: Colors.grey[800], child: Icon(Icons.movie, color: Colors.white54)),
          title: Text(movie['ar_title'] ?? movie['en_title'] ?? 'بدون عنوان', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          subtitle: movie['year'] != null && movie['year'].isNotEmpty ? Text(movie['year'], style: TextStyle(color: Colors.grey[400])) : null,
          trailing: Icon(Icons.arrow_forward_ios, color: Colors.grey[400]),
          onTap: () {
            close(context, movie);
            onMovieSelected(movie);
          },
        );
      },
    );
  }
}

class MovieSection {
  final String title;
  List<Map<String, dynamic>> movies;
  bool isLoading;
  // *** إضافة fetcher هنا لتسهيل الوصول إليه لاحقاً ***
  final Future<List<dynamic>> Function()? fetcher;

  MovieSection({
    required this.title,
    this.movies = const [],
    this.isLoading = true,
    this.fetcher,
  });
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? featuredMovie;
  List<MovieSection> movieSections = [];
  int _currentIndex = 0;
  bool isInitialLoading = true;

  List<Map<String, dynamic>> watchlist = [];
  Set<String> watchlistIds = {};

  List<Map<String, dynamic>> continueWatchingList = [];
  Map<String, double> watchProgress = {};

  Timer? _autoChangeTimer;
  List<Map<String, dynamic>> _popularMoviesForFeatured = [];
  int _featuredMovieIndex = 0;

  // *** قائمة تعريف الفئات والـ fetchers الخاصة بها ***
  late final List<Map<String, dynamic>> _categoriesToLoad;

  @override
  void initState() {
    super.initState();
    _initializeCategories(); // Initialize categories list
    loadInitialData();
  }

  @override
  void dispose() {
    _autoChangeTimer?.cancel();
    super.dispose();
  }

  // *** تعريف قائمة الفئات في دالة منفصلة ***
  void _initializeCategories() {
    _categoriesToLoad = [
      {'title': 'من أفضل الاختيارات من أجلك اليوم', 'fetcher': () => Future.value(_popularMoviesForFeatured)}, // Already fetched
      // 'لنواصل المشاهدة' سيتم إضافته لاحقاً إذا لم يكن فارغاً
      {'title': 'أنيمي', 'fetcher': TMDBService.getAnimeMovies},
      {'title': 'برامج تلفزيونية رومانسية', 'fetcher': TMDBService.getRomanticTVShows},
      {'title': 'أفلام الحركة', 'fetcher': TMDBService.getActionMovies},
      {'title': 'أفلام رومانسية', 'fetcher': TMDBService.getRomanticMovies},
      {'title': 'أفلام الكوميديا', 'fetcher': TMDBService.getComedyMovies},
      {'title': 'أفلام الرعب', 'fetcher': TMDBService.getHorrorMovies},
      {'title': 'أفلام الخيال العلمي', 'fetcher': TMDBService.getScienceFictionMovies},
      {'title': 'أفلام الإثارة والتشويق', 'fetcher': TMDBService.getThrillerMovies},
      {'title': 'أفلام الغموض', 'fetcher': TMDBService.getMysteryMovies},
      {'title': 'أفلام المغامرات', 'fetcher': TMDBService.getAdventureMovies},
      {'title': 'أفلام عائلية', 'fetcher': TMDBService.getFamilyMovies},
      {'title': 'أفلام دراما', 'fetcher': TMDBService.getDramaMovies},
      {'title': 'مسلسلات شائعة', 'fetcher': TMDBService.getPopularTVShows},
    ];
  }

  // --- دوال تحميل البيانات المحفوظة (تبقى كما هي) ---
  Future<void> loadWatchlist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final watchlistJson = prefs.getString('watchlist');
      if (watchlistJson != null) {
        final List<dynamic> decoded = json.decode(watchlistJson);
        watchlist = decoded.map((item) => Map<String, dynamic>.from(item)).toList();
        watchlistIds = watchlist.map((movie) => movie['id'].toString()).toSet();
      }
    } catch (e) {
      print("خطأ في تحميل قائمة المشاهدة: $e");
    }
  }

  Future<void> saveWatchlist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final watchlistJson = json.encode(watchlist);
      await prefs.setString('watchlist', watchlistJson);
    } catch (e) {
      print("خطأ في حفظ قائمة المشاهدة: $e");
    }
  }

  Future<void> loadContinueWatchingList() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final continueWatchingJson = prefs.getString('continue_watching');
      final progressJson = prefs.getString('watch_progress');

      if (continueWatchingJson != null) {
        final List<dynamic> decoded = json.decode(continueWatchingJson);
        continueWatchingList = decoded.map((item) => Map<String, dynamic>.from(item)).toList();
      }

      if (progressJson != null) {
        final Map<String, dynamic> decoded = json.decode(progressJson);
        watchProgress = Map<String, double>.from(decoded.map((key, value) => MapEntry(key, value.toDouble())));
      }
    } catch (e) {
      print("خطأ في تحميل قائمة المشاهدة المستمرة: $e");
    }
  }

  Future<void> saveContinueWatchingList() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final continueWatchingJson = json.encode(continueWatchingList);
      final progressJson = json.encode(watchProgress);

      await prefs.setString('continue_watching', continueWatchingJson);
      await prefs.setString('watch_progress', progressJson);
    } catch (e) {
      print("خطأ في حفظ قائمة المشاهدة المستمرة: $e");
    }
  }

  // --- دوال التعامل مع القوائم (تبقى كما هي) ---
  void addToContinueWatching(Map<String, dynamic> movie, double progress) {
    final movieId = movie['id'].toString();
    final existingIndex = continueWatchingList.indexWhere((item) => item['id'].toString() == movieId);

    setState(() {
      if (existingIndex >= 0) {
        // Move to top if already exists
        final existingMovie = continueWatchingList.removeAt(existingIndex);
        continueWatchingList.insert(0, existingMovie);
      } else {
        continueWatchingList.insert(0, movie);
      }
      watchProgress[movieId] = progress;

      // Update or add the 'Continue Watching' section
      final continueWatchingSectionIndex = movieSections.indexWhere((s) => s.title == 'لنواصل المشاهدة');
      if (continueWatchingSectionIndex != -1) {
        movieSections[continueWatchingSectionIndex].movies = List.from(continueWatchingList); // Update with new order
      } else if (continueWatchingList.isNotEmpty) {
         // Add section if it wasn't there (e.g., first time adding)
         // Find the fetcher for 'Continue Watching' (it's just Future.value)
         final continueWatchingFetcher = () => Future.value(continueWatchingList);
         movieSections.insert(1, MovieSection(title: 'لنواصل المشاهدة', movies: List.from(continueWatchingList), isLoading: false, fetcher: continueWatchingFetcher));
      }
    });
    saveContinueWatchingList();
  }

  void removeFromContinueWatching(String movieId) {
    setState(() {
      continueWatchingList.removeWhere((movie) => movie['id'].toString() == movieId);
      watchProgress.remove(movieId);
      final continueWatchingSectionIndex = movieSections.indexWhere((s) => s.title == 'لنواصل المشاهدة');
      if (continueWatchingSectionIndex != -1) {
        if (continueWatchingList.isEmpty) {
          movieSections.removeAt(continueWatchingSectionIndex);
        } else {
          movieSections[continueWatchingSectionIndex].movies = List.from(continueWatchingList);
        }
      }
    });
    saveContinueWatchingList();
  }

  void toggleWatchlist(Map<String, dynamic> movie) {
    final movieId = movie['id'].toString();
    setState(() {
      if (watchlistIds.contains(movieId)) {
        watchlist.removeWhere((item) => item['id'].toString() == movieId);
        watchlistIds.remove(movieId);
      } else {
        watchlist.add(movie);
        watchlistIds.add(movieId);
      }
    });
    saveWatchlist();
  }

  bool isInWatchlist(String movieId) {
    return watchlistIds.contains(movieId);
  }

  void showMovieDetails(Map<String, dynamic> movie) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MovieDetailsScreen(
          movie: movie,
          isInWatchlist: isInWatchlist(movie['id'].toString()),
          onToggleWatchlist: () => toggleWatchlist(movie),
          onUpdateContinueWatching: addToContinueWatching,
        ),
      ),
    );
  }

  // --- دوال التحميل (معدلة للتحميل التدريجي) ---
  Future<void> loadInitialData() async {
    print("بدء التحميل الأولي...");
    setState(() {
      isInitialLoading = true;
      movieSections = []; // Clear sections before loading
    });

    try {
      // Load saved lists first
      await Future.wait([loadWatchlist(), loadContinueWatchingList()]);

      // Fetch popular movies for the featured section
      _popularMoviesForFeatured = (await TMDBService.getPopularMovies()).map((e) => Map<String, dynamic>.from(e)).toList();

      if (_popularMoviesForFeatured.isNotEmpty) {
        featuredMovie = TMDBService.convertTMDBMovieToAppFormat(_popularMoviesForFeatured[0]);
        _startAutoChangeFeaturedMovie();
      } else {
        featuredMovie = null;
      }

      // *** إعداد قائمة الأقسام بدون تحميل بياناتها بعد ***
      final initialSections = _categoriesToLoad
          .map((cat) => MovieSection(
                title: cat['title'] as String,
                // *** تمرير الـ fetcher لكل قسم ***
                fetcher: cat['fetcher'] as Future<List<dynamic>> Function(),
                // *** تعيين isLoading = true للجميع مبدئياً (ما عدا الأول والرائج) ***
                isLoading: cat['title'] != 'من أفضل الاختيارات من أجلك اليوم',
                // *** تعيين الأفلام المحملة مسبقاً للقسم الأول ***
                movies: cat['title'] == 'من أفضل الاختيارات من أجلك اليوم' ? _popularMoviesForFeatured.map((m) => TMDBService.convertTMDBMovieToAppFormat(m)).toList() : [],
              ))
          .toList();

      // *** إضافة قسم 'لنواصل المشاهدة' إذا كان يحتوي على عناصر ***
      if (continueWatchingList.isNotEmpty) {
        initialSections.insert(1, MovieSection(
          title: 'لنواصل المشاهدة',
          movies: continueWatchingList,
          isLoading: false, // Already loaded
          fetcher: () => Future.value(continueWatchingList) // Dummy fetcher
        ));
      }

      setState(() {
        movieSections = initialSections;
        isInitialLoading = false;
      });

      print("انتهاء التحميل الأولي، الأقسام جاهزة للتحميل التدريجي.");

      // *** لا يتم استدعاء fetcher هنا ***
      // loadMovieCategories(); // <-- إزالة الاستدعاء القديم

    } catch (e) {
      print("خطأ فادح في التحميل الأولي: $e");
      setState(() {
        isInitialLoading = false;
        featuredMovie = null;
        // Optionally set sections to empty or show an error state
        movieSections = [];
      });
    }
  }

  // *** دالة جديدة لتحميل بيانات قسم محدد ***
  Future<void> _loadSectionData(int index) async {
    if (index < 0 || index >= movieSections.length) return; // Index out of bounds

    final section = movieSections[index];

    // *** التحقق مما إذا كان القسم قيد التحميل بالفعل أو تم تحميله ***
    if (!section.isLoading || section.movies.isNotEmpty) {
      // print("Skipping load for section: ${section.title} (already loaded or not marked for loading)");
      return;
    }

    // *** التأكد من وجود fetcher ***
    if (section.fetcher == null) {
       print("Error: No fetcher found for section: ${section.title}");
       if (mounted) {
         setState(() {
           movieSections[index].isLoading = false; // Mark as not loading to prevent retries
         });
       }
       return;
    }

    print("بدء تحميل قسم: ${section.title}");
    // *** تحديث الحالة للإشارة إلى أن التحميل جارٍ (اختياري، لأن isLoading=true بالفعل) ***
    // if (mounted) {
    //   setState(() {
    //     movieSections[index].isLoading = true;
    //   });
    // }

    try {
      final moviesRaw = await section.fetcher!();
      final moviesFormatted = moviesRaw.map((movie) => TMDBService.convertTMDBMovieToAppFormat(movie)).toList();

      if (mounted) {
        setState(() {
          // التأكد من أن الفهرس لا يزال صالحاً (قد تتغير القائمة)
          if (index < movieSections.length && movieSections[index].title == section.title) {
             movieSections[index].movies = moviesFormatted;
             movieSections[index].isLoading = false;
          }
        });
      }
      print("تم تحميل قسم: ${section.title} (${moviesFormatted.length} عنصر)");
    } catch (e) {
      print("خطأ في تحميل قسم ${section.title}: $e");
      if (mounted) {
        setState(() {
          // التأكد من أن الفهرس لا يزال صالحاً
          if (index < movieSections.length && movieSections[index].title == section.title) {
             movieSections[index].isLoading = false; // Mark as loaded even on error
          }
        });
      }
    }
  }

  void _startAutoChangeFeaturedMovie() {
    _autoChangeTimer?.cancel();
    if (_popularMoviesForFeatured.length <= 1) return;

    _autoChangeTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _featuredMovieIndex = (_featuredMovieIndex + 1) % _popularMoviesForFeatured.length;
        featuredMovie = TMDBService.convertTMDBMovieToAppFormat(_popularMoviesForFeatured[_featuredMovieIndex]);
      });
      // print("تم تغيير الفيلم المميز إلى: ${featuredMovie?['ar_title'] ?? featuredMovie?['en_title']}");
    });
  }

  // --- بناء واجهة المستخدم ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          _currentIndex == 0 ? 'BGW Flix ↓' :
          _currentIndex == 1 ? 'الجديد والرائج' :
          _currentIndex == 2 ? 'طلبات الأفلام' :
          'قائمتي',
          style: TextStyle(fontSize: 24, color: Colors.white),
        ),
        actions: [
          IconButton(icon: Icon(Icons.cast, color: Colors.white), onPressed: () {}),
          IconButton(icon: Icon(Icons.file_download, color: Colors.white), onPressed: () {}),
          IconButton(
            icon: Icon(Icons.search, color: Colors.white),
            onPressed: () {
              showSearch(
                context: context,
                delegate: MovieSearchDelegate(showMovieDetails),
              );
            }
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: Colors.black,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'الرئيسية'),
          BottomNavigationBarItem(icon: Icon(Icons.video_library), label: 'الجديد والرائج'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'طلبات الأفلام'),
          BottomNavigationBarItem(icon: Icon(Icons.bookmark), label: 'قائمتي'),
        ],
      ),
    );
  }

  Widget _buildBody() {
    // *** عرض مؤشر تحميل عام فقط أثناء التحميل الأولي ***
    if (isInitialLoading && _currentIndex == 0) {
      return Center(child: CircularProgressIndicator());
    }
    switch (_currentIndex) {
      case 0:
        return _buildHomeContent();
      case 1:
        return TrendingScreen(
          onMovieSelected: showMovieDetails,
          onToggleWatchlist: toggleWatchlist,
          isInWatchlist: isInWatchlist,
          onUpdateContinueWatching: addToContinueWatching,
        );
      case 2:
        return RequestScreen(onMovieSelected: showMovieDetails);
      case 3:
        return _buildWatchlistContent();
      default:
        return _buildHomeContent(); // Fallback to home
    }
  }

  Widget _buildWatchlistContent() {
    if (watchlist.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_border, size: 80, color: Colors.grey),
            SizedBox(height: 20),
            Text('قائمة المشاهدة فارغة', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            SizedBox(height: 10),
            Text('أضف أفلامك المفضلة بالضغط على زر "قائمتي"', style: TextStyle(fontSize: 16, color: Colors.grey), textAlign: TextAlign.center),
          ],
        ),
      );
    }

    // Use GridView directly for simplicity, or CustomScrollView if more complex layouts are needed
    return GridView.builder(
      padding: EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: watchlist.length,
      itemBuilder: (context, index) {
        final movie = watchlist[index];
        return _buildWatchlistItem(movie);
      },
    );
  }

  Widget _buildWatchlistItem(Map<String, dynamic> movie) {
    final imageUrl = movie['img_url'] ?? '';
    final title = movie['ar_title'] ?? movie['en_title'] ?? 'بدون عنوان';

    return GestureDetector(
      onTap: () => showMovieDetails(movie),
      child: Card(
         color: Colors.grey[900],
         clipBehavior: Clip.antiAlias,
         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
         child: Stack(
           fit: StackFit.expand,
           children: [
             imageUrl.isNotEmpty
                 ? Image.network(
                     imageUrl,
                     fit: BoxFit.cover,
                     errorBuilder: (c, e, s) => Container(color: Colors.grey[800], child: Icon(Icons.movie, color: Colors.white54, size: 40)),
                   )
                 : Container(color: Colors.grey[800], child: Icon(Icons.movie, color: Colors.white54, size: 40)),
             Positioned(
               bottom: 0,
               left: 0,
               right: 0,
               child: Container(
                 padding: EdgeInsets.all(8).copyWith(top: 20),
                 decoration: BoxDecoration(
                   gradient: LinearGradient(
                     begin: Alignment.topCenter,
                     end: Alignment.bottomCenter,
                     colors: [Colors.transparent, Colors.black.withOpacity(0.8), Colors.black],
                     stops: [0.0, 0.5, 1.0],
                   ),
                 ),
                 child: Text(
                   title,
                   style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                   maxLines: 2,
                   overflow: TextOverflow.ellipsis,
                   textAlign: TextAlign.center,
                 ),
               ),
             ),
             Positioned(
               top: 4,
               right: 4,
               child: Material(
                 color: Colors.black54,
                 shape: CircleBorder(),
                 child: IconButton(
                   icon: Icon(Icons.close, color: Colors.white, size: 18),
                   onPressed: () => toggleWatchlist(movie),
                   tooltip: 'إزالة من قائمة المشاهدة',
                   constraints: BoxConstraints(),
                   padding: EdgeInsets.all(4),
                 ),
               ),
             ),
           ],
         ),
       ),
    );
  }

  // *** تعديل بناء محتوى الصفحة الرئيسية لاستخدام SliverList للتحميل التدريجي ***
  Widget _buildHomeContent() {
    if (featuredMovie == null && !isInitialLoading) {
      // Show error only if featured movie failed and initial load is complete
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 80, color: Colors.red),
            SizedBox(height: 20),
            Text('حدث خطأ في تحميل البيانات الرئيسية', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: loadInitialData, // Retry initial load
              child: Text('إعادة المحاولة'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: EdgeInsets.symmetric(horizontal: 30, vertical: 10)),
            ),
          ],
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        // Featured Movie Section (if available)
        if (featuredMovie != null)
          SliverToBoxAdapter(
            child: _buildFeaturedMovie(featuredMovie!),
          ),
        // *** استخدام SliverList لبناء الأقسام بشكل تدريجي ***
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) {
              // *** بناء ويدجت القسم مع تمرير دالة التحميل ***
              return _MovieSectionWidget(
                section: movieSections[index],
                index: index,
                loadDataCallback: _loadSectionData, // Pass the loading function
                onMovieTap: showMovieDetails, // Pass the navigation function
              );
            },
            childCount: movieSections.length, // عدد الأقسام الكلي
          ),
        ),
        // Add some padding at the bottom
        SliverPadding(padding: EdgeInsets.only(bottom: 20)),
      ],
    );
  }

  Widget _buildFeaturedMovie(Map<String, dynamic> movie) {
    final imageUrl = movie['img_url'] ?? '';
    final title = movie['ar_title'] ?? movie['en_title'] ?? 'بدون عنوان';

    return GestureDetector(
      onTap: () => showMovieDetails(movie),
      child: Container(
        height: 400,
        child: Stack(
          children: [
            Positioned.fill(
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => Container(color: Colors.grey[900]),
                    )
                  : Container(color: Colors.grey[900]),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.8), Colors.black],
                    stops: [0.4, 0.8, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 10),
                  SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildFeaturedButton(
                        icon: isInWatchlist(movie['id'].toString()) ? Icons.check : Icons.add,
                        label: 'قائمتي',
                        onPressed: () => toggleWatchlist(movie),
                      ),
                      ElevatedButton.icon(
                        icon: Icon(Icons.play_arrow),
                        label: Text('تشغيل'),
                        onPressed: () => showMovieDetails(movie),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ),
                      _buildFeaturedButton(
                        icon: Icons.info_outline,
                        label: 'معلومات',
                        onPressed: () => showMovieDetails(movie),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedButton({required IconData icon, required String label, required VoidCallback onPressed}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(icon: Icon(icon, color: Colors.white, size: 28), onPressed: onPressed),
        SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }
}

// *** ويدجت جديد لعرض قسم واحد وتحميل بياناته عند الحاجة ***
class _MovieSectionWidget extends StatefulWidget {
  final MovieSection section;
  final int index;
  final Future<void> Function(int) loadDataCallback;
  final Function(Map<String, dynamic>) onMovieTap; // Callback for tapping a movie

  const _MovieSectionWidget({
    Key? key,
    required this.section,
    required this.index,
    required this.loadDataCallback,
    required this.onMovieTap,
  }) : super(key: key);

  @override
  State<_MovieSectionWidget> createState() => _MovieSectionWidgetState();
}

class _MovieSectionWidgetState extends State<_MovieSectionWidget> {
  @override
  void initState() {
    super.initState();
    // *** استدعاء تحميل البيانات إذا كان القسم بحاجة للتحميل ولم يتم تحميله بعد ***
    if (widget.section.isLoading && widget.section.movies.isEmpty) {
      // print("Initiating load for section: ${widget.section.title} at index ${widget.index}");
      // Use addPostFrameCallback to ensure the build cycle is complete
      // WidgetsBinding.instance.addPostFrameCallback((_) {
      //    if (mounted) { // Check if still mounted before calling async
             widget.loadDataCallback(widget.index);
      //    }
      // });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              widget.section.title,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          SizedBox(height: 12),
          // *** عرض مؤشر التحميل أو قائمة الأفلام ***
          Container(
            height: 200, // ارتفاع ثابت لقائمة الأفلام الأفقية
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    // *** إذا كان القسم قيد التحميل ***
    if (widget.section.isLoading) {
      // print("Building loading state for: ${widget.section.title}");
      // Show a horizontal list of placeholders or a single centered indicator
      return Center(child: CircularProgressIndicator());
      // Or use a placeholder list:
      // return ListView.builder(
      //   scrollDirection: Axis.horizontal,
      //   itemCount: 5, // Number of placeholders
      //   itemBuilder: (context, index) => _buildMoviePlaceholder(),
      // );
    }

    // *** إذا لم يكن قيد التحميل وفارغ (خطأ أو لا توجد بيانات) ***
    if (widget.section.movies.isEmpty) {
      // print("Building empty state for: ${widget.section.title}");
      return Center(
        child: Text(
          'لا توجد أفلام في هذا القسم حالياً.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    // *** إذا تم التحميل بنجاح ويحتوي على أفلام ***
    // print("Building movie list for: ${widget.section.title}");
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: widget.section.movies.length,
      itemBuilder: (context, index) {
        final movie = widget.section.movies[index];
        return _buildMovieItem(movie);
      },
      padding: EdgeInsets.symmetric(horizontal: 16.0),
    );
  }

  Widget _buildMovieItem(Map<String, dynamic> movie) {
    final imageUrl = movie['img_url'] ?? '';
    return GestureDetector(
      onTap: () => widget.onMovieTap(movie), // Use the callback
      child: Container(
        width: 130, // عرض عنصر الفيلم
        margin: EdgeInsets.only(right: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (c, e, s) => Container(color: Colors.grey[800], child: Icon(Icons.movie, color: Colors.white54)),
                      )
                    : Container(color: Colors.grey[800], child: Icon(Icons.movie, color: Colors.white54)),
              ),
            ),
            SizedBox(height: 5),
            Text(
              movie['ar_title'] ?? movie['en_title'] ?? 'بدون عنوان',
              style: TextStyle(color: Colors.white, fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // Placeholder widget (optional)
  // Widget _buildMoviePlaceholder() {
  //   return Container(
  //     width: 130,
  //     margin: EdgeInsets.only(right: 10),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         Expanded(
  //           child: ClipRRect(
  //             borderRadius: BorderRadius.circular(8),
  //             child: Container(color: Colors.grey[800]),
  //           ),
  //         ),
  //         SizedBox(height: 5),
  //         Container(
  //           height: 14, // Approx height of text
  //           width: 100, // Approx width of text
  //           color: Colors.grey[700],
  //         ),
  //       ],
  //     ),
  //   );
  // }
}

