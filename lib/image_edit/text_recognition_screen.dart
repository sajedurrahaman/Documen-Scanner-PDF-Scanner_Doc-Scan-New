// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:doc_scanner/utils/app_color.dart';
import 'package:doc_scanner/utils/download_helper.dart';
import 'package:doc_scanner/utils/helper.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import '../localaization/language_constant.dart';

class TextRecognitionScreen extends StatefulWidget {
  final String recognisedText;
  const TextRecognitionScreen({super.key, required this.recognisedText});

  @override
  State<TextRecognitionScreen> createState() => _TextRecognitionScreenState();
}

class _TextRecognitionScreenState extends State<TextRecognitionScreen> {
  TextEditingController textEditingController = TextEditingController();
  TextEditingController renameController = TextEditingController();
  String? uniqName;
  @override
  void initState() {
    textEditingController.text = widget.recognisedText;
    super.initState();
  }

  Future<void> savePdfFile(String path, String content) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Center(
          child: pw.Text(content),
        ),
      ),
    );

    // Ensure the directory exists
    final directory = Directory(path).parent;
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final file = File(path);
    await file.writeAsBytes(await pdf.save(), flush: true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "PDF saved successfully to Downloads folder",
          style: TextStyle(
            color: Colors.white,
          ),
        ),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF131314),
      appBar: AppBar(
        backgroundColor: const Color(0xff1E1F20),
        leading: IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(
              Icons.arrow_back,
              color: Color(0xffffffff),
            )),
        centerTitle: true,
        title: Text(
          translation(context).recognizeText,
          style: const TextStyle(
              fontSize: 20, fontWeight: FontWeight.w500, color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await showDialog(
                context: context,
                builder: (context) {
                  TextEditingController renameController =
                      TextEditingController();
                  return AlertDialog(
                    title: const Text("PDF"),
                    content: TextFormField(
                      controller: renameController,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.done,
                      autofocus: true,
                      validator: (value) {
                        if (value!.isEmpty) {
                          return translation(context).pleaseEnterFileName;
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        hintText: translation(context).enterFileName,
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: AppColor.primaryColor),
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 10),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: Text(translation(context).cancel),
                      ),
                      TextButton(
                        onPressed: () async {
                          if (renameController.text.isNotEmpty) {
                            // Get application directory
                            final applicationDirectory =
                                await getApplicationDocumentsDirectory();
                            String baseSavePath =
                                '${applicationDirectory.path}/Doc Scanner/Document';
                            String initialSavePath =
                                '$baseSavePath/${renameController.text}.pdf';

                            Navigator.pop(context);

                            // Check if file exists
                            File file = File(initialSavePath);
                            if (await file.exists()) {
                              String uniqueSavePath = await getUniqueFileName(
                                baseSavePath,
                                renameController.text,
                              );

                              showDialog(
                                context: context,
                                builder: (context) {
                                  return AlertDialog(
                                    title: const Text("File Exists"),
                                    content: const Text(
                                      "This file already exists. Do you want to create a duplicate file?",
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(
                                              context); // Close the dialog
                                        },
                                        child: const Text("Cancel"),
                                      ),
                                      TextButton(
                                        onPressed: () async {
                                          Navigator.pop(context);
                                          await savePdfFile(uniqueSavePath,
                                              textEditingController.text);
                                          await DownloadHelper
                                              .trySaveToPublicDocuments(
                                            uniqueSavePath,
                                            subfolder: 'Document',
                                          );
                                        },
                                        child: const Text("Create Duplicate"),
                                      ),
                                    ],
                                  );
                                },
                              );
                            } else {
                              // Save the PDF if the file doesn't exist
                              await savePdfFile(
                                  initialSavePath, textEditingController.text);
                              await DownloadHelper.trySaveToPublicDocuments(
                                initialSavePath,
                                subfolder: 'Document',
                              );
                            }
                          } else {
                            // Show an error message if the file name is empty
                            ScaffoldMessenger.of(context).clearSnackBars();
                            AppHelper.showTopSnackBar(
                              context,
                              "Please enter a file name",
                            );
                          }
                        },
                        child: Text(translation(context).ok),
                      ),
                    ],
                  );
                },
              );
            },
            child: Text(
              translation(context).save,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColor.primaryColor),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: TextField(
          controller: textEditingController,
          maxLines: null,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            errorBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
        ),
      ),
    );
  }

  Future<String> getUniqueFileName(String baseSavePath, String fileName) async {
    int counter = 1;
    String uniqueFileName = fileName;
    String uniqueSavePath = '$baseSavePath/$uniqueFileName.pdf';

    while (await File(uniqueSavePath).exists()) {
      uniqueFileName = '${fileName}_$counter';
      uniqName = '${fileName}_$counter';
      uniqueSavePath = '$baseSavePath/$uniqueFileName.pdf';
      counter++;
    }

    return uniqueSavePath;
  }
}
