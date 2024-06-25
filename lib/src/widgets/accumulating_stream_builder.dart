import 'dart:async';

import 'package:flutter/widgets.dart';

StreamTransformer<T, List<T>> _transformer<T>() {
  final items = List<T>.empty(growable: true);
  return StreamTransformer.fromHandlers(
    handleData: (data, sink) => sink.add(items..add(data)),
  );
}

class AccumulatingStreamBuilder<T> extends StreamBuilder<List<T>> {
  AccumulatingStreamBuilder(
      {super.key, required Stream<T> stream, required super.builder})
      : super(initialData: [], stream: stream.transform(_transformer<T>()));
}
