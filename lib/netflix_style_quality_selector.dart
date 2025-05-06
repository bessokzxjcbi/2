import 'package:flutter/material.dart';
import 'models.dart';

class NetflixStyleQualitySelector extends StatelessWidget {
  final List<VideoQuality> qualities;
  final VideoQuality selectedQuality;
  final Function(VideoQuality) onQualitySelected;

  const NetflixStyleQualitySelector({
    Key? key,
    required this.qualities,
    required this.selectedQuality,
    required this.onQualitySelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.9),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // عنوان القائمة
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'جودة الفيديو',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          
          // قائمة الجودات
          ListView.builder(
            shrinkWrap: true,
            itemCount: qualities.length,
            itemBuilder: (context, index) {
              final quality = qualities[index];
              final isSelected = selectedQuality.resolution == quality.resolution;
              
              return ListTile(
                title: Text(
                  _getQualityDisplayName(quality.resolution),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: isSelected 
                  ? Icon(Icons.check_circle, color: Colors.red) 
                  : null,
                onTap: () {
                  Navigator.of(context).pop();
                  onQualitySelected(quality);
                },
              );
            },
          ),
        ],
      ),
    );
  }
  
  // تحويل اسم الدقة إلى اسم عرض أكثر وضوحاً
  String _getQualityDisplayName(String resolution) {
    switch (resolution) {
      case '240p':
        return 'منخفضة (240p)';
      case '360p':
        return 'منخفضة (360p)';
      case '480p':
        return 'متوسطة (480p)';
      case '720p':
        return 'عالية (720p)';
      case '1080p':
        return 'عالية الوضوح (1080p)';
      case '2160p':
        return 'فائقة الوضوح (4K)';
      default:
        return resolution;
    }
  }
}

// زر اختيار الجودة بنمط نتفليكس
class NetflixStyleQualityButton extends StatelessWidget {
  final VideoQuality selectedQuality;
  final VoidCallback onPressed;

  const NetflixStyleQualityButton({
    Key? key,
    required this.selectedQuality,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.settings, color: Colors.white, size: 18),
            SizedBox(width: 4),
            Text(
              _getQualityDisplayName(selectedQuality.resolution),
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
  
  // تحويل اسم الدقة إلى اسم عرض أكثر وضوحاً
  String _getQualityDisplayName(String resolution) {
    switch (resolution) {
      case '240p':
        return 'منخفضة';
      case '360p':
        return 'منخفضة';
      case '480p':
        return 'متوسطة';
      case '720p':
        return 'عالية';
      case '1080p':
        return 'عالية الوضوح';
      case '2160p':
        return '4K';
      default:
        return resolution;
    }
  }
}

// عرض نافذة منبثقة لاختيار الجودة بنمط نتفليكس
void showNetflixStyleQualitySelector(
  BuildContext context,
  List<VideoQuality> qualities,
  VideoQuality selectedQuality,
  Function(VideoQuality) onQualitySelected,
) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => NetflixStyleQualitySelector(
      qualities: qualities,
      selectedQuality: selectedQuality,
      onQualitySelected: onQualitySelected,
    ),
  );
}
