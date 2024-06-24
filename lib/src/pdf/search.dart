import 'dart:ffi' as ffi;
import 'dart:math';
import 'dart:ui';

import 'package:ffi/ffi.dart';
import 'package:flutter_pdfium/flutter_pdfium.dart';

import 'pdfium.dart';

sealed class SearchResult {
  final String match;
  final Rect boundingBox;

  const SearchResult({required this.match, required this.boundingBox});
}

final class PageSearchResult extends SearchResult {
  const PageSearchResult({required super.match, required super.boundingBox});
}

final class DocumentSearchResult extends SearchResult {
  final int pageIndex;

  const DocumentSearchResult(
      {required this.pageIndex,
      required super.match,
      required super.boundingBox});

  factory DocumentSearchResult.fromPageResult(
          PageSearchResult result, int pageIndex) =>
      DocumentSearchResult(
        pageIndex: pageIndex,
        match: result.match,
        boundingBox: result.boundingBox,
      );
}

/// Internal library method to search trough the text of a PDF page.
/// Does not use the pdf worker, therefore, must be used inside a computation.
Iterable<PageSearchResult> executePageSearch(
    FPDF_PAGE page, Size pageSizeInPixel,
    {required String text,
    bool matchCase = false,
    bool matchWholeWord = false}) sync* {
  assert(text.isNotEmpty);

  var flags = 0;
  if (matchCase) {
    flags = flags | FPDF_MATCHCASE;
  }
  if (matchWholeWord) {
    flags = flags | FPDF_MATCHWHOLEWORD;
  }

  final lib = pdfium();
  final textPointer = lib.Text_LoadPage(page);
  final searchPointer = using(
      (arena) => lib.Text_FindStart(
          textPointer,
          text.toNativeUtf8(allocator: arena).cast<ffi.UnsignedShort>(),
          flags,
          0),
      malloc);

  while (lib.Text_FindNext(searchPointer) != 0) {
    final matchStartIndex = lib.Text_GetSchResultIndex(searchPointer);
    final matchCharacterCount = lib.Text_GetSchCount(searchPointer);

    var match = '';
    var left = double.infinity;
    var right = 0.0;
    var top = 0.0;
    var bottom = double.infinity;

    for (var index = matchStartIndex;
        index < matchStartIndex + matchCharacterCount;
        index++) {
      final (l, r, b, t) = using((arena) {
        final leftH = arena<ffi.Double>();
        final topH = arena<ffi.Double>();
        final rightH = arena<ffi.Double>();
        final bottomH = arena<ffi.Double>();

        lib.Text_GetCharBox(textPointer, index, leftH, rightH, bottomH, topH);

        return (
          leftH.value,
          rightH.value,
          bottomH.value,
          topH.value,
        );
      }, malloc);

      // get the unicode character at the position
      final unicodeValue = lib.Text_GetUnicode(textPointer, index);
      match += String.fromCharCode(unicodeValue);

      // left is "from left" so take the minimal value of left to find the left most coordinate of
      // matching characters. start with "double.infinity".
      left = min(left, l);

      // right is calculated "from left". Take the maximal value of all "right values" to
      // get the right-most position of the matches. Start with 0.0.
      right = max(right, r);

      // top is calculated "from bottom". Take the maximal value of all "top points"
      // to get the top-most position of the matches. start with 0.0.
      top = max(top, t);

      // bottom is also calced "from bottom". Take the minimal value of all bottom points
      // to calculate the bottom most position of the rectangle. start with infinity.
      bottom = min(bottom, b);
    }

    final matchBox = using((arena) {
      final deviceLeftPointer = arena<ffi.Int>();
      final deviceTopPointer = arena<ffi.Int>();
      final deviceRightPointer = arena<ffi.Int>();
      final deviceBottomPointer = arena<ffi.Int>();

      lib.PageToDevice(
          page,
          0,
          0,
          pageSizeInPixel.width.round(),
          pageSizeInPixel.height.round(),
          0,
          left,
          top,
          deviceLeftPointer,
          deviceTopPointer);

      lib.PageToDevice(
          page,
          0,
          0,
          pageSizeInPixel.width.round(),
          pageSizeInPixel.height.round(),
          0,
          right,
          bottom,
          deviceRightPointer,
          deviceBottomPointer);

      return Rect.fromLTRB(
        deviceLeftPointer.value.toDouble(),
        deviceTopPointer.value.toDouble(),
        deviceRightPointer.value.toDouble(),
        deviceBottomPointer.value.toDouble(),
      );
    }, malloc);

    yield PageSearchResult(match: match, boundingBox: matchBox);
  }

  lib.Text_FindClose(searchPointer);
  lib.Text_ClosePage(textPointer);
}
