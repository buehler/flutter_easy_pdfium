import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';
import 'package:flutter_pdfium/flutter_pdfium.dart';

import 'pdfium.dart';

final class Bookmark {
  final FPDF_BOOKMARK _pointer;
  final String title;
  final int pageIndex;
  final int depth;

  const Bookmark._(
    this._pointer, {
    required this.title,
    required this.pageIndex,
    required this.depth,
  });

  @override
  String toString() => 'Bookmark "$title" on page ${pageIndex + 1}';
}

/// Internal method to create a bookmark from pointers and a given [depth].
/// Must be used inside pdfWorker computation.
Bookmark createBookmark(
    FPDF_DOCUMENT documentPointer, FPDF_BOOKMARK bookmarkPointer, int depth) {
  final titleLength =
      pdfium().Bookmark_GetTitle(bookmarkPointer, ffi.nullptr, 0);
  final title = using((arena) {
    final dataBuffer = arena<ffi.Uint16>(titleLength);
    pdfium().Bookmark_GetTitle(
        bookmarkPointer, dataBuffer.cast<ffi.Void>(), titleLength);
    return dataBuffer.cast<Utf16>().toDartString();
  }, malloc);

  final dest = pdfium().Bookmark_GetDest(documentPointer, bookmarkPointer);

  return Bookmark._(
    bookmarkPointer,
    title: title,
    pageIndex: pdfium().Dest_GetDestPageIndex(documentPointer, dest),
    depth: depth,
  );
}
