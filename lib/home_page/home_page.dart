// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:doc_scanner/camera_screen/bar_code_camera_screen.dart';
import 'package:doc_scanner/camera_screen/model/image_model.dart';
import 'package:doc_scanner/camera_screen/qr_code_camera_screen.dart';
import 'package:doc_scanner/google_ads_helper/google_ads_helper.dart';
import 'package:doc_scanner/home_page/provider/home_page_provider.dart';
import 'package:doc_scanner/home_page/search_page.dart';
import 'package:doc_scanner/image_edit/id_card_image_view.dart';
import 'package:doc_scanner/image_edit/image_edit_preview.dart';
import 'package:doc_scanner/main.dart';
import 'package:doc_scanner/utils/app_assets.dart';
import 'package:doc_scanner/utils/app_color.dart';
import 'package:doc_scanner/utils/helper.dart';
import 'package:doc_scanner/utils/pdf_view_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
// ignore: depend_on_referenced_packages
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';
import '../camera_screen/provider/camera_provider.dart';
import '../localaization/language_constant.dart';
import '../utils/utils.dart';
import 'directory_view.dart';
import 'model/camera_item_model.dart';
import 'package:http/http.dart' as http;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomePageProvider>().clearDocumentImageFiles();
      context.read<HomePageProvider>().clearIdCardImageFiles();
      context.read<HomePageProvider>().clearQRCodeFiles();
      context.read<HomePageProvider>().clearBarCodeFiles();
      context.read<HomePageProvider>().loadDocumentImage();
      context.read<HomePageProvider>().loadIdCardImage();
      context.read<HomePageProvider>().loadQRCode();
      context.read<HomePageProvider>().loadBarCode();
      context.read<HomePageProvider>().getDirectoriesForCreate();

      checkForUpdate(context);
      showInterstitialAd(context);
    });
    super.initState();
  }

  Future<void> checkForUpdate(BuildContext context) async {
    print("objects: checkForUpdate called");
    final PackageInfo info = await PackageInfo.fromPlatform();
    final String currentVersion = info.version;
    final String packageName = info.packageName;
    print("objects: $currentVersion");
    print("objects: $packageName");

    final playStoreUrl =
        'https://play.google.com/store/apps/details?id=$packageName&hl=en';

    try {
      final response = await http.get(Uri.parse(playStoreUrl));
      if (response.statusCode == 200) {
        print('url: ${response.body}');
        // Use regex to extract the version number from the HTML response
        final regex = RegExp(r'Current Version.+?>([\d.]+)<');
        final match = regex.firstMatch(response.body);
        if (match != null) {
          final storeVersion = match.group(1)!.trim();
          if (_isVersionNewer(currentVersion, storeVersion)) {
            _showUpdateDialog(context, packageName);
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to check version: $e');
    }
  }

  bool _isVersionNewer(String current, String store) {
    final curr = current.split('.').map(int.parse).toList();
    final st = store.split('.').map(int.parse).toList();

    for (int i = 0; i < st.length; i++) {
      if (i >= curr.length || st[i] > curr[i]) return true;
      if (st[i] < curr[i]) return false;
    }
    return false;
  }

  void _showUpdateDialog(BuildContext context, String packageName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text("Update Required"),
          content: const Text(
              "A new version of the app is available. Please update to continue."),
          actions: [
            TextButton(
              onPressed: () async {
                final url =
                    "https://play.google.com/store/apps/details?id=$packageName";
                if (await canLaunch(url)) {
                  await launch(url);
                }
              },
              child: const Text("Update"),
            ),
            TextButton(
              onPressed: () {
                // Exit app
                Future.delayed(const Duration(milliseconds: 200), () {
                  // Use SystemNavigator.pop() or exit(0)
                  // SystemNavigator.pop(); // if in main page
                  // or
                  Future.delayed(
                      Duration.zero, () => Navigator.of(context).pop());
                });
              },
              child: const Text("Exit"),
            ),
          ],
        );
      },
    );
  }

  void checkCameraPermissionAndNavigate(
      BuildContext context, Widget targetScreen) async {
    PermissionStatus status = await Permission.camera.status;

    if (status.isGranted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => targetScreen,
        ),
      );
    } else if (status.isDenied) {
      PermissionStatus newStatus = await Permission.camera.request();

      if (newStatus.isGranted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => targetScreen,
          ),
        );
      } else if (newStatus.isPermanentlyDenied) {
        AppHelper.showTopSnackBar(context, "Permission is required!");
        Future.delayed(const Duration(seconds: 3), () {
          openAppSettings();
        });
      }
    } else if (status.isPermanentlyDenied) {
      AppHelper.showTopSnackBar(context, "Permission is required!");

      Future.delayed(const Duration(seconds: 3), () {
        openAppSettings();
      });
    }
  }

  String getCameraModeName(String name, BuildContext context) {
    switch (name) {
      case "Document":
        return translation(context).documents;
      case "ID Card":
        return translation(context).idCard;
      case "QR Code":
        return translation(context).qrCode;
      case "Bar Code":
        return translation(context).barCode;
      default:
        return "";
    }
  }

  String getFolderModeName(String name, BuildContext context) {
    switch (name) {
      case "Document":
        return translation(context).documents;
      case "ID Card":
        return translation(context).idCard;
      case "QR Code":
        return translation(context).qrCode;
      case "Bar Code":
        return translation(context).barCode;
      default:
        return "";
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final homePageProvider = Provider.of<HomePageProvider>(context);
    final cameraProvider = Provider.of<CameraProvider>(context);
    final size = MediaQuery.sizeOf(context);
    return ValueListenableBuilder<bool>(
        valueListenable: interstitialReadyNotifier,
        builder: (context, interstitialReady, _) {
          return Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shadowColor: Colors.transparent,
              scrolledUnderElevation: 0,
              elevation: 0,
              title: Text(translation(context).docScanner),
              titleTextStyle: const TextStyle(
                fontSize: 28,
                color: Colors.black,
                fontWeight: FontWeight.w500,
              ),
              actions: [
                // GestureDetector(
                //     onTap: () {
                //       Navigator.push(
                //         context,
                //         MaterialPageRoute(
                //           builder: (context) =>
                //               const DirectoryCreatePage(),
                //         ),
                //       );
                //     },
                //     child: SvgPicture.asset(
                //       AppAssets.create_folder,
                //       height:AppHelper.isTablet(context)?32: 28,
                //       width:AppHelper.isTablet(context)?32: 28,
                //     )),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15.0),
                  child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SearchPage(),
                          ),
                        );
                      },
                      child: SvgPicture.asset(
                        AppAssets.search,
                        height: AppHelper.isTablet(context) ? 32 : 28,
                        width: AppHelper.isTablet(context) ? 32 : 28,
                      )),
                ),
                // IconButton(
                //   onPressed: () async {
                //     Navigator.push(
                //       context,
                //       MaterialPageRoute(
                //         builder: (context) => const DirectoryCreatePage(),
                //       ),
                //     );
                //
                //   },
                //   icon:  Icon(
                //     Icons.create_new_folder,
                //     color: AppColor.primaryColor,
                //     size: size.width >= 600? 30: 25,
                //   ),
                // ),
                // IconButton(
                //   onPressed: () async {
                //
                //     Navigator.push(
                //       context,
                //       MaterialPageRoute(
                //         builder: (context) => const SearchPage(),
                //       ),
                //     );
                //   },
                //   icon:  Icon(
                //     Icons.search,
                //     size: size.width >= 600? 30: 25,
                //   ),
                // ),
              ],
            ),
            body: cameraProvider.pdfConverting
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          width: MediaQuery.sizeOf(context).width,
                          alignment: Alignment.center,
                          height: size.width >= 600 ? 130 : 100,
                          child: Row(
                            mainAxisAlignment: size.width >= 600
                                ? MainAxisAlignment.spaceAround
                                : MainAxisAlignment.spaceEvenly,
                            children:
                                List.generate(cameraItems.length, (index) {
                              final cameraItem = cameraItems[index];
                              return GestureDetector(
                                onTap: () async {
                                  if (cameraItem.name == "Document") {
                                    try {
                                      final pictures =
                                          await CunningDocumentScanner
                                              .getPictures(
                                        isGalleryImportAllowed: true,
                                      );

                                      if (pictures != null &&
                                          pictures.isNotEmpty) {
                                        for (var element in pictures) {
                                          String imageName =
                                              DateFormat('yyyyMMdd_SSSS')
                                                  .format(DateTime.now());
                                          cameraProvider.addImage(ImageModel(
                                            docType: 'Document',
                                            imageByte: await File(element)
                                                .readAsBytes(),
                                            name: "Document-$imageName",
                                          ));
                                        }

                                        if (cameraProvider
                                            .imageList.isNotEmpty) {
                                          createInterstitialAd();
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const EditImagePreview(),
                                            ),
                                          );
                                        }
                                      }
                                    } catch (e) {
                                      debugPrint("Error: $e");

                                      AppHelper.showTopSnackBar(context,
                                          'Failed to scan document: $e');
                                    }
                                  } else if (cameraItem.name == "ID Card") {
                                    try {
                                      final pictures =
                                          await CunningDocumentScanner
                                              .getPictures(
                                        noOfPages: 2,
                                        isGalleryImportAllowed: true,
                                      );

                                      if (pictures != null &&
                                          pictures.isNotEmpty) {
                                        for (var element in pictures) {
                                          cameraProvider
                                              .addIdCardImage(element);
                                        }

                                        if (cameraProvider
                                            .idCardImages.isNotEmpty) {
                                          createInterstitialAd();
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const IdCardImagePreview(
                                                imageIndex: 2,
                                                isCameFromRetake: false,
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    } catch (e) {
                                      debugPrint("Error: $e");
                                      AppHelper.showTopSnackBar(context,
                                          'Failed to scan ID Card: $e');
                                    }
                                  } else {
                                    cameraItem.name == "QR Code"
                                        ? checkCameraPermissionAndNavigate(
                                            context,
                                            const QRCodeCameraScreen(),
                                          )
                                        : checkCameraPermissionAndNavigate(
                                            context,
                                            const BarCodeCameraScreen(),
                                          );
                                  }
                                },
                                child: Column(
                                  children: [
                                    CircleAvatar(
                                      radius: size.width >= 600 ? 40 : 30,
                                      backgroundColor: cameraItem.color,
                                      child: SvgPicture.asset(cameraItem.icon,
                                          height: size.width >= 600 ? 30 : 25,
                                          width: size.width >= 600 ? 30 : 25),
                                    ),
                                    SizedBox(
                                      width: size.width >= 600 ? 100 : 67,
                                      child: Text(
                                        getCameraModeName(
                                            cameraItem.name, context),
                                        style: TextStyle(
                                            fontSize:
                                                AppHelper.isTablet(context)
                                                    ? 14
                                                    : 12),
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                      ),
                                    )
                                  ],
                                ),
                              );
                            }),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          width: MediaQuery.sizeOf(context).width,
                          height: 110,
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: size.width >= 600
                                ? MainAxisAlignment.spaceAround
                                : MainAxisAlignment.spaceEvenly,
                            children: List.generate(
                                homePageProvider.directories.length, (index) {
                              final directory =
                                  homePageProvider.directories[index];
                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            DirectoryDetailsPage(
                                          directoryPath: directory.path,
                                        ),
                                      ));
                                },
                                child: Container(
                                  width: size.width >= 600 ? 90 : 70,
                                  alignment: Alignment.center,
                                  decoration: const BoxDecoration(
                                    image: DecorationImage(
                                      image: AssetImage(
                                          'assets/icons/folder_bg.png'),
                                      fit: BoxFit.fill,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.folder,
                                        size: size.width >= 600 ? 50 : 40,
                                        color: AppColor.primaryColor,
                                      ),
                                      Text(
                                        getFolderModeName(
                                            path.basename(directory.path),
                                            context),
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: AppHelper.isTablet(context)
                                              ? 14
                                              : 12,
                                          fontWeight: FontWeight.w400,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                        Expanded(
                          child: homePageProvider.isHistoryLoading
                              ? const Center(
                                  child: CircularProgressIndicator(),
                                )
                              : Row(
                                  children: [
                                    SizedBox(
                                      width: MediaQuery.sizeOf(context).width *
                                          0.235,
                                      child: ListView.builder(
                                        scrollDirection: Axis.vertical,
                                        itemCount: homePageProvider
                                            .documentImageFiles.length,
                                        itemBuilder: (context, index) {
                                          final imageFile = homePageProvider
                                              .documentImageFiles[index];

                                          if (imageFile.path
                                                  .toLowerCase()
                                                  .endsWith('.jpg') ||
                                              imageFile.path
                                                  .toLowerCase()
                                                  .endsWith('.jpeg') ||
                                              imageFile.path
                                                  .toLowerCase()
                                                  .endsWith('.png')) {
                                            return GestureDetector(
                                              onTap: () async {
                                                await flutterGenralDialogue(
                                                  context: context,
                                                  imageFile: imageFile,
                                                );
                                              },
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(8.0),
                                                child: Container(
                                                  width: 90,
                                                  height: 100,
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                    color: Colors.grey.shade200,
                                                  ),
                                                  padding:
                                                      const EdgeInsets.all(8),
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceAround,
                                                    children: [
                                                      SizedBox(
                                                        height: 60,
                                                        child: Image.file(
                                                          imageFile,
                                                        ),
                                                      ),
                                                      SizedBox(
                                                        height: 20,
                                                        child: Text(
                                                          path.basename(
                                                              imageFile.path),
                                                          style:
                                                              const TextStyle(
                                                            color: Colors.black,
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w400,
                                                          ),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          textAlign:
                                                              TextAlign.center,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            );
                                          } else if (imageFile.path
                                              .toLowerCase()
                                              .endsWith('.pdf')) {
                                            return GestureDetector(
                                              onTap: () async {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        PdfViewScreen(
                                                      filePath: imageFile.path,
                                                      fileName: imageFile.path
                                                          .split('/')
                                                          .last,
                                                    ),
                                                  ),
                                                );
                                              },
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(8.0),
                                                child: Container(
                                                  width: 90,
                                                  height: 100,
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                    color: Colors.grey.shade200,
                                                  ),
                                                  padding:
                                                      const EdgeInsets.all(8),
                                                  child: Column(
                                                    children: [
                                                      SizedBox(
                                                        height: 60,
                                                        child: SvgPicture.asset(
                                                            AppAssets.pdf),
                                                      ),
                                                      SizedBox(
                                                        height: 20,
                                                        child: Text(
                                                          path.basename(
                                                              imageFile.path),
                                                          style:
                                                              const TextStyle(
                                                            color: Colors.black,
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            );
                                          }
                                          return Text(translation(context)
                                              .somethingWentWrong);
                                        },
                                      ),
                                    ),
                                    SizedBox(
                                      width: MediaQuery.sizeOf(context).width *
                                          0.235,
                                      child: ListView.builder(
                                        scrollDirection: Axis.vertical,
                                        itemCount: homePageProvider
                                            .idCardImageFiles.length,
                                        itemBuilder: (context, index) {
                                          final imageFile = homePageProvider
                                              .idCardImageFiles[index];

                                          if (imageFile.path
                                                  .toLowerCase()
                                                  .endsWith('.jpg') ||
                                              imageFile.path
                                                  .toLowerCase()
                                                  .endsWith('.jpeg') ||
                                              imageFile.path
                                                  .toLowerCase()
                                                  .endsWith('.png')) {
                                            return GestureDetector(
                                              onTap: () async {
                                                await flutterGenralDialogue(
                                                  context: context,
                                                  imageFile: imageFile,
                                                );
                                              },
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(8.0),
                                                child: Container(
                                                  height: 100,
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                    color: Colors.grey.shade200,
                                                  ),
                                                  padding:
                                                      const EdgeInsets.all(8),
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceAround,
                                                    children: [
                                                      SizedBox(
                                                        height: 60,
                                                        child: Image.file(
                                                          imageFile,
                                                        ),
                                                      ),
                                                      SizedBox(
                                                        height: 20,
                                                        child: Text(
                                                          path.basename(
                                                              imageFile.path),
                                                          style:
                                                              const TextStyle(
                                                            color: Colors.black,
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w400,
                                                          ),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            );
                                          } else if (imageFile.path
                                              .toLowerCase()
                                              .endsWith('.pdf')) {
                                            return GestureDetector(
                                              onTap: () async {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        PdfViewScreen(
                                                      filePath: imageFile.path,
                                                      fileName: imageFile.path
                                                          .split('/')
                                                          .last,
                                                    ),
                                                  ),
                                                );
                                              },
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(8.0),
                                                child: Container(
                                                  width: 90,
                                                  height: 100,
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                    color: Colors.grey.shade200,
                                                  ),
                                                  padding:
                                                      const EdgeInsets.all(8),
                                                  child: Column(
                                                    children: [
                                                      SizedBox(
                                                        height: 60,
                                                        child: SvgPicture.asset(
                                                            AppAssets.pdf),
                                                      ),
                                                      SizedBox(
                                                        height: 20,
                                                        child: Text(
                                                          path.basename(
                                                              imageFile.path),
                                                          style:
                                                              const TextStyle(
                                                            color: Colors.black,
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w400,
                                                          ),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            );
                                          }
                                          return Text(translation(context)
                                              .somethingWentWrong);
                                        },
                                      ),
                                    ),
                                    SizedBox(
                                      width: MediaQuery.sizeOf(context).width *
                                          0.235,
                                      child: ListView.builder(
                                        scrollDirection: Axis.vertical,
                                        itemCount:
                                            homePageProvider.qrCodeFiles.length,
                                        itemBuilder: (context, index) {
                                          final qrCode = homePageProvider
                                              .qrCodeFiles[index];
                                          return GestureDetector(
                                            onTap: () async {
                                              var urlLink =
                                                  await homePageProvider
                                                      .readTxtFile(qrCode);
                                              showQrAndBarCodeViewDialogue(
                                                  context: context,
                                                  text: await homePageProvider
                                                      .readTxtFile(qrCode),
                                                  browserView: () {
                                                    StringBuffer
                                                        formattedContent =
                                                        StringBuffer();

                                                    List<String> parts = urlLink
                                                        .toString()
                                                        .split(';');
                                                    for (var part
                                                        in parts.where((p) =>
                                                            p.isNotEmpty)) {
                                                      List<String> keyValue =
                                                          part.split(':');
                                                      String key = keyValue[0];
                                                      String value =
                                                          keyValue.length > 1
                                                              ? keyValue
                                                                  .sublist(1)
                                                                  .join(':')
                                                              : '';

                                                      // Format keys into labels
                                                      if (key == "WIFI" ||
                                                          key == "Wifi" ||
                                                          key == "wifi") {
                                                        formattedContent.writeln(
                                                            "WIFI NAME : $value");
                                                      } else if (key == "T") {
                                                        formattedContent.writeln(
                                                            "TYPE : $value");
                                                      } else if (key == "P") {
                                                        formattedContent.writeln(
                                                            "PASSWORD : $value");
                                                      } else {
                                                        formattedContent.writeln(
                                                            "$key : $value");
                                                      }
                                                    }

                                                    // Copy the formatted content to the clipboard
                                                    urlLink
                                                                .toString()
                                                                .startsWith(
                                                                    "WIFI") ||
                                                            urlLink
                                                                .toString()
                                                                .startsWith(
                                                                    "Wifi") ||
                                                            urlLink
                                                                .toString()
                                                                .startsWith(
                                                                    "wifi")
                                                        ? _openBrowserWithSearch(
                                                            formattedContent
                                                                .toString())
                                                        : _openBrowserWithSearch(
                                                            urlLink);
                                                  });
                                            },
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.all(8.0),
                                              child: Container(
                                                width: 90,
                                                height: 100,
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  color: Colors.grey.shade200,
                                                ),
                                                padding:
                                                    const EdgeInsets.all(8),
                                                child: Column(
                                                  children: [
                                                    SizedBox(
                                                      height: 60,
                                                      child: SvgPicture.asset(
                                                          AppAssets.txt),
                                                    ),
                                                    SizedBox(
                                                      height: 20,
                                                      child: Text(
                                                        path.basename(qrCode),
                                                        style: const TextStyle(
                                                          color: Colors.black,
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w400,
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
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
                                    SizedBox(
                                      width: MediaQuery.sizeOf(context).width *
                                          0.235,
                                      child: ListView.builder(
                                        scrollDirection: Axis.vertical,
                                        itemCount: homePageProvider
                                            .barCodeFiles.length,
                                        itemBuilder: (context, index) {
                                          final barCode = homePageProvider
                                              .barCodeFiles[index];
                                          return GestureDetector(
                                            onTap: () async {
                                              var urlLink =
                                                  await homePageProvider
                                                      .readTxtFile(barCode);
                                              showQrAndBarCodeViewDialogue(
                                                  context: context,
                                                  text: await homePageProvider
                                                      .readTxtFile(barCode),
                                                  browserView: () {
                                                    StringBuffer
                                                        formattedContent =
                                                        StringBuffer();

                                                    List<String> parts = urlLink
                                                        .toString()
                                                        .split(';');
                                                    for (var part
                                                        in parts.where((p) =>
                                                            p.isNotEmpty)) {
                                                      List<String> keyValue =
                                                          part.split(':');
                                                      String key = keyValue[0];
                                                      String value =
                                                          keyValue.length > 1
                                                              ? keyValue
                                                                  .sublist(1)
                                                                  .join(':')
                                                              : '';

                                                      // Format keys into labels
                                                      if (key == "WIFI" ||
                                                          key == "Wifi" ||
                                                          key == "wifi") {
                                                        formattedContent.writeln(
                                                            "WIFI NAME : $value");
                                                      } else if (key == "T") {
                                                        formattedContent.writeln(
                                                            "TYPE : $value");
                                                      } else if (key == "P") {
                                                        formattedContent.writeln(
                                                            "PASSWORD : $value");
                                                      } else {
                                                        formattedContent.writeln(
                                                            "$key : $value");
                                                      }
                                                    }

                                                    // Copy the formatted content to the clipboard
                                                    urlLink
                                                                .toString()
                                                                .startsWith(
                                                                    "WIFI") ||
                                                            urlLink
                                                                .toString()
                                                                .startsWith(
                                                                    "Wifi") ||
                                                            urlLink
                                                                .toString()
                                                                .startsWith(
                                                                    "wifi")
                                                        ? _openBrowserWithSearch(
                                                            formattedContent
                                                                .toString())
                                                        : _openBrowserWithSearch(
                                                            urlLink);
                                                  });
                                            },
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.all(8.0),
                                              child: Container(
                                                width: 90,
                                                height: 100,
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  color: Colors.grey.shade200,
                                                ),
                                                padding:
                                                    const EdgeInsets.all(8),
                                                child: Column(
                                                  children: [
                                                    SizedBox(
                                                      height: 60,
                                                      child: SvgPicture.asset(
                                                          AppAssets.txt),
                                                    ),
                                                    SizedBox(
                                                      height: 20,
                                                      child: Text(
                                                        path.basename(barCode),
                                                        style: const TextStyle(
                                                          color: Colors.black,
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w400,
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
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
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
          );
        });
  }

  List<CameraItem> cameraItems = [
    CameraItem(
      name: 'Document',
      color: const Color(0xFFFFF7EB),
      icon: AppAssets.documents,
    ),
    CameraItem(
      name: 'ID Card',
      color: const Color(0xFFFBF3F2),
      icon: AppAssets.idCard,
    ),
    CameraItem(
      name: 'QR Code',
      color: const Color(0xFFFFF1F1),
      icon: AppAssets.qrcode,
    ),
    CameraItem(
      name: 'Bar Code',
      color: const Color(0xFFEEF0FD),
      icon: AppAssets.barCode,
    ),
  ];
}
