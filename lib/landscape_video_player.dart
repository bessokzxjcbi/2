import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'dart:async'; // إضافة استيراد مكتبة dart:async للتعامل مع Timer
import 'models.dart';
import 'netflix_style_quality_selector.dart';
import 'youtube_video_player.dart'; // استيراد مشغل فيديو يوتيوب الجديد
import 'dart:math' as math; // إضافة استيراد مكتبة math للتعامل مع العمليات الحسابية
import 'browser_utils.dart'; // استيراد ملف الكشف عن نوع المتصفح
import 'package:flutter/foundation.dart' show kIsWeb; // للتحقق مما إذا كان التطبيق يعمل على الويب

// مكون مشغل الفيديو مع إجبار الوضع الأفقي
class LandscapeVideoPlayerScreen extends StatefulWidget {
  final List<VideoQuality> qualities;
  final VideoQuality initialQuality;
  
  const LandscapeVideoPlayerScreen({
    Key? key,
    required this.qualities,
    required this.initialQuality,
  }) : super(key: key);

  @override
  _LandscapeVideoPlayerScreenState createState() => _LandscapeVideoPlayerScreenState();
}

class _LandscapeVideoPlayerScreenState extends State<LandscapeVideoPlayerScreen> {
  late VideoQuality _selectedQuality;
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isYoutubeUrl = false; // إضافة متغير للتحقق من نوع الرابط
  DateTime _initializationTime = DateTime.now(); // وقت بدء التهيئة
  
  // متغيرات للتحميل التدريجي وإدارة المخزن المؤقت
  double _bufferingProgress = 0.0; // نسبة التخزين المؤقت
  bool _isBuffering = false; // هل الفيديو في حالة تخزين مؤقت
  Timer? _bufferCheckTimer; // مؤقت للتحقق من حالة التخزين المؤقت
  bool _showBufferingInfo = true; // عرض معلومات التخزين المؤقت
  int _chunkSize = 1024 * 1024; // حجم الجزء المحمل (1 ميجابايت)
  int _preloadChunks = 1; // عدد الأجزاء المحملة مسبقاً (تم تقليله من 2 إلى 1)

  @override
  void initState() {
    super.initState();
    _selectedQuality = widget.initialQuality;
    _initializationTime = DateTime.now();
    
    // إجبار الوضع الأفقي عند فتح الشاشة - تم نقل هذا الكود إلى movie_details_screen.dart
    // لكن نحتفظ به هنا كإجراء احتياطي
    _setLandscapeOrientation();
    
    // التحقق من نوع الرابط قبل تهيئة المشغل
    _checkUrlTypeAndInitialize();
    
    // بدء مؤقت للتحقق من حالة التخزين المؤقت
    _startBufferCheckTimer();
  }
  
  // دالة لبدء مؤقت التحقق من حالة التخزين المؤقت
  void _startBufferCheckTimer() {
    _bufferCheckTimer?.cancel();
    _bufferCheckTimer = Timer.periodic(Duration(milliseconds: 500), (timer) {
      if (_videoPlayerController != null && 
          _videoPlayerController!.value.isInitialized && 
          mounted) {
        _updateBufferingStatus();
      }
    });
  }
  
