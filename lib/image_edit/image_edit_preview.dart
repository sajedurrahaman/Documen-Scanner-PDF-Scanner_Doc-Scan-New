// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:doc_scanner/google_ads_helper/banner_ad_widget.dart';
import 'package:doc_scanner/google_ads_helper/google_ads_helper.dart';
import 'package:doc_scanner/home_page/provider/recent_files_provider.dart';
import 'package:doc_scanner/image_edit/select_target_document_screen.dart';
import 'package:doc_scanner/image_edit/text_recognition_screen.dart';
import 'package:doc_scanner/image_edit/widget/image_edit_button.dart';
import 'package:doc_scanner/utils/app_color.dart';
import 'package:doc_scanner/utils/pdf_append_helper.dart';
import 'package:doc_scanner/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../bottom_bar/bottom_bar.dart';
import '../camera_screen/model/image_model.dart';
import '../camera_screen/provider/camera_provider.dart';
import '../localaization/language_constant.dart';
import '../utils/app_assets.dart';
import '../utils/helper.dart';
import 'add_sgnature_screen.dart';
import 'image_edit_screen.dart';
import 'page_image_viewer.dart';

class EditImagePreview extends StatefulWidget {
  const EditImagePreview({
    super.key,
    /// When set (Recent open), navigate immediately and load page 1 first.
    this.openFilePath,
  });

  final String? openFilePath;

  @override
  State<EditImagePreview> createState() => _EditImagePreviewState();
}

class _EditImagePreviewState extends State<EditImagePreview> {
  final GlobalKey _globalKey = GlobalKey();
  int _currentIndex = 0;
  bool isSaving = false;
  bool _addingPages = false;
  /// Waiting for first page from [openFilePath].
  bool _openingDocument = false;
  /// More PDF pages still decoding after page 1 is shown.
  bool _loadingMorePages = false;
  bool _openLoadCancelled = false;
  /// false = list (CamScanner vertical + Add below), true = grid + Add cell.
  bool _isGridView = false;
  /// CamScanner-style: stays on after long-press until back / deselect.
  bool _isSelectionMode = false;
  final Set<int> _selectedIndexes = {};
  int? _draggingIndex;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _renameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final GlobalKey _listViewportKey = GlobalKey();
  final GlobalKey _listAddKey = GlobalKey();
  final List<GlobalKey> _pageItemKeys = [];

  /// Recent/Document open path — Export as PDF overwrites this file.
  String? _openedDocumentPath;
  String? _openedDocumentBaseName;

