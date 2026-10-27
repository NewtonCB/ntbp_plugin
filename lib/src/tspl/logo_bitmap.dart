import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// A 1-bit image in TSPL `BITMAP` row format: rows of [widthBytes] bytes,
/// most significant bit first, where a 1 bit is white (not printed) and a
/// 0 bit is black.
class MonoBitmap {
  final int width;
  final int height;
  final Uint8List data;

  const MonoBitmap({required this.width, required this.height, required this.data});

  int get widthBytes => (width + 7) ~/ 8;

  /// Fraction of black pixels, useful for tests and density checks.
  double get inkCoverage {
    var black = 0;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final byte = data[y * widthBytes + (x >> 3)];
        if ((byte & (0x80 >> (x & 7))) == 0) black++;
      }
    }
    return width * height == 0 ? 0 : black / (width * height);
  }
}

/// A logo (or any raster image) prepared for printing on a label.
///
/// Decode once with [CargoLogo.fromBytes] (PNG, JPEG, GIF, BMP, WebP) and
/// reuse the instance for every label; [toMono] scales and thresholds the
/// image to the size the layout asks for and caches the result.
///
/// Colour is reduced with a luminance threshold: anything darker than
/// [threshold] prints black. Transparent pixels count as white. Logos with
/// coloured artwork on a light background work well; photographs should
/// use [dither].
class CargoLogo {
  final img.Image _source;

  /// 0..255. Pixels with luminance below this print black.
  final int threshold;

  /// Floyd-Steinberg dithering instead of a hard threshold.
  final bool dither;

  MonoBitmap? _cached;
  int _cachedMaxWidth = -1;
  int _cachedMaxHeight = -1;

  CargoLogo._(this._source, {required this.threshold, required this.dither});

  /// Decodes [bytes]. Returns null when the format is not recognised.
  static CargoLogo? fromBytes(Uint8List bytes, {int threshold = 170, bool dither = false}) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    return CargoLogo._(_flattenOnWhite(decoded), threshold: threshold, dither: dither);
  }

  int get sourceWidth => _source.width;
  int get sourceHeight => _source.height;

  /// Scales the logo to fit inside [maxWidth] x [maxHeight] dots (keeping
  /// the aspect ratio, never upscaling beyond 2x) and converts it to 1-bit.
  MonoBitmap toMono({required int maxWidth, required int maxHeight}) {
    final cached = _cached;
    if (cached != null && _cachedMaxWidth == maxWidth && _cachedMaxHeight == maxHeight) {
      return cached;
    }

    final scale = [
      maxWidth / _source.width,
      maxHeight / _source.height,
      2.0,
    ].reduce((a, b) => a < b ? a : b);
    final w = (_source.width * scale).floor().clamp(1, maxWidth);
    final h = (_source.height * scale).floor().clamp(1, maxHeight);

    var scaled = (w == _source.width && h == _source.height)
        ? _source
        : img.copyResize(_source, width: w, height: h, interpolation: img.Interpolation.average);
    scaled = img.grayscale(scaled);

    final widthBytes = (w + 7) ~/ 8;
    final data = Uint8List(widthBytes * h);
    // Start all white (1 bits), including the padding bits past the width.
    data.fillRange(0, data.length, 0xFF);

    if (dither) {
      final err = List<double>.filled((w + 2) * (h + 1), 0);
      int idx(int x, int y) => y * (w + 2) + x + 1;
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final lum = scaled.getPixel(x, y).r.toDouble() + err[idx(x, y)];
          final black = lum < 128;
          final value = black ? 0.0 : 255.0;
          final e = lum - value;
          if (black) data[y * widthBytes + (x >> 3)] &= ~(0x80 >> (x & 7));
          err[idx(x + 1, y)] += e * 7 / 16;
          err[idx(x - 1, y + 1)] += e * 3 / 16;
          err[idx(x, y + 1)] += e * 5 / 16;
          err[idx(x + 1, y + 1)] += e * 1 / 16;
        }
      }
    } else {
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          if (scaled.getPixel(x, y).r < threshold) {
            data[y * widthBytes + (x >> 3)] &= ~(0x80 >> (x & 7));
          }
        }
      }
    }

    final result = MonoBitmap(width: w, height: h, data: data);
    _cached = result;
    _cachedMaxWidth = maxWidth;
    _cachedMaxHeight = maxHeight;
    return result;
  }

  /// Composites transparent areas onto white so they do not print black.
  static img.Image _flattenOnWhite(img.Image source) {
    if (!source.hasAlpha) return source.convert(numChannels: 3);
    final out = img.Image(width: source.width, height: source.height, numChannels: 3);
    for (final p in source) {
      final a = p.a / p.maxChannelValue;
      final r = (p.r * a + 255 * (1 - a)).round();
      final g = (p.g * a + 255 * (1 - a)).round();
      final b = (p.b * a + 255 * (1 - a)).round();
      out.setPixelRgb(p.x, p.y, r, g, b);
    }
    return out;
  }
}
