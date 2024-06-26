import 'package:fluorflow/annotations.dart';
import 'package:fluorflow/fluorflow.dart';
import 'package:flutter/material.dart';

import 'bookmarks_viewmodel.dart';

@Routable(
  routeBuilder: RouteBuilder.platform,
)
final class BookmarksView extends FluorFlowView<BookmarksViewModel> {
  const BookmarksView({super.key});

  @override
  Widget builder(
          BuildContext context, BookmarksViewModel viewModel, Widget? child) =>
      Scaffold(
        appBar: AppBar(
          title: const Text('Bookmarks Example'),
        ),
        body: Column(
          children: [
            const Text('Show the bookmarks (document outline) of a PDF.'),
            const SizedBox(height: 16),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            if (viewModel.data != null)
              Expanded(
                child: SingleChildScrollView(
                  child: FutureBuilder(
                      future: viewModel.data!.bookmarks.toList(),
                      builder: (context, snapshot) => snapshot.hasData
                          ? Column(
                              children: snapshot.requireData
                                  .map((b) => ListTile(
                                        title: Text(
                                            '${List.filled(b.depth, '-').join()}${b.title}'),
                                        subtitle: Text(
                                            'Page ${b.pageIndex + 1} (@ ${b.depth} level)'),
                                      ))
                                  .toList(),
                            )
                          : const CircularProgressIndicator()),
                ),
              )
          ],
        ),
      );

  @override
  BookmarksViewModel viewModelBuilder(BuildContext context) =>
      BookmarksViewModel();
}
