import '../utils/app_color.dart';
// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:doc_scanner/camera_screen/bar_code_camera_screen.dart';
import 'package:doc_scanner/camera_screen/model/image_model.dart';
import 'package:doc_scanner/camera_screen/qr_code_camera_screen.dart';
import 'package:doc_scanner/google_ads_helper/google_ads_helper.dart';
import 'package:doc_scanner/home_page/provider/home_page_provider.dart';
import 'package:doc_scanner/home_page/provider/recent_files_provider.dart';
import 'package:doc_scanner/home_page/search_page.dart';
import 'package:doc_scanner/image_edit/id_card_image_view.dart';
import 'package:doc_scanner/image_edit/image_edit_preview.dart';
import 'package:doc_scanner/main.dart';
import 'package:doc_scanner/utils/app_assets.dart';
import 'package:doc_scanner/utils/download_helper.dart';
import 'package:doc_scanner/utils/helper.dart';
import 'package:doc_scanner/utils/pdf_view_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
// ignore: depend_on_referenced_packages
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';
import '../camera_screen/provider/camera_provider.dart';
import '../localaization/language_constant.dart';
import '../utils/utils.dart';
import 'directory_view.dart';
import 'recent_file_see_all_screen.dart';
import 'model/camera_item_model.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<HomePageProvider>().clearDocumentImageFiles();
      context.read<HomePageProvider>().clearIdCardImageFiles();
      context.read<HomePageProvider>().clearQRCodeFiles();
      context.read<HomePageProvider>().clearBarCodeFiles();
      context.read<HomePageProvider>().loadDocumentImage();
      context.read<HomePageProvider>().loadIdCardImage();
      context.read<HomePageProvider>().loadQRCode();
      context.read<HomePageProvider>().loadBarCode();
      context.read<HomePageProvider>().getDirectoriesForCreate();
      context.read<RecentFilesProvider>().load();

      showInterstitialAd(context);
    });
    super.initState();
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

  static const Color _headerBlue = AppColor.headerBlue;
  static const Color _pageBackground = Color(0xFFF4F6FB);
  static const Color _titleColor = Color(0xFF1B2437);
  static const Color _mutedColor = Color(0xFF8B95A7);

  bool _homeRouteVisible = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = ModalRoute.of(context)?.isCurrent ?? true;
    if (visible && !_homeRouteVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _refreshRecentFiles();
      });
    }
    _homeRouteVisible = visible;
  }

  Future<void> _onCameraItemTap(CameraItem cameraItem) async {
    if (cameraItem.name == "Document") {
      try {
        final pictures = await CunningDocumentScanner.getPictures(
          isGalleryImportAllowed: true,
        );

        if (pictures != null && pictures.isNotEmpty) {
          for (var element in pictures) {
            if (!mounted) return;
            String imageName =
                DateFormat('yyyyMMdd_SSSS').format(DateTime.now());
            context.read<CameraProvider>().addImage(ImageModel(
                  docType: 'Document',
                  imageByte: await File(element).readAsBytes(),
                  name: "Document-$imageName",
                ));
          }

          if (!mounted) return;
          if (context.read<CameraProvider>().imageList.isNotEmpty) {
            createInterstitialAd();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const EditImagePreview(),
              ),
            );
          }
        }
      } catch (e) {
        debugPrint("Error: $e");
        if (!mounted) return;
        AppHelper.showTopSnackBar(context, 'Failed to scan document: $e');
      }
    } else if (cameraItem.name == "ID Card") {
      try {
        final pictures = await CunningDocumentScanner.getPictures(
          noOfPages: 2,
          isGalleryImportAllowed: true,
        );

        if (pictures != null && pictures.isNotEmpty) {
          for (var element in pictures) {
            if (!mounted) return;
            context.read<CameraProvider>().addIdCardImage(element);
          }

          if (!mounted) return;
          if (context.read<CameraProvider>().idCardImages.isNotEmpty) {
            createInterstitialAd();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const IdCardImagePreview(
                  imageIndex: 2,
                  isCameFromRetake: false,
                ),
              ),
            );
          }
        }
      } catch (e) {
        debugPrint("Error: $e");
        if (!mounted) return;
        AppHelper.showTopSnackBar(context, 'Failed to scan ID Card: $e');
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
  }

  Future<void> _openStoredFile(File imageFile) async {
    final lower = imageFile.path.toLowerCase();
    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png')) {
      await flutterGenralDialogue(
        context: context,
        imageFile: imageFile,
      );
    } else if (lower.endsWith('.pdf')) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfViewScreen(
            filePath: imageFile.path,
            fileName: path.basename(imageFile.path),
          ),
        ),
      );
    }
  }

  Future<void> _openCodeFile(String filePath) async {
    final urlLink =
        await context.read<HomePageProvider>().readTxtFile(filePath);
    if (!mounted) return;
    showQrAndBarCodeViewDialogue(
      context: context,
      text: urlLink,
      browserView: () {
        final formattedContent = StringBuffer();
        final parts = urlLink.toString().split(';');
        for (var part in parts.where((p) => p.isNotEmpty)) {
          final keyValue = part.split(':');
          final key = keyValue[0];
          final value =
              keyValue.length > 1 ? keyValue.sublist(1).join(':') : '';
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
        final raw = urlLink.toString();
        raw.startsWith("WIFI") ||
                raw.startsWith("Wifi") ||
                raw.startsWith("wifi")
            ? _openBrowserWithSearch(formattedContent.toString())
            : _openBrowserWithSearch(urlLink);
      },
    );
  }

  String _scanIcon(String name) {
    switch (name) {
      case "ID Card":
        return AppAssets.homeIdCardIcon;
      case "QR Code":
        return AppAssets.homeQrCodeIcon;
      case "Bar Code":
        return AppAssets.homeBarCodeIcon;
      default:
        return AppAssets.homeDocumentIcon;
    }
  }

  Color _scanBackground(String name) {
    switch (name) {
      case "ID Card":
        return const Color(0xFFE7F8EE);
      case "QR Code":
        return const Color(0xFFF3E9FD);
      case "Bar Code":
        return const Color(0xFFFFF4E8);
      default:
        return const Color(0xFFE8F1FE);
    }
  }

  String _folderIcon(String name) {
    switch (name) {
      case "ID Card":
        return AppAssets.homeIdCardFolder;
      case "QR Code":
        return AppAssets.homeQrCodeFolder;
      case "Bar Code":
        return AppAssets.homeBarCodeFolder;
      default:
        return AppAssets.homeDocumentFolder;
    }
  }

  int _folderCount(String name, HomePageProvider provider) {
    switch (name) {
      case "ID Card":
        return provider.idCardImageFiles.length;
      case "QR Code":
        return provider.qrCodeFiles.length;
      case "Bar Code":
        return provider.barCodeFiles.length;
      default:
        return provider.documentImageFiles.length;
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} min ago';
    }
    if (diff.inHours < 24) {
      final hours = diff.inHours;
      return '$hours hour${hours == 1 ? '' : 's'} ago';
    }
    if (diff.inDays == 1) return '1 day ago';
    return '${diff.inDays} days ago';
  }

  Future<void> _openRecent(RecentFile file) {
    if (file.kind == RecentKind.qr || file.kind == RecentKind.barcode) {
      return _openCodeFile(file.path);
    }
    return _openStoredFile(File(file.path));
  }

  Future<void> _refreshRecentFiles() {
    final provider = context.read<HomePageProvider>();
    provider.clearDocumentImageFiles();
    provider.clearIdCardImageFiles();
    provider.clearQRCodeFiles();
    provider.clearBarCodeFiles();
    provider.loadDocumentImage();
    provider.loadIdCardImage();
    provider.loadQRCode();
    provider.loadBarCode();
    return context.read<RecentFilesProvider>().load();
  }

  Future<void> _renameRecent(RecentFile file) async {
    final controller = TextEditingController(
      text: path.basenameWithoutExtension(file.path),
    );
    final formKey = GlobalKey<FormState>();
    var errorMessage = '';
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(
                translation(dialogContext).renameFile,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              content: Form(
                key: formKey,
                child: TextFormField(
                  controller: controller,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return translation(dialogContext).pleaseEnterFileName;
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: translation(dialogContext).enterFileName,
                    errorText: errorMessage.isEmpty ? null : errorMessage,
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(translation(dialogContext).cancel),
                ),
                TextButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    final parent = File(file.path).parent.path;
                    final extension = path.extension(file.path);
                    final newPath = path.join(
                      parent,
                      '${controller.text.trim()}$extension',
                    );
                    if (newPath == file.path) {
                      Navigator.pop(dialogContext);
                      return;
                    }
                    if (await File(newPath).exists()) {
                      setDialogState(() {
                        errorMessage =
                            translation(dialogContext).fileAlreadyExists;
                      });
                      return;
                    }
                    await File(file.path).rename(newPath);
                    if (!dialogContext.mounted) return;
                    Navigator.pop(dialogContext);
                    if (!mounted) return;
                    await _refreshRecentFiles();
                  },
                  child: Text(translation(dialogContext).save),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
  }

  Future<void> _downloadRecent(RecentFile file) async {
    try {
      await DownloadHelper.saveFileToDownloads(file.path);
      if (!mounted) return;
      AppHelper.showTopSnackBar(
        context,
        translation(context).fileSavedDownloadFolder,
      );
    } catch (e) {
      if (!mounted) return;
      AppHelper.showTopSnackBar(context, 'Failed to download file: $e');
    }
  }

  Future<void> _shareRecent(RecentFile file) async {
    if (file.path.toLowerCase().endsWith('.txt')) {
      final text = await File(file.path).readAsString();
      if (!mounted) return;
      await Share.share(text);
      return;
    }
    await Share.shareXFiles([XFile(file.path)]);
  }

  Future<void> _deleteRecent(RecentFile file) {
    return showNormalAlertDialogue(
      context: context,
      title: translation(context).deleteFile,
      content: translation(context)
          .areYouSureYouWantToDeleteTheSelectedItems
          .trim()
          .replaceAllMapped(RegExp(r'\s+([?؟？])'), (match) => match[1]!),
      onOkText: translation(context).ok,
      onCancelText: translation(context).cancel,
      onOk: () async {
        Navigator.pop(context);
        await File(file.path).delete();
        if (!mounted) return;
        await _refreshRecentFiles();
      },
      onCancel: () => Navigator.pop(context),
    );
  }

  Future<void> _onRecentMenu(
    RecentFile file,
    _RecentMenuAction action,
  ) {
    switch (action) {
      case _RecentMenuAction.rename:
        return _renameRecent(file);
      case _RecentMenuAction.download:
        return _downloadRecent(file);
      case _RecentMenuAction.share:
        return _shareRecent(file);
      case _RecentMenuAction.delete:
        return _deleteRecent(file);
    }
  }

  @override
  Widget build(BuildContext context) {
    final homePageProvider = Provider.of<HomePageProvider>(context);
    final cameraProvider = Provider.of<CameraProvider>(context);
    return ValueListenableBuilder<bool>(
        valueListenable: interstitialReadyNotifier,
        builder: (context, interstitialReady, _) {
          return Scaffold(
            backgroundColor: _headerBlue,
            body: cameraProvider.pdfConverting
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _HomeHeader(
                        onSearch: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SearchPage(),
                            ),
                          );
                        },
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(28)),
                          child: ColoredBox(
                            color: _pageBackground,
                            child: SingleChildScrollView(
                              // The translated recent section already leaves 74
                              // pixels below it; only reserve the remaining inset.
                              padding: EdgeInsets.only(
                                bottom: (MediaQuery.paddingOf(context).bottom - 74)
                                    .clamp(0.0, double.infinity),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(28),
                                      ),
                                    ),
                                    child: _ScanOptionsCard(
                                      items: cameraItems,
                                      labelFor: (name) =>
                                          getCameraModeName(name, context),
                                      iconFor: _scanIcon,
                                      backgroundFor: _scanBackground,
                                      onTap: _onCameraItemTap,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Transform.translate(
                                    offset: const Offset(0, -28),
                                    child: Container(
                                      padding: const EdgeInsets.fromLTRB(
                                          16, 18, 16, 64),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFF6F9FE),
                                        borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(28),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Text(
                                            translation(context).myDocuments,
                                            style: const TextStyle(
                                              color: _titleColor,
                                              fontSize: 22,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.4,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          _FolderRow(
                                            directories:
                                                homePageProvider.directories,
                                            nameFor: (directoryName) =>
                                                getFolderModeName(
                                                    directoryName, context),
                                            iconFor: _folderIcon,
                                            countFor: (directoryName) =>
                                                _folderCount(directoryName,
                                                    homePageProvider),
                                            onTap: (directory) {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      DirectoryDetailsPage(
                                                    directoryPath:
                                                        directory.path,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Transform.translate(
                                    offset: const Offset(0, -74),
                                    child: Column(
                                      children: [
                                        _RecentFilesSection(
                                          timeAgo: _timeAgo,
                                          sizeLabel: _formatBytes,
                                          onOpen: _openRecent,
                                          onMenu: _onRecentMenu,
                                          onSeeAll: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    RecentFileSeeAllScreen(
                                                  onOpen: _openRecent,
                                                  onRename: _renameRecent,
                                                  onDownload: _downloadRecent,
                                                  onShare: _shareRecent,
                                                  onDelete: _deleteRecent,
                                                  onRefresh:
                                                      _refreshRecentFiles,
                                                  timeAgo: _timeAgo,
                                                  sizeLabel: _formatBytes,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 20),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
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

class _HomeHeader extends StatelessWidget {
  final VoidCallback onSearch;

  const _HomeHeader({required this.onSearch});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _HomePageState._headerBlue,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 4, 18),
          child: Row(
            children: [
              SvgPicture.asset(
                AppAssets.homeAppBarIcon,
                width: 46,
                height: 46,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      translation(context).documentScanner,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                        letterSpacing: 0.4,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      translation(context).scanSaveShare,
                      style: TextStyle(
                        color: Color(0xD9FFFFFF),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onSearch,
                icon: SvgPicture.asset(AppAssets.search, width: 28, height: 28),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanOptionsCard extends StatelessWidget {
  final List<CameraItem> items;
  final String Function(String name) labelFor;
  final String Function(String name) iconFor;
  final Color Function(String name) backgroundFor;
  final Future<void> Function(CameraItem item) onTap;

  const _ScanOptionsCard({
    required this.items,
    required this.labelFor,
    required this.iconFor,
    required this.backgroundFor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            translation(context).scanOptions,
            style: const TextStyle(
              color: _HomePageState._titleColor,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: Material(
                    color: backgroundFor(items[i].name),
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => onTap(items[i]),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          children: [
                            SvgPicture.asset(
                              iconFor(items[i].name),
                              width: 44,
                              height: 44,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              labelFor(items[i].name),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _HomePageState._titleColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _FolderRow extends StatelessWidget {
  final List<Directory> directories;
  final String Function(String directoryName) nameFor;
  final String Function(String directoryName) iconFor;
  final int Function(String directoryName) countFor;
  final void Function(Directory directory) onTap;

  const _FolderRow({
    required this.directories,
    required this.nameFor,
    required this.iconFor,
    required this.countFor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (directories.isEmpty) {
      return const SizedBox.shrink();
    }
    return Row(
      children: [
        for (var i = 0; i < directories.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: _FolderTile(
              directory: directories[i],
              nameFor: nameFor,
              iconFor: iconFor,
              countFor: countFor,
              onTap: onTap,
            ),
          ),
        ],
      ],
    );
  }
}

class _FolderTile extends StatelessWidget {
  final Directory directory;
  final String Function(String directoryName) nameFor;
  final String Function(String directoryName) iconFor;
  final int Function(String directoryName) countFor;
  final void Function(Directory directory) onTap;

  const _FolderTile({
    required this.directory,
    required this.nameFor,
    required this.iconFor,
    required this.countFor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final directoryName = path.basename(directory.path);
    final count = countFor(directoryName);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => onTap(directory),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE6EAF2)),
          ),
          child: Column(
            children: [
              SvgPicture.asset(
                iconFor(directoryName),
                width: 42,
                height: 32,
              ),
              const SizedBox(height: 8),
              Text(
                nameFor(directoryName),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _HomePageState._titleColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                count == 1 ? '1 file' : '$count files',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _HomePageState._mutedColor,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentFilesSection extends StatelessWidget {
  final String Function(DateTime time) timeAgo;
  final String Function(int bytes) sizeLabel;
  final Future<void> Function(RecentFile file) onOpen;
  final Future<void> Function(RecentFile file, _RecentMenuAction action) onMenu;
  final VoidCallback onSeeAll;

  const _RecentFilesSection({
    required this.timeAgo,
    required this.sizeLabel,
    required this.onOpen,
    required this.onMenu,
    required this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    final recent = context.watch<RecentFilesProvider>();
    return _RecentFilesCard(
      loading: recent.loading,
      files: recent.files,
      timeAgo: timeAgo,
      sizeLabel: sizeLabel,
      onOpen: onOpen,
      onMenu: onMenu,
      onSeeAll: onSeeAll,
    );
  }
}

class _RecentFilesCard extends StatelessWidget {
  final bool loading;
  final List<RecentFile> files;
  final String Function(DateTime time) timeAgo;
  final String Function(int bytes) sizeLabel;
  final Future<void> Function(RecentFile file) onOpen;
  final Future<void> Function(RecentFile file, _RecentMenuAction action) onMenu;
  final VoidCallback onSeeAll;

  const _RecentFilesCard({
    required this.loading,
    required this.files,
    required this.timeAgo,
    required this.sizeLabel,
    required this.onOpen,
    required this.onMenu,
    required this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    translation(context).recentFiles,
                    style: const TextStyle(
                      color: _HomePageState._titleColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                if (files.isNotEmpty)
                  TextButton(
                    onPressed: onSeeAll,
                    child: const Text(
                      'See all',
                      style: TextStyle(
                        color: Color(0xFF2F6FE4),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            )
          else if (files.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 32, 36),
              child: Column(
                children: [
                  const Image(
                    image: AssetImage(AppAssets.homeEmptyState),
                    width: 104,
                    height: 104,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    translation(context).noFilesHereYet,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _HomePageState._titleColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    translation(context).tapCameraToScanFirstDocument,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _HomePageState._mutedColor,
                      fontSize: 14,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            )
          else
            Builder(
              builder: (context) {
                final visible = files.take(6).toList();
                return Column(
                  children: [
                    for (var i = 0; i < visible.length; i++) ...[
                      _RecentFileTile(
                        file: visible[i],
                        timeAgo: timeAgo,
                        sizeLabel: sizeLabel,
                        onOpen: onOpen,
                        onMenu: onMenu,
                      ),
                      if (i != visible.length - 1)
                        const Divider(
                          height: 1,
                          indent: 56,
                          endIndent: 8,
                          color: Color(0xFFE4EBF7),
                        ),
                    ],
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _RecentFileTile extends StatelessWidget {
  final RecentFile file;
  final String Function(DateTime time) timeAgo;
  final String Function(int bytes) sizeLabel;
  final Future<void> Function(RecentFile file) onOpen;
  final Future<void> Function(RecentFile file, _RecentMenuAction action) onMenu;

  const _RecentFileTile({
    required this.file,
    required this.timeAgo,
    required this.sizeLabel,
    required this.onOpen,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final lower = file.path.toLowerCase();
    final isPdf = lower.endsWith('.pdf');
    final isCode =
        file.kind == RecentKind.qr || file.kind == RecentKind.barcode;
    final extension =
        path.extension(file.path).replaceFirst('.', '').toUpperCase();
    final thumbAsset = isPdf
        ? AppAssets.homePdfThumb
        : isCode
            ? AppAssets.homeQrBarThumb
            : AppAssets.homeImageThumb;
    final thumbBackground = isPdf
        ? const Color(0xFFFFEEF1)
        : isCode
            ? const Color(0xFFE7EAF5)
            : const Color(0xFFF3E9FD);
    return InkWell(
      onTap: () => onOpen(file),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: thumbBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SvgPicture.asset(
                thumbAsset,
                width: isPdf || isCode ? 28 : 25,
                height: isPdf || isCode ? 28 : 25,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    path.basename(file.path),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _HomePageState._titleColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$extension • ${sizeLabel(file.size)} • ${timeAgo(file.modified)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _HomePageState._mutedColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<_RecentMenuAction>(
              padding: EdgeInsets.zero,
              color: Colors.white,
              elevation: 8,
              position: PopupMenuPosition.under,
              constraints: const BoxConstraints(minWidth: 150, maxWidth: 168),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: (action) => onMenu(file, action),
              itemBuilder: (context) => [
                _recentMenuItem(
                  _RecentMenuAction.rename,
                  AppAssets.recentMenuRename,
                  'Rename',
                ),
                _recentMenuItem(
                  _RecentMenuAction.download,
                  AppAssets.recentMenuDownload,
                  'Download',
                ),
                _recentMenuItem(
                  _RecentMenuAction.share,
                  AppAssets.recentMenuShare,
                  'Share',
                ),
                _recentMenuItem(
                  _RecentMenuAction.delete,
                  AppAssets.recentMenuDelete,
                  'Delete',
                ),
              ],
              icon: const Icon(Icons.more_vert, color: Color(0xFF9AA3B2)),
            ),
          ],
        ),
      ),
    );
  }
}

enum _RecentMenuAction { rename, download, share, delete }

PopupMenuItem<_RecentMenuAction> _recentMenuItem(
  _RecentMenuAction value,
  String icon,
  String label,
) {
  return PopupMenuItem<_RecentMenuAction>(
    value: value,
    height: 36,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Row(
      children: [
        SvgPicture.asset(icon, width: 18, height: 18),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}
