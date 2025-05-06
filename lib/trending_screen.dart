import 'package:flutter/material.dart';
import 'services/tmdb_service.dart';
import 'movie_details_screen.dart';

class TrendingScreen extends StatefulWidget {
  final Function(Map<String, dynamic>) onMovieSelected;
  final Function(Map<String, dynamic>) onToggleWatchlist;
  final Function(String) isInWatchlist;
  final Function(Map<String, dynamic>, double)? onUpdateContinueWatching;

  const TrendingScreen({
    Key? key,
    required this.onMovieSelected,
    required this.onToggleWatchlist,
    required this.isInWatchlist,
    this.onUpdateContinueWatching,
  }) : super(key: key);

  @override
  _TrendingScreenState createState() => _TrendingScreenState();
}

class _TrendingScreenState extends State<TrendingScreen> {
  List<Map<String, dynamic>> _trendingItems = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTrendingContent();
  }

  Future<void> _loadTrendingContent() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      // تم تصحيح الاستدعاء هنا وإصلاح التنسيق
      final trendingRaw = await TMDBService.getTrendingAll(); 
      final trendingFormatted = trendingRaw
          .map((item) => TMDBService.convertTMDBMovieToAppFormat(item))
          .toList();
      setState(() {
        _trendingItems = trendingFormatted;
        _isLoading = false;
      });
    } catch (e) {
      print("خطأ في تحميل المحتوى الرائج: $e");
      setState(() {
        _isLoading = false;
        _errorMessage = "حدث خطأ أثناء تحميل المحتوى الرائج.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 60),
            SizedBox(height: 16),
            Text(_errorMessage!, style: TextStyle(color: Colors.white)),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadTrendingContent,
              child: Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }
    if (_trendingItems.isEmpty) {
      return Center(child: Text('لا يوجد محتوى رائج حالياً.', style: TextStyle(color: Colors.white)));
    }

    return ListView.builder(
      itemCount: _trendingItems.length,
      itemBuilder: (context, index) {
        final item = _trendingItems[index];
        return _buildTrendingCard(item);
      },
    );
  }

  Widget _buildTrendingCard(Map<String, dynamic> item) {
    final title = item['ar_title'] ?? item['en_title'] ?? 'بدون عنوان';
    final overview = item['content'] ?? 'لا يوجد وصف متاح.';
    // استخدام backdrop_path للصورة الكبيرة إذا كان متاحاً، وإلا استخدام img_url (poster_path)
    final imageUrl = item['backdrop_path'] != null && item['backdrop_path'].isNotEmpty
        ? 'https://image.tmdb.org/t/p/w780${item['backdrop_path']}' 
        : item['img_url'] ?? '';

    return GestureDetector(
      onTap: () => widget.onMovieSelected(item),
      child: Card(
        color: Colors.black,
        margin: EdgeInsets.symmetric(vertical: 10, horizontal: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // الصورة الكبيرة
            if (imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(4.0)),
                child: Image.network(
                  imageUrl,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 200,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 200,
                      color: Colors.grey[900],
                      child: Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                    );
                  },
                ),
              )
            else
              Container(
                height: 200,
                color: Colors.grey[900],
                child: Center(child: Icon(Icons.movie, color: Colors.grey, size: 50)),
              ),
            // العنوان والوصف
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 20, 
                      fontWeight: FontWeight.bold, 
                      color: Colors.white
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    overview,
                    style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 10),
                  // أزرار الإجراءات (اختياري، يمكن إضافتها لاحقاً)
                  // Row(
                  //   mainAxisAlignment: MainAxisAlignment.end,
                  //   children: [
                  //     IconButton(
                  //       icon: Icon(widget.isInWatchlist(item['id'].toString()) ? Icons.check : Icons.add, color: Colors.white),
                  //       onPressed: () => widget.onToggleWatchlist(item),
                  //     ),
                  //     IconButton(
                  //       icon: Icon(Icons.info_outline, color: Colors.white),
                  //       onPressed: () => widget.onMovieSelected(item),
                  //     ),
                  //   ],
                  // ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

