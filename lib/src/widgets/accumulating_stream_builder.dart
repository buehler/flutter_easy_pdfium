import 'dart:async';

import 'package:flutter/widgets.dart';

class AccumulatingStreamBuilder<T> extends StreamBuilder<List<T>> {
  AccumulatingStreamBuilder({required Stream<T> stream, required super.builder})
      : super(
            initialData: [],
            stream: stream.transform(StreamTransformer.fromHandlers(
                handleData: (data, sink) =>
                    sink.add((sink.events ?? [])..add(data)))));
}

// class AccumulatingStreamBuilder extends StatefulWidget {
//   const AccumulatingStreamBuilder({super.key});

//   @override
//   State<AccumulatingStreamBuilder> createState() =>
//       _AccumulatingStreamBuilderState();
// }

// class _AccumulatingStreamBuilderState extends State<AccumulatingStreamBuilder> {
//   @override
//   Widget build(BuildContext context) {
//     return const Placeholder();
//   }
// }
