import 'package:flutter_pdfium/flutter_pdfium.dart';

import '../utils/lazy.dart';

void disposeLibrary(Pdfium fpdf) => fpdf.DestroyLibrary();

const pdfium = Lazy(createInitializedLibrary, disposeLibrary);
