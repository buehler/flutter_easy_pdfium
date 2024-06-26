import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../pdf/page.dart' as p;

class PageRenderer extends StatefulWidget {
  final p.Page page;

  const PageRenderer(this.page, {super.key});

  @override
  State<PageRenderer> createState() => _PageRendererState();
}

class _PageRendererState extends State<PageRenderer> {
  ui.Image? _image;
  var _disposed = false;

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.page.renderImage().then((image) =>
          !_disposed ? setState(() => _image = image) : image.dispose());
    });
    super.initState();
  }

  @override
  void dispose() {
    _disposed = true;
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _image == null
      ? SizedBox.fromSize(size: widget.page.pixelSize)
      : RawImage(image: _image!);
}