  // دالة لتحديث حالة التخزين المؤقت
  void _updateBufferingStatus() {
    if (_videoPlayerController == null) return;
    
    final bufferedRanges = _videoPlayerController!.value.buffered;
    final currentPosition = _videoPlayerController!.value.position;
    final duration = _videoPlayerController!.value.duration;
    
    if (bufferedRanges.isEmpty || duration == Duration.zero) {
      setState(() {
        _bufferingProgress = 0.0;
      });
      return;
    }
    
    // حساب نسبة التخزين المؤقت
    double totalBufferedSeconds = 0.0;
    for (final range in bufferedRanges) {
      totalBufferedSeconds += range.end.inMilliseconds - range.start.inMilliseconds;
    }
    
    final bufferingProgress = totalBufferedSeconds / duration.inMilliseconds;
    
    // التحقق مما إذا كان الفيديو في حالة تخزين مؤقت
    bool isBuffering = false;
    for (final range in bufferedRanges) {
      if (currentPosition >= range.start && currentPosition <= range.end) {
        // الموضع الحالي ضمن نطاق مخزن مؤقتاً
        isBuffering = false;
        break;
      } else if (currentPosition < range.start) {
        // الموضع الحالي قبل نطاق مخزن مؤقتاً
        isBuffering = true;
      }
    }
    
    setState(() {
      _bufferingProgress = math.min(1.0, math.max(0.0, bufferingProgress));
      _isBuffering = isBuffering;
    });
    
    // إذا كان التخزين المؤقت منخفضاً جداً، نبدأ التشغيل على أي حال بعد 10 ثوانٍ
    if (_bufferingProgress < 0.05 && !_videoPlayerController!.value.isPlaying && 
        _videoPlayerController!.value.isInitialized && 
        DateTime.now().difference(_initializationTime).inSeconds > 10) {
      print("بدء التشغيل بعد 10 ثوانٍ من الانتظار بغض النظر عن حالة التخزين المؤقت");
      _videoPlayerController!.play();
    }
    
    // طباعة معلومات التخزين المؤقت للتصحيح
    print("حالة التخزين المؤقت: ${_bufferingProgress * 100}% - جاري التخزين المؤقت: $_isBuffering");
  }
  
  // دالة مستمع لتغييرات حالة الفيديو
  void _onVideoPlayerValueChanged() {
    if (_videoPlayerController == null || !_videoPlayerController!.value.isInitialized) return;
    
    // تحديث حالة التخزين المؤقت
    _updateBufferingStatus();
    
    // التحقق من حالة التشغيل
    final isPlaying = _videoPlayerController!.value.isPlaying;
    final isBuffering = _videoPlayerController!.value.isBuffering;
    
    // إذا كان الفيديو في حالة تخزين مؤقت وليس في حالة تشغيل، نعرض مؤشر التحميل
    if (isBuffering && !isPlaying) {
      print("الفيديو في حالة تخزين مؤقت...");
    }
    
    // إذا كان الفيديو في حالة تشغيل ولكن نسبة التخزين المؤقت منخفضة، نحاول تحسين التخزين المؤقت
    if (isPlaying && _bufferingProgress < 0.1) {
      print("نسبة التخزين المؤقت منخفضة، جاري محاولة تحسين التخزين المؤقت...");
      // يمكن إضافة منطق هنا لتحسين التخزين المؤقت، مثل تقليل جودة الفيديو مؤقتاً
    }
  }

  // دالة للتحقق من نوع الرابط وتهيئة المشغل المناسب
  void _checkUrlTypeAndInitialize() {
    final videoUrl = _selectedQuality.videoUrl;
    
    // التحقق من نوع الرابط (YouTube أو رابط مباشر)
    if (videoUrl.contains('youtube.com') || videoUrl.contains('youtu.be')) {
      setState(() {
        _isYoutubeUrl = true;
      });
      
      // لا نحتاج لتهيئة مشغل الفيديو العادي لأننا سنستخدم مشغل يوتيوب
      setState(() {
        _isLoading = false;
      });
    } else {
      // إذا كان رابط مباشر، نستخدم مشغل الفيديو العادي
      // تأخير قصير لضمان اكتمال التحول إلى الوضع الأفقي
      Future.delayed(Duration(milliseconds: 100), () {
        if (mounted) {
          _initializePlayer();
        }
      });
    }
  }

