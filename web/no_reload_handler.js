// إضافة كود للتعامل مع التنقل بدون إعادة تحميل
// هذا الملف يضيف وظائف لتحسين تجربة المستخدم وتجنب إعادة تحميل الصفحة

// تنفيذ وظيفة للتعامل مع التنقل بين الصفحات
function setupSinglePageNavigation() {
  // التقاط جميع الروابط الداخلية
  document.addEventListener('click', function(event) {
    // التحقق مما إذا كان العنصر المنقر عليه هو رابط
    let target = event.target;
    while (target && target.tagName !== 'A') {
      target = target.parentElement;
    }
    
    // إذا كان رابطًا داخليًا
    if (target && target.href && target.href.startsWith(window.location.origin)) {
      // منع السلوك الافتراضي (إعادة تحميل الصفحة)
      event.preventDefault();
      
      // استخدام History API للتنقل بدون إعادة تحميل
      const url = new URL(target.href);
      window.history.pushState({}, '', url);
      
      // إرسال حدث مخصص للتطبيق للتعامل مع التغيير في المسار
      const navigationEvent = new CustomEvent('flutter-route-change', {
        detail: { path: url.pathname }
      });
      window.dispatchEvent(navigationEvent);
      
      // إضافة: تحديث الكاش عند التنقل بين الصفحات
      if (window.dispatchEvent) {
        window.dispatchEvent(new CustomEvent('force-cache-refresh'));
      }
    }
  });
  
  // التعامل مع أزرار التنقل في المتصفح (الرجوع/التقدم)
  window.addEventListener('popstate', function() {
    // إرسال حدث مخصص للتطبيق للتعامل مع التغيير في المسار
    const navigationEvent = new CustomEvent('flutter-route-change', {
      detail: { path: window.location.pathname }
    });
    window.dispatchEvent(navigationEvent);
    
    // إضافة: تحديث الكاش عند استخدام أزرار التنقل
    if (window.dispatchEvent) {
      window.dispatchEvent(new CustomEvent('force-cache-refresh'));
    }
  });
}

// تنفيذ وظيفة لتخزين حالة التطبيق
function setupStateManagement() {
  // حفظ حالة التطبيق في sessionStorage عند تغيير الصفحة
  window.addEventListener('beforeunload', function() {
    // يمكن للتطبيق استخدام هذا الحدث لحفظ الحالة
    const stateEvent = new CustomEvent('flutter-save-state');
    window.dispatchEvent(stateEvent);
    
    // إضافة: تسجيل وقت الخروج من الصفحة
    localStorage.setItem('lastExitTimestamp', new Date().getTime());
  });
  
  // استعادة حالة التطبيق عند العودة إلى الصفحة
  window.addEventListener('flutter-first-frame', function() {
    // يمكن للتطبيق استخدام هذا الحدث لاستعادة الحالة
    const stateEvent = new CustomEvent('flutter-restore-state');
    window.dispatchEvent(stateEvent);
    
    // إضافة: التحقق من وقت الخروج السابق
    const lastExit = localStorage.getItem('lastExitTimestamp');
    const currentTime = new Date().getTime();
    
    // إذا كان آخر خروج قبل أكثر من دقيقة، تحديث الكاش
    if (lastExit && (currentTime - lastExit > 60 * 1000)) {
      console.log('تم اكتشاف فترة طويلة منذ آخر استخدام، جاري تحديث الكاش...');
      if (window.dispatchEvent) {
        window.dispatchEvent(new CustomEvent('force-cache-refresh'));
      }
    }
  });
}

