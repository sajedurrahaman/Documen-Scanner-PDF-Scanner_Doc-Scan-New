import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:doc_scanner/camera_screen/provider/camera_provider.dart';
import 'package:doc_scanner/localaization/language_constant.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../image_edit/image_preview.dart';
import 'model/image_model.dart';

class GalleryPermission extends StatefulWidget {
  const GalleryPermission({super.key});

  @override
  State<GalleryPermission> createState() => _GalleryPermissionState();
}

class _GalleryPermissionState extends State<GalleryPermission>
    with WidgetsBindingObserver {
  late PermissionStatus storageStatus;
  late PermissionStatus storageStatus1;
  late PermissionStatus storage;

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    super.initState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      checkPermission().then((value) async {
        if (value) {
          final ImagePicker picker = ImagePicker();
          final List<XFile?> image =
              await picker.pickMultiImage(imageQuality: 50);
          if (image.isNotEmpty) {
            for (int i = 0; i < image.length; i++) {
              String documentName =
                  DateFormat('yyyyMMdd_SSSS').format(DateTime.now());
              if (image[i] != null) {
                final bytes = await image[i]!.readAsBytes();
                Provider.of<CameraProvider>(context, listen: false).addImage(
                  ImageModel(
                    imageByte: bytes,
                    rawBytes: bytes,
                    name: 'Doc-$documentName',
                    docType: 'Document',
                  ),
                );
              }
            }
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => const ImagePreviewScreen(),
              ),
              (route) => false,
            );
          }
        }
      });
    }
  }

  Future<bool> checkPermission() async {
    if (Platform.isAndroid) {
      AndroidDeviceInfo build = await DeviceInfoPlugin().androidInfo;
      print("android");
      if (build.version.sdkInt <= 32) {
        storage = await Permission.storage.status;
      } else {
        storage = await Permission.photos.status;
      }

      if (storage.isDenied) {
        return false;
      } else if (storage.isPermanentlyDenied) {
        return false;
      } else if (storage.isGranted) {
        return true;
      } else {
        return false;
      }
    } else {
      print("Ios");
      storage = await Permission.photos.status;
      if (storage.isDenied) {
        return false;
      } else if (storage.isPermanentlyDenied) {
        return false;
      } else if (storage.isGranted) {
        return true;
      } else {
        return true;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cameraProvider = context.watch<CameraProvider>();
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            if (Platform.isAndroid) {
              AndroidDeviceInfo build = await DeviceInfoPlugin().androidInfo;
              if (build.version.sdkInt <= 32) {
                storageStatus = await Permission.storage.request();
              } else {
                storageStatus = await Permission.photos.request();
              }
              if (storageStatus.isGranted) {
                final ImagePicker picker = ImagePicker();
                final List<XFile?> image =
                    await picker.pickMultiImage(imageQuality: 50);
                if (image.isNotEmpty) {
                  for (int i = 0; i < image.length; i++) {
                    String documentName =
                        DateFormat('yyyyMMdd_SSSS').format(DateTime.now());
                    if (image[i] != null) {
                      final bytes = await image[i]!.readAsBytes();
                      cameraProvider.addImage(
                        ImageModel(
                          imageByte: bytes,
                          rawBytes: bytes,
                          name: 'Doc-$documentName',
                          docType: 'Document',
                        ),
                      );
                    }
                  }
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ImagePreviewScreen(),
                    ),
                    (route) => false,
                  );
                }
              } else if (storageStatus.isPermanentlyDenied) {
                showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: Text(translation(context).permissionDenied),
                      content: Text(translation(context)
                          .pleaseAllowStoragePermissionToAccessGallery),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: Text(translation(context).cancel),
                        ),
                        TextButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            await openAppSettings();
                          },
                          child: Text(translation(context).openSettings),
                        )
                      ],
                    );
                  },
                );
              } else {
                if (build.version.sdkInt <= 32) {
                  storageStatus1 = await Permission.storage.request();
                } else {
                  storageStatus1 = await Permission.photos.request();
                }
                if (storageStatus1.isGranted) {
                  Navigator.pop(context);
                  final ImagePicker picker = ImagePicker();
                  final List<XFile?> image =
                      await picker.pickMultiImage(limit: 5, imageQuality: 50);
                  if (image.isNotEmpty) {
                    for (int i = 0; i < image.length; i++) {
                      String documentName =
                          DateFormat('yyyyMMdd_SSSS').format(DateTime.now());
                      if (image[i] != null) {
                        final bytes = await image[i]!.readAsBytes();
                        cameraProvider.addImage(
                          ImageModel(
                            imageByte: bytes,
                            rawBytes: bytes,
                            name: 'Doc-$documentName',
                            docType: 'Document',
                          ),
                        );
                      }
                    }
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ImagePreviewScreen(),
                      ),
                      (route) => false,
                    );
                  }
                } else {
                  showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: Text(translation(context).permissionDenied),
                        content: Text(translation(context)
                            .pleaseAllowStoragePermissionToAccessGallery),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: Text(translation(context).cancel),
                          ),
                          TextButton(
                            onPressed: () async {
                              Navigator.pop(context);
                              await openAppSettings();
                            },
                            child: Text(translation(context).openSettings),
                          )
                        ],
                      );
                    },
                  );
                }
              }
            } else {
              // this for ios implementation
              storageStatus = await Permission.photos.request();

              if (storageStatus.isGranted) {
                final ImagePicker picker = ImagePicker();
                final List<XFile?> image =
                    await picker.pickMultiImage(imageQuality: 50);
                if (image.isNotEmpty) {
                  for (int i = 0; i < image.length; i++) {
                    String documentName =
                        DateFormat('yyyyMMdd_SSSS').format(DateTime.now());
                    if (image[i] != null) {
                      final bytes = await image[i]!.readAsBytes();
                      cameraProvider.addImage(
                        ImageModel(
                          imageByte: bytes,
                          rawBytes: bytes,
                          name: 'Doc-$documentName',
                          docType: 'Document',
                        ),
                      );
                    }
                  }
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ImagePreviewScreen(),
                    ),
                    (route) => false,
                  );
                }
              } else if (storageStatus.isPermanentlyDenied) {
                showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: Text(translation(context).permissionDenied),
                      content: Text(translation(context)
                          .pleaseAllowStoragePermissionToAccessGallery),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: Text(translation(context).cancel),
                        ),
                        TextButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            await openAppSettings();
                          },
                          child: Text(translation(context).openSettings),
                        )
                      ],
                    );
                  },
                );
              } else {
                storageStatus1 = await Permission.photos.request();
                if (storageStatus1.isGranted) {
                  Navigator.pop(context);
                  final ImagePicker picker = ImagePicker();
                  final List<XFile?> image =
                      await picker.pickMultiImage(limit: 5, imageQuality: 50);
                  if (image.isNotEmpty) {
                    for (int i = 0; i < image.length; i++) {
                      String documentName =
                          DateFormat('yyyyMMdd_SSSS').format(DateTime.now());
                      if (image[i] != null) {
                        final bytes = await image[i]!.readAsBytes();
                        cameraProvider.addImage(
                          ImageModel(
                            imageByte: bytes,
                            rawBytes: bytes,
                            name: 'Doc-$documentName',
                            docType: 'Document',
                          ),
                        );
                      }
                    }
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ImagePreviewScreen(),
                      ),
                      (route) => false,
                    );
                  }
                } else {
                  showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: Text(translation(context).permissionDenied),
                        content: Text(translation(context)
                            .pleaseAllowStoragePermissionToAccessGallery),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: Text(translation(context).cancel),
                          ),
                          TextButton(
                            onPressed: () async {
                              Navigator.pop(context);
                              await openAppSettings();
                            },
                            child: Text(translation(context).openSettings),
                          )
                        ],
                      );
                    },
                  );
                }
              }
            }
          },
          child: Text(translation(context).allowStoragePermission),
        ),
      ),
    );
  }
}