  // دالة لإجبار الوضع الأفقي مع دعم متصفحات الهواتف المحمولة
  void _setLandscapeOrientation() {
    // استخدام SystemChrome فقط إذا لم يكن تطبيق ويب أو إذا كان متصفح سطح المكتب
    if (!kIsWeb || (kIsWeb && !isMobileBrowser())) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      
      // إخفاء شريط الحالة وشريط التنقل
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.immersiveSticky,
      );
    } 
    // إذا كان متصفح هاتف محمول، نستخدم JavaScript لتدوير الشاشة
    else if (kIsWeb && isMobileBrowser()) {
      _applyLandscapeOrientationForMobile();
    }
  }
  
  // دالة خاصة لتطبيق الوضع الأفقي على متصفحات الهواتف المحمولة باستخدام CSS و JavaScript
  void _applyLandscapeOrientationForMobile() {
    try {
      // استخدام CSS و JavaScript لتدوير العناصر وتعديل الأبعاد
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // تطبيق تغييرات CSS على العنصر الحالي لجعله في وضع أفقي
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        
        // استخدام JavaScript لتطبيق الوضع الأفقي على متصفحات الهواتف المحمولة
        // هذا يتم من خلال إضافة كود JavaScript إلى صفحة الويب
        if (kIsWeb) {
          // إضافة أسلوب CSS لإجبار الوضع الأفقي
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
          
          // تطبيق أسلوب CSS على الصفحة
          _injectCSSToWebPage(styleElement);
          
          // محاولة تدوير الشاشة باستخدام Screen Orientation API إذا كان مدعوماً
          _requestFullscreenAndLandscape();
        }
        
        // طباعة معلومات تصحيح
        print('تطبيق الوضع الأفقي على متصفح الهاتف المحمول');
        print('نوع المتصفح: ${isMobileBrowser() ? "متصفح هاتف محمول" : "متصفح سطح المكتب"}');
        print('iOS: ${isIOSBrowser()}, Android: ${isAndroidBrowser()}');
        print('أبعاد الشاشة: $screenWidth x $screenHeight');
      });
    } catch (e) {
      print('خطأ في تطبيق الوضع الأفقي على متصفح الهاتف المحمول: $e');
    }
  }
  
  // دالة لحقن كود CSS في صفحة الويب
  void _injectCSSToWebPage(String css) {
    if (kIsWeb) {
      try {
        // استخدام JavaScript مباشرة لإضافة عنصر style إلى الصفحة
        final styleElement = '''
          var style = document.createElement('style');
          style.type = 'text/css';
          style.innerHTML = `$css`;
          document.head.appendChild(style);
        ''';
        
        // تنفيذ كود JavaScript لإضافة عنصر style إلى الصفحة
        executeJavaScript(styleElement);
      } catch (e) {
        print('خطأ في حقن CSS: $e');
      }
    }
  }
  
  // دالة لطلب وضع ملء الشاشة والوضع الأفقي
  void _requestFullscreenAndLandscape() {
    if (kIsWeb) {
      try {
        // كود JavaScript لطلب وضع ملء الشاشة والوضع الأفقي
        final jsCode = '''
          // طلب وضع ملء الشاشة
          function requestFullscreen() {
            var elem = document.documentElement;
            if (elem.requestFullscreen) {
              elem.requestFullscreen();
            } else if (elem.webkitRequestFullscreen) { /* Safari */
              elem.webkitRequestFullscreen();
            } else if (elem.msRequestFullscreen) { /* IE11 */
              elem.msRequestFullscreen();
            }
          }
          
          // طلب الوضع الأفقي بعد ملء الشاشة
          function requestLandscapeOrientation() {
            if (screen.orientation && screen.orientation.lock) {
              screen.orientation.lock('landscape').catch(function(error) {
                console.log('خطأ في قفل الاتجاه: ' + error);
              });
            } else if (screen.lockOrientation) {
              screen.lockOrientation('landscape');
            } else if (screen.mozLockOrientation) {
              screen.mozLockOrientation('landscape');
            } else if (screen.msLockOrientation) {
              screen.msLockOrientation('landscape');
            }
          }
          
          // تنفيذ الدوال
          requestFullscreen();
          setTimeout(requestLandscapeOrientation, 500);
        ''';
        
        // تنفيذ كود JavaScript
        executeJavaScript(jsCode);
      } catch (e) {
        print('خطأ في طلب وضع ملء الشاشة والوضع الأفقي: $e');
      }
    }
  }

  // دالة لإعادة الوضع الطبيعي مع دعم متصفحات الهواتف المحمولة
  void _resetOrientation() {
    // إعادة الوضع الطبيعي فقط إذا لم يكن تطبيق ويب أو إذا كان متصفح سطح المكتب
    if (!kIsWeb || (kIsWeb && !isMobileBrowser())) {
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
    // إذا كان متصفح هاتف محمول، نستخدم JavaScript لإعادة الوضع الطبيعي
    else if (kIsWeb && isMobileBrowser()) {
      _resetOrientationForMobile();
    }
  }
  
  // دالة خاصة لإعادة الوضع الطبيعي على متصفحات الهواتف المحمولة
  void _resetOrientationForMobile() {
    if (kIsWeb) {
      try {
        // كود JavaScript لإعادة الوضع الطبيعي
        final jsCode = '''
          // إزالة أي أسلوب CSS تم إضافته
          var styleElements = document.querySelectorAll('style');
          for (var i = 0; i < styleElements.length; i++) {
            var style = styleElements[i];
            if (style.innerHTML.includes('transform: rotate')) {
              style.remove();
            }
          }
          
          // الخروج من وضع ملء الشاشة
          if (document.exitFullscreen) {
            document.exitFullscreen();
          } else if (document.webkitExitFullscreen) {
            document.webkitExitFullscreen();
          } else if (document.msExitFullscreen) {
            document.msExitFullscreen();
          }
          
          // إعادة تعيين توجيه الشاشة إذا كان مدعوماً
          if (screen.orientation && screen.orientation.unlock) {
            screen.orientation.unlock();
          }
        ''';
        
        // تنفيذ كود JavaScript
        executeJavaScript(jsCode);
      } catch (e) {
        print('خطأ في إعادة الوضع الطبيعي على متصفح الهاتف المحمول: $e');
      }
    }
  }

  @override
  void dispose() {
    _resetOrientation();
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    _bufferCheckTimer?.cancel(); // إلغاء مؤقت التحقق من حالة التخزين المؤقت
    super.dispose();
  }

  Future<void> _initializePlayer() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _bufferingProgress = 0.0;
      _isBuffering = false;
    });
    
    try {
      await _videoPlayerController?.dispose();
      _chewieController?.dispose();
      
      // تحسين التعامل مع روابط الفيديو الافتراضية
      final videoUrl = _selectedQuality.videoUrl;
      print("محاولة تشغيل الفيديو من الرابط: $videoUrl");
      
      // التحقق من صلاحية الرابط قبل محاولة التشغيل
      if (videoUrl.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'رابط الفيديو غير صالح أو فارغ';
        });
        return;
      }
      
      // إضافة معلمات لتجاوز مشكلة التخزين المؤقت
      final Uri videoUri = Uri.parse(videoUrl);
      final Uri modifiedUri = videoUri.replace(
        queryParameters: {
          ...videoUri.queryParameters,
          'nocache': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      );
      
      // محاولة تهيئة مشغل الفيديو مع الرابط المعدل
      _videoPlayerController = VideoPlayerController.networkUrl(modifiedUri);
      
      // إضافة مستمع لحدث تغيير حالة الفيديو لتتبع التحميل التدريجي
      _videoPlayerController!.addListener(_onVideoPlayerValueChanged);
      
      // إضافة معالجة أخطاء أفضل مع محاولات إعادة المحاولة
      int retryCount = 0;
      const maxRetries = 2;
      
      while (retryCount <= maxRetries) {
        try {
          await _videoPlayerController!.initialize();
          // إذا نجحت التهيئة، نخرج من الحلقة
          break;
        } catch (e) {
          print("خطأ في تهيئة مشغل الفيديو (محاولة ${retryCount + 1}): $e");
          retryCount++;
          
          if (retryCount > maxRetries) {
            // إذا فشلت جميع المحاولات
            setState(() {
              _isLoading = false;
              _errorMessage = 'تعذر تشغيل الفيديو: $e';
            });
            return;
          }
          
          // انتظار قبل إعادة المحاولة
          await Future.delayed(Duration(seconds: 1));
          
          // إعادة تهيئة المشغل للمحاولة التالية
          await _videoPlayerController!.dispose();
          _videoPlayerController = VideoPlayerController.networkUrl(modifiedUri);
          _videoPlayerController!.addListener(_onVideoPlayerValueChanged);
        }
      }
      
      // تحديث حالة التخزين المؤقت الأولية
      _updateBufferingStatus();
      
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
        aspectRatio: 16/9,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        fullScreenByDefault: true,
        startAt: Duration.zero, // بدء التشغيل من البداية فوراً
        autoInitialize: true, // تهيئة تلقائية
        allowPlaybackSpeedChanging: true, // السماح بتغيير سرعة التشغيل
        deviceOrientationsAfterFullScreen: [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ],
        // تعطيل زر ملء الشاشة لأننا بالفعل في وضع ملء الشاشة الأفقي
        hideControlsTimer: const Duration(seconds: 3),
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.red,
          handleColor: Colors.red,
          backgroundColor: Colors.grey,
          bufferedColor: Colors.white.withOpacity(0.5), // تعديل شفافية لون التخزين المؤقت
        ),
        placeholder: Container(
          color: Colors.black,
          child: const Center(
            child: CircularProgressIndicator(
              color: Colors.red,
            ),
          ),
        ),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, color: Colors.red, size: 50),
                SizedBox(height: 20),
                Text(
                  'فشل تحميل الفيديو',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Text(
                  'تعذر تشغيل الفيديو: صيغة الفيديو غير مدعومة أو الرابط غير صالح',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 10),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 30),
                  child: Text(
                    'يرجى تحديث التطبيق أو المحاولة لاحقاً',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _initializePlayer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  child: Text('إعادة المحاولة', style: TextStyle(fontSize: 16)),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[800],
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  child: Text('العودة', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          );
        },
        customControls: MaterialControls(
          showQualityButton: widget.qualities.length > 1,
          onQualityButtonPressed: _showQualitySelector,
          selectedQuality: _selectedQuality,
          videoPlayerController: _videoPlayerController,
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
      print("خطأ في تهيئة مشغل الفيديو: $e");
    }
  }

  void _changeQuality(VideoQuality quality) async {
    if (_selectedQuality.resolution == quality.resolution) return;
    
    // حفظ موضع التشغيل الحالي
    final currentPosition = _videoPlayerController?.value.position ?? Duration.zero;
    
    setState(() {
      _selectedQuality = quality;
    });
    
    // التحقق من نوع الرابط الجديد
    if (quality.videoUrl.contains('youtube.com') || quality.videoUrl.contains('youtu.be')) {
      setState(() {
        _isYoutubeUrl = true;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isYoutubeUrl = false;
      });
      await _initializePlayer();
      
      // استئناف التشغيل من نفس الموضع
      _videoPlayerController?.seekTo(currentPosition);
    }
  }

  // عرض نافذة منبثقة لاختيار الجودة بنمط نتفليكس
  void _showQualitySelector() {
    if (widget.qualities.isEmpty) return;
    
    showNetflixStyleQualitySelector(
      context,
      widget.qualities,
      _selectedQuality,
      _changeQuality,
    );
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
    // إذا كان رابط يوتيوب، نستخدم مشغل يوتيوب
    if (_isYoutubeUrl) {
      return YouTubeVideoPlayerScreen(
        youtubeUrl: _selectedQuality.videoUrl,
        title: _selectedQuality.resolution,
      );
    }
    
    // وإلا نستخدم مشغل الفيديو العادي
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
    } else if (_chewieController != null) {
      return Stack(
        children: [
          // مشغل الفيديو
          Center(
            child: Chewie(
              controller: _chewieController!,
            ),
          ),
          
          // مؤشر التخزين المؤقت
          if (_isBuffering)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.5),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        color: Colors.red,
                        value: _bufferingProgress > 0 ? _bufferingProgress : null,
                      ),
                      SizedBox(height: 20),
                      Text(
                        'جاري تحميل الفيديو... ${(_bufferingProgress * 100).toStringAsFixed(0)}%',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          
          // معلومات التخزين المؤقت
          if (_showBufferingInfo && _videoPlayerController != null && _videoPlayerController!.value.isInitialized)
            Positioned(
              bottom: 80,
              left: 20,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  'تم تحميل: ${(_bufferingProgress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
        ],
      );
    } else {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('لا يمكن تحميل مشغل الفيديو', style: TextStyle(color: Colors.white)),
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
    }
  }
}