// تنفيذ وظيفة لتحسين تحميل الموارد
function setupResourcePreloading() {
  // تحميل مسبق للموارد الشائعة
  const resources = [
    // يمكن إضافة مسارات للصور والملفات الشائعة هنا
  ];
  
  // إنشاء عناصر preload لتحميل الموارد مسبقًا
  resources.forEach(function(resource) {
    const link = document.createElement('link');
    link.rel = 'preload';
    link.href = resource;
    link.as = resource.endsWith('.js') ? 'script' : 
              resource.endsWith('.css') ? 'style' : 
              resource.endsWith('.jpg') || resource.endsWith('.jpeg') || resource.endsWith('.png') ? 'image' : 
              'fetch';
    
    // إضافة: إضافة طابع زمني للموارد المحملة مسبقًا
    const timestamp = new Date().getTime();
    link.href = link.href.includes('?') ? 
      `${link.href}&_=${timestamp}` : 
      `${link.href}?_=${timestamp}`;
      
    document.head.appendChild(link);
  });
}

// إضافة: وظيفة للتعامل مع تحديثات الصفحة
function setupPageRefreshHandling() {
  // التقاط حدث تحديث الصفحة
  window.addEventListener('beforeunload', function(event) {
    // تسجيل وقت التحديث
    localStorage.setItem('lastRefreshTimestamp', new Date().getTime());
  });
  
  // التحقق من وقت آخر تحديث عند تحميل الصفحة
  window.addEventListener('load', function() {
    const lastRefresh = localStorage.getItem('lastRefreshTimestamp');
    const currentTime = new Date().getTime();
    
    // تحديث وقت التحميل الحالي
    localStorage.setItem('lastLoadTimestamp', currentTime);
    
    // إذا كان آخر تحديث قبل أكثر من 5 دقائق، تنظيف الكاش
    if (lastRefresh && (currentTime - lastRefresh > 5 * 60 * 1000)) {
      console.log('تم اكتشاف فترة طويلة منذ آخر تحديث، جاري تنظيف الكاش...');
      
      // محاولة تنظيف الكاش باستخدام Cache API إذا كانت متوفرة
      if (window.caches) {
        caches.keys().then(function(cacheNames) {
          return Promise.all(
            cacheNames.map(function(cacheName) {
              return caches.delete(cacheName);
            })
          );
        }).then(function() {
          console.log('تم تنظيف الكاش بنجاح');
        }).catch(function(error) {
          console.warn('تعذر تنظيف الكاش:', error);
        });
      }
    }
  });
}

// تهيئة جميع الوظائف عند تحميل الصفحة
document.addEventListener('DOMContentLoaded', function() {
  setupSinglePageNavigation();
  setupStateManagement();
  setupResourcePreloading();
  setupPageRefreshHandling(); // إضافة: تهيئة وظيفة التعامل مع تحديثات الصفحة
  
  console.log('تم تهيئة وظائف تحسين التنقل بدون إعادة تحميل');
  
  // إضافة: إرسال حدث لتحديث الكاش عند تحميل الصفحة
  if (window.dispatchEvent) {
    window.dispatchEvent(new CustomEvent('force-cache-refresh'));
  }
});

// إضافة: وظيفة للتحقق من تحديثات الصفحة بشكل دوري
setInterval(function() {
  // إرسال طلب للتحقق من آخر وقت تعديل للصفحة
  const timestamp = new Date().getTime();
  fetch(`${window.location.href}?_=${timestamp}`, { 
    method: 'HEAD',
    cache: 'no-store'
  })
  .then(function(response) {
    // التحقق من رأس Last-Modified
    const lastModified = response.headers.get('Last-Modified');
    if (lastModified) {
      const lastModifiedTime = new Date(lastModified).getTime();
      const lastCheckedTime = localStorage.getItem('lastCheckedModifiedTime');
      
      // تحديث وقت آخر تحقق
      localStorage.setItem('lastCheckedModifiedTime', lastModifiedTime);
      
      // إذا كان هناك تغيير في وقت التعديل، إعادة تحميل الصفحة
      if (lastCheckedTime && lastModifiedTime > lastCheckedTime) {
        console.log('تم اكتشاف تحديث في الصفحة، جاري إعادة التحميل...');
        window.location.reload(true);
      }
    }
  })
  .catch(function(error) {
    console.warn('تعذر التحقق من تحديثات الصفحة:', error);
  });
}, 5 * 60 * 1000); // التحقق كل 5 دقائق
