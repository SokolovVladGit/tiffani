/// Safe product-description HTML.
///
/// Tags become data. Nothing here is executed, and unknown markup is
/// unwrapped so its text survives.
sealed class CatalogHtmlNode {
  const CatalogHtmlNode();
}

class CatalogHtmlText extends CatalogHtmlNode {
  final String text;

  const CatalogHtmlText(this.text);
}

class CatalogHtmlElement extends CatalogHtmlNode {
  final String tag;
  final String? href;
  final List<CatalogHtmlNode> children;

  const CatalogHtmlElement(this.tag, this.children, {this.href});
}

class CatalogDescription {
  final String? plain;
  final List<CatalogHtmlNode> html;
  final String? country;

  const CatalogDescription({
    required this.plain,
    required this.html,
    required this.country,
  });

  bool get isHtml => html.isNotEmpty;

  bool get isEmpty =>
      !isHtml && (plain == null || plain!.trim().isEmpty);
}

const catalogHtmlTags = {
  'p',
  'br',
  'strong',
  'em',
  'u',
  'span',
  'a',
  'ul',
  'ol',
  'li',
};

const _voidTags = {'br'};
const _droppedTags = {'script', 'style', 'iframe', 'object', 'embed'};

/// Full HTML wins. The 500-character intro is only the fallback.
CatalogDescription? prepareCatalogDescription({
  String? full,
  String? short,
}) {
  final fullText = full?.trim();
  final source = (fullText != null && fullText.isNotEmpty)
      ? fullText
      : short?.trim();
  if (source == null || source.isEmpty) return null;

  final withoutCountry = _takeCountry(source);
  if (_looksLikeHtml(withoutCountry.body)) {
    return CatalogDescription(
      plain: null,
      html: parseCatalogHtml(withoutCountry.body),
      country: withoutCountry.country,
    );
  }

  final plain = _plainText(withoutCountry.body);
  if (plain == null && withoutCountry.country == null) return null;
  return CatalogDescription(
    plain: plain,
    html: const [],
    country: withoutCountry.country,
  );
}

List<CatalogHtmlNode> parseCatalogHtml(String source) {
  final root = <CatalogHtmlNode>[];
  final stack = <_Frame>[_Frame(null, root)];
  final buffer = StringBuffer();
  var i = 0;

  void flush() {
    if (buffer.isEmpty) return;
    final text = decodeCatalogHtml(buffer.toString());
    buffer.clear();
    if (text.isEmpty) return;
    final parent = stack.last.tag;
    if ((parent == null || parent == 'ul' || parent == 'ol') &&
        text.trim().isEmpty) {
      return;
    }
    stack.last.children.add(CatalogHtmlText(text));
  }

  while (i < source.length) {
    if (source[i] != '<') {
      buffer.write(source[i]);
      i++;
      continue;
    }
    if (source.startsWith('<!--', i)) {
      flush();
      final end = source.indexOf('-->', i + 4);
      i = end < 0 ? source.length : end + 3;
      continue;
    }
    final close = source.indexOf('>', i + 1);
    if (close < 0) {
      buffer.write(source.substring(i));
      break;
    }
    final raw = source.substring(i + 1, close).trim();
    i = close + 1;
    if (raw.isEmpty) continue;
    flush();

    final selfClosing = raw.endsWith('/');
    final body = selfClosing ? raw.substring(0, raw.length - 1).trim() : raw;
    if (body.startsWith('/')) {
      final name = _tagName(body.substring(1));
      _closeTag(stack, name);
      continue;
    }
    if (body.startsWith('!') || body.startsWith('?')) continue;

    final name = _tagName(body);
    if (_droppedTags.contains(name)) {
      i = _skipUntilClose(source, i, name);
      continue;
    }
    if (_voidTags.contains(name) || selfClosing) {
      stack.last.children.add(CatalogHtmlElement(name, const []));
      continue;
    }
    final href = name == 'a' ? _safeHref(body) : null;
    final frame = _Frame(name, <CatalogHtmlNode>[], href: href);
    stack.last.children.add(
      CatalogHtmlElement(name, frame.children, href: href),
    );
    stack.add(frame);
  }
  flush();
  return _unwrapUnknown(root);
}

