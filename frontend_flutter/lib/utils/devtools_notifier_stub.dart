// Stub for non-web platforms
class HtmlVisualViewport {
  double? width;
}

class HtmlWindow {
  HtmlVisualViewport? visualViewport;
  double? innerWidth;
  dynamic onResize; // Stream or something, but for stub, dynamic
}

class Html {
  static HtmlWindow? window;
}
