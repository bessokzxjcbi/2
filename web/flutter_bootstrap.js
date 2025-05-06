// flutter_bootstrap.js
// هذا الملف يقوم بتهيئة تطبيق Flutter Web ويضمن توافقه مع جميع المتصفحات

// تضمين كود Flutter الأساسي (سيتم استبداله أثناء البناء)
{{flutter_js}}

// تضمين إعدادات البناء (سيتم استبداله أثناء البناء)
{{flutter_build_config}}

// تكوين Flutter لاستخدام renderer من نوع CanvasKit لضمان التوافق مع جميع المتصفحات
const flutterConfig = {
  // استخدام CanvasKit بدلاً من HTML renderer
  renderer: "canvaskit",
  
  // تحسين أداء CanvasKit
  canvasKitMaximumSurfaces: 8,
  
  // تعطيل وضع التصحيح للسيمانتكس
  debugShowSemanticNodes: false
};

// تهيئة Flutter مع إعدادات مخصصة
_flutter.loader.load({
  config: flutterConfig,
  onEntrypointLoaded: async (engineInitializer) => {
    try {
      // تهيئة المحرك
      const appRunner = await engineInitializer.initializeEngine({
        // يمكن إضافة إعدادات إضافية هنا إذا لزم الأمر
      });
      
      // تشغيل التطبيق
      await appRunner.runApp();
      
      console.log("تم تهيئة تطبيق Flutter Web بنجاح باستخدام CanvasKit renderer");
    } catch (e) {
      console.error("حدث خطأ أثناء تهيئة تطبيق Flutter Web:", e);
    }
  }
});
