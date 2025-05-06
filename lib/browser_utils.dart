// ملف للكشف عن نوع المتصفح بدون استخدام مكتبات خارجية
import 'dart:js' as js;
import 'package:flutter/foundation.dart' show kIsWeb;

// دالة للتحقق مما إذا كان المتصفح هو متصفح هاتف محمول
bool isMobileBrowser() {
  if (!kIsWeb) return false;
  
  try {
    // استخدام JavaScript مباشرة للوصول إلى navigator.userAgent
    final userAgent = js.context['navigator']['userAgent'].toString().toLowerCase();
    return userAgent.contains('android') || 
           userAgent.contains('iphone') || 
           userAgent.contains('ipad') || 
           userAgent.contains('ipod') ||
           userAgent.contains('mobile') ||
           userAgent.contains('tablet');
  } catch (e) {
    print('خطأ في الكشف عن نوع المتصفح: $e');
    return false;
  }
}

// دالة للتحقق مما إذا كان المتصفح هو متصفح iOS
bool isIOSBrowser() {
  if (!kIsWeb) return false;
  
  try {
    // استخدام JavaScript مباشرة للوصول إلى navigator.userAgent
    final userAgent = js.context['navigator']['userAgent'].toString().toLowerCase();
    return userAgent.contains('iphone') || 
           userAgent.contains('ipad') || 
           userAgent.contains('ipod');
  } catch (e) {
    print('خطأ في الكشف عن نوع متصفح iOS: $e');
    return false;
  }
}

// دالة للتحقق مما إذا كان المتصفح هو متصفح Android
bool isAndroidBrowser() {
  if (!kIsWeb) return false;
  
  try {
    // استخدام JavaScript مباشرة للوصول إلى navigator.userAgent
    final userAgent = js.context['navigator']['userAgent'].toString().toLowerCase();
    return userAgent.contains('android');
  } catch (e) {
    print('خطأ في الكشف عن نوع متصفح Android: $e');
    return false;
  }
}

// دالة لتنفيذ كود JavaScript
void executeJavaScript(String jsCode) {
  if (!kIsWeb) return;
  
  try {
    // تنفيذ كود JavaScript مباشرة
    js.context.callMethod('eval', [jsCode]);
  } catch (e) {
    print('خطأ في تنفيذ JavaScript: $e');
  }
}

// دالة لطلب الوضع الأفقي باستخدام واجهة برمجة التطبيقات المباشرة
void requestLandscapeMode() {
  if (!kIsWeb) return;
  
  try {
    // استدعاء الدالة المعرفة في index.html
    js.context.callMethod('requestLandscapeMode', []);
  } catch (e) {
    print('خطأ في طلب الوضع الأفقي: $e');
  }
}

// دالة لإعادة الوضع الطبيعي
void resetOrientation() {
  if (!kIsWeb) return;
  
  try {
    // استدعاء الدالة المعرفة في index.html
    js.context.callMethod('resetOrientation', []);
  } catch (e) {
    print('خطأ في إعادة الوضع الطبيعي: $e');
  }
}
