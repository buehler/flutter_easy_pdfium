import 'package:fluorflow/annotations.dart';
import 'package:fluorflow/fluorflow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easy_pdfium/pdf.dart';
import 'package:flutter_easy_pdfium/widgets.dart';
import 'in_memory_viewmodel.dart';

@Routable(
  routeBuilder: RouteBuilder.platform,
)
final class InMemoryView extends FluorFlowView<InMemoryViewModel> {
  const InMemoryView({super.key});

  @override
  Widget builder(
          BuildContext context, InMemoryViewModel viewModel, Widget? child) =>
      Scaffold(
        appBar: AppBar(
          title: const Text('InMemory Example'),
        ),
        body: Column(
          children: [
            const Text(
                'Load a PDF file from memory and display its pages in a scrollable list.'),
            const SizedBox(height: 16),
            if (viewModel.data == null)
              ElevatedButton(
                  onPressed: viewModel.loadDocument,
                  child: const Text('Load PDF')),
            if (viewModel.data != null)
              ElevatedButton(
                  onPressed: viewModel.unloadDocument,
                  child: const Text('Unload PDF')),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            Expanded(
              child: ListenableBuilder(
                  listenable: viewModel.dataNotifier,
                  builder: (context, _) =>
                      switch ((viewModel.busy, viewModel.data)) {
                        (true, _) => const CircularProgressIndicator(),
                        (_, final Document doc) => SingleChildScrollView(
                            padding: const EdgeInsets.only(
                                left: 16, right: 16, bottom: 32),
                            child: FutureBuilder(
                              future: doc.pages
                                  .map((p) => PageRenderer(p))
                                  .toList(),
                              builder: (context, snapshot) => snapshot.hasData
                                  ? Column(
                                      children: snapshot.requireData,
                                    )
                                  : const CircularProgressIndicator(),
                            ),
                          ),
                        _ => const Text('No document loaded'),
                      }),
            )
          ],
        ),
      );

  @override
  InMemoryViewModel viewModelBuilder(BuildContext context) =>
      InMemoryViewModel();
}