String decodeCatalogHtml(String input) {
  return input.replaceAllMapped(
    RegExp(r'&(#x[0-9a-fA-F]+|#\d+|[a-zA-Z]+);'),
    (match) {
      final token = match.group(1)!;
      if (token.startsWith('#x')) {
        final value = int.tryParse(token.substring(2), radix: 16);
        return value == null ? match.group(0)! : String.fromCharCode(value);
      }
      if (token.startsWith('#')) {
        final value = int.tryParse(token.substring(1));
        return value == null ? match.group(0)! : String.fromCharCode(value);
      }
      return _namedEntities[token.toLowerCase()] ?? match.group(0)!;
    },
  );
}

class _Frame {
  final String? tag;
  final List<CatalogHtmlNode> children;
  final String? href;

  _Frame(this.tag, this.children, {this.href});
}

void _closeTag(List<_Frame> stack, String name) {
  for (var i = stack.length - 1; i > 0; i--) {
    if (stack[i].tag == name) {
      stack.removeRange(i, stack.length);
      return;
    }
  }
}

int _skipUntilClose(String source, int from, String name) {
  final end = RegExp('</$name\\s*>', caseSensitive: false).firstMatch(
    source.substring(from),
  );
  if (end == null) return source.length;
  return from + end.end;
}

String _tagName(String body) {
  final match = RegExp(r'^([a-zA-Z0-9]+)').firstMatch(body.trim());
  return match?.group(1)?.toLowerCase() ?? '';
}

String? _safeHref(String body) {
  final match = RegExp(
    '''href\\s*=\\s*(?:"([^"]*)"|'([^']*)'|([^\\s>]+))''',
    caseSensitive: false,
  ).firstMatch(body);
  if (match == null) return null;
  final raw = (match.group(1) ?? match.group(2) ?? match.group(3) ?? '').trim();
  final uri = Uri.tryParse(raw);
  if (uri == null) return null;
  if (uri.scheme != 'https' && uri.scheme != 'http') return null;
  return uri.toString();
}

List<CatalogHtmlNode> _unwrapUnknown(List<CatalogHtmlNode> nodes) {
  final out = <CatalogHtmlNode>[];
  for (final node in nodes) {
    if (node is CatalogHtmlText) {
      if (node.text.isNotEmpty) out.add(node);
      continue;
    }
    final element = node as CatalogHtmlElement;
    final children = _unwrapUnknown(element.children);
    if (catalogHtmlTags.contains(element.tag)) {
      out.add(CatalogHtmlElement(element.tag, children, href: element.href));
    } else {
      out.addAll(children);
    }
  }
  return out;
}

bool _looksLikeHtml(String source) {
  return RegExp(r'<\s*/?\s*[a-zA-Z]').hasMatch(source);
}

({String body, String? country}) _takeCountry(String source) {
  final match = RegExp(
    r'(?:<p[^>]*>\s*)?Страна[- ]производитель\s*:\s*([^<\n]+)(?:\s*</p>)?',
    caseSensitive: false,
  ).firstMatch(source);
  if (match == null) return (body: source, country: null);
  final country = decodeCatalogHtml(match.group(1)!).trim();
  final body = source.replaceRange(match.start, match.end, '').trim();
  return (
    body: body,
    country: country.isEmpty ? null : country,
  );
}

String? _plainText(String source) {
  final text = decodeCatalogHtml(
    source
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'<[^>]+>'), ''),
  ).replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  return text.isEmpty ? null : text;
}

const _namedEntities = {
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
  'nbsp': '\u00A0',
  'ndash': '\u2013',
  'mdash': '\u2014',
  'laquo': '«',
  'raquo': '»',
  'hellip': '…',
};
