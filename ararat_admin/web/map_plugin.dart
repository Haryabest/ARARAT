import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

class MapPlugin {
  static void initialize() {
    // Register the map view factory
    ui_web.platformViewRegistry.registerViewFactory('map-view', (int viewId) {
      final div = html.DivElement()
        ..id = 'map-container'
        ..style.width = '100%'
        ..style.height = '100%';
      return div;
    });

    // Load Google Maps API
    final script = html.ScriptElement()
      ..src =
          'https://maps.googleapis.com/maps/api/js?key=YOUR_API_KEY&libraries=places'
      ..async = true;
    html.document.head?.append(script);
  }
} 