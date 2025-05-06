import 'package:flutter/material.dart';
import 'models.dart'; // For movie model if needed
import 'services/request_service.dart'; // Import the request service
import 'services/tmdb_service.dart'; // To fetch movies for the 'to request' list
import 'services/viewing_service.dart'; // To check for viewing links
import 'dart:async'; // For Future.wait
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart'; // Import pagination package

class RequestScreen extends StatefulWidget {
  final Function(Map<String, dynamic>) onMovieSelected; // Callback to show details

  const RequestScreen({Key? key, required this.onMovieSelected}) : super(key: key);

  @override
  _RequestScreenState createState() => _RequestScreenState();
}

class _RequestScreenState extends State<RequestScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // For 'My Requests' tab (loaded once)
  List<Map<String, dynamic>> myRequestedMovies = [];
  bool _isLoadingMyRequests = true;
  Set<String> _myRequestIds = {}; // To quickly check if a movie is already requested by the user

  // For 'Movies to Request' tab (paginated)
  static const _pageSize = 20; // TMDB default page size
  final PagingController<int, Map<String, dynamic>> _pagingController =
      PagingController(firstPageKey: 1);

  // Keep track of movies being checked for links to avoid redundant checks
  final Set<String> _currentlyCheckingLinks = {};
  // Keep track of movies confirmed to have no links
  final Set<String> _moviesConfirmedWithoutLinks = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMyRequests();

    // Add listener for pagination controller
    _pagingController.addPageRequestListener((pageKey) {
      _fetchMoviesToRequestPage(pageKey);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pagingController.dispose(); // Dispose the paging controller
    super.dispose();
  }

  // Load movies requested by the user (remains the same, loads all at once from SharedPreferences)
  Future<void> _loadMyRequests() async {
    if (!mounted) return;
    setState(() {
      _isLoadingMyRequests = true;
    });
    myRequestedMovies = await RequestService.loadRequestedMovies();
    _myRequestIds = myRequestedMovies.map((m) => m['id']?.toString() ?? '').toSet();
    if (mounted) {
      setState(() {
        _isLoadingMyRequests = false;
      });
    }
  }

  // Fetch a single page of movies for the 'Movies to Request' tab
  Future<void> _fetchMoviesToRequestPage(int pageKey) async {
    print("Fetching page $pageKey for movies to request...");
    try {
      // Fetch popular movies for the current page
      // TODO: Consider fetching from multiple sources/genres page by page if needed
      final paginatedResult = await TMDBService.getPopularMoviesPaginated(page: pageKey);
      final rawMovies = paginatedResult['results'] as List<dynamic>? ?? [];
      final totalPages = paginatedResult['total_pages'] as int? ?? pageKey;
      final currentPage = paginatedResult['page'] as int? ?? pageKey;

      print("Page $pageKey fetched. Raw movies: ${rawMovies.length}");

      List<Map<String, dynamic>> moviesWithoutLinksThisPage = [];
      List<Future<void>> linkCheckFutures = [];

      for (var movieRaw in rawMovies) {
        final movie = TMDBService.convertTMDBMovieToAppFormat(movieRaw);
        final movieId = movie['id']?.toString();

        if (movieId != null && !_myRequestIds.contains(movieId) && !_currentlyCheckingLinks.contains(movieId)) {
          // Check if we already know this movie has no links
          if (_moviesConfirmedWithoutLinks.contains(movieId)) {
             moviesWithoutLinksThisPage.add(movie);
             continue; // Skip checking again
          }

          _currentlyCheckingLinks.add(movieId);
          linkCheckFutures.add(
            ViewingService.getMovieData(movieId).then((movieData) {
              final qualities = ViewingService.extractVideoQualitiesFromData(movieData);
              if (qualities.isEmpty) {
                moviesWithoutLinksThisPage.add(movie);
                _moviesConfirmedWithoutLinks.add(movieId); // Remember this movie has no links
              }
            }).catchError((e) {
              print("Error checking links for movie ID $movieId on page $pageKey: $e");
              // Optionally add movies with errors? For now, we don't.
            }).whenComplete(() {
               _currentlyCheckingLinks.remove(movieId);
            })
          );
        }
      }

      // Wait for all link checks for this page to complete
      await Future.wait(linkCheckFutures);
      print("Link checks complete for page $pageKey. Movies without links found: ${moviesWithoutLinksThisPage.length}");

      final isLastPage = currentPage >= totalPages;
      if (isLastPage) {
        _pagingController.appendLastPage(moviesWithoutLinksThisPage);
        print("Appended last page ($pageKey) with ${moviesWithoutLinksThisPage.length} items.");
      } else {
        final nextPageKey = pageKey + 1;
        _pagingController.appendPage(moviesWithoutLinksThisPage, nextPageKey);
        print("Appended page $pageKey with ${moviesWithoutLinksThisPage.length} items. Next key: $nextPageKey");
      }
    } catch (error) {
      print("Error fetching page $pageKey: $error");
      _pagingController.error = error;
    }
  }

  // Action when a user requests a movie from the 'Movies to Request' tab
  Future<void> _requestMovie(Map<String, dynamic> movie) async {
    final movieId = movie['id']?.toString();
    if (movieId == null) return;

    await RequestService.addMovieToRequests(movie);
    print("DEV_LOG: User requested movie: ${movie['ar_title'] ?? movie['en_title']} (ID: $movieId)");

    if (mounted) {
      setState(() {
        if (!_myRequestIds.contains(movieId)) {
           myRequestedMovies.insert(0, movie);
           _myRequestIds.add(movieId);
        }
        // Remove from the paginated list if it exists there
        final currentItems = _pagingController.itemList;
        if (currentItems != null) {
           final indexToRemove = currentItems.indexWhere((m) => m['id']?.toString() == movieId);
           if (indexToRemove != -1) {
              currentItems.removeAt(indexToRemove);
              // Notify the controller about the change
              _pagingController.notifyListeners(); 
           }
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تمت إضافة "${movie['ar_title'] ?? movie['en_title']}" إلى طلباتك بنجاح!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // Action to remove a movie from the user's personal 'My Requests' list
  Future<void> _removeMovieFromMyRequests(Map<String, dynamic> movie) async {
    final movieId = movie['id']?.toString();
    if (movieId == null) return;

    await RequestService.removeMovieFromRequests(movieId);

    if (mounted) {
       setState(() {
          myRequestedMovies.removeWhere((m) => m['id']?.toString() == movieId);
          _myRequestIds.remove(movieId);
          // Optionally, trigger a refresh of the paginated list if the movie might appear there again
          // _pagingController.refresh(); 
          // For simplicity, we don't add it back automatically here.
       });
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تمت إزالة "${movie['ar_title'] ?? movie['en_title']}" من طلباتك.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: TabBar(
        controller: _tabController,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey,
        indicatorColor: Colors.red,
        tabs: [
          Tab(text: 'أفلام للطلب'),
          Tab(text: 'طلباتي'),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMoviesToRequestTabPaginated(), // Use the new paginated builder
          _buildMyRequestsTab(),
        ],
      ),
    );
  }

  // Builder for the 'Movies to Request' tab using PagedGridView
  Widget _buildMoviesToRequestTabPaginated() {
    return RefreshIndicator(
       onRefresh: () => Future.sync(() => _pagingController.refresh()), // Allow pull-to-refresh
       color: Colors.white,
       backgroundColor: Colors.red,
       child: PagedGridView<int, Map<String, dynamic>>(
          pagingController: _pagingController,
          padding: const EdgeInsets.all(10.0),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, // Adjust number of columns
            childAspectRatio: 0.65, // Adjust aspect ratio for button
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          builderDelegate: PagedChildBuilderDelegate<Map<String, dynamic>>(
            itemBuilder: (context, movie, index) => _buildMovieItem(movie, isMyRequests: false),
            // --- Customize loading and error indicators ---
            firstPageProgressIndicatorBuilder: (_) => Center(child: CircularProgressIndicator(color: Colors.red)),
            newPageProgressIndicatorBuilder: (_) => Center(child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent),
            )),
            firstPageErrorIndicatorBuilder: (context) => _buildErrorState(
              'حدث خطأ أثناء تحميل الأفلام',
              'يرجى المحاولة مرة أخرى.',
              () => _pagingController.refresh(),
            ),
            newPageErrorIndicatorBuilder: (context) => _buildErrorState(
              'حدث خطأ أثناء تحميل المزيد',
              'اسحب للأسفل للمحاولة مرة أخرى.',
              () => _pagingController.retryLastFailedRequest(),
              isRetryButton: false, // Show text instead of button for subsequent errors
            ),
            noItemsFoundIndicatorBuilder: (_) => _buildEmptyState(
              'لا توجد أفلام متاحة للطلب حالياً',
              'يتم عرض الأفلام الشائعة التي لا تتوفر لها روابط مشاهدة هنا.',
            ),
            noMoreItemsIndicatorBuilder: (_) => Padding(
              padding: const EdgeInsets.all(20.0),
              child: Center(child: Text("لا يوجد المزيد من الأفلام", style: TextStyle(color: Colors.grey))),
            ), 
          ),
        ),
    );
  }

  // Builder for the 'My Requests' tab (remains largely the same, uses ListView + GridView)
  Widget _buildMyRequestsTab() {
    if (_isLoadingMyRequests) {
      return Center(child: CircularProgressIndicator());
    }
    if (myRequestedMovies.isEmpty) {
      return _buildEmptyState('قائمة طلباتك فارغة', 'الأفلام التي تطلبها ستظهر هنا.');
    }
     return RefreshIndicator(
       onRefresh: _loadMyRequests, // Allow pull-to-refresh
       color: Colors.white,
       backgroundColor: Colors.red,
       child: ListView( // Keep ListView for RefreshIndicator compatibility
         children: [
           GridView.builder(
              padding: const EdgeInsets.all(10.0),
              shrinkWrap: true, // Important for ListView
              physics: NeverScrollableScrollPhysics(), // Important for ListView
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, // Adjust number of columns
                childAspectRatio: 0.65, // Adjust aspect ratio for button
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemBuilder: (context, index) {
                  final movie = myRequestedMovies[index];
                  return _buildMovieItem(movie, isMyRequests: true);
                },
              itemCount: myRequestedMovies.length,
            ),
         ],
       ),
    );
  }

  // Generic empty state widget
  Widget _buildEmptyState(String title, String subtitle) {
    // ... (remains the same)
     return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.list_alt_outlined, size: 80, color: Colors.grey),
            SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 10),
            Text(
              subtitle,
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Generic error state widget for pagination
  Widget _buildErrorState(String title, String subtitle, VoidCallback onRetry, {bool isRetryButton = true}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 80, color: Colors.redAccent),
            SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 10),
            Text(
              subtitle,
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            if (isRetryButton) ...[
              SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: Icon(Icons.refresh),
                label: Text('إعادة المحاولة'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              ),
            ]
          ],
        ),
      ),
    );
  }

  // Generic movie item widget (remains the same)
  Widget _buildMovieItem(Map<String, dynamic> movie, {required bool isMyRequests}) {
    // ... (remains the same)
    final imageUrl = movie['img_url'] ?? '';
    final title = movie['ar_title'] ?? movie['en_title'] ?? 'بدون عنوان';
    final movieId = movie['id']?.toString() ?? '';
    // Check _myRequestIds which is updated in setState
    final alreadyRequestedByUser = _myRequestIds.contains(movieId);

    return Card(
      color: Colors.grey[900],
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => widget.onMovieSelected(movie), // Navigate to details on image tap
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Container(color: Colors.grey[800], child: Icon(Icons.movie, color: Colors.white54, size: 40)),
                      // Add loading builder for better UX
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                : null,
                            strokeWidth: 2,
                            color: Colors.redAccent,
                          ),
                        );
                      },
                    )
                  : Container(color: Colors.grey[800], child: Icon(Icons.movie, color: Colors.white54, size: 40)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Text(
              title,
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
          // Button: 'Remove' for 'My Requests', 'Request' or 'Requested' for 'Movies to Request'
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
            child: isMyRequests
                ? TextButton.icon(
                    icon: Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                    label: Text('إزالة', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                    onPressed: () => _removeMovieFromMyRequests(movie), // Pass the whole movie map
                    style: TextButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: EdgeInsets.symmetric(vertical: 4)
                    ),
                  )
                : TextButton.icon(
                    icon: Icon(
                      alreadyRequestedByUser ? Icons.check_circle_outline : Icons.add_to_queue,
                      size: 18,
                      color: alreadyRequestedByUser ? Colors.grey : Colors.blueAccent,
                    ),
                    label: Text(
                      alreadyRequestedByUser ? 'تم الطلب' : 'طلب الفيلم',
                      style: TextStyle(
                        color: alreadyRequestedByUser ? Colors.grey : Colors.blueAccent,
                        fontSize: 12
                      ),
                    ),
                    // Disable button if already requested
                    onPressed: alreadyRequestedByUser ? null : () => _requestMovie(movie),
                    style: TextButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: EdgeInsets.symmetric(vertical: 4)
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

