import 'dart:developer';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:doc_scanner/camera_screen/model/image_model.dart';
import 'package:doc_scanner/google_ads_helper/banner_ad_widget.dart';
import 'package:doc_scanner/google_ads_helper/google_ads_helper.dart';
import 'package:doc_scanner/image_edit/widget/image_edit_button.dart';
import 'package:doc_scanner/image_edit/widget/signature_sticker_widget.dart';
import 'package:doc_scanner/utils/app_color.dart';
import 'package:doc_scanner/utils/baseurl.dart';
import 'package:doc_scanner/utils/helper.dart';
import 'package:doc_scanner/utils/image_bytes_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../camera_screen/provider/camera_provider.dart';
import '../localaization/language_constant.dart';
import '../utils/app_assets.dart';
import '../utils/meta_events_helper.dart';
import 'drawing.dart';

class AddSignature extends StatefulWidget {
  final ImageModel imageModel;
  final int imageIndex;

  const AddSignature({
    super.key,
    required this.imageModel,
    required this.imageIndex,
  });

  @override
  State<AddSignature> createState() => _AddSignatureState();
}

class _AddSignatureState extends State<AddSignature> {
  String? signaturePath;
  bool drawSignature = false;
  final GlobalKey _globalKey = GlobalKey();
  /// `false` = show red border + handles (edit mode).
  /// `true` = hide controls for screenshot (PDF scanner behavior).
  bool isScaleView = false;
  Uint8List? processedImageBytes;

  @override
  Widget build(BuildContext context) {
    final cameraProvider = context.watch<CameraProvider>();
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
        title: Text(
          translation(context).addSignature,
          style: const TextStyle(
              fontWeight: FontWeight.w500, fontSize: 20, color: Colors.white),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () async {
              // Hide sticker border/handles, then capture only the page
              // bounds (no body letterbox → no extra top/bottom pad).
              setState(() => isScaleView = true);
              await WidgetsBinding.instance.endOfFrame;
              await Future<void>.delayed(const Duration(milliseconds: 32));
              if (!mounted) return;
              final image = await captureImage();
              if (image == null || !mounted) return;
              cameraProvider.updateImage(
                image: widget.imageModel.withDisplayBytes(image),
                index: widget.imageIndex,
              );
              await MetaEventsHelper.logPdfSigned();
              if (mounted) Navigator.pop(context);
            },
            child: Text(
              translation(context).done,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColor.primaryColor,
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Center outside RepaintBoundary so padding/empty space is not
            // baked into the page (was causing top/bottom letterbox).
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: constraints.maxWidth,
                  maxHeight: constraints.maxHeight,
                ),
                child: RepaintBoundary(
                  key: _globalKey,
                  child: Stack(
                    fit: StackFit.passthrough,
                    children: [
                      Image.memory(
                        widget.imageModel.imageByte,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                      ),
                      if (processedImageBytes != null)
                        SignatureStickerWidget(
                          key: ValueKey(
                            'processed_signature_${processedImageBytes.hashCode}',
                          ),
                          isScaleView: isScaleView,
                          onDelete: () =>
                              setState(() => processedImageBytes = null),
                          child: Image.memory(
                            processedImageBytes!,
                            width: 100,
                            fit: BoxFit.contain,
                          ),
                        ),
                      if (signaturePath != null)
                        SignatureStickerWidget(
                          key: const ValueKey('drawn_signature'),
                          isScaleView: isScaleView,
                          onDelete: () => setState(() => signaturePath = null),
                          child: drawSignature
                              ? SvgPicture.string(signaturePath!, width: 100)
                              : Image.memory(
                                  Uint8List.fromList(
                                      signaturePath!.codeUnits),
                                  width: 100,
                                  fit: BoxFit.contain,
                                ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: BottomBarWithBanner(
        adUnitId: AdHelper.addSignatureBannerAdUnitId,
        child: BottomAppBar(
        color: const Color(0xff1E1F20),
        padding: const EdgeInsets.symmetric(horizontal: 10.0),
        surfaceTintColor: const Color(0xff1E1F20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            ImageEditButton(
              title: translation(context).draw,
              onTap: () async {
                var signature = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DrawingScreen(),
                  ),
                );
                if (signature != null) {
                  setState(() {
                    signaturePath = signature;
                    processedImageBytes = null;
                    drawSignature = true;
                    isScaleView = false;
                  });
                }
              },
              iconPath: AppAssets.sign,
            ),
            ImageEditButton(
              title: 'Scan',
              onTap: () async {
                await importFromScan();
              },
              iconPath: AppAssets.scan,
            ),
            ImageEditButton(
              title: translation(context).gallery,
              onTap: () async {
                await importFromGallery();
              },
              iconPath: AppAssets.gallery,
            ),
          ],
        ),
      ),
      ),
    );
  }

  Future<Uint8List?> captureImage() async {
    try {
      final boundary = _globalKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      log(boundary.size.toString());
      // Keep capture sharp but avoid huge bitmaps on high-DPI devices.
      final pixelRatio =
          MediaQuery.of(context).devicePixelRatio.clamp(1.0, 3.0);
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;
      // Match other edit tools — JPEG page, no PNG alpha letterbox edges.
      return ensureJpegBytes(byteData.buffer.asUint8List());
    } catch (e) {
      return null;
    }
  }

  Future<void> importFromGallery() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final file = File(pickedFile.path);
      final processedBytes = await removeImageBackground(
        context: context,
        imageFile: file,
      );

      if (!mounted || processedBytes == null) return;
      setState(() {
        processedImageBytes = processedBytes;
        signaturePath = null;
        drawSignature = false;
        isScaleView = false;
      });
    }
  }

  Future<void> importFromScan() async {
    try {
      await AppHelper.handlePermissions();
      final pictures = await CunningDocumentScanner.getPictures(
        isGalleryImportAllowed: true,
        noOfPages: 1,
      );

      if (pictures == null || pictures.isEmpty) return;

      final file = File(pictures.first);
      final processedBytes = await removeImageBackground(
        context: context,
        imageFile: file,
      );

      if (!mounted || processedBytes == null) return;
      setState(() {
        processedImageBytes = processedBytes;
        signaturePath = null;
        drawSignature = false;
        isScaleView = false;
      });
    } catch (e) {
      // Scanner cancelled by user.
    }
  }

  /// Same endpoint/logic as PDF-Scanner-Convert-Document.
  Future<Uint8List?> removeImageBackground({
    required BuildContext context,
    required File imageFile,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        title: Text('Processing Image'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Removing background...'),
          ],
        ),
      ),
    );

    try {
      final uri = Uri.parse('$baseUrl/convert/remove-background');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          imageFile.path,
          filename: imageFile.path.split('/').last,
        ),
      );

      final streamedResponse = await request.send();
      final responseBytes = await streamedResponse.stream.toBytes();

      if (streamedResponse.statusCode != 200) {
        final status = streamedResponse.statusCode;
        final message = status == 422
            ? 'Image could not be processed. Please use a clearer signature image.'
            : 'Server error ($status). Please try again.';
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: Colors.red),
          );
        }
        debugPrint(
          'removeImageBackground failed ($status): '
          '${String.fromCharCodes(responseBytes).trim()}',
        );
        return null;
      }

      return responseBytes;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to remove image background.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      debugPrint('removeImageBackground exception: $e');
      return null;
    } finally {
      if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }
}
