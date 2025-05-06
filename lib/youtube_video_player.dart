import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'models.dart';

// مكون مشغل فيديو يوتيوب مع إجبار الوضع الأفقي
class YouTubeVideoPlayerScreen extends StatefulWidget {
  final String youtubeUrl;
  final String title;
  
  const YouTubeVideoPlayerScreen({
    Key? key,
    required this.youtubeUrl,
    required this.title,
  }) : super(key: key);

  @override
  _YouTubeVideoPlayerScreenState createState() => _YouTubeVideoPlayerScreenState();
}

class _YouTubeVideoPlayerScreenState extends State<YouTubeVideoPlayerScreen> {
  late YoutubePlayerController _controller;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    
    // إجبار الوضع الأفقي عند فتح الشاشة
    _setLandscapeOrientation();
    
    _initializePlayer();
  }

  // دالة لإجبار الوضع الأفقي
  void _setLandscapeOrientation() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    // إخفاء شريط الحالة وشريط التنقل
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
    );
  }

  // دالة لإعادة الوضع الطبيعي
  void _resetOrientation() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    // إظهار شريط الحالة وشريط التنقل
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
    );
  }

  @override
  void dispose() {
    _resetOrientation();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initializePlayer() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // استخراج معرف فيديو يوتيوب من الرابط
      final videoId = extractYoutubeId(widget.youtubeUrl);
      
      if (videoId == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'تعذر استخراج معرف فيديو يوتيوب من الرابط المقدم';
        });
        return;
      }
      
      print("تم استخراج معرف فيديو يوتيوب: $videoId");
      
      // تهيئة مشغل يوتيوب
      _controller = YoutubePlayerController(
        initialVideoId: videoId,
        flags: YoutubePlayerFlags(
          autoPlay: true,
          mute: false,
          disableDragSeek: false,
          loop: false,
          isLive: false,
          forceHD: true,
          enableCaption: true,
        ),
      );
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
      print("خطأ في تهيئة مشغل يوتيوب: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // استخدام Scaffold كامل الشاشة للوضع الأفقي
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Colors.red,
            ),
            SizedBox(height: 20),
            Text(
              'جاري تحميل الفيديو...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    } else if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, color: Colors.red, size: 50),
            SizedBox(height: 10),
            Text('فشل تحميل الفيديو', style: TextStyle(color: Colors.white)),
            SizedBox(height: 10),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _initializePlayer,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: Text('إعادة المحاولة'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[800],
              ),
              child: Text('العودة'),
            ),
          ],
        ),
      );
    } else {
      return YoutubePlayerBuilder(
        player: YoutubePlayer(
          controller: _controller,
          showVideoProgressIndicator: true,
          progressIndicatorColor: Colors.red,
          progressColors: ProgressBarColors(
            playedColor: Colors.red,
            handleColor: Colors.redAccent,
          ),
          onReady: () {
            print('مشغل يوتيوب جاهز');
          },
          onEnded: (data) {
            print('انتهى تشغيل الفيديو');
          },
        ),
        builder: (context, player) {
          return Column(
            children: [
              // مشغل الفيديو
              Expanded(child: player),
            ],
          );
        },
      );
    }
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
