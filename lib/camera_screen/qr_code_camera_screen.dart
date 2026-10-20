import 'package:doc_scanner/utils/copy_feedback.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:doc_scanner/camera_screen/provider/camera_provider.dart';
import 'package:doc_scanner/camera_screen/widget/analyzee_image.dart';
import 'package:doc_scanner/camera_screen/widget/scanner_button_widget.dart';
import 'package:doc_scanner/camera_screen/widget/scanner_error_widget.dart';
import 'package:doc_scanner/camera_screen/widget/zoom_scale_slider.dart';
import 'package:doc_scanner/core/local_storage.dart';
import 'package:doc_scanner/localaization/language_constant.dart';
import 'package:doc_scanner/utils/app_constant.dart';
import 'package:doc_scanner/utils/helper.dart';
import 'package:doc_scanner/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vibration/vibration.dart';

class QRCodeCameraScreen extends StatefulWidget {
  const QRCodeCameraScreen({super.key});

  @override
  _QRCodeCameraScreenState createState() => _QRCodeCameraScreenState();
}

class _QRCodeCameraScreenState extends State<QRCodeCameraScreen> {
  final MobileScannerController controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  bool activeDialog = false;
  final player = AudioPlayer();
  void _openBrowserWithSearch(String query) async {
    // Encode the query to make it URL-safe
    final encodedQuery = Uri.encodeComponent(query);
    // Form the Google search URL
    final url = 'https://www.google.com/search?q=$encodedQuery';

    // Check if the URL can be launched
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  String _formatBarcodeContent(String rawValue) {
    final StringBuffer formattedContent = StringBuffer();

    List<String> parts = rawValue.split(';');
    for (var part in parts.where((p) => p.isNotEmpty)) {
      List<String> keyValue = part.split(':');
      String key = keyValue[0];
      String value = keyValue.length > 1 ? keyValue.sublist(1).join(':') : '';

      if (key.toLowerCase() == "wifi") {
        formattedContent.writeln("WIFI NAME : $value");
      } else if (key == "T") {
        formattedContent.writeln("TYPE : $value");
      } else if (key == "P") {
        formattedContent.writeln("PASSWORD : $value");
      } else {
        formattedContent.writeln("$key : $value");
      }
    }

    return formattedContent.toString();
  }

  @override
  Widget build(BuildContext context) {
    final cameraProvider = context.watch<CameraProvider>();
    final scanWindow = Rect.fromCenter(
      center: MediaQuery.sizeOf(context).center(const Offset(0, -5)),
      width: 300,
      height: 300,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: MobileScanner(
              controller: controller,
              scanWindow: scanWindow,
              onDetect: (capture) async {
                final List<Barcode> barcodes = capture.barcodes;
                if (!activeDialog && barcodes.isNotEmpty) {
                  final barcode =
                      barcodes.first; // Get the first detected barcode
                  LocalStorage().getBool(AppConstant.BEEP_KEY) == true
                      ? player.play(
                          AssetSource('audio/beep_sound.mp3'),
                        )
                      : null; // Place the beep file in assets

                  // Trigger vibration
                  LocalStorage().getBool(AppConstant.VIBRATION_KEY) == true
                      ? Vibration.vibrate(
                          duration: 200) // Vibrate for 200 milliseconds
                      : null;

                  if (barcode.rawValue != null) {
                    setState(() {
                      activeDialog = true;
                    });
                    controller.stop(); // Pause the camera
                    // _showQrAndBarCodeDialogue(context, barcode.rawValue!);
                    showQrAndBarCodeDialogue(
                      context: context,
                      title: translation(context).qrCodeDetected,
                      content: barcode.rawValue.toString(),
                      browserView: () {
                        StringBuffer formattedContent = StringBuffer();

                        List<String> parts =
                            barcode.rawValue.toString().split(';');
                        for (var part in parts.where((p) => p.isNotEmpty)) {
                          List<String> keyValue = part.split(':');
                          String key = keyValue[0];
                          String value = keyValue.length > 1
                              ? keyValue.sublist(1).join(':')
                              : '';

                          // Format keys into labels
                          if (key == "WIFI" || key == "Wifi" || key == "wifi") {
                            formattedContent.writeln("WIFI NAME : $value");
                          } else if (key == "T") {
                            formattedContent.writeln("TYPE : $value");
                          } else if (key == "P") {
                            formattedContent.writeln("PASSWORD : $value");
                          } else {
                            formattedContent.writeln("$key : $value");
                          }
                        }

                        // Copy the formatted content to the clipboard
                        barcode.rawValue.toString().startsWith("WIFI") ||
                                barcode.rawValue
                                    .toString()
                                    .startsWith("Wifi") ||
                                barcode.rawValue.toString().startsWith("wifi")
                            ? _openBrowserWithSearch(
                                formattedContent.toString())
                            : _openBrowserWithSearch(
                                barcode.rawValue.toString(),
                              );
                      },
                      onCopy: () async {
                        StringBuffer formattedContent = StringBuffer();

                        List<String> parts =
                            barcode.rawValue.toString().split(';');
                        for (var part in parts.where((p) => p.isNotEmpty)) {
                          List<String> keyValue = part.split(':');
                          String key = keyValue[0];
                          String value = keyValue.length > 1
                              ? keyValue.sublist(1).join(':')
                              : '';

                          // Format keys into labels
                          if (key == "WIFI" || key == "Wifi" || key == "wifi") {
                            formattedContent.writeln("WIFI NAME : $value");
                          } else if (key == "T") {
                            formattedContent.writeln("TYPE : $value");
                          } else if (key == "P") {
                            formattedContent.writeln("PASSWORD : $value");
                          } else {
                            formattedContent.writeln("$key : $value");
                          }
                        }

                        // Copy the formatted content to the clipboard
                        barcode.rawValue.toString().startsWith("WIFI") ||
                                barcode.rawValue
                                    .toString()
                                    .startsWith("Wifi") ||
                                barcode.rawValue.toString().startsWith("wifi")
                            ? Clipboard.setData(ClipboardData(
                                text: formattedContent.toString()))
                            : Clipboard.setData(ClipboardData(
                                text: barcode.rawValue.toString(),
                              ));
                        showCopyFeedback(context, translation(context).copiedToClipboard);

                        Navigator.pop(context);

                        await _resumeCamera();
                      },
                      onSave: () async {
                        // Add your saving logic here
                        cameraProvider.saveQRCodeText(
                            barcode.rawValue.toString(), context);
                        Navigator.pop(context);
                        await _resumeCamera();
                      },
                      cancle: () async {
                        Navigator.pop(context);

                        await _resumeCamera();
                      },
                    );
                  }
                }
              },
              errorBuilder: (context, error, child) {
                return ScannerErrorWidget(error: error);
              },
            ),
          ),
          ValueListenableBuilder(
            valueListenable: controller,
            builder: (context, value, child) {
              if (!value.isInitialized ||
                  !value.isRunning ||
                  value.error != null) {
                return const SizedBox();
              }

              return CustomPaint(
                painter: ScannerOverlay(scanWindow: scanWindow),
              );
            },
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Color(0xffffffff),
                      )),

                  // SwitchCameraButton(controller: controller),
                ],
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -120),
            child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width:AppHelper.isIpad(context)?180: 125,
                  height:AppHelper.isIpad(context)?70: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.black.withOpacity(0.4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ToggleFlashlightButton(controller: controller),
                      ValueListenableBuilder(
                          valueListenable: controller,
                          builder: (context, state, child) {
                            if (!state.isInitialized || !state.isRunning) {
                              return const SizedBox.shrink();
                            }

                            return VerticalDivider(
                              color: Colors.white.withOpacity(0.5),
                              endIndent: 12,
                              indent: 12,
                            );
                          }),
                      AnalyzeImageButton(
                        type: "QR Code",
                        onBarcodeFound: (String rawValue) async {
                          if (!activeDialog) {
                            setState(() {
                              activeDialog = true;
                            });
                            controller.stop();

                            final formattedContent =
                                _formatBarcodeContent(rawValue);

                            showQrAndBarCodeDialogue(
                              context: context,
                              title: translation(context).qrCodeDetected,
                              content: rawValue,
                              browserView: () {
                                rawValue.toLowerCase().startsWith("wifi")
                                    ? _openBrowserWithSearch(formattedContent)
                                    : _openBrowserWithSearch(rawValue);
                              },
                              onCopy: () async {
                                rawValue.toLowerCase().startsWith("wifi")
                                    ? Clipboard.setData(
                                        ClipboardData(text: formattedContent))
                                    : Clipboard.setData(
                                        ClipboardData(text: rawValue));

                                showCopyFeedback(context, translation(context).copiedToClipboard);

                                Navigator.pop(context);
                                await _resumeCamera();
                              },
                              onSave: () async {
                                context
                                    .read<CameraProvider>()
                                    .saveQRCodeText(rawValue, context);
                                Navigator.pop(context);
                                await _resumeCamera();
                              },
                              cancle: () async {
                                Navigator.pop(context);
                                await _resumeCamera();
                              },
                            );
                          }
                        },
                        controller: controller,
                      ),
                    ],
                  ),
                )),
          ),
          Transform.translate(
            offset: const Offset(0, -35),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                  width: MediaQuery.of(context).size.width,
                  height: 60,
                  child: ZoomScaleSlider(controller: controller)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _resumeCamera() async {
    setState(() {
      activeDialog = false;
    });
    await controller.start(); // Resume the camera
    await controller.setZoomScale(0.0);
  }

  @override
  Future<void> dispose() async {
    super.dispose();
    await controller.dispose();
  }
}

