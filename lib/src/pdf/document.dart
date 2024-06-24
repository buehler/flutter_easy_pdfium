import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter_pdfium/flutter_pdfium.dart';

import '../utils/isolate.dart';
import '../utils/lazy.dart';
import 'bookmark.dart';
import 'errors.dart';
import 'page.dart';
import 'pdfium.dart';
import 'search.dart';

final class Document {
  final FPDF_DOCUMENT _pointer;
  final List<AsyncLazy<Page>> _pages;

  Document._(this._pointer)
      : _pages = List.generate(
          pdfium().GetPageCount(_pointer),
          (index) => AsyncLazy(() => loadPage(_pointer, index), closePage),
          growable: false,
        );

  /// Load a (pdf) document from memory [data] with an optional [password].
  /// Note that documents MUST BE CLOSED with [close] when they are
  /// no longer needed to prevent memory leaks.
  static Future<Document> fromMemory(Uint8List data, [String? password]) =>
      pdfWorker.compute(() {
        final document = using((arena) {
          final dataPointer = arena<ffi.Uint8>(data.length);
          for (var i = 0; i < data.length; i++) {
            dataPointer[i] = data[i];
          }

          final voidPointer = dataPointer.cast<ffi.Void>();

          return pdfium().LoadMemDocument(voidPointer, data.length,
              (password ?? '').toNativeUtf8().cast<ffi.Char>());
        }, malloc);

        if (document == ffi.nullptr) {
          throw getLastLibraryError();
        }

        return Document._(document);
      });

  /// Load a (pdf) document from a file [path] with an optional [password].
  /// Note that documents MUST BE CLOSED with [close] when they are
  /// no longer needed to prevent memory leaks.
  static Future<Document> fromPath(String path, [String? password]) =>
      pdfWorker.compute(() {
        final document = pdfium().LoadDocument(
          path.toNativeUtf8().cast<ffi.Char>(),
          (password ?? '').toNativeUtf8().cast<ffi.Char>(),
        );
        if (document == ffi.nullptr) {
          throw getLastLibraryError();
        }

        return Document._(document);
      });

  int get pageCount => _pages.length;

  Future<Page> operator [](int index) async => _pages[index]();

  Stream<Page> get pages async* {
    for (final page in _pages) {
      yield await page();
    }
  }

  Stream<Bookmark> get bookmarks => pdfWorker.computeStream(() async* {
        Iterable<(FPDF_BOOKMARK, int)> iterateChildren(
            FPDF_BOOKMARK anchor, int level) sync* {
          var child = pdfium().Bookmark_GetFirstChild(_pointer, anchor);
          while (child != ffi.nullptr) {
            yield (child, level);
            yield* iterateChildren(child, level + 1);

            child = pdfium().Bookmark_GetNextSibling(_pointer, child);
          }
        }

        for (final (bookmarkPointer, level)
            in iterateChildren(ffi.nullptr, 0)) {
          yield createBookmark(_pointer, bookmarkPointer, level);
        }
      });

  Future getBookmarkLocation(Bookmark bookmark) async =>
      pdfWorker.compute(() {});

  Stream<DocumentSearchResult> search(String text,
      {bool matchCase = false, bool matchWholeWord = false}) async* {
    if (text.trim().isEmpty) {
      return;
    }

    yield* pdfWorker.computeStream(() async* {
      var pageIndex = 0;
      await for (final page in pages) {
        for (final result in executePageSearch(
            getPagePointer(page), page.pixelSize,
            text: text, matchCase: matchCase, matchWholeWord: matchWholeWord)) {
          yield DocumentSearchResult.fromPageResult(result, pageIndex);
        }
        pageIndex++;
      }
    });
  }

  /// Close the document and release all resources.
  void close() {
    for (final page in _pages) {
      page.dispose();
    }
    pdfium().CloseDocument(_pointer);
  }

  @override
  String toString() => 'Document{pageCount: $pageCount}';
}
