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
import 'package:doc_scanner/utils/helper.dart';
import 'package:doc_scanner/utils/pdf_view_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';
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

  static const Color _headerBlue = Color(0xFF1E56D8);
  static const Color _pageBackground = Color(0xFFF4F6FB);
  static const Color _titleColor = Color(0xFF1B2437);
  static const Color _mutedColor = Color(0xFF8B95A7);

  String? _recentKey;
  Future<List<_HomeRecentFile>>? _recentFuture;

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

  Future<List<_HomeRecentFile>> _recentFiles(HomePageProvider provider) {
    final paths = <String>[
      ...provider.documentImageFiles.map((file) => file.path),
      ...provider.idCardImageFiles.map((file) => file.path),
      ...provider.qrCodeFiles,
      ...provider.barCodeFiles,
    ];
    final key = paths.join('\n');
    if (_recentKey != key || _recentFuture == null) {
      _recentKey = key;
      _recentFuture = _loadRecentFiles(provider);
    }
    return _recentFuture!;
  }

  Future<List<_HomeRecentFile>> _loadRecentFiles(
      HomePageProvider provider) async {
    final items = <_HomeRecentFile>[];

    Future<void> add(String filePath, _RecentKind kind) async {
      try {
        final stat = await File(filePath).stat();
        items.add(_HomeRecentFile(
          path: filePath,
          kind: kind,
          modified: stat.modified,
          size: stat.size,
        ));
      } catch (_) {}
    }

    await Future.wait([
      for (final file in provider.documentImageFiles)
        add(file.path, _RecentKind.document),
      for (final file in provider.idCardImageFiles)
        add(file.path, _RecentKind.idCard),
      for (final file in provider.qrCodeFiles) add(file, _RecentKind.qr),
      for (final file in provider.barCodeFiles) add(file, _RecentKind.barcode),
    ]);
    items.sort((a, b) => b.modified.compareTo(a.modified));
    return items;
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

  Future<void> _openRecent(_HomeRecentFile file) {
    if (file.kind == _RecentKind.qr || file.kind == _RecentKind.barcode) {
      return _openCodeFile(file.path);
    }
    return _openStoredFile(File(file.path));
  }

  @override
  Widget build(BuildContext context) {
    final homePageProvider = Provider.of<HomePageProvider>(context);
    final cameraProvider = Provider.of<CameraProvider>(context);
    return ValueListenableBuilder<bool>(
        valueListenable: interstitialReadyNotifier,
        builder: (context, interstitialReady, _) {
          return Scaffold(
            backgroundColor: _pageBackground,
            body: cameraProvider.pdfConverting
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    child: Column(
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
                        Transform.translate(
                          offset: const Offset(0, -18),
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
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 18, 16, 64),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFE3E9F3),
                                    borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(28),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      const Text(
                                        'My Documents',
                                        style: TextStyle(
                                          color: _titleColor,
                                          fontSize: 22,
                                          fontWeight: FontWeight.w700,
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
                                                directoryPath: directory.path,
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
                                    _RecentFilesCard(
                                      loading:
                                          homePageProvider.isHistoryLoading,
                                      files: _recentFiles(homePageProvider),
                                      timeAgo: _timeAgo,
                                      sizeLabel: _formatBytes,
                                      onOpen: _openRecent,
                                      onSeeAll: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const SearchPage(),
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 120),
                                  ],
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
          padding: const EdgeInsets.fromLTRB(16, 8, 4, 36),
          child: Row(
            children: [
              SvgPicture.asset(
                AppAssets.homeAppBarIcon,
                width: 46,
                height: 46,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Document Scanner',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Scan • Save • Share',
                      style: TextStyle(
                        color: Color(0xD9FFFFFF),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onSearch,
                icon: const Icon(Icons.search, color: Colors.white, size: 28),
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
          const Text(
            'Scan Options',
            style: TextStyle(
              color: _HomePageState._titleColor,
              fontSize: 20,
              fontWeight: FontWeight.w700,
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

class _RecentFilesCard extends StatelessWidget {
  final bool loading;
  final Future<List<_HomeRecentFile>> files;
  final String Function(DateTime time) timeAgo;
  final String Function(int bytes) sizeLabel;
  final Future<void> Function(_HomeRecentFile file) onOpen;
  final VoidCallback onSeeAll;

  const _RecentFilesCard({
    required this.loading,
    required this.files,
    required this.timeAgo,
    required this.sizeLabel,
    required this.onOpen,
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
                const Expanded(
                  child: Text(
                    'Recent Files',
                    style: TextStyle(
                      color: _HomePageState._titleColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
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
          else
            FutureBuilder<List<_HomeRecentFile>>(
              future: files,
              builder: (context, snapshot) {
                final items = snapshot.data ?? const <_HomeRecentFile>[];
                if (items.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.fromLTRB(0, 8, 8, 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'No files yet',
                        style: TextStyle(color: _HomePageState._mutedColor),
                      ),
                    ),
                  );
                }
                final visible = items.take(6).toList();
                return Column(
                  children: [
                    for (var i = 0; i < visible.length; i++) ...[
                      _RecentFileTile(
                        file: visible[i],
                        timeAgo: timeAgo,
                        sizeLabel: sizeLabel,
                        onOpen: onOpen,
                      ),
                      if (i != visible.length - 1)
                        const Divider(
                          height: 1,
                          color: Color(0xFFE8ECF2),
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
  final _HomeRecentFile file;
  final String Function(DateTime time) timeAgo;
  final String Function(int bytes) sizeLabel;
  final Future<void> Function(_HomeRecentFile file) onOpen;

  const _RecentFileTile({
    required this.file,
    required this.timeAgo,
    required this.sizeLabel,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final lower = file.path.toLowerCase();
    final isPdf = lower.endsWith('.pdf');
    final isCode =
        file.kind == _RecentKind.qr || file.kind == _RecentKind.barcode;
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
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Color(0xFF9AA3B2)),
              onSelected: (_) => onOpen(file),
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'open', child: Text('Open')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _RecentKind { document, idCard, qr, barcode }

class _HomeRecentFile {
  final String path;
  final _RecentKind kind;
  final DateTime modified;
  final int size;

  const _HomeRecentFile({
    required this.path,
    required this.kind,
    required this.modified,
    required this.size,
  });
}