class ScannerOverlay extends CustomPainter {
  const ScannerOverlay({
    required this.scanWindow,
    this.borderRadius = 8.0,
  });

  final Rect scanWindow;
  final double borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    // we need to pass the size to the custom paint widget
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final cutoutPath = Path()
      ..addRRect(
        RRect.fromRectAndCorners(
          scanWindow,
          topLeft: Radius.circular(borderRadius),
          topRight: Radius.circular(borderRadius),
          bottomLeft: Radius.circular(borderRadius),
          bottomRight: Radius.circular(borderRadius),
        ),
      );

    final backgroundPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.dstOver;

    final backgroundWithCutout = Path.combine(
      PathOperation.difference,
      backgroundPath,
      cutoutPath,
    );

    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;

    final borderRect = RRect.fromRectAndCorners(
      scanWindow,
      topLeft: Radius.circular(borderRadius),
      topRight: Radius.circular(borderRadius),
      bottomLeft: Radius.circular(borderRadius),
      bottomRight: Radius.circular(borderRadius),
    );

    // First, draw the background,
    // with a cutout area that is a bit larger than the scan window.
    // Finally, draw the scan window itself.
    canvas.drawPath(backgroundWithCutout, backgroundPaint);
    canvas.drawRRect(borderRect, borderPaint);
  }

  @override
  bool shouldRepaint(ScannerOverlay oldDelegate) {
    return scanWindow != oldDelegate.scanWindow ||
        borderRadius != oldDelegate.borderRadius;
  }
}
