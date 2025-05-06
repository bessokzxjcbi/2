import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:shared_preferences/shared_preferences.dart'; // No longer needed here
// import 'dart:convert'; // No longer needed here
import 'models.dart';
import 'landscape_video_player.dart';
import 'youtube_video_player.dart';
import 'browser_utils.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'services/tmdb_service.dart';
import 'services/viewing_service.dart';
import 'services/request_service.dart'; // *** Import the new service ***
// import 'request_screen.dart'; // *** Remove import causing cycle ***

class MovieDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> movie;
  final bool isInWatchlist;
  final VoidCallback onToggleWatchlist;
  final Function(Map<String, dynamic>, double)? onUpdateContinueWatching;

  const MovieDetailsScreen({
    Key? key,
    required this.movie,
    required this.isInWatchlist,
    required this.onToggleWatchlist,
    this.onUpdateContinueWatching,
  }) : super(key: key);

  @override
  _MovieDetailsScreenState createState() => _MovieDetailsScreenState();
}

class _MovieDetailsScreenState extends State<MovieDetailsScreen> {
  bool _isVideoLoading = true;
  String? _errorMessage;
  List<VideoQuality> _availableQualities = [];
  VideoQuality? _selectedQuality;
  bool _isLoadingDetails = true;
  List<Actor> _cast = [];
  Map<String, dynamic> _movieDetails = {};
  bool _isRequested = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadVideoQualities(),
      _loadMovieDetails(),
      _loadMovieCast(),
      _checkIfRequested(),
    ]);
    if (mounted) {
       setState(() {});
    }
  }

  // *** Use RequestService to check if requested ***
  Future<void> _checkIfRequested() async {
    final movieId = widget.movie['id']?.toString();
    if (movieId != null) {
      final requested = await RequestService.isMovieRequested(movieId);
      if (mounted) {
        setState(() {
          _isRequested = requested;
        });
      }
    }
  }

  Future<void> _loadVideoQualities() async {
    if (!mounted) return;
    setState(() {
      _isVideoLoading = true;
      _errorMessage = null;
    });
    try {
      final qualities = await getVideoQualities(widget.movie['id'].toString());
      if (!mounted) return;
      setState(() {
        _availableQualities = qualities;
        if (qualities.isNotEmpty) {
          _selectedQuality = qualities.first;
        } else {
          _errorMessage = 'لم يتم العثور على روابط فيديو متاحة';
        }
        _isVideoLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'خطأ في تحميل روابط الفيديو';
        _isVideoLoading = false;
      });
      print("خطأ في تحميل قائمة الدقات: $e");
    }
  }

  Future<void> _loadMovieDetails() async {
     if (!mounted) return;
    setState(() {
      _isLoadingDetails = true;
    });
    try {
      final details = await getMovieDetails(widget.movie['id'].toString());
       if (!mounted) return;
      setState(() {
        _movieDetails = details;
        _isLoadingDetails = false;
      });
    } catch (e) {
       if (!mounted) return;
      setState(() {
        _isLoadingDetails = false;
      });
      print("خطأ في تحميل تفاصيل الفيلم: $e");
    }
  }

  Future<void> _loadMovieCast() async {
    try {
      final cast = await getMovieCast(widget.movie['id'].toString());
       if (!mounted) return;
      setState(() {
        _cast = cast;
      });
    } catch (e) {
      print("خطأ في تحميل قائمة الممثلين: $e");
    }
  }

  // *** Use RequestService to add movie to requests ***
  Future<void> _requestMovie() async {
    await RequestService.addMovieToRequests(widget.movie);
    if (mounted) {
       setState(() {
         _isRequested = true;
       });
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
           content: Text('تمت إضافة الفيلم إلى قائمة طلباتك بنجاح!'),
           backgroundColor: Colors.green,
         ),
       );
    }
  }

  void _openVideoPlayer() {
    if (_availableQualities.isEmpty || _selectedQuality == null) {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
           content: Text('لا توجد روابط مشاهدة متاحة لهذا الفيلم.'),
           backgroundColor: Colors.orange,
         ),
       );
      return;
    }

    if (!kIsWeb || (kIsWeb && !isMobileBrowser())) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else if (kIsWeb && isMobileBrowser()) {
      _applyLandscapeOrientationForMobile();
    }

    final videoUrl = _selectedQuality!.videoUrl;
    final movieTitle = _movieDetails['ar_title'] ?? widget.movie['ar_title'] ?? widget.movie['en_title'] ?? 'فيديو';

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => videoUrl.contains('youtube.com') || videoUrl.contains('youtu.be')
            ? YouTubeVideoPlayerScreen(youtubeUrl: videoUrl, title: movieTitle)
            : LandscapeVideoPlayerScreen(qualities: _availableQualities, initialQuality: _selectedQuality!),
      ),
    ).then((_) {
      _resetOrientation();
    });
  }

  void _resetOrientation() {
    if (!kIsWeb || (kIsWeb && !isMobileBrowser())) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } else if (kIsWeb && isMobileBrowser()) {
      _resetOrientationForMobile();
    }
  }

  // --- Landscape and browser functions remain the same ---
  void _applyLandscapeOrientationForMobile() {
     if (kIsWeb) {
       try {
         WidgetsBinding.instance.addPostFrameCallback((_) {
           final styleElement = '''
             @media screen and (orientation: portrait) {
               html {
                 transform: rotate(-90deg);
                 transform-origin: left top;
                 width: 100vh;
                 height: 100vw;
                 overflow-x: hidden;
                 position: absolute;
                 top: 100%;
                 left: 0;
               }
             }
           ''';
           _injectCSSToWebPage(styleElement);
           _requestFullscreenAndLandscape();
         });
       } catch (e) {
         print('خطأ في تطبيق الوضع الأفقي على متصفح الهاتف المحمول: $e');
       }
     }
   }

   void _resetOrientationForMobile() {
     if (kIsWeb) {
       try {
         final jsCode = '''
           var styleElements = document.querySelectorAll('style');
           for (var i = 0; i < styleElements.length; i++) {
             if (styleElements[i].innerHTML.includes('transform: rotate(-90deg)')) {
               styleElements[i].remove();
             }
           }
           if (document.exitFullscreen) { document.exitFullscreen(); }
           else if (document.webkitExitFullscreen) { document.webkitExitFullscreen(); }
           else if (document.mozCancelFullScreen) { document.mozCancelFullScreen(); }
           else if (document.msExitFullscreen) { document.msExitFullscreen(); }
         ''';
         _executeJavaScript(jsCode);
       } catch (e) {
         print('خطأ في إعادة الوضع الطبيعي على متصفح الهاتف المحمول: $e');
       }
     }
   }

   void _injectCSSToWebPage(String css) {
     if (kIsWeb) {
       final jsCode = '''
         var style = document.createElement('style');
         style.type = 'text/css';
         style.innerHTML = `$css`;
         document.head.appendChild(style);
       ''';
       _executeJavaScript(jsCode);
     }
   }

   void _requestFullscreenAndLandscape() {
     if (kIsWeb) {
       final jsCode = '''
         var docElm = document.documentElement;
         if (docElm.requestFullscreen) { docElm.requestFullscreen(); }
         else if (docElm.webkitRequestFullScreen) { docElm.webkitRequestFullScreen(); }
         else if (docElm.mozRequestFullScreen) { docElm.mozRequestFullScreen(); }
         else if (docElm.msRequestFullscreen) { docElm.msRequestFullscreen(); }
         try {
           if (screen.orientation && screen.orientation.lock) {
             screen.orientation.lock('landscape').catch(function(error) { console.log('Orientation lock error: ' + error); });
           } else if (screen.lockOrientation) { screen.lockOrientation('landscape'); }
           else if (screen.mozLockOrientation) { screen.mozLockOrientation('landscape'); }
           else if (screen.msLockOrientation) { screen.msLockOrientation('landscape'); }
         } catch (e) { console.log('Orientation lock error: ' + e); }
       ''';
       _executeJavaScript(jsCode);
     }
   }

   void _executeJavaScript(String jsCode) {
     if (kIsWeb) {
       // Placeholder for JS execution - requires js package or similar
       print('Executing JS: $jsCode');
     }
   }
   // --- End landscape and browser functions ---

  @override
  Widget build(BuildContext context) {
    final movieTitle = _movieDetails['ar_title'] ?? widget.movie['ar_title'] ?? widget.movie['en_title'] ?? 'فيلم';
    final movieContent = _movieDetails['content'] ?? widget.movie['content'] ?? '';
    final movieYear = _movieDetails['year'] ?? widget.movie['year'] ?? '';
    final movieDuration = _movieDetails['duration'] ?? widget.movie['duration'] ?? '0';
    final movieStars = _movieDetails['stars'] ?? widget.movie['stars'] ?? '0';
    final movieImageUrl = _movieDetails['img_url'] ?? widget.movie['img_url'] ?? '';

    final durationInSeconds = double.tryParse(movieDuration) ?? 0;
    final hours = (durationInSeconds / 3600).floor();
    final minutes = ((durationInSeconds % 3600) / 60).floor();
    final durationText = hours > 0 ? '$hours ساعة و $minutes دقيقة' : '$minutes دقيقة';

    final bool showRequestButton = !_isVideoLoading && _availableQualities.isEmpty;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(movieTitle, style: TextStyle(color: Colors.white)),
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(
              widget.isInWatchlist ? Icons.bookmark : Icons.bookmark_border,
              color: Colors.white,
            ),
            onPressed: widget.onToggleWatchlist,
          ),
        ],
      ),
      body: _isLoadingDetails
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Movie Image
                  Container(
                    width: double.infinity,
                    height: 250,
                    decoration: BoxDecoration(
                      image: movieImageUrl.isNotEmpty
                          ? DecorationImage(image: NetworkImage(movieImageUrl), fit: BoxFit.cover)
                          : null,
                      color: Colors.grey[900],
                    ),
                    child: Stack(
                      children: [
                        Container(color: Colors.black.withOpacity(0.5)),
                        if (!_isVideoLoading && _availableQualities.isNotEmpty)
                           Center(
                             child: IconButton(
                               icon: Icon(Icons.play_circle_fill, size: 80, color: Colors.white.withOpacity(0.8)),
                               onPressed: _openVideoPlayer,
                             ),
                           ),
                        if (_isVideoLoading)
                          Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white))),
                        if (!_isVideoLoading && _availableQualities.isEmpty)
                           Center(
                             child: Padding(
                               padding: const EdgeInsets.all(16.0),
                               child: Text(
                                 _isRequested ? 'تم طلب هذا الفيلم بالفعل' : (_errorMessage ?? 'لا توجد روابط مشاهدة حالياً'),
                                 style: TextStyle(color: Colors.white, fontSize: 16),
                                 textAlign: TextAlign.center,
                               ),
                             ),
                           ),
                      ],
                    ),
                  ),

                  // Movie Info
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(movieTitle, style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            if (movieYear.isNotEmpty)
                              _buildInfoChip(movieYear),
                            SizedBox(width: 8),
                            if (durationInSeconds > 0)
                              _buildInfoChip(durationText),
                            SizedBox(width: 8),
                            if (movieStars.isNotEmpty && double.tryParse(movieStars) != 0)
                               Container(
                                 padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                 decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(4)),
                                 child: Row(
                                   children: [
                                     Icon(Icons.star, size: 16, color: Colors.black),
                                     SizedBox(width: 4),
                                     Text(movieStars, style: TextStyle(color: Colors.black)),
                                   ],
                                 ),
                               ),
                          ],
                        ),
                        SizedBox(height: 16),
                        Text('القصة', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        Text(movieContent, style: TextStyle(color: Colors.white)),
                        SizedBox(height: 24),
                        if (_cast.isNotEmpty) ...[
                          Text('الممثلين', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          SizedBox(height: 8),
                          Container(
                            height: 120,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _cast.length,
                              itemBuilder: (context, index) {
                                final actor = _cast[index];
                                return Padding(
                                  padding: const EdgeInsets.only(right: 16.0),
                                  child: Column(
                                    children: [
                                      CircleAvatar(
                                        radius: 40,
                                        backgroundImage: actor.profileUrl.isNotEmpty ? NetworkImage(actor.profileUrl) : null,
                                        backgroundColor: Colors.grey[800],
                                        child: actor.profileUrl.isEmpty ? Icon(Icons.person, color: Colors.white, size: 40) : null,
                                      ),
                                      SizedBox(height: 8),
                                      Container(
                                        width: 80,
                                        child: Text(actor.name, style: TextStyle(color: Colors.white), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          SizedBox(height: 24),
                        ],
                        if (_availableQualities.isNotEmpty) ...[
                           Text(
                             'جودات المشاهدة المتاحة',
                             style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                           ),
                           SizedBox(height: 8),
                           Wrap(
                             spacing: 8,
                             children: _availableQualities.map((quality) {
                               final isSelected = _selectedQuality == quality;
                               return ChoiceChip(
                                 label: Text(quality.resolution),
                                 selected: isSelected,
                                 onSelected: (selected) {
                                   if (selected) setState(() => _selectedQuality = quality);
                                 },
                                 backgroundColor: Colors.grey[800],
                                 selectedColor: Colors.blue,
                                 labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.grey[300]),
                               );
                             }).toList(),
                           ),
                           SizedBox(height: 24),
                         ],
                        Container(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: Icon(showRequestButton ? Icons.add_to_queue : Icons.play_arrow),
                            label: Text(showRequestButton
                                        ? (_isRequested ? 'تم الطلب' : 'طلب هذا الفيلم')
                                        : 'مشاهدة الآن'),
                            onPressed: showRequestButton
                                       ? (_isRequested ? null : _requestMovie)
                                       : _openVideoPlayer,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: showRequestButton
                                               ? (_isRequested ? Colors.grey[700] : Colors.blue)
                                               : Colors.red,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 16),
                              textStyle: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoChip(String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: TextStyle(color: Colors.white)),
    );
  }
}

