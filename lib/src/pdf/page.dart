import 'dart:ffi' as ffi;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_easy_pdfium/src/pdf/search.dart';
import 'package:flutter_pdfium/flutter_pdfium.dart';

import '../utils/isolate.dart';
import '../utils/lazy.dart';
import 'errors.dart';
import 'pdfium.dart';

/// The default rendering flags.
const int _renderDefaultFlags = FPDF_LCD_TEXT | FPDF_REVERSE_BYTE_ORDER;

/// Base DPI for Flutter, based on
/// https://groups.google.com/g/flutter-dev/c/oYN_prI7sio/m/ZUk9VSHUAQAJ
const _baseDpi = 160.0;

/// Defines the rotation of the rendered bitmap image of a pdf page.
enum PageRenderRotation {
  /// The image is "normal" upfacing.
  rotate0,

  /// The image is rotated clockwise by 90 degrees.
  rotate90,

  /// The image is rotated by 180 degrees.
  rotate180,

  /// The image is rotated clockwise by 270 degrees
  /// (therefore 90 degrees counter-clockwise).
  rotate270,
}

final class Page {
  final FPDF_PAGE _pointer;
  final AsyncLazy<int> _characterCount;

  final Size size;

  Page._(this._pointer)
      : size = Size(
          pdfium().GetPageWidthF(_pointer),
          pdfium().GetPageHeightF(_pointer),
        ),
        _characterCount = AsyncLazy(() => pdfWorker.compute(() {
              final textPointer = pdfium().Text_LoadPage(_pointer);
              final result = pdfium().Text_CountChars(textPointer);
              pdfium().Text_ClosePage(textPointer);
              return result;
            }));

  double get _ratio =>
      WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;

  Size get pixelSize => (size / 72.0) * _baseDpi * _ratio;

  Future<int> get characterCount async => await _characterCount();

  Stream<PageSearchResult> search(String text,
      {bool matchCase = false, bool matchWholeWord = false}) async* {
    if (text.trim().isEmpty) {
      return;
    }

    yield* pdfWorker.computeStream(() async* {
      for (final result in executePageSearch(_pointer, pixelSize,
          text: text, matchCase: matchCase, matchWholeWord: matchWholeWord)) {
        yield result;
      }
    });
  }

  /// Renders the page as a raw [ui.Image]. The returned image is parsed
  /// by flutters native image codec. The received image must be disposed
  /// when it is no longer needed.
  Future<ui.Image> renderImage(
      {Color backgroundColor = const Color.fromARGB(255, 255, 255, 255),
      bool grayscale = false,
      bool renderAnnotations = false,
      PageRenderRotation rotation = PageRenderRotation.rotate0,
      double scale = 1.0}) async {
    assert(scale > 0.0, 'Scale must be greater than 0.0');

    var flags = _renderDefaultFlags;
    if (grayscale) {
      flags = flags | FPDF_GRAYSCALE;
    }
    if (renderAnnotations) {
      flags = flags | FPDF_ANNOT;
    }

    final scaledSize = pixelSize * scale;
    final scaledWidth = scaledSize.width.round();
    final scaledHeight = scaledSize.height.round();

    final data = await pdfWorker.compute(() {
      final bitmapPointer =
          pdfium().Bitmap_Create(scaledWidth, scaledHeight, 1);

      pdfium().Bitmap_FillRect(bitmapPointer, 0, 0, scaledWidth, scaledHeight,
          backgroundColor.value);
      pdfium().RenderPageBitmap(bitmapPointer, _pointer, 0, 0, scaledWidth,
          scaledHeight, rotation.index, flags);
      final stride = pdfium().Bitmap_GetStride(bitmapPointer);
      final bitmapData = pdfium()
          .Bitmap_GetBuffer(bitmapPointer)
          .cast<ffi.Uint8>()
          .asTypedList(scaledHeight * stride);

      final buffer = bitmapData.toList(growable: false);

      pdfium().Bitmap_Destroy(bitmapPointer);

      return buffer;
    });

    final buffer =
        await ui.ImmutableBuffer.fromUint8List(Uint8List.fromList(data));
    final descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: scaledWidth,
      height: scaledHeight,
      pixelFormat: ui.PixelFormat.bgra8888,
    );
    final codec = await descriptor.instantiateCodec();
    final frameInfo = await codec.getNextFrame();

    return frameInfo.image;
  }
}

Future<Page> loadPage(FPDF_DOCUMENT document, int index) =>
    pdfWorker.compute(() {
      final page = pdfium().LoadPage(document, index);
      if (page == ffi.nullptr) {
        throw getLastLibraryError();
      }

      return Page._(page);
    });

Future closePage(Page page) =>
    pdfWorker.compute(() => pdfium().ClosePage(page._pointer));

FPDF_PAGE getPagePointer(Page page) => page._pointer;
