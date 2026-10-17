import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

class PdfViewScreen extends StatefulWidget {
  PdfViewScreen({super.key, required this.filePath, required this.fileName});
  String filePath;
  final String? fileName;

  @override
  State<PdfViewScreen> createState() => _PdfViewScreenState();
}

class _PdfViewScreenState extends State<PdfViewScreen> {
  static const int _initialPage = 1;
  late PdfControllerPinch _pdfControllerPinch;

  @override
  void initState() {
    _pdfControllerPinch = PdfControllerPinch(
      // document: PdfDocument.openAsset('assets/hello.pdf'),
      document: PdfDocument.openFile(widget.filePath),
      initialPage: _initialPage,
    );
    super.initState();
  }

  @override
  void dispose() {
    _pdfControllerPinch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey,
      appBar: AppBar(
        backgroundColor: const Color(0xff1E1F20),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.fileName.toString(),
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: PdfViewPinch(
        builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
          options: const DefaultBuilderOptions(),
          documentLoaderBuilder: (_) =>
              const Center(child: CircularProgressIndicator()),
          pageLoaderBuilder: (_) =>
              const Center(child: CircularProgressIndicator()),
          errorBuilder: (_, error) => Center(child: Text(error.toString())),
        ),
        controller: _pdfControllerPinch,
      ),
      bottomNavigationBar: BottomAppBar(
        color: const Color(0xff1E1F20),
        height: 60,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.navigate_before),
              onPressed: () {
                _pdfControllerPinch.previousPage(
                  curve: Curves.ease,
                  duration: const Duration(milliseconds: 100),
                );
              },
            ),
            PdfPageNumber(
              controller: _pdfControllerPinch,
              builder: (_, loadingState, page, pagesCount) => Container(
                alignment: Alignment.center,
                child: Text(
                  '$page/${pagesCount ?? 0}',
                  style: const TextStyle(fontSize: 22, color: Colors.white),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.navigate_next),
              onPressed: () {
                _pdfControllerPinch.nextPage(
                  curve: Curves.ease,
                  duration: const Duration(milliseconds: 100),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