// مكون مخصص للتحكم في مشغل الفيديو مع دعم زر اختيار الجودة بنمط نتفليكس
class MaterialControls extends StatefulWidget {
  final bool showQualityButton;
  final VoidCallback onQualityButtonPressed;
  final VideoQuality selectedQuality;
  final VideoPlayerController? videoPlayerController;

  const MaterialControls({
    Key? key,
    this.showQualityButton = false,
    required this.onQualityButtonPressed,
    required this.selectedQuality,
    this.videoPlayerController,
  }) : super(key: key);

  @override
  _MaterialControlsState createState() => _MaterialControlsState();
}

class _MaterialControlsState extends State<MaterialControls> {
  bool _showControls = true;
  Timer? _hideTimer;
  
  @override
  void initState() {
    super.initState();
    _startHideTimer();
  }
  
  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }
  
  // بدء مؤقت لإخفاء أزرار التحكم
  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }
  
  // إظهار أزرار التحكم وإعادة تشغيل المؤقت
  void _handleTap() {
    setState(() {
      _showControls = !_showControls;
    });
    
    if (_showControls) {
      _startHideTimer();
    }
  }

  // دالة للتقديم بمقدار 10 ثوانٍ
  void _fastForward() {
    if (widget.videoPlayerController != null) {
      final currentPosition = widget.videoPlayerController!.value.position;
      final newPosition = currentPosition + Duration(seconds: 10);
      widget.videoPlayerController!.seekTo(newPosition);
      _startHideTimer();
    }
  }

  // دالة للترجيع بمقدار 10 ثوانٍ
  void _rewind() {
    if (widget.videoPlayerController != null) {
      final currentPosition = widget.videoPlayerController!.value.position;
      final newPosition = currentPosition - Duration(seconds: 10);
      widget.videoPlayerController!.seekTo(newPosition);
      _startHideTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          // استخدام عناصر التحكم الافتراضية من Chewie
          MaterialDesktopControls(),
          
          // إضافة زر اختيار الجودة بنمط نتفليكس
          if (_showControls && widget.showQualityButton)
            Positioned(
              bottom: 16,
              right: 16,
              child: NetflixStyleQualityButton(
                selectedQuality: widget.selectedQuality,
                onPressed: widget.onQualityButtonPressed,
              ),
            ),
            
          // إضافة زر التقديم بمقدار 10 ثوانٍ - تم تعديل الموضع ليكون أقرب للمنتصف
          if (_showControls)
            Positioned(
              top: 0,
              bottom: 0,
              right: MediaQuery.of(context).size.width * 0.25, // تعديل الموضع ليكون أقرب للمنتصف (ربع المسافة من اليمين)
              child: Center(
                child: GestureDetector(
                  onTap: _fastForward,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.forward_10, color: Colors.white, size: 30),
                        Text(
                          '10',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          
          // إضافة زر الترجيع بمقدار 10 ثوانٍ - تم تعديل الموضع ليكون أقرب للمنتصف
          if (_showControls)
            Positioned(
              top: 0,
              bottom: 0,
              left: MediaQuery.of(context).size.width * 0.25, // تعديل الموضع ليكون أقرب للمنتصف (ربع المسافة من اليسار)
              child: Center(
                child: GestureDetector(
                  onTap: _rewind,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.replay_10, color: Colors.white, size: 30),
                        Text(
                          '10',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
