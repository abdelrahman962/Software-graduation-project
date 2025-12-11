// Stub for non-web platforms
class HtmlWindow {
  void addEventListener(String type, Function(dynamic) listener) {}
}

class HtmlDocument {
  HtmlDocumentBody? body;
}

class HtmlDocumentBody {
  HtmlStyle? style;
}

class HtmlStyle {
  set margin(String value) {}
  set padding(String value) {}
  set overflow(String value) {}
  set height(String value) {}
  set width(String value) {}
}

class HtmlDocumentStub implements HtmlDocument {
  @override
  HtmlDocumentBody? body = HtmlDocumentBody();
}

class HtmlWindowStub implements HtmlWindow {
  @override
  void addEventListener(String type, Function(dynamic) listener) {}
}

final HtmlWindowStub window = HtmlWindowStub();
final HtmlDocumentStub document = HtmlDocumentStub();