  static const _addAccent = Color(0xFF8AB4F8);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onListScroll);
    final openPath = widget.openFilePath;
    if (openPath != null && openPath.isNotEmpty) {
      _openingDocument = true;
      _openedDocumentPath = openPath;
      final fileName = openPath.split(Platform.pathSeparator).last;
      final dot = fileName.lastIndexOf('.');
      _openedDocumentBaseName =
          dot > 0 ? fileName.substring(0, dot) : fileName;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadOpenFile(openPath);
      });
    }
  }

  Future<void> _loadOpenFile(String filePath) async {
    final camera = context.read<CameraProvider>();
    camera.clearImageList();
    final fileName = filePath.split(Platform.pathSeparator).last;
    final dot = fileName.lastIndexOf('.');
    final baseName = dot > 0 ? fileName.substring(0, dot) : fileName;
    final stamp = DateFormat('yyyyMMdd_SSSS').format(DateTime.now());

    try {
      await loadDocumentPagesProgressive(
        filePath,
        isCancelled: () => _openLoadCancelled || !mounted,
        onPage: (bytes, index, total) async {
          if (_openLoadCancelled || !mounted) return;
          final raw = await readRawSidecarPage(filePath, index);
          if (_openLoadCancelled || !mounted) return;
          camera.addImage(
            ImageModel(
              imageByte: bytes,
              rawBytes: raw,
              name: total > 1 ? '$baseName-${index + 1}-$stamp' : baseName,
              docType: 'Document',
            ),
          );
          if (!mounted) return;
          if (index == 0) {
            setState(() {
              _openingDocument = false;
              _loadingMorePages = total > 1;
              _currentIndex = 0;
            });
          } else if (index >= total - 1) {
            setState(() => _loadingMorePages = false);
          } else {
            setState(() {});
          }
        },
      );
      if (!mounted || _openLoadCancelled) return;
      if (camera.imageList.isEmpty) {
        setState(() {
          _openingDocument = false;
          _loadingMorePages = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(translation(context).somethingWentWrong)),
        );
        Navigator.pop(context);
        return;
      }
      setState(() {
        _openingDocument = false;
        _loadingMorePages = false;
      });
    } catch (e) {
      if (!mounted || _openLoadCancelled) return;
      setState(() {
        _openingDocument = false;
        _loadingMorePages = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${translation(context).somethingWentWrong}: $e'),
        ),
      );
      if (camera.imageList.isEmpty) Navigator.pop(context);
    }
  }

  void _ensurePageKeys(int count) {
    while (_pageItemKeys.length < count) {
      _pageItemKeys.add(GlobalKey());
    }
    if (_pageItemKeys.length > count) {
      _pageItemKeys.removeRange(count, _pageItemKeys.length);
    }
  }

  void _onListScroll() {
    if (_isGridView) return;
    _syncListPageIndex();
  }

  /// Fixed top badge follows whichever page sits under the list top (CamScanner).
  void _syncListPageIndex() {
    if (!mounted || _isGridView) return;
    final count = context.read<CameraProvider>().imageList.length;
    if (count == 0) return;

    final viewportCtx = _listViewportKey.currentContext;
    if (viewportCtx == null) return;
    final viewportBox = viewportCtx.findRenderObject() as RenderBox?;
    if (viewportBox == null || !viewportBox.hasSize) return;

    final viewportTop = viewportBox.localToGlobal(Offset.zero).dy;
    final viewportBottom = viewportTop + viewportBox.size.height;
    final anchor = viewportTop + 15;

    int? covering;
    int closest = _currentIndex.clamp(0, count - 1);
    var closestDist = double.infinity;

    for (var i = 0; i < count && i < _pageItemKeys.length; i++) {
      final ctx = _pageItemKeys[i].currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final top = box.localToGlobal(Offset.zero).dy;
      final bottom = top + box.size.height;
      if (bottom <= viewportTop || top >= viewportBottom) continue;
      if (top <= anchor && bottom > anchor) {
        covering = i;
      }
      final dist = (top - anchor).abs();
      if (dist < closestDist) {
        closestDist = dist;
        closest = i;
      }
    }

    final next = covering ?? closest;
    if (next != _currentIndex) {
      setState(() => _currentIndex = next);
    }
  }

  void _enterSelectionMode(int index) {
    setState(() {
      _isSelectionMode = true;
      _selectedIndexes
        ..clear()
        ..add(index);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIndexes.clear();
      _draggingIndex = null;
    });
  }

  void _togglePageSelection(int index) {
    setState(() {
      if (_selectedIndexes.contains(index)) {
        _selectedIndexes.remove(index);
        // Stay in selection mode (CamScanner: only back exits).
      } else {
        _selectedIndexes.add(index);
      }
    });
  }

  void _toggleSelectAll(int imageCount) {
    setState(() {
      if (_selectedIndexes.length == imageCount && imageCount > 0) {
        // Deselect all pages but keep selection mode active.
        _selectedIndexes.clear();
      } else {
        _selectedIndexes
          ..clear()
          ..addAll(List.generate(imageCount, (i) => i));
      }
    });
  }

  void _remapSelectionAfterReorder(int fromIndex, int toIndex) {
    final next = <int>{};
    for (final i in _selectedIndexes) {
      if (i == fromIndex) {
        next.add(toIndex);
      } else if (fromIndex < toIndex && i > fromIndex && i <= toIndex) {
        next.add(i - 1);
      } else if (fromIndex > toIndex && i >= toIndex && i < fromIndex) {
        next.add(i + 1);
      } else {
        next.add(i);
      }
    }
    _selectedIndexes
      ..clear()
      ..addAll(next);
  }

  List<int> get _sortedSelectedIndexes {
    final indexes = _selectedIndexes.toList()..sort();
    return indexes;
  }

  Future<void> _shareSelectedPages(CameraProvider cameraProvider) async {
    if (_selectedIndexes.isEmpty) return;
    final files = <XFile>[];
    for (final index in _sortedSelectedIndexes) {
      if (index < 0 || index >= cameraProvider.imageList.length) continue;
      final file = await AppHelper().convertUint8ListToFile(
        data: cameraProvider.imageList[index].imageByte,
        extension: 'jpg',
      );
      files.add(XFile(file.path));
    }
    if (files.isEmpty || !mounted) return;
    await Share.shareXFiles(files);
  }

  Future<void> _deleteSelectedPages(CameraProvider cameraProvider) async {
    if (_selectedIndexes.isEmpty) return;
    final labels = translation(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(labels.delete),
        content: Text(labels.areYouSureYouWantToDeleteTheSelectedItems),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(labels.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(labels.delete,
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final toRemove = _sortedSelectedIndexes.reversed.toList();
    for (final index in toRemove) {
      if (index >= 0 && index < cameraProvider.imageList.length) {
        cameraProvider.deleteImage(index);
      }
    }
    _exitSelectionMode();
    if (cameraProvider.imageList.isEmpty && mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const BottomBar()),
        (_) => false,
      );
    } else if (mounted) {
      setState(() {
        _currentIndex =
            _currentIndex.clamp(0, cameraProvider.imageList.length - 1);
      });
    }
  }

  Future<void> _showMoveCopySheet(CameraProvider cameraProvider) async {
    if (_selectedIndexes.isEmpty) return;
    final labels = translation(context);
    final choice = await showModalBottomSheet<TargetDocumentAction>(
      context: context,
      backgroundColor: const Color(0xff1E1F20),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        Widget option({
          required IconData icon,
          required String title,
          required TargetDocumentAction action,
        }) {
          return ListTile(
            leading: Icon(icon, color: Colors.white),
            title: Text(title,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
            onTap: () => Navigator.pop(sheetContext, action),
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 12),
                option(
                  icon: Icons.copy_outlined,
                  title: labels.copy,
                  action: TargetDocumentAction.copy,
                ),
                const Divider(color: Color(0xFF2A2B2C)),
                option(
                  icon: Icons.drive_file_move_outline,
                  title: labels.move,
                  action: TargetDocumentAction.move,
                ),
              ],
            ),
          ),
        );
      },
    );
    if (choice == null || !mounted) return;
    await _pickTargetAndTransfer(cameraProvider, choice);
  }

  Future<void> _pickTargetAndTransfer(
    CameraProvider cameraProvider,
    TargetDocumentAction action,
  ) async {
    final target = await Navigator.push<RecentFile>(
      context,
      MaterialPageRoute(
        builder: (_) => SelectTargetDocumentScreen(action: action),
      ),
    );
    if (target == null || !mounted) return;

    final selectedSet = _selectedIndexes.toSet();
    final selectedBytes = _sortedSelectedIndexes
        .where((i) => i >= 0 && i < cameraProvider.imageList.length)
        .map((i) => cameraProvider.imageList[i].imageByte)
        .toList();
    if (selectedBytes.isEmpty) return;

    // Source doc for Recents: full doc on copy, remaining pages on move.
    final sourceBytes = <Uint8List>[];
    String sourceName = 'Document';
    for (var i = 0; i < cameraProvider.imageList.length; i++) {
      final page = cameraProvider.imageList[i];
      if (action == TargetDocumentAction.move && selectedSet.contains(i)) {
        continue;
      }
      sourceBytes.add(page.imageByte);
      if (sourceBytes.length == 1) sourceName = page.name;
    }

    try {
      // CamScanner-like: load target pages once, paste in memory, open grid ASAP.
      // Disk writes happen in the background — no blocking loader.
      final targetPages = await loadDocumentPagesFast(target.path);
      final previewPages = <Uint8List>[...targetPages, ...selectedBytes];
      if (!mounted) return;

      final stamp = DateFormat('yyyyMMdd_SSSS').format(DateTime.now());
      cameraProvider.replaceImageList([
        for (var i = 0; i < previewPages.length; i++)
          ImageModel(
            imageByte: previewPages[i],
            name: 'Doc-$stamp-$i',
            docType: 'Document',
          ),
      ]);

      setState(() {
        _isSelectionMode = false;
        _selectedIndexes.clear();
        _draggingIndex = null;
        _isGridView = true;
        _currentIndex = 0;
      });

      final outPath = resolvedPdfOutputPath(target.path);
      final sourceToSave = List<Uint8List>.from(sourceBytes);
      final pagesToPersist = List<Uint8List>.from(previewPages);
      final recent = context.read<RecentFilesProvider>();
      // Preserve target's place in Recents; source (moved/copied from) goes #1.
      final targetOriginalModified = File(target.path).existsSync()
          ? File(target.path).lastModifiedSync()
          : null;
      final openedSourcePath = _openedDocumentPath;
      final isMove = action == TargetDocumentAction.move;

      // After paste, preview shows the target document.
      _openedDocumentPath = outPath;
      final outName = outPath.split(Platform.pathSeparator).last;
      final outDot = outName.lastIndexOf('.');
      _openedDocumentBaseName =
          outDot > 0 ? outName.substring(0, outDot) : outName;

      unawaited(() async {
        try {
          final targetFile = await writePdfFromImages(
            outputPath: outPath,
            images: pagesToPersist,
          );
          // Paste target keeps its previous Recent position.
          if (await targetFile.exists()) {
            await targetFile.setLastModified(
              targetOriginalModified ??
                  DateTime.now().subtract(const Duration(seconds: 5)),
            );
          }

          // Source persistence — never invent an extra PDF when Recent file
          // was opened (overwrite / leave alone / delete instead).
          final openedPdf = openedSourcePath != null &&
              openedSourcePath.toLowerCase().endsWith('.pdf');
          if (isMove) {
            if (sourceToSave.isEmpty) {
              if (openedPdf) {
                final f = File(openedSourcePath!);
                if (await f.exists()) await f.delete();
                await deleteRawSidecarForPdf(openedSourcePath);
              }
            } else if (openedPdf) {
              final sourceFile = await writePdfFromImages(
                outputPath: openedSourcePath!,
                images: sourceToSave,
              );
              if (await sourceFile.exists()) {
                await sourceFile.setLastModified(DateTime.now());
              }
            } else {
              final sourceFile = await cameraProvider.saveImagesAsDocumentPdf(
                images: sourceToSave,
                fileName: sourceName,
              );
              if (sourceFile != null && await sourceFile.exists()) {
                await sourceFile.setLastModified(DateTime.now());
              }
            }
          } else {
            // Copy: source file on disk stays unchanged when opened from Recent.
            // Only create a source PDF for an unsaved new scan session.
            if (!openedPdf && sourceToSave.isNotEmpty) {
              final sourceFile = await cameraProvider.saveImagesAsDocumentPdf(
                images: sourceToSave,
                fileName: sourceName,
              );
              if (sourceFile != null && await sourceFile.exists()) {
                await sourceFile.setLastModified(DateTime.now());
              }
            }
          }
          await recent.load();
        } catch (e) {
          debugPrint('Background copy/move persist failed: $e');
        }
      }());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${translation(context).somethingWentWrong}: $e'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _openLoadCancelled = true;
    _scrollController.dispose();
    _renameController.dispose();
    super.dispose();
  }

  /// Opens document scanner again and appends pages on the same screen.
  Future<void> _addMorePages(CameraProvider cameraProvider) async {
    if (_addingPages || cameraProvider.imageList.isEmpty) return;
    setState(() => _addingPages = true);
    try {
      await AppHelper.handlePermissions();
      final pictures = await CunningDocumentScanner.getPictures(
        isGalleryImportAllowed: true,
      );
      if (!mounted) return;
      if (pictures == null || pictures.isEmpty) return;

      final jumpTo = cameraProvider.imageList.length;
      final docType = cameraProvider.imageList[_currentIndex].docType;
      for (final path in pictures) {
        final imageName =
            DateFormat('yyyyMMdd_SSSS').format(DateTime.now());
        final bytes = await File(path).readAsBytes();
        cameraProvider.addImage(
          ImageModel(
            docType: docType.isNotEmpty ? docType : 'Document',
            imageByte: bytes,
            rawBytes: bytes,
            name: 'Document-$imageName',
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _currentIndex = jumpTo;
        _addingPages = false;
      });
      // Scanner Activity resume needs a beat before list layout is ready.
      await _scrollToShowNewPageAndAdd();
      return;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${translation(context).somethingWentWrong}: $e'),
        ),
      );
    } finally {
      if (mounted && _addingPages) setState(() => _addingPages = false);
    }
  }

  /// CamScanner: scroll to end so the new page + Add button are on screen.
  Future<void> _scrollToShowNewPageAndAdd() async {
    // Let setState + image layout run after returning from GMS scanner.
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;
    await WidgetsBinding.instance.endOfFrame;

    for (var i = 0; i < 24; i++) {
      if (!mounted) return;
      if (!_scrollController.hasClients) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        continue;
      }

      final position = _scrollController.position;
      final max = position.maxScrollExtent;
      // Jump first so builder/layout builds trailing items (Add + new pages).
      if (max > 0) {
        _scrollController.jumpTo(max);
      }
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || !_scrollController.hasClients) return;

      final settledMax = _scrollController.position.maxScrollExtent;
      if (settledMax <= 0) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        continue;
      }

      if ((_scrollController.offset - settledMax).abs() > 2) {
        await _scrollController.animateTo(
          settledMax,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }

      // Image decode can grow extent — pull to end again once.
      await Future<void>.delayed(const Duration(milliseconds: 280));
      if (!mounted || !_scrollController.hasClients) return;
      final finalMax = _scrollController.position.maxScrollExtent;
      if ((finalMax - _scrollController.offset).abs() > 8) {
        await _scrollController.animateTo(
          finalMax,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }

      // Prefer ensuring Add is visible if its row is built.
      final addCtx = _listAddKey.currentContext;
      if (addCtx != null) {
        await Scrollable.ensureVisible(
          addCtx,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: 1.0,
        );
      }
      return;
    }
  }

  void _openPageViewer(CameraProvider cameraProvider, int index) {
    if (_isSelectionMode) {
      _togglePageSelection(index);
      return;
    }
    if (cameraProvider.imageList.isEmpty) return;
    final safeIndex = index.clamp(0, cameraProvider.imageList.length - 1);
    setState(() => _currentIndex = safeIndex);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PageImageViewer(
          pages: cameraProvider.imageList.map((e) => e.imageByte).toList(),
          initialIndex: safeIndex,
          title: cameraProvider.imageList[safeIndex].name,
        ),
      ),
    );
  }

  void _reorderPage(
    CameraProvider cameraProvider, {
    required int fromIndex,
    required int toIndex,
  }) {
    if (fromIndex == toIndex) return;
    cameraProvider.reorderImages(fromIndex, toIndex);
    setState(() {
      if (_currentIndex == fromIndex) {
        _currentIndex = toIndex;
      } else if (fromIndex < _currentIndex && toIndex >= _currentIndex) {
        _currentIndex--;
      } else if (fromIndex > _currentIndex && toIndex <= _currentIndex) {
        _currentIndex++;
      }
      _remapSelectionAfterReorder(fromIndex, toIndex);
      _draggingIndex = null;
    });
  }

  void showTopSnackbar(BuildContext context, String message) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 10.0,
        left: 0,
        right: 0,
        child: TopSnackbar(message: message),
      ),
    );

    overlay.insert(overlayEntry);

    Future.delayed(const Duration(seconds: 3), () {
      overlayEntry.remove();
    });
  }

  Future<String> getUniqueFileName(String baseSavePath, String fileName) async {
    int counter = 1;
    String uniqueFileName = fileName;
    String uniqueSavePath = '$baseSavePath/$uniqueFileName.pdf';

    while (await File(uniqueSavePath).exists()) {
      uniqueFileName = '${fileName}_$counter';
      uniqueSavePath = '$baseSavePath/$uniqueFileName.pdf';
      counter++;
    }

    return uniqueSavePath;
  }

  @override
  Widget build(BuildContext context) {
    final cameraProvider = context.watch<CameraProvider>();
    final size = MediaQuery.sizeOf(context);
    final imageCount = cameraProvider.imageList.length;
    final safeIndex = imageCount == 0
        ? 0
        : _currentIndex.clamp(0, imageCount - 1);
    if (safeIndex != _currentIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _currentIndex = safeIndex);
      });
    }
    return PopScope(
        canPop: false,
        onPopInvoked: (didPop) {
          showGoogleAlertDialogue(
              context: context,
              title: 'Discard document?',
              content: 'If you leave now, your progress will be lost',
              onOkText: 'Discard',
              onCancelText: 'keep editing',
              onOk: () {
                cameraProvider.clearImageList();
                setState(() {
                  didPop = true;
                });
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(
                  builder: (context) {
                    return const BottomBar();
                  },
                ), (route) => false);
              },
              onCancel: () {
                Navigator.pop(context);
              });
        },
        child: Scaffold(
          backgroundColor: const Color(0xFF131314),
          appBar: AppBar(
            backgroundColor: _isSelectionMode
                ? AppColor.primaryColor
                : const Color(0xff1E1F20),
            centerTitle: false,
            toolbarHeight: 49,
            titleSpacing: 0,
            leadingWidth: 40,
            iconTheme: const IconThemeData(color: Colors.white, size: 23),
            actionsIconTheme:
                const IconThemeData(color: Colors.white, size: 23),
            leading: IconButton(
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  if (_isSelectionMode) {
                    _exitSelectionMode();
                    return;
                  }
                  showGoogleAlertDialogue(
                      context: context,
                      title: 'Discard document?',
                      content: 'If you leave now, your progress will be lost',
                      onOkText: 'Discard',
                      onCancelText: 'keep editing',
                      onOk: () {
                        cameraProvider.clearImageList();
                        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(
                          builder: (context) {
                            return const BottomBar();
                          },
                        ), (route) => false);
                      },
                      onCancel: () {
                        Navigator.pop(context);
                      });
                },
                icon: const Icon(
                  Icons.arrow_back,
                  size: 23,
                  color: Color(0xffffffff),
                )),
            title: _isSelectionMode
                ? Text(
                    '${_selectedIndexes.length.toString().padLeft(2, '0')} ${translation(context).selected}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                        color: Colors.white),
                  )
                : cameraProvider.imageList.isEmpty
                    ? Text(
                        translation(context).pleaseTakePhoto,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                            color: Colors.white),
                      )
                    : Text(
                        cameraProvider.imageList[safeIndex].name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                            color: Colors.white),
                      ),
            titleTextStyle: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w500,
            ),
            actions: [
              if (_isSelectionMode)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColor.primaryColor,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: const Size(0, 32),
                      shape: const StadiumBorder(),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => _toggleSelectAll(imageCount),
                    child: Text(
                      _selectedIndexes.length == imageCount && imageCount > 0
                          ? translation(context).deselectAll
                          : translation(context).selectAll,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
              else ...[
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: _isGridView ? 'List' : 'Grid',
                onPressed: () => setState(() {
                  _isGridView = !_isGridView;
                  if (!_isGridView) {
                    _isSelectionMode = false;
                    _selectedIndexes.clear();
                    _draggingIndex = null;
                  }
                }),
                icon: Icon(
                  _isGridView
                      ? Icons.view_agenda_outlined
                      : Icons.grid_view_rounded,
                  size: 23,
                  color: Colors.white,
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(0, 37),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () async {
                  if (cameraProvider.imageList.isNotEmpty) {
                    await showModalBottomSheet(
                      context: context,
                      builder: (context) {
                        return Container(
                          height: MediaQuery.sizeOf(context).height * 0.3,
                          width: MediaQuery.sizeOf(context).width,
                          decoration: const BoxDecoration(
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(20),
                                topRight: Radius.circular(20),
                              ),
                              color: Colors.white),
                          child: Column(
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10)
                                        .copyWith(top: 20, bottom: 10),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(''),
                                    Text(
                                      translation(context).documentFiles,
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Container(
                                      height: size.width >= 600 ? 40 : 30,
                                      width: size.width >= 600 ? 40 : 30,
                                      alignment: Alignment.center,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFF4F4F4),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius:
                                              BorderRadius.circular(30),
                                          onTap: () {
                                            Navigator.pop(context);
                                          },
                                          child: Icon(
                                            Icons.close_rounded,
                                            size: size.width >= 600 ? 30 : 20,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Divider(
                                color: Colors.grey[200],
                                thickness: 1,
                              ),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () async {
                                    Navigator.pop(context);
                                    _renameController.text = cameraProvider
                                        .imageList[_currentIndex].name;
                                    showDialog(
                                      context: context,
                                      builder: (context) {
                                        String errorMessage = '';
                                        return StatefulBuilder(
                                            builder: (context, setState) {
                                          return AlertDialog(
                                            title: SizedBox(
                                              width: AppHelper.isTablet(context)
                                                  ? 250
                                                  : 200,
                                              child: Text(
                                                translation(context).renameFile,
                                                style: const TextStyle(
                                                  color: Colors.black,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                            content: Form(
                                              key: _formKey,
                                              child: TextFormField(
                                                controller: _renameController,
                                                keyboardType:
                                                    TextInputType.text,
                                                textInputAction:
                                                    TextInputAction.done,
                                                autofocus: true,
                                                validator: (value) {
                                                  if (value!.isEmpty) {
                                                    return translation(context)
                                                        .pleaseEnterFileName;
                                                  }
                                                  return null;
                                                },
                                                decoration: InputDecoration(
                                                  errorText:
                                                      errorMessage.isEmpty
                                                          ? null
                                                          : errorMessage,
                                                  hintText: translation(context)
                                                      .enterFileName,
                                                  border:
                                                      const OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                        color: AppColor
                                                            .primaryColor),
                                                  ),
                                                  contentPadding:
                                                      const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 10),
                                                ),
                                              ),
                                            ),
                                            actions: [
                                              TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(context),
                                                  child: Text(
                                                      translation(context)
                                                          .cancel)),
                                              TextButton(
                                                  onPressed: () async {
                                                    if (_formKey.currentState!
                                                        .validate()) {
                                                      bool isNameAlreadyExists = cameraProvider
                                                          .imageList
                                                          .any((image) =>
                                                              image.name ==
                                                                  _renameController
                                                                      .text &&
                                                              image !=
                                                                  cameraProvider
                                                                          .imageList[
                                                                      _currentIndex]);

                                                      if (isNameAlreadyExists) {
                                                        // Show confirmation popup for creating a duplicate name
                                                        bool allowDuplicate =
                                                            await showDialog<
                                                                    bool>(
                                                                  context:
                                                                      context,
                                                                  builder:
                                                                      (context) {
                                                                    return AlertDialog(
                                                                      title: const Text(
                                                                          "File Already Exist"),
                                                                      content:
                                                                          const Text(
                                                                              "This file already exists. Do you want to create a duplicate file?"),
                                                                      actions: [
                                                                        TextButton(
                                                                          onPressed: () => Navigator.pop(
                                                                              context,
                                                                              false),
                                                                          child:
                                                                              Text(translation(context).cancel),
                                                                        ),
                                                                        TextButton(
                                                                          onPressed: () => Navigator.pop(
                                                                              context,
                                                                              true),
                                                                          child:
                                                                              const Text("Allow Duplicate"),
                                                                        ),
                                                                      ],
                                                                    );
                                                                  },
                                                                ) ??
                                                                false;

                                                        if (allowDuplicate) {
                                                          // Generate a unique name
                                                          String uniqueName =
                                                              _renameController
                                                                  .text;
                                                          int counter = 1;
                                                          while (cameraProvider
                                                              .imageList
                                                              .any((image) =>
                                                                  image.name ==
                                                                  uniqueName)) {
                                                            uniqueName =
                                                                "${_renameController.text}$counter";
                                                            counter++;
                                                          }

                                                          // Update image with the unique name
                                                          final old = cameraProvider
                                                              .imageList[
                                                                  _currentIndex];
                                                          cameraProvider
                                                              .updateImage(
                                                            index:
                                                                _currentIndex,
                                                            image: old.copyWith(
                                                              name: uniqueName,
                                                            ),
                                                          );

                                                          Navigator.pop(
                                                              context);
                                                        }
                                                      } else if (cameraProvider
                                                              .imageList
                                                              .first
                                                              .docType ==
                                                          "ID Card") {
                                                        Directory
                                                            rootDirectory =
                                                            await getApplicationDocumentsDirectory();
                                                        String path =
                                                            "${rootDirectory.path}/Doc Scanner/ID Card";
                                                        File file = File(
                                                            "$path/${_renameController.text}.jpg");
                                                        if (file.existsSync()) {
                                                          setState(() {
                                                            errorMessage =
                                                                translation(
                                                                        context)
                                                                    .fileAlreadyExists;
                                                          });
                                                        } else {
                                                          final old = cameraProvider
                                                              .imageList[
                                                                  _currentIndex];
                                                          cameraProvider
                                                              .updateImage(
                                                            index:
                                                                _currentIndex,
                                                            image: old.copyWith(
                                                              name:
                                                                  _renameController
                                                                      .text,
                                                            ),
                                                          );

                                                          Navigator.pop(
                                                              context);
                                                        }
                                                      } else {
                                                        Directory
                                                            rootDirectory =
                                                            await getApplicationDocumentsDirectory();
                                                        String path =
                                                            "${rootDirectory.path}/Doc Scanner/Document";
                                                        File file = File(
                                                            "$path/${_renameController.text}.jpg");
                                                        if (file.existsSync()) {
                                                          setState(() {
                                                            errorMessage =
                                                                translation(
                                                                        context)
                                                                    .fileAlreadyExists;
                                                          });
                                                        } else {
                                                          final old = cameraProvider
                                                              .imageList[
                                                                  _currentIndex];
                                                          cameraProvider
                                                              .updateImage(
                                                            index:
                                                                _currentIndex,
                                                            image: old.copyWith(
                                                              name:
                                                                  _renameController
                                                                      .text,
                                                            ),
                                                          );

                                                          Navigator.pop(
                                                              context);
                                                        }
                                                      }
                                                    }
                                                  },
                                                  child: Text(
                                                      translation(context)
                                                          .save)),
                                            ],
                                          );
                                        });
                                      },
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20.0, vertical: 5),
                                    child: Row(
                                      children: [
                                        SvgPicture.asset(
                                          AppAssets.rename,
                                          color: Colors.black,
                                          height: size.width >= 600 ? 30 : 20,
                                          width: size.width >= 600 ? 30 : 20,
                                        ),
                                        const SizedBox(
                                          width: 20,
                                        ),
                                        Text(
                                          translation(context).renameFile,
                                          style: const TextStyle(
                                            color: Colors.black,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Divider(
                                color: Colors.grey[200],
                                thickness: 1,
                                indent: MediaQuery.sizeOf(context).width * 0.15,
                              ),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () async {
                                    showNormalAlertDialogue(
                                      context: context,
                                      title: translation(context).saveImages,
                                      content: translation(context)
                                          .doYouWantSaveAllImages,
                                      onOkText: translation(context).save,
                                      onCancelText: translation(context).cancel,
                                      onOk: () async {
                                        await cameraProvider
                                            .exportAllImages()
                                            .then((value) {
                                          cameraProvider.clearImageList();
                                          Navigator.pushAndRemoveUntil(context,
                                              MaterialPageRoute(
                                            builder: (context) {
                                              return const BottomBar(
                                                shouldShowReview: true,
                                              );
                                            },
                                          ), (route) => false);
                                          showTopSnackbar(
                                              context,
                                              translation(context)
                                                  .allImagesSavedSuccessfully);
                                        });
                                      },
                                      onCancel: () => Navigator.pop(context),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20.0, vertical: 5),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.ios_share_outlined,
                                          color: Colors.black,
                                          size: size.width >= 600 ? 30 : 20,
                                        ),
                                        const SizedBox(
                                          width: 20,
                                        ),
                                        Text(
                                          translation(context).exportImages,
                                          style: const TextStyle(
                                            color: Colors.black,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Divider(
                                color: Colors.grey[200],
                                thickness: 1,
                                indent: MediaQuery.sizeOf(context).width * 0.15,
                              ),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () async {
                                    await showDialog(
                                      context: context,
                                      builder: (context) {
                                        final cameProvider =
                                            context.watch<CameraProvider>();
                                        TextEditingController renameController =
                                            TextEditingController(
                                          text: _openedDocumentBaseName ?? '',
                                        );
                                        return StatefulBuilder(
                                          builder: (context, setState) {
                                            return AlertDialog(
                                              title: SizedBox(
                                                width:
                                                    AppHelper.isTablet(context)
                                                        ? 350
                                                        : 300,
                                                child: Text(translation(context)
                                                    .savePdf),
                                              ),
                                              content: isSaving
                                                  ? ConstrainedBox(
                                                      constraints:
                                                          const BoxConstraints(
                                                              maxHeight: 40,
                                                              maxWidth: 40),
                                                      child: const Center(
                                                        child:
                                                            CircularProgressIndicator(),
                                                      ),
                                                    )
                                                  : TextFormField(
                                                      controller:
                                                          renameController,
                                                      keyboardType:
                                                          TextInputType.text,
                                                      textInputAction:
                                                          TextInputAction.done,
                                                      autofocus: true,
                                                      validator: (value) {
                                                        if (value!.isEmpty) {
                                                          return translation(
                                                                  context)
                                                              .pleaseEnterFileName;
                                                        }
                                                        return null;
                                                      },
                                                      decoration:
                                                          InputDecoration(
                                                        hintText:
                                                            translation(context)
                                                                .enterFileName,
                                                        border:
                                                            const OutlineInputBorder(
                                                          borderSide: BorderSide(
                                                              color: AppColor
                                                                  .primaryColor),
                                                        ),
                                                        contentPadding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 10),
                                                      ),
                                                    ),
                                              actions: isSaving
                                                  ? []
                                                  : [
                                                      TextButton(
                                                        onPressed: () {
                                                          if (renameController
                                                              .text
                                                              .isNotEmpty) {
                                                            setState(() {
                                                              isSaving =
                                                                  true; // Show progress indicator
                                                            });
                                                            final name =
                                                                renameController
                                                                    .text
                                                                    .trim();
                                                            // Same doc from Recent → update in place.
                                                            final overwrite =
                                                                _openedDocumentPath !=
                                                                        null &&
                                                                    name ==
                                                                        _openedDocumentBaseName
                                                                    ? _openedDocumentPath
                                                                    : null;
                                                            cameProvider
                                                                .createPDFFromByte(
                                                              context: context,
                                                              fileName: name,
                                                              overwritePath:
                                                                  overwrite,
                                                            )
                                                                .then((value) {
                                                              if (value ==
                                                                  null) {
                                                                if (context
                                                                    .mounted) {
                                                                  setState(() {
                                                                    isSaving =
                                                                        false;
                                                                  });
                                                                }
                                                                return;
                                                              }
                                                              cameraProvider
                                                                  .clearImageList();
                                                              if (!context
                                                                  .mounted) {
                                                                return;
                                                              }
                                                              Navigator
                                                                  .pushAndRemoveUntil(
                                                                context,
                                                                MaterialPageRoute(
                                                                  builder:
                                                                      (context) {
                                                                    return const BottomBar(
                                                                      shouldShowReview:
                                                                          true,
                                                                    );
                                                                  },
                                                                ),
                                                                (route) =>
                                                                    false,
                                                              );
                                                              AppHelper
                                                                  .showTopSnackBar(
                                                                context,
                                                                "PDF save successfully in Document Folder",
                                                              );
                                                              showInterstitialAd(
                                                                  context);
                                                            });
                                                          }
                                                        },
                                                        style:
                                                            const ButtonStyle(
                                                          splashFactory: InkSparkle
                                                              .splashFactory, // Disable splash effect
                                                        ),
                                                        child: Text(
                                                            translation(context)
                                                                .ok),
                                                      ),
                                                      TextButton(
                                                        onPressed: () {
                                                          Navigator.pop(
                                                              context);
                                                        },
                                                        child: Text(
                                                            translation(context)
                                                                .cancel),
                                                      )
                                                    ],
                                            );
                                          },
                                        );
                                      },
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20.0, vertical: 5),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.picture_as_pdf_outlined,
                                          color: Colors.black,
                                          size: size.width >= 600 ? 30 : 20,
                                        ),
                                        const SizedBox(
                                          width: 20,
                                        ),
                                        Text(
                                          translation(context).exportAsPdf,
                                          style: const TextStyle(
                                            color: Colors.black,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // Divider(
                              //   color: Colors.grey[200],
                              //   thickness: 1,
                              //   indent: MediaQuery.sizeOf(context).width * 0.15,
                              // ),
                              // Material(
                              //   color: Colors.transparent,
                              //   child: InkWell(
                              //     onTap: () async {
                              //       showNormalAlertDialogue(
                              //         context: context,
                              //         title: translation(context).deleteImage,
                              //         content: translation(context)
                              //             .doYouWantToDeleteThisImage,
                              //         onOkText: translation(context).delete,
                              //         onCancelText: translation(context).cancel,
                              //         onOk: () {
                              //           cameraProvider.deleteImage(_currentIndex);
                              //           if(_currentIndex>0){
                              //             _currentIndex--;
                              //           }
                              //           if (cameraProvider.imageList.isEmpty) {
                              //             Navigator.pop(context);
                              //             Navigator.pop(context);
                              //             Navigator.pop(context);
                              //           } else {
                              //             Navigator.pop(context);
                              //             Navigator.pop(context);
                              //           }
                              //         },
                              //         onCancel: () => Navigator.pop(context),
                              //       );
                              //     },
                              //     child: Padding(
                              //       padding: const EdgeInsets.symmetric(
                              //           horizontal: 20.0, vertical: 5),
                              //       child: Row(
                              //         children: [
                              //           SvgPicture.asset(
                              //             AppAssets.delete,
                              //             color: Colors.red,
                              //           ),
                              //           const SizedBox(
                              //             width: 20,
                              //           ),
                              //           Text(
                              //             translation(context).delete,
                              //             style: TextStyle(
                              //               color: Colors.red,
                              //               fontSize: 16,
                              //               fontWeight: FontWeight.w400,
                              //             ),
                              //           ),
                              //         ],
                              //       ),
                              //     ),
                              //   ),
                              // ),
                            ],
                          ),
                        );
                      },
                    );
                  }
                },
                child: Text(
                  translation(context).option,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColor.primaryColor,
                  ),
                ),
              ),
              ],
            ],
          ),
          body: Column(
            children: [
              if (_isGridView && _isSelectionMode)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 16, color: Colors.white.withValues(alpha: 0.55)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          translation(context).holdAndDragToReorder,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              cameraProvider.imageList.isEmpty
                  ? Expanded(
                      child: Center(
                        child: _openingDocument
                            ? const CircularProgressIndicator()
                            : Text(translation(context).noImageFound),
                      ),
                    )
                  : Expanded(
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: _isGridView
                                ? _buildGridPages(cameraProvider)
                                : Stack(
                                    key: _listViewportKey,
                                    children: [
                                      _buildListPages(cameraProvider),
                                      // One fixed CamScanner-style badge.
                                      Positioned(
                                        left: 16,
                                        top: 15,
                                        child: IgnorePointer(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: const BoxDecoration(
                                              color: Color(0x8C000000),
                                            ),
                                            child: Text(
                                              '${safeIndex + 1}/$imageCount',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                          if (_loadingMorePages)
                            const Positioned(
                              left: 0,
                              right: 0,
                              bottom: 8,
                              child: Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
            ],
          ),
          bottomNavigationBar: BottomBarWithBanner(
            adUnitId: AdHelper.imageEditPreviewBannerAdUnitId,
            child: BottomAppBar(
            color: const Color(0xff1E1F20),
            padding: EdgeInsets.symmetric(
                horizontal: _isSelectionMode ? 24.0 : 10.0),
            surfaceTintColor: const Color(0xff1E1F20),
            child: Row(
              mainAxisAlignment: _isSelectionMode
                  ? MainAxisAlignment.spaceEvenly
                  : MainAxisAlignment.spaceBetween,
              children: [
                if (_isSelectionMode) ...[
                  Expanded(
                    child: ImageEditButton(
                      title:
                          '${translation(context).copy}/${translation(context).move}',
                      onTap: _selectedIndexes.isEmpty
                          ? null
                          : () => _showMoveCopySheet(cameraProvider),
                      iconPath: AppAssets.moveIconGridView,
                    ),
                  ),
                  Expanded(
                    child: ImageEditButton(
                      title: translation(context).share,
                      onTap: _selectedIndexes.isEmpty
                          ? null
                          : () => _shareSelectedPages(cameraProvider),
                      iconPath: AppAssets.shareIconGridView,
                    ),
                  ),
                  Expanded(
                    child: ImageEditButton(
                      title: translation(context).delete,
                      onTap: _selectedIndexes.isEmpty
                          ? null
                          : () => _deleteSelectedPages(cameraProvider),
                      iconPath: AppAssets.deleteIconGridView,
                    ),
                  ),
                ] else ...[
                  ImageEditButton(
                    title: translation(context).add,
                    onTap: _addingPages
                        ? null
                        : () => _addMorePages(cameraProvider),
                    iconPath: AppAssets.cameraIcon,
                  ),
                  ImageEditButton(
                    title: translation(context).edit,
                    onTap: () {
                      if (cameraProvider.imageList.isEmpty) return;
                      // CamScanner-style: open swipeable editor on the
                      // currently focused page (user can scroll 1/n … n/n).
                      final start = _currentIndex.clamp(
                          0, cameraProvider.imageList.length - 1);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ImageEditScreen(
                            imageIndex: start,
                            image: cameraProvider.imageList[start],
                          ),
                        ),
                      );
                    },
                    iconPath: AppAssets.edit,
                  ),
                  ImageEditButton(
                    title: translation(context).convert,
                    onTap: () async {
                      final Uint8List textRecognitionImage =
                          cameraProvider.imageList[_currentIndex].imageByte;
                      await AppHelper()
                          .convertUint8ListToFile(data: textRecognitionImage)
                          .then((value) async {
                        final inputImage = InputImage.fromFile(value);
                        final textRecognizer = TextRecognizer(
                            script: TextRecognitionScript.latin);
                        await textRecognizer
                            .processImage(inputImage)
                            .then((recognizedText) {
                          String text = recognizedText.text;
                          if (text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  translation(context)
                                      .thisLanguageNotSupported,
                                ),
                              ),
                            );
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TextRecognitionScreen(
                                    recognisedText: text),
                              ),
                            );
                          }
                        });
                      });
                    },
                    iconPath: AppAssets.ocr,
                  ),
                  ImageEditButton(
                    title: translation(context).sign,
                    onTap: () {
                      if (cameraProvider.imageList.isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddSignature(
                              imageModel:
                                  cameraProvider.imageList[_currentIndex],
                              imageIndex: _currentIndex,
                            ),
                          ),
                        );
                      }
                    },
                    iconPath: AppAssets.sign,
                  ),
                  ImageEditButton(
                    title: translation(context).share,
                    onTap: () async {
                      await AppHelper()
                          .convertUint8ListToFile(
                              data: cameraProvider
                                  .imageList[_currentIndex].imageByte,
                              extension: 'jpg')
                          .then((value) async {
                        await Share.shareXFiles([XFile(value.path)]);
                      });
                    },
                    iconPath: AppAssets.share,
                  ),
                ],
              ],
            ),
          ),
          ),
        ));
  }

  Widget _buildListPages(CameraProvider cameraProvider) {
    final images = cameraProvider.imageList;
    final pageCount = images.length;
    _ensurePageKeys(pageCount);
    // Non-builder ListView so maxScrollExtent is real (builder underestimates
    // variable-height pages, so auto-scroll after add never reached Add).
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification ||
            notification is ScrollEndNotification) {
          _syncListPageIndex();
        }
        return false;
      },
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(0, 15, 0, 16),
        children: [
          for (var index = 0; index < pageCount; index++)
            Padding(
              key: _pageItemKeys[index],
              padding: EdgeInsets.fromLTRB(
                16,
                0,
                16,
                index == pageCount - 1 ? 0 : 12,
              ),
              child: GestureDetector(
                onTap: () => _openPageViewer(cameraProvider, index),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: index == _currentIndex
                          ? _addAccent
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.memory(
                      images[index].imageByte,
                      fit: BoxFit.contain,
                      width: double.infinity,
                      gaplessPlayback: true,
                    ),
                  ),
                ),
              ),
            ),
          // Last page → Add (same spacing/UI as before).
          Padding(
            key: _listAddKey,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: _DashedAddButton(
              label: translation(context).add,
              enabled: !_addingPages,
              onTap: () => _addMorePages(cameraProvider),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridPages(CameraProvider cameraProvider) {
    final images = cameraProvider.imageList;
    final size = MediaQuery.sizeOf(context);
    final crossAxisCount = size.width >= 600 ? 3 : 2;
    final inSelectionMode = _isSelectionMode;
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 16,
        crossAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      // Hide Add tile while in CamScanner-style selection/reorder mode.
      itemCount: images.length + (inSelectionMode ? 0 : 1),
      itemBuilder: (context, index) {
        if (!inSelectionMode && index == images.length) {
          return _GridAddTile(
            enabled: !_addingPages,
            onTap: () => _addMorePages(cameraProvider),
            label: translation(context).addPage,
          );
        }
        return _buildDraggableGridThumb(
          cameraProvider: cameraProvider,
          index: index,
          feedbackWidth: size.width / crossAxisCount - 18,
          feedbackHeight: (size.width / crossAxisCount - 18) / 0.72,
        );
      },
    );
  }

  Widget _buildGridThumbVisual({
    required Uint8List bytes,
    required String pageLabel,
    required bool isPageSelected,
    required bool selectionMode,
    double opacity = 1,
  }) {
    final showSelectUi = selectionMode && isPageSelected;
    final borderColor = showSelectUi
        ? AppColor.primaryColor
        : (selectionMode
            ? const Color(0xFF4A4B4C)
            : (isPageSelected ? _addAccent : Colors.transparent));
    final borderWidth = showSelectUi ? 2.5 : 2.0;
    return Opacity(
      opacity: opacity,
      child: Column(
        children: [
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: borderColor,
                        width: borderWidth,
                      ),
                      boxShadow: [
                        if (showSelectUi)
                          BoxShadow(
                            color: AppColor.primaryColor.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        else
                          const BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.memory(
                        bytes,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
                  ),
                ),
                if (selectionMode)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: showSelectUi
                            ? AppColor.primaryColor
                            : Colors.black.withValues(alpha: 0.35),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: showSelectUi
                          ? const Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (showSelectUi)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppColor.primaryColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                pageLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            Text(
              pageLabel,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }

  /// Long-press enters persistent selection mode; drag reorders (CamScanner).
  Widget _buildDraggableGridThumb({
    required CameraProvider cameraProvider,
    required int index,
    required double feedbackWidth,
    required double feedbackHeight,
  }) {
    final images = cameraProvider.imageList;
    final page = images[index];
    final pageLabel = (index + 1).toString().padLeft(2, '0');
    final isPageSelected = _isSelectionMode
        ? _selectedIndexes.contains(index)
        : index == _currentIndex;
    final isDragging = _draggingIndex == index;

    return LongPressDraggable<int>(
      data: index,
      delay: const Duration(milliseconds: 180),
      onDragStarted: () {
        setState(() {
          if (!_isSelectionMode) {
            _isSelectionMode = true;
            _selectedIndexes
              ..clear()
              ..add(index);
          } else if (!_selectedIndexes.contains(index)) {
            _selectedIndexes.add(index);
          }
          _draggingIndex = index;
        });
      },
      onDragEnd: (_) {
        // Keep selection mode — only clear active drag ghost.
        if (mounted) setState(() => _draggingIndex = null);
      },
      onDraggableCanceled: (_, __) {
        if (!mounted) return;
        setState(() {
          _draggingIndex = null;
          if (!_isSelectionMode) {
            _isSelectionMode = true;
            _selectedIndexes
              ..clear()
              ..add(index);
          }
        });
      },
      feedback: Material(
        color: Colors.transparent,
        elevation: 8,
        child: SizedBox(
          width: feedbackWidth,
          height: feedbackHeight,
          child: _buildGridThumbVisual(
            bytes: page.imageByte,
            pageLabel: pageLabel,
            isPageSelected: true,
            selectionMode: true,
          ),
        ),
      ),
      childWhenDragging: _buildGridThumbVisual(
        bytes: page.imageByte,
        pageLabel: pageLabel,
        isPageSelected: true,
        selectionMode: true,
        opacity: 0.35,
      ),
      child: DragTarget<int>(
        onWillAcceptWithDetails: (details) => details.data != index,
        onAcceptWithDetails: (details) {
          _reorderPage(
            cameraProvider,
            fromIndex: details.data,
            toIndex: index,
          );
        },
        builder: (context, candidateData, rejectedData) {
          final isTarget = candidateData.isNotEmpty;
          return GestureDetector(
            onTap: () => _openPageViewer(cameraProvider, index),
            onLongPress: () {
              if (!_isSelectionMode) {
                _enterSelectionMode(index);
              } else {
                _togglePageSelection(index);
              }
            },
            child: AnimatedScale(
              scale: isTarget ? 0.96 : 1,
              duration: const Duration(milliseconds: 120),
              child: _buildGridThumbVisual(
                bytes: page.imageByte,
                pageLabel: pageLabel,
                isPageSelected: isPageSelected,
                selectionMode: _isSelectionMode,
                opacity: isDragging ? 0.35 : 1,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DashedAddButton extends StatelessWidget {
  const _DashedAddButton({
    required this.label,
    required this.onTap,
    required this.enabled,
  });

  final String label;
  final VoidCallback onTap;
  final bool enabled;

  // Figma: soft blue icon/text + dashed stroke on dark navy chip.
  static const _accent = Color(0xFF9BB8E8);
  static const _fill = Color(0xFF151B28);

  @override
  Widget build(BuildContext context) {
    final accent = _accent.withValues(alpha: enabled ? 1 : 0.45);
    return Center(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(4),
          child: CustomPaint(
            // Stroke must paint ABOVE the fill or the dashed border disappears.
            foregroundPainter: _DashedRRectPainter(
              color: accent,
              radius: 4,
              strokeWidth: 1.5,
              dashWidth: 5,
              dashGap: 4,
            ),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 50),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
              decoration: BoxDecoration(
                color: _fill,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    AppAssets.cameraIcon,
                    width: 20,
                    height: 20,
                    colorFilter: ColorFilter.mode(accent, BlendMode.srcIn),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      color: accent,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GridAddTile extends StatelessWidget {
  const _GridAddTile({
    required this.onTap,
    required this.enabled,
    required this.label,
  });

  final VoidCallback onTap;
  final bool enabled;
  final String label;

  static const _accent = Color(0xFF9BB8E8);
  static const _fill = Color(0xFF151B28);
  static const _buttonBlue = Color(0xFF1C58BE);

  @override
  Widget build(BuildContext context) {
    final accent = _accent.withValues(alpha: enabled ? 1 : 0.45);
    // Match thumbnail cells: dashed tile on top, empty space where page # sits.
    return Column(
      children: [
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: enabled ? onTap : null,
              borderRadius: BorderRadius.circular(4),
              child: CustomPaint(
                foregroundPainter: _DashedRRectPainter(
                  color: accent,
                  radius: 4,
                  strokeWidth: 1.5,
                  dashWidth: 5,
                  dashGap: 4,
                ),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: _fill,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SvgPicture.asset(
                        AppAssets.cameraIcon,
                        width: 28,
                        height: 28,
                        colorFilter: ColorFilter.mode(accent, BlendMode.srcIn),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: enabled
                              ? _buttonBlue
                              : _buttonBlue.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const SizedBox(height: 18),
      ],
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
    required this.dashWidth,
    required this.dashGap,
  });

  final Color color;
  final double radius;
  final double strokeWidth;
  final double dashWidth;
  final double dashGap;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final inset = strokeWidth / 2;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        inset,
        inset,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + dashWidth).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) =>
      color != oldDelegate.color ||
      radius != oldDelegate.radius ||
      strokeWidth != oldDelegate.strokeWidth ||
      dashWidth != oldDelegate.dashWidth ||
      dashGap != oldDelegate.dashGap;
}
