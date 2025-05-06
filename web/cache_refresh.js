// تحسين أداء التطبيق من خلال إدارة ذاكرة التخزين المؤقت
(function() {
  // تنظيف ذاكرة التخزين المؤقت عند بدء التطبيق
  function clearCacheOnStartup() {
    if ('caches' in window) {
      caches.keys().then(function(cacheNames) {
        return Promise.all(
          cacheNames.map(function(cacheName) {
            // حذف جميع ذاكرات التخزين المؤقت القديمة
            return caches.delete(cacheName);
          })
        );
      });
    }
  }

  // تحسين تحميل الموارد
  function optimizeResourceLoading() {
    // إضافة معلمة للتحقق من الإصدار لتجنب التخزين المؤقت
    const timestamp = Date.now();
    const scripts = document.querySelectorAll('script[src]');
    const links = document.querySelectorAll('link[rel="stylesheet"]');
    
    // إضافة طابع زمني لملفات JavaScript
    scripts.forEach(function(script) {
      if (!script.src.includes('?v=')) {
        script.src = script.src + '?v=' + timestamp;
      }
    });
    
    // إضافة طابع زمني لملفات CSS
    links.forEach(function(link) {
      if (!link.href.includes('?v=')) {
        link.href = link.href + '?v=' + timestamp;
      }
    });
  }

  // تحسين أداء الفيديو
  function optimizeVideoPerformance() {
    window.addEventListener('message', function(event) {
      // استقبال رسائل من Flutter
      if (event.data && event.data.type === 'videoOptimization') {
        // تطبيق إعدادات تحسين الفيديو
        if (event.data.action === 'preloadVideo') {
          preloadVideo(event.data.url);
        } else if (event.data.action === 'cleanupCache') {
          clearVideoCache();
        }
      }
    });
  }

  // تحميل الفيديو مسبقاً
  function preloadVideo(url) {
    if (!url) return;
    
    const videoPreload = document.createElement('link');
    videoPreload.rel = 'preload';
    videoPreload.href = url;
    videoPreload.as = 'video';
    document.head.appendChild(videoPreload);
    
    console.log('تم تحميل الفيديو مسبقاً: ' + url);
  }

  // تنظيف ذاكرة التخزين المؤقت للفيديو
  function clearVideoCache() {
    if ('caches' in window) {
      caches.keys().then(function(cacheNames) {
        return Promise.all(
          cacheNames.filter(function(cacheName) {
            return cacheName.includes('video');
          }).map(function(cacheName) {
            return caches.delete(cacheName);
          })
        );
      });
    }
  }

  // تنفيذ التحسينات عند تحميل الصفحة
  window.addEventListener('load', function() {
    // clearCacheOnStartup();
    // optimizeResourceLoading();
    optimizeVideoPerformance();
    
    // إزالة شاشة التحميل بعد 3 ثوانٍ كحد أقصى
    setTimeout(function() {
      const loading = document.getElementById('loading');
      if (loading && loading.style.display !== 'none') {
        loading.style.display = 'none';
      }
    }, 3000);
  });
})();
