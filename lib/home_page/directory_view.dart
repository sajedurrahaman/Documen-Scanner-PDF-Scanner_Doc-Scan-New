// ignore_for_file: deprecated_member_use, use_build_context_synchronously, empty_catches

import 'dart:developer';
import 'dart:io';
import 'package:doc_scanner/utils/Common.dart';
import 'package:doc_scanner/utils/addHelper.dart';
import 'package:doc_scanner/home_page/provider/home_page_provider.dart';
import 'provider/recent_files_provider.dart';
import 'package:doc_scanner/localaization/language_constant.dart';
import 'package:doc_scanner/utils/app_assets.dart';
import 'package:doc_scanner/utils/app_color.dart';
import 'package:doc_scanner/utils/download_helper.dart';
import 'package:doc_scanner/utils/helper.dart';
import 'package:doc_scanner/utils/pdf_view_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_svg/svg.dart';
import 'package:gal/gal.dart';
import 'package:doc_scanner/utils/banner_ad_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/utils.dart';
// ignore: depend_on_referenced_packages
import 'package:path/path.dart' as path;
// import 'package:document_file_save_plus/document_file_save_plus.dart';

class DirectoryDetailsPage extends StatefulWidget {
  final String directoryPath;

  const DirectoryDetailsPage({super.key, required this.directoryPath});

  @override
  State<DirectoryDetailsPage> createState() => _DirectoryDetailsPageState();
}

class _DirectoryDetailsPageState extends State<DirectoryDetailsPage> {
  final _selectedItems = <String>{};
  bool _isLongPressed = false;
  List<String> directoryList = [];
  late Future<List<String>> allFiles;
  bool isDeleteLoading = false;
  bool isShareIng = false;
  late Directory rootDirectory;
  String subFilePath = "";

  final _searchController = TextEditingController();
  final _folderNameController = TextEditingController();
  String _query = '';
  bool _searching = false;
  List<String> _loadedFiles = [];
  final Map<String, FileStat> _fileStats = {};
  final Map<String, int> _folderCounts = {};

  Future<List<String>> _loadFiles() async {
    final files = await context
        .read<HomePageProvider>()
        .getFileList(widget.directoryPath);
    final stats = <String, FileStat>{};
    final counts = <String, int>{};
    await Future.wait(files.map((file) async {
      final stat = await FileStat.stat(file);
      stats[file] = stat;
      if (stat.type == FileSystemEntityType.directory) {
        try {
          counts[file] = await Directory(file).list(followLinks: false).length;
        } on FileSystemException {
          counts[file] = 0;
        }
      }
    }));
    files.sort((a, b) {
      final aFolder = stats[a]?.type == FileSystemEntityType.directory;
      final bFolder = stats[b]?.type == FileSystemEntityType.directory;
      if (aFolder != bFolder) return aFolder ? -1 : 1;
      return (stats[b]?.modified ?? DateTime(0))
          .compareTo(stats[a]?.modified ?? DateTime(0));
    });
    _fileStats
      ..clear()
      ..addAll(stats);
    _folderCounts
      ..clear()
      ..addAll(counts);
    _loadedFiles = files;
    directoryList = counts.keys.toList();
    _selectedItems.removeWhere((file) => !files.contains(file));
    return files;
  }

  Future<void> _refresh() async {
    final next = _loadFiles();
    setState(() {
      allFiles = next;
    });
    await next;
  }

  void _exitSelection() {
    setState(() {
      _isLongPressed = false;
      _selectedItems.clear();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _folderNameController.dispose();
    super.dispose();
  }

  String get _title {
    final labels = translation(context);
    switch (path.basename(widget.directoryPath)) {
      case 'Document':
        return labels.document;
      case 'ID Card':
        return labels.idCard;
      case 'QR Code':
        return labels.qrCode;
      case 'Bar Code':
        return labels.barCode;
      default:
        return path.basename(widget.directoryPath);
    }
  }

  bool get _isCategoryRoot =>
      path.basename(path.dirname(path.normalize(widget.directoryPath))) ==
          'Doc Scanner' &&
      const {'Document', 'ID Card', 'QR Code', 'Bar Code'}
          .contains(path.basename(path.normalize(widget.directoryPath)));

  PreferredSizeWidget _buildHeader() {
    final labels = translation(context);
    final allSelected =
        _loadedFiles.isNotEmpty && _loadedFiles.every(_selectedItems.contains);
    return AppBar(
      backgroundColor: AppColor.primaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      toolbarHeight: 70,
      leading: IconButton(
        tooltip: _isLongPressed
            ? labels.cancel
            : MaterialLocalizations.of(context).backButtonTooltip,
        icon: Icon(_isLongPressed ? Icons.close : Icons.arrow_back),
        onPressed: () {
          if (_isLongPressed) {
            _exitSelection();
          } else {
            Navigator.pop(context);
          }
        },
      ),
      titleSpacing: 0,
      title: _isLongPressed
          ? Text(
              _selectedItems.isEmpty
                  ? labels.select
                  : '${_selectedItems.length} ${labels.selected}',
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600))
          : _searching
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  cursorColor: Colors.white,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                      hintText: labels.searchHere,
                      hintStyle: const TextStyle(color: Colors.white70),
                      border: InputBorder.none),
                  onChanged: (value) => setState(() => _query = value),
                )
              : Text(_title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w600)),
      actions: _isLongPressed
          ? [
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 16),
                child: Center(
                    child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                    shape: const StadiumBorder(),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onPressed: () => setState(() {
                    _selectedItems.clear();
                    if (!allSelected) _selectedItems.addAll(_loadedFiles);
                  }),
                  child: Text(
                      allSelected ? labels.deselectAll : labels.selectAll,
                      style: const TextStyle(fontSize: 12)),
                )),
              )
            ]
          : !_isCategoryRoot
              ? const <Widget>[]
              : [
                  if (!_searching)
                    IconButton(
                      tooltip: 'Create folder',
                      icon: const Icon(Icons.create_new_folder_outlined),
                      onPressed: () => _showCenterDialog(context),
                    ),
                  IconButton(
                    tooltip: _searching ? labels.cancel : labels.search,
                    icon:
                        Icon(_searching ? Icons.close : Icons.search, size: 27),
                    onPressed: () => setState(() {
                      _searching = !_searching;
                      if (!_searching) {
                        _query = '';
                        _searchController.clear();
                        FocusScope.of(context).unfocus();
                      }
                    }),
                  ),
                  const SizedBox(width: 8),
                ],
    );
  }

  String _fileSubtitle(String file) {
    if (_fileStats[file]?.type == FileSystemEntityType.directory) {
      final count = _folderCounts[file] ?? 0;
      return '$count Item${count == 1 ? '' : 's'}';
    }
    final stat = _fileStats[file];
    if (stat == null) return '';
    final bytes = stat.size;
    final size = bytes < 1024
        ? '$bytes B'
        : bytes < 1024 * 1024
            ? '${(bytes / 1024).toStringAsFixed(1)} KB'
            : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    final elapsed = DateTime.now().difference(stat.modified);
    final String time;
    if (elapsed.inMinutes < 1) {
      time = 'Just now';
    } else if (elapsed.inHours < 1) {
      time = '${elapsed.inMinutes} min ago';
    } else if (elapsed.inDays < 1) {
      time = '${elapsed.inHours} hour${elapsed.inHours == 1 ? '' : 's'} ago';
    } else {
      time = '${elapsed.inDays} day${elapsed.inDays == 1 ? '' : 's'} ago';
    }
    final extension = path.extension(file).replaceFirst('.', '').toUpperCase();
    return '$extension • $size • $time';
  }

  Widget _deleteMenuItem(BuildContext sheetContext, String filePath) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
        minLeadingWidth: 24,
        horizontalTitleGap: 20,
        leading: const Icon(Icons.delete_outline, color: Colors.black, size: 24),
        title: Text(translation(sheetContext).delete,
            style: const TextStyle(color: Colors.black, fontSize: 16)),
        onTap: () {
          Navigator.pop(sheetContext);
          _deleteEntry(filePath);
        },
      ),
    );
  }

  Future<void> _deleteEntry(String filePath) async {
    final labels = translation(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(labels.delete),
        content: Text(
          labels.areYouSureYouWantToDeleteTheSelectedItems
              .trim()
              .replaceAllMapped(RegExp(r'\s+([?؟？])'), (match) => match[1]!),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(labels.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child:
                Text(labels.delete, style: const TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final home = context.read<HomePageProvider>();
    final recent = context.read<RecentFilesProvider?>();
    setState(() => isDeleteLoading = true);
    try {
      final type = await FileSystemEntity.type(filePath, followLinks: false);
      if (type == FileSystemEntityType.directory) {
        await Directory(filePath).delete(recursive: true);
      } else if (type == FileSystemEntityType.file) {
        await File(filePath).delete();
      }
      // Re-read storage so folder contents disappear from Home and Recents too.
      home.clearDocumentImageFiles();
      home.clearIdCardImageFiles();
      home.clearQRCodeFiles();
      home.clearBarCodeFiles();
      await Future.wait([
        home.loadDocumentImage(),
        home.loadIdCardImage(),
        home.loadQRCode(),
        home.loadBarCode(),
        if (recent != null) recent.load(),
      ]);
      if (!mounted) return;
      _selectedItems.remove(filePath);
      if (_selectedItems.isEmpty) _isLongPressed = false;
      await _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${labels.somethingWentWrong}: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => isDeleteLoading = false);
    }
  }

  Future<void> _showFileActions({
    required BuildContext context,
    required WidgetBuilder builder,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (sheetContext) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.85,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 16),
            child: builder(sheetContext),
          ),
        ),
      ),
    );
  }

  Widget _directoryTile(
    String file,
    bool selected, {
    required VoidCallback onTap,
    required VoidCallback onLongPress,
    required VoidCallback onMenu,
  }) {
    final folder = _fileStats[file]?.type == FileSystemEntityType.directory;
    final pdf = file.toLowerCase().endsWith('.pdf');
    final txt = file.toLowerCase().endsWith('.txt');
    final asset = folder
        ? AppAssets.homeDocumentFolder
        : pdf
            ? AppAssets.homePdfThumb
            : txt
                ? AppAssets.homeQrBarThumb
                : AppAssets.homeImageThumb;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? const Color(0xFFE3EDFD) : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
              color: selected ? const Color(0xFFC3D8FC) : Colors.transparent),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Row(children: [
            if (_isLongPressed)
              SizedBox(
                width: 32,
                child: Checkbox(
                  shape: const CircleBorder(),
                  value: selected,
                  activeColor: AppColor.primaryColor,
                  side: const BorderSide(color: Color(0xFFBACAE4)),
                  onChanged: (_) => _toggleItemSelection(file),
                ),
              ),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 50,
              height: 50,
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: pdf ? const Color(0xFFFFF1F3) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE0E8F5)),
              ),
              child: SvgPicture.asset(asset),
            ),
            const SizedBox(width: 14),
            Expanded(
                child: Container(
              constraints: const BoxConstraints(minHeight: 70),
              decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFE0E8F5)))),
              child: Row(children: [
                Expanded(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(path.basename(file),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Color(0xFF0D2C66),
                            fontSize: 14,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text(_fileSubtitle(file),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Color(0xFF7183A2), fontSize: 12)),
                  ],
                )),
                IconButton(
                  tooltip: MaterialLocalizations.of(context).showMenuTooltip,
                  icon: const Icon(Icons.more_vert, color: Color(0xFF455774)),
                  onPressed: onMenu,
                ),
              ]),
            )),
          ]),
        ),
      ),
    );
  }

  void _toggleItemSelection(String filePath) {
    setState(() {
      if (_selectedItems.contains(filePath)) {
        _selectedItems.remove(filePath);
      } else {
        _selectedItems.add(filePath);
      }
    });
  }

  void _enterSelectionMode(String filePath) {
    setState(() {
      _isLongPressed = true;
      _searching = false;
      _query = '';
      _searchController.clear();
      FocusScope.of(context).unfocus();
      _selectedItems.add(filePath);
    });
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

  Future<bool> _directoryExistsWithCaseInsensitive(
      Directory parentDirectory, String directoryName) async {
    try {
      final List<FileSystemEntity> entities =
          await parentDirectory.list().toList();
      for (final entity in entities) {
        if (entity is Directory &&
            entity.path.split('/').last.toLowerCase() ==
                directoryName.toLowerCase()) {
          return true;
        }
      }
    } catch (e) {
      log(e.toString());
    }
    return false;
  }

  Future<bool> createDirectory({
    required Directory targetDirectory,
    required String directoryName,
  }) async {
    Directory rootDirectory = await getApplicationDocumentsDirectory();
    final documentDirectory =
        Directory('${rootDirectory.path}/Doc Scanner/Document');
    final idCardDirectory =
        Directory('${rootDirectory.path}/Doc Scanner/ID Card');
    final qrCodeDirectory =
        Directory('${rootDirectory.path}/Doc Scanner/QR Code');
    final barCodeDirectory =
        Directory('${rootDirectory.path}/Doc Scanner/Bar Code');

    try {
      if (await _directoryExistsWithCaseInsensitive(
              documentDirectory, directoryName) ||
          await _directoryExistsWithCaseInsensitive(
              idCardDirectory, directoryName) ||
          await _directoryExistsWithCaseInsensitive(
              qrCodeDirectory, directoryName) ||
          await _directoryExistsWithCaseInsensitive(
              barCodeDirectory, directoryName)) {
        return false;
      } else {
        final newCreatedDirectory =
            Directory('${targetDirectory.path}/$directoryName');
        await newCreatedDirectory.create(recursive: true);
        return true;
      }
    } catch (e) {
      return false;
    }
  }

  void _showCenterDialog(BuildContext context) {
    _folderNameController.clear();
    showDialog(
      context: context,
      barrierDismissible:
          false, // Prevents dialog from closing by tapping outside
      builder: (BuildContext context) {
        return AlertDialog(
          alignment: Alignment.center,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Folder",
                      style: TextStyle(fontSize: 15),
                    ),
                    IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: Icon(
                          Icons.close,
                          size: AppHelper.isTablet(context) ? 15 : 12,
                        ))
                  ],
                ),
                TextField(
                  controller: _folderNameController,
                  decoration: const InputDecoration(
                    labelText: 'Enter Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    if (_folderNameController.text.trim().isNotEmpty) {
                      FocusScope.of(context).unfocus();
                      bool created = await createDirectory(
                          targetDirectory: Directory(widget.directoryPath),
                          directoryName: _folderNameController.text);
                      if (created && context.mounted) {
                        Navigator.pop(context);
                        await _refresh();
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            translation(context).pleaseEnterADirectoryName,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      );
                    }
                  },
                  child: const Text('Create Folder'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    allFiles = _loadFiles();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      rootDirectory = await getApplicationDocumentsDirectory();
    });
  }

  bool isSubfolderOfQRCode(String directoryPath) {
    List<String> parts = directoryPath.split('/');
    int qrCodeIndex = parts.indexOf("QR Code");
    int barCodeIndex = parts.indexOf("Bar Code");

    // If "QR Code" exists in the path and it's not the last part (indicating a subfolder), return true
    return qrCodeIndex != -1 && qrCodeIndex < parts.length - 1 ||
        barCodeIndex != -1 && barCodeIndex < parts.length - 1;
  }

  @override
  Widget build(BuildContext context) {
    final homePageProvider = context.watch<HomePageProvider>();
    final size = MediaQuery.sizeOf(context);
    return WillPopScope(
      onWillPop: () async {
        if (_isLongPressed) {
          _exitSelection();
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: AppColor.primaryColor,
        appBar: _buildHeader(),
        body: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          child: ColoredBox(
            color: const Color(0xFFF4F7FC),
            child: SafeArea(
              top: false,
              child: FutureBuilder<List<String>>(
                future: allFiles,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done ||
                      homePageProvider.isCreatingPDF ||
                      isDeleteLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                        child: Text(translation(context).somethingWentWrong));
                  }
                  final fileList = (snapshot.data ?? <String>[])
                      .where((file) => path
                          .basename(file)
                          .toLowerCase()
                          .contains(_query.trim().toLowerCase()))
                      .toList();
                  return Column(children: [
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _refresh,
                        child: fileList.isEmpty
                            ? LayoutBuilder(
                                builder: (context, constraints) => ListView(
                                      physics:
                                          const AlwaysScrollableScrollPhysics(),
                                      children: [
                                        SizedBox(
                                            height: constraints.maxHeight,
                                            child: Center(
                                              child: Text(_query.isEmpty
                                                  ? translation(context)
                                                      .noDataFound
                                                  : translation(context)
                                                      .noResultFound),
                                            ))
                                      ],
                                    ))
                            : ListView.builder(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 14, 16, 12),
                                physics: const AlwaysScrollableScrollPhysics(),
                                keyboardDismissBehavior:
                                    ScrollViewKeyboardDismissBehavior.onDrag,
                                itemCount: fileList.length,
                                itemBuilder: (context, index) {
                                  String filePath = fileList[index];
                                  subFilePath = filePath;
                                  final isSelected =
                                      _selectedItems.contains(filePath);
                                  if (_fileStats[filePath]?.type ==
                                      FileSystemEntityType.directory) {
                                    return _directoryTile(
                                      filePath,
                                      isSelected,
                                      onTap: () {
                                        if (_isLongPressed) {
                                          _toggleItemSelection(filePath);
                                          return;
                                        }
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) =>
                                                  DirectoryDetailsPage(
                                                      directoryPath: filePath)),
                                        ).then((_) {
                                          if (mounted) _refresh();
                                        });
                                      },
                                      onLongPress: () =>
                                          _enterSelectionMode(filePath),
                                      onMenu: () {
                                        _showFileActions(
                                          context: context,
                                          builder: (context) {
                                            return Container(
                                              width: MediaQuery.sizeOf(context)
                                                  .width,
                                              decoration: const BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.only(
                                                    topLeft:
                                                        Radius.circular(20),
                                                    topRight:
                                                        Radius.circular(20),
                                                  ),
                                                  color: Colors.white),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Padding(
                                                    padding: const EdgeInsets
                                                            .symmetric(
                                                            horizontal: 10)
                                                        .copyWith(
                                                            top: 20,
                                                            bottom: 10),
                                                    child: Row(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .center,
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceBetween,
                                                      children: [
                                                        const Text(''),
                                                        Text(
                                                          translation(context)
                                                              .documentFiles,
                                                          style:
                                                              const TextStyle(
                                                            color: Colors.black,
                                                            fontSize: 20,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                        Container(
                                                          height:
                                                              size.width >= 600
                                                                  ? 40
                                                                  : 30,
                                                          width:
                                                              size.width >= 600
                                                                  ? 40
                                                                  : 30,
                                                          alignment:
                                                              Alignment.center,
                                                          decoration:
                                                              const BoxDecoration(
                                                            color: Color(
                                                                0xFFF4F4F4),
                                                            shape:
                                                                BoxShape.circle,
                                                          ),
                                                          child: Material(
                                                            color: Colors
                                                                .transparent,
                                                            child: InkWell(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          30),
                                                              onTap: () {
                                                                Navigator.pop(
                                                                    context);
                                                              },
                                                              child: Icon(
                                                                Icons
                                                                    .close_rounded,
                                                                size:
                                                                    size.width >=
                                                                            600
                                                                        ? 30
                                                                        : 20,
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
                                                        TextEditingController
                                                            renameController =
                                                            TextEditingController(
                                                                text: filePath
                                                                    .split("/")
                                                                    .last);
                                                        final formKey =
                                                            GlobalKey<
                                                                FormState>();
                                                        Navigator.pop(context);
                                                        showDialog(
                                                          context: context,
                                                          builder: (context) {
                                                            String
                                                                errorMessage =
                                                                '';
                                                            return StatefulBuilder(
                                                                builder: (context,
                                                                    setState) {
                                                              return AlertDialog(
                                                                title: Text(
                                                                  translation(
                                                                          context)
                                                                      .renameFile,
                                                                  style:
                                                                      const TextStyle(
                                                                    color: Colors
                                                                        .black,
                                                                    fontSize:
                                                                        16,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500,
                                                                  ),
                                                                ),
                                                                content: Form(
                                                                  key: formKey,
                                                                  child:
                                                                      TextFormField(
                                                                    controller:
                                                                        renameController,
                                                                    keyboardType:
                                                                        TextInputType
                                                                            .text,
                                                                    textInputAction:
                                                                        TextInputAction
                                                                            .done,
                                                                    autofocus:
                                                                        true,
                                                                    validator:
                                                                        (value) {
                                                                      if (value!
                                                                          .isEmpty) {
                                                                        return translation(context)
                                                                            .pleaseEnterFileName;
                                                                      }
                                                                      return null;
                                                                    },
                                                                    decoration:
                                                                        InputDecoration(
                                                                      errorText: errorMessage
                                                                              .isEmpty
                                                                          ? null
                                                                          : errorMessage,
                                                                      hintText:
                                                                          translation(context)
                                                                              .enterFileName,
                                                                      border:
                                                                          const OutlineInputBorder(
                                                                        borderSide:
                                                                            BorderSide(color: AppColor.primaryColor),
                                                                      ),
                                                                      contentPadding: const EdgeInsets
                                                                          .symmetric(
                                                                          horizontal:
                                                                              10),
                                                                    ),
                                                                  ),
                                                                ),
                                                                actions: [
                                                                  TextButton(
                                                                      onPressed: () =>
                                                                          Navigator.pop(
                                                                              context),
                                                                      child: Text(
                                                                          translation(context)
                                                                              .cancel)),
                                                                  TextButton(
                                                                    onPressed:
                                                                        () async {
                                                                      if (formKey
                                                                          .currentState!
                                                                          .validate()) {
                                                                        String
                                                                            newName =
                                                                            renameController.text;
                                                                        String parentPath = Directory(filePath)
                                                                            .parent
                                                                            .path;
                                                                        String
                                                                            newPath =
                                                                            "$parentPath/$newName";
                                                                        String
                                                                            lowerCaseNewPath =
                                                                            "$parentPath/${newName.toLowerCase()}";
                                                                        String
                                                                            upperCaseNewPath =
                                                                            "$parentPath/${newName.toUpperCase()}";
                                                                        final Directory
                                                                            newDirectory =
                                                                            Directory(newPath);
                                                                        if (newDirectory.existsSync() ||
                                                                            Directory(lowerCaseNewPath).existsSync() ||
                                                                            Directory(upperCaseNewPath).existsSync()) {
                                                                          setState(
                                                                              () {
                                                                            errorMessage =
                                                                                translation(context).folderAlreadyExists;
                                                                          });
                                                                        } else {
                                                                          await Directory(filePath)
                                                                              .rename(newPath);
                                                                          Navigator.pop(
                                                                              context);
                                                                          allFiles =
                                                                              _loadFiles();
                                                                        }
                                                                      }
                                                                    },
                                                                    child: Text(
                                                                        translation(context)
                                                                            .save),
                                                                  ),
                                                                ],
                                                              );
                                                            });
                                                          },
                                                        );
                                                      },
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal:
                                                                    20.0,
                                                                vertical: 5),
                                                        child: Row(
                                                          children: [
                                                            SvgPicture.asset(
                                                              AppAssets.rename,
                                                              color:
                                                                  Colors.black,
                                                            ),
                                                            const SizedBox(
                                                              width: 20,
                                                            ),
                                                            const Text(
                                                              "Rename Folder",
                                                              style: TextStyle(
                                                                color: Colors
                                                                    .black,
                                                                fontSize: 16,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w400,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  _deleteMenuItem(
                                                      context, filePath),
                                                ],
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    );
                                  } else if (filePath
                                          .toLowerCase()
                                          .endsWith('.jpg') ||
                                      filePath
                                          .toLowerCase()
                                          .endsWith('.jpeg') ||
                                      filePath.toLowerCase().endsWith('.png')) {
                                    return _directoryTile(
                                      filePath,
                                      isSelected,
                                      onTap: () async {
                                        if (_isLongPressed) {
                                          _toggleItemSelection(filePath);
                                          return;
                                        }
                                        await flutterGenralDialogue(
                                          context: context,
                                          imageFile: File(filePath),
                                        );
                                      },
                                      onLongPress: () =>
                                          _enterSelectionMode(filePath),
                                      onMenu: () {
                                        _showFileActions(
                                          context: context,
                                          builder: (context) {
                                            return Container(
                                              width: MediaQuery.sizeOf(context)
                                                  .width,
                                              decoration: const BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.only(
                                                    topLeft:
                                                        Radius.circular(20),
                                                    topRight:
                                                        Radius.circular(20),
                                                  ),
                                                  color: Colors.white),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Padding(
                                                    padding: const EdgeInsets
                                                            .symmetric(
                                                            horizontal: 10)
                                                        .copyWith(
                                                            top: 20,
                                                            bottom: 10),
                                                    child: Row(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .center,
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceBetween,
                                                      children: [
                                                        const Text(''),
                                                        Text(
                                                          translation(context)
                                                              .documentFiles,
                                                          style:
                                                              const TextStyle(
                                                            color: Colors.black,
                                                            fontSize: 20,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                        Container(
                                                          height:
                                                              size.width >= 600
                                                                  ? 40
                                                                  : 30,
                                                          width:
                                                              size.width >= 600
                                                                  ? 40
                                                                  : 30,
                                                          alignment:
                                                              Alignment.center,
                                                          decoration:
                                                              const BoxDecoration(
                                                            color: Color(
                                                                0xFFF4F4F4),
                                                            shape:
                                                                BoxShape.circle,
                                                          ),
                                                          child: Material(
                                                            color: Colors
                                                                .transparent,
                                                            child: InkWell(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          30),
                                                              onTap: () {
                                                                Navigator.pop(
                                                                    context);
                                                              },
                                                              child: Icon(
                                                                Icons
                                                                    .close_rounded,
                                                                size:
                                                                    size.width >=
                                                                            600
                                                                        ? 30
                                                                        : 20,
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
                                                        TextEditingController
                                                            renameController =
                                                            TextEditingController(
                                                                text: path
                                                                    .basenameWithoutExtension(
                                                                        filePath));
                                                        final formKey =
                                                            GlobalKey<
                                                                FormState>();
                                                        Navigator.pop(context);
                                                        showDialog(
                                                          context: context,
                                                          builder: (context) {
                                                            String
                                                                errorMessage =
                                                                '';
                                                            return StatefulBuilder(
                                                                builder: (context,
                                                                    setState) {
                                                              return AlertDialog(
                                                                title: Text(
                                                                    translation(
                                                                            context)
                                                                        .renameFile,
                                                                    style:
                                                                        const TextStyle(
                                                                      color: Colors
                                                                          .black,
                                                                      fontSize:
                                                                          16,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w500,
                                                                    )),
                                                                content: Form(
                                                                  key: formKey,
                                                                  child:
                                                                      TextFormField(
                                                                    controller:
                                                                        renameController,
                                                                    keyboardType:
                                                                        TextInputType
                                                                            .text,
                                                                    textInputAction:
                                                                        TextInputAction
                                                                            .done,
                                                                    autofocus:
                                                                        true,
                                                                    validator:
                                                                        (value) {
                                                                      if (value!
                                                                          .isEmpty) {
                                                                        return translation(context)
                                                                            .pleaseEnterFileName;
                                                                      }
                                                                      return null;
                                                                    },
                                                                    decoration:
                                                                        InputDecoration(
                                                                      errorText: errorMessage
                                                                              .isEmpty
                                                                          ? null
                                                                          : errorMessage,
                                                                      hintText:
                                                                          translation(context)
                                                                              .enterFileName,
                                                                      border:
                                                                          const OutlineInputBorder(
                                                                        borderSide:
                                                                            BorderSide(color: AppColor.primaryColor),
                                                                      ),
                                                                      contentPadding: const EdgeInsets
                                                                          .symmetric(
                                                                          horizontal:
                                                                              10),
                                                                    ),
                                                                  ),
                                                                ),
                                                                actions: [
                                                                  TextButton(
                                                                      onPressed: () =>
                                                                          Navigator.pop(
                                                                              context),
                                                                      child: Text(
                                                                          translation(context)
                                                                              .cancel)),
                                                                  ////ID Card Image File Rename
                                                                  TextButton(
                                                                    onPressed:
                                                                        () async {
                                                                      if (formKey
                                                                          .currentState!
                                                                          .validate()) {
                                                                        String
                                                                            newName =
                                                                            renameController.text;
                                                                        String parentPath = Directory(filePath)
                                                                            .parent
                                                                            .path;
                                                                        String
                                                                            newPath =
                                                                            "$parentPath/$newName.jpg";
                                                                        if (File(newPath)
                                                                            .existsSync()) {
                                                                          setState(
                                                                              () {
                                                                            errorMessage =
                                                                                translation(context).fileAlreadyExists;
                                                                          });
                                                                        } else {
                                                                          File(filePath)
                                                                              .renameSync(newPath);
                                                                          Navigator.pop(
                                                                              context);
                                                                          allFiles =
                                                                              _loadFiles();
                                                                        }
                                                                      }
                                                                    },
                                                                    child: Text(
                                                                        translation(context)
                                                                            .save),
                                                                  ),

                                                                  // TextButton(
                                                                  //     onPressed: () async {
                                                                  //       if (_formKey.currentState!.validate()) {
                                                                  //         String newPath = filePath.replaceAll(path.basenameWithoutExtension(filePath), _renameController.text);
                                                                  //         File(filePath).renameSync(newPath);
                                                                  //         Navigator.pop(context);
                                                                  //         allFiles = _loadFiles();
                                                                  //       }
                                                                  //     },
                                                                  //     child: Text(translation(context).save)),
                                                                ],
                                                              );
                                                            });
                                                          },
                                                        );
                                                      },
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal:
                                                                    20.0,
                                                                vertical: 5),
                                                        child: Row(
                                                          children: [
                                                            SvgPicture.asset(
                                                              AppAssets.rename,
                                                              color:
                                                                  Colors.black,
                                                            ),
                                                            const SizedBox(
                                                              width: 20,
                                                            ),
                                                            Text(
                                                              translation(
                                                                      context)
                                                                  .renameFile,
                                                              style:
                                                                  const TextStyle(
                                                                color: Colors
                                                                    .black,
                                                                fontSize: 16,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w400,
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
                                                    indent: MediaQuery.sizeOf(
                                                                context)
                                                            .width *
                                                        0.15,
                                                  ),
                                                  Material(
                                                    color: Colors.transparent,
                                                    child: InkWell(
                                                      onTap: () async {
                                                        await Gal.putImage(
                                                            filePath,
                                                            album:
                                                                "Doc Scanner");
                                                        Navigator.pop(context);
                                                        AppHelper.showTopSnackBar(
                                                            context,
                                                            translation(context)
                                                                .saveAtGallery);
                                                      },
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal:
                                                                    20.0,
                                                                vertical: 5),
                                                        child: Row(
                                                          children: [
                                                            const Icon(
                                                              Icons
                                                                  .ios_share_outlined,
                                                              color:
                                                                  Colors.black,
                                                            ),
                                                            const SizedBox(
                                                              width: 20,
                                                            ),
                                                            Text(
                                                              translation(
                                                                      context)
                                                                  .saveAtGallery,
                                                              style:
                                                                  const TextStyle(
                                                                color: Colors
                                                                    .black,
                                                                fontSize: 16,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w400,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  _deleteMenuItem(
                                                      context, filePath),
                                                ],
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    );
                                  } else if (filePath
                                      .toLowerCase()
                                      .endsWith('.txt')) {
                                    return _directoryTile(
                                      filePath,
                                      isSelected,
                                      onTap: () async {
                                        if (_isLongPressed) {
                                          _toggleItemSelection(filePath);
                                          return;
                                        }
                                        var urlLink = await homePageProvider
                                            .readTxtFile(filePath);
                                        showQrAndBarCodeViewDialogue(
                                            context: context,
                                            text: await homePageProvider
                                                .readTxtFile(filePath),
                                            browserView: () {
                                              StringBuffer formattedContent =
                                                  StringBuffer();

                                              List<String> parts =
                                                  urlLink.toString().split(';');
                                              for (var part in parts
                                                  .where((p) => p.isNotEmpty)) {
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
                                                  formattedContent
                                                      .writeln("TYPE : $value");
                                                } else if (key == "P") {
                                                  formattedContent.writeln(
                                                      "PASSWORD : $value");
                                                } else {
                                                  formattedContent
                                                      .writeln("$key : $value");
                                                }
                                              }

                                              // Copy the formatted content to the clipboard
                                              urlLink
                                                          .toString()
                                                          .startsWith("WIFI") ||
                                                      urlLink
                                                          .toString()
                                                          .startsWith("Wifi") ||
                                                      urlLink
                                                          .toString()
                                                          .startsWith("wifi")
                                                  ? _openBrowserWithSearch(
                                                      formattedContent
                                                          .toString())
                                                  : _openBrowserWithSearch(
                                                      urlLink);
                                            });
                                      },
                                      onLongPress: () =>
                                          _enterSelectionMode(filePath),
                                      onMenu: () {
                                        _showFileActions(
                                          context: context,
                                          builder: (context) {
                                            return Container(
                                              width: MediaQuery.sizeOf(context)
                                                  .width,
                                              decoration: const BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.only(
                                                    topLeft:
                                                        Radius.circular(20),
                                                    topRight:
                                                        Radius.circular(20),
                                                  ),
                                                  color: Colors.white),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Padding(
                                                    padding: const EdgeInsets
                                                            .symmetric(
                                                            horizontal: 10)
                                                        .copyWith(
                                                            top: 20,
                                                            bottom: 10),
                                                    child: Row(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .center,
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceBetween,
                                                      children: [
                                                        const Text(''),
                                                        Text(
                                                          translation(context)
                                                              .documentFiles,
                                                          style:
                                                              const TextStyle(
                                                            color: Colors.black,
                                                            fontSize: 20,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                        Container(
                                                          height:
                                                              size.width >= 600
                                                                  ? 40
                                                                  : 30,
                                                          width:
                                                              size.width >= 600
                                                                  ? 40
                                                                  : 30,
                                                          alignment:
                                                              Alignment.center,
                                                          decoration:
                                                              const BoxDecoration(
                                                            color: Color(
                                                                0xFFF4F4F4),
                                                            shape:
                                                                BoxShape.circle,
                                                          ),
                                                          child: Material(
                                                            color: Colors
                                                                .transparent,
                                                            child: InkWell(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          30),
                                                              onTap: () {
                                                                Navigator.pop(
                                                                    context);
                                                              },
                                                              child: Icon(
                                                                Icons
                                                                    .close_rounded,
                                                                size:
                                                                    size.width >=
                                                                            600
                                                                        ? 30
                                                                        : 20,
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
                                                        TextEditingController
                                                            renameController =
                                                            TextEditingController(
                                                                text: path
                                                                    .basenameWithoutExtension(
                                                                        filePath));
                                                        final formKey =
                                                            GlobalKey<
                                                                FormState>();
                                                        Navigator.pop(context);
                                                        showDialog(
                                                          context: context,
                                                          builder: (context) {
                                                            String
                                                                errorMessage =
                                                                '';
                                                            return StatefulBuilder(
                                                                builder: (context,
                                                                    setState) {
                                                              return AlertDialog(
                                                                title: Text(
                                                                    translation(
                                                                            context)
                                                                        .renameFile,
                                                                    style:
                                                                        const TextStyle(
                                                                      color: Colors
                                                                          .black,
                                                                      fontSize:
                                                                          16,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w500,
                                                                    )),
                                                                content: Form(
                                                                  key: formKey,
                                                                  child:
                                                                      TextFormField(
                                                                    controller:
                                                                        renameController,
                                                                    keyboardType:
                                                                        TextInputType
                                                                            .text,
                                                                    textInputAction:
                                                                        TextInputAction
                                                                            .done,
                                                                    autofocus:
                                                                        true,
                                                                    validator:
                                                                        (value) {
                                                                      if (value!
                                                                          .isEmpty) {
                                                                        return translation(context)
                                                                            .pleaseEnterFileName;
                                                                      }
                                                                      return null;
                                                                    },
                                                                    decoration:
                                                                        InputDecoration(
                                                                      errorText: errorMessage
                                                                              .isEmpty
                                                                          ? null
                                                                          : errorMessage,
                                                                      hintText:
                                                                          translation(context)
                                                                              .enterFileName,
                                                                      border:
                                                                          const OutlineInputBorder(
                                                                        borderSide:
                                                                            BorderSide(color: AppColor.primaryColor),
                                                                      ),
                                                                      contentPadding: const EdgeInsets
                                                                          .symmetric(
                                                                          horizontal:
                                                                              10),
                                                                    ),
                                                                  ),
                                                                ),
                                                                actions: [
                                                                  TextButton(
                                                                      onPressed: () =>
                                                                          Navigator.pop(
                                                                              context),
                                                                      child: Text(
                                                                          translation(context)
                                                                              .cancel)),
                                                                  TextButton(
                                                                    onPressed:
                                                                        () async {
                                                                      if (formKey
                                                                          .currentState!
                                                                          .validate()) {
                                                                        // String newPath = filePath.replaceAll(path.basenameWithoutExtension(filePath), _renameController.text);
                                                                        String
                                                                            newName =
                                                                            renameController.text;
                                                                        String parentPath = Directory(filePath)
                                                                            .parent
                                                                            .path;
                                                                        String
                                                                            newPath =
                                                                            "$parentPath/$newName.txt";

                                                                        if (File(newPath)
                                                                            .existsSync()) {
                                                                          setState(
                                                                              () {
                                                                            errorMessage =
                                                                                translation(context).fileAlreadyExists;
                                                                          });
                                                                        } else {
                                                                          File(filePath)
                                                                              .renameSync(newPath);
                                                                          Navigator.pop(
                                                                              context);
                                                                          allFiles =
                                                                              _loadFiles();
                                                                        }
                                                                      }
                                                                    },
                                                                    child: Text(
                                                                        translation(context)
                                                                            .save),
                                                                  ),
                                                                ],
                                                              );
                                                            });
                                                          },
                                                        );
                                                      },
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal:
                                                                    20.0,
                                                                vertical: 5),
                                                        child: Row(
                                                          children: [
                                                            SvgPicture.asset(
                                                              AppAssets.rename,
                                                              color:
                                                                  Colors.black,
                                                            ),
                                                            const SizedBox(
                                                              width: 20,
                                                            ),
                                                            Text(
                                                              translation(
                                                                      context)
                                                                  .renameFile,
                                                              style:
                                                                  const TextStyle(
                                                                color: Colors
                                                                    .black,
                                                                fontSize: 16,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w400,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  _deleteMenuItem(
                                                      context, filePath),
                                                ],
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    );
                                  } else if (filePath
                                      .toLowerCase()
                                      .endsWith('.pdf')) {
                                    return _directoryTile(
                                      filePath,
                                      isSelected,
                                      onTap: () async {
                                        if (_isLongPressed) {
                                          _toggleItemSelection(filePath);
                                          return;
                                        }
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => PdfViewScreen(
                                              filePath: filePath,
                                              fileName:
                                                  filePath.split('/').last,
                                            ),
                                          ),
                                        );
                                      },
                                      onLongPress: () =>
                                          _enterSelectionMode(filePath),
                                      onMenu: () {
                                        _showFileActions(
                                          context: context,
                                          builder: (context) {
                                            return Container(
                                              width: MediaQuery.sizeOf(context)
                                                  .width,
                                              decoration: const BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.only(
                                                    topLeft:
                                                        Radius.circular(20),
                                                    topRight:
                                                        Radius.circular(20),
                                                  ),
                                                  color: Colors.white),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Padding(
                                                    padding: const EdgeInsets
                                                            .symmetric(
                                                            horizontal: 10)
                                                        .copyWith(
                                                            top: 20,
                                                            bottom: 10),
                                                    child: Row(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .center,
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceBetween,
                                                      children: [
                                                        const Text(''),
                                                        Text(
                                                          translation(context)
                                                              .documentFiles,
                                                          style:
                                                              const TextStyle(
                                                            color: Colors.black,
                                                            fontSize: 20,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                        Container(
                                                          height:
                                                              size.width >= 600
                                                                  ? 40
                                                                  : 30,
                                                          width:
                                                              size.width >= 600
                                                                  ? 40
                                                                  : 30,
                                                          alignment:
                                                              Alignment.center,
                                                          decoration:
                                                              const BoxDecoration(
                                                            color: Color(
                                                                0xFFF4F4F4),
                                                            shape:
                                                                BoxShape.circle,
                                                          ),
                                                          child: Material(
                                                            color: Colors
                                                                .transparent,
                                                            child: InkWell(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          30),
                                                              onTap: () {
                                                                Navigator.pop(
                                                                    context);
                                                              },
                                                              child: Icon(
                                                                Icons
                                                                    .close_rounded,
                                                                size:
                                                                    size.width >=
                                                                            600
                                                                        ? 30
                                                                        : 20,
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
                                                        TextEditingController
                                                            renameController =
                                                            TextEditingController(
                                                                text: path
                                                                    .basenameWithoutExtension(
                                                                        filePath));
                                                        final formKey =
                                                            GlobalKey<
                                                                FormState>();
                                                        Navigator.pop(context);
                                                        showDialog(
                                                          context: context,
                                                          builder: (context) {
                                                            String
                                                                errorMessage =
                                                                '';
                                                            return StatefulBuilder(
                                                                builder: (context,
                                                                    setState) {
                                                              return AlertDialog(
                                                                title: Text(
                                                                  translation(
                                                                          context)
                                                                      .renameFile,
                                                                  style:
                                                                      const TextStyle(
                                                                    color: Colors
                                                                        .black,
                                                                    fontSize:
                                                                        16,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500,
                                                                  ),
                                                                ),
                                                                content: Form(
                                                                  key: formKey,
                                                                  child:
                                                                      TextFormField(
                                                                    controller:
                                                                        renameController,
                                                                    keyboardType:
                                                                        TextInputType
                                                                            .text,
                                                                    textInputAction:
                                                                        TextInputAction
                                                                            .done,
                                                                    autofocus:
                                                                        true,
                                                                    validator:
                                                                        (value) {
                                                                      if (value!
                                                                          .isEmpty) {
                                                                        return translation(context)
                                                                            .pleaseEnterFileName;
                                                                      }
                                                                      return null;
                                                                    },
                                                                    decoration:
                                                                        InputDecoration(
                                                                      hintText:
                                                                          translation(context)
                                                                              .enterFileName,
                                                                      errorText: errorMessage
                                                                              .isEmpty
                                                                          ? null
                                                                          : errorMessage,
                                                                      border:
                                                                          const OutlineInputBorder(
                                                                        borderSide:
                                                                            BorderSide(color: AppColor.primaryColor),
                                                                      ),
                                                                      contentPadding: const EdgeInsets
                                                                          .symmetric(
                                                                          horizontal:
                                                                              10),
                                                                    ),
                                                                  ),
                                                                ),
                                                                actions: [
                                                                  TextButton(
                                                                    onPressed: () =>
                                                                        Navigator.pop(
                                                                            context),
                                                                    child: Text(
                                                                        translation(context)
                                                                            .cancel),
                                                                  ),
                                                                  TextButton(
                                                                      onPressed:
                                                                          () async {
                                                                        if (formKey
                                                                            .currentState!
                                                                            .validate()) {
                                                                          //  String newPath = filePath.replaceAll(path.basenameWithoutExtension(filePath), _renameController.text);

                                                                          String
                                                                              newName =
                                                                              renameController.text;
                                                                          String
                                                                              parentPath =
                                                                              Directory(filePath).parent.path;
                                                                          String
                                                                              newPath =
                                                                              "$parentPath/$newName.pdf";

                                                                          if (File(newPath)
                                                                              .existsSync()) {
                                                                            setState(() {
                                                                              errorMessage = translation(context).fileAlreadyExists;
                                                                            });
                                                                          } else {
                                                                            File(filePath).renameSync(newPath);
                                                                            Navigator.pop(context);
                                                                            allFiles =
                                                                                _loadFiles();
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
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal:
                                                                    20.0,
                                                                vertical: 5),
                                                        child: Row(
                                                          children: [
                                                            SvgPicture.asset(
                                                              AppAssets.rename,
                                                              color:
                                                                  Colors.black,
                                                            ),
                                                            const SizedBox(
                                                              width: 20,
                                                            ),
                                                            Text(
                                                              translation(
                                                                      context)
                                                                  .renameFile,
                                                              style:
                                                                  const TextStyle(
                                                                color: Colors
                                                                    .black,
                                                                fontSize: 16,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w400,
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
                                                    indent: MediaQuery.sizeOf(
                                                                context)
                                                            .width *
                                                        0.15,
                                                  ),
                                                  Material(
                                                    color: Colors.transparent,
                                                    child: InkWell(
                                                      onTap: () async {
                                                        Navigator.pop(context);
                                                        try {
                                                          await DownloadHelper
                                                              .saveFileToDownloads(
                                                                  filePath);
                                                          AppHelper
                                                              .showTopSnackBar(
                                                            context,
                                                            translation(context)
                                                                .fileSavedDownloadFolder,
                                                          );
                                                        } catch (e) {
                                                          AppHelper
                                                              .showTopSnackBar(
                                                            context,
                                                            "Failed to download file: $e",
                                                          );
                                                        }
                                                      },
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal:
                                                                    20.0,
                                                                vertical: 5),
                                                        child: Row(
                                                          children: [
                                                            const Icon(
                                                              Icons
                                                                  .ios_share_outlined,
                                                              color:
                                                                  Colors.black,
                                                            ),
                                                            const SizedBox(
                                                              width: 20,
                                                            ),
                                                            Text(
                                                              translation(
                                                                      context)
                                                                  .downloadFile,
                                                              style:
                                                                  const TextStyle(
                                                                color: Colors
                                                                    .black,
                                                                fontSize: 16,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w400,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  _deleteMenuItem(
                                                      context, filePath),
                                                ],
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    );
                                  } else {
                                    return Text(
                                      translation(context).somethingWentWrong,
                                    );
                                  }
                                },
                              ),
                      ),
                    ),
                    Column(
                      children: [
                        if (_isLongPressed)
                          Container(
                            height: size.width >= 600 ? 100 : 70,
                            color: Colors.white,
                            padding: EdgeInsets.symmetric(
                                horizontal:
                                    AppHelper.isTablet(context) ? 40 : 24.0),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                GestureDetector(
                                  onTap: () async {
                                    if (_selectedItems.every((element) =>
                                            element
                                                .toLowerCase()
                                                .endsWith('.jpg') ||
                                            element
                                                .toLowerCase()
                                                .endsWith('.txt') ||
                                            element
                                                .toLowerCase()
                                                .endsWith('.pdf') ||
                                            element
                                                .toLowerCase()
                                                .endsWith('.jpeg') ||
                                            element
                                                .toLowerCase()
                                                .endsWith('.png')) &&
                                        _selectedItems.isNotEmpty) {
                                      await showModalBottomSheet(
                                        context: context,
                                        builder: (context) {
                                          List<String> directories =
                                              getSubdirectoriesSyncForIos(
                                                  widget.directoryPath);
                                          directories
                                              .remove(widget.directoryPath);
                                          log(directories.toString());

                                          return SizedBox(
                                            height: MediaQuery.of(context)
                                                    .size
                                                    .height *
                                                0.5,
                                            child: directories.isNotEmpty
                                                ? Padding(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 20.0,
                                                        vertical: 10),
                                                    child: ListView(
                                                      scrollDirection:
                                                          Axis.vertical,
                                                      children: List.generate(
                                                          directories.length,
                                                          (index) {
                                                        return ListTile(
                                                          leading: const Icon(
                                                            Icons.folder,
                                                            color: AppColor
                                                                .primaryColor,
                                                            size: 40,
                                                          ),
                                                          title: Text(
                                                              directories[index]
                                                                  .split('/')
                                                                  .last),
                                                          onTap: () async {
                                                            var conflictResult =
                                                                homePageProvider
                                                                    .checkIfFilesExistInDirectory(
                                                              targetDirectoryPath:
                                                                  directories[
                                                                      index],
                                                              filePaths:
                                                                  _selectedItems
                                                                      .toList(),
                                                            );

                                                            if (conflictResult) {
                                                              showDialog(
                                                                context:
                                                                    context,
                                                                builder:
                                                                    (context) {
                                                                  return AlertDialog(
                                                                    title: Text(
                                                                        translation(context)
                                                                            .conflictAlert),
                                                                    content: Text(
                                                                        translation(context)
                                                                            .fileConflictAlertContent),
                                                                    actions: [
                                                                      TextButton(
                                                                        onPressed:
                                                                            () {
                                                                          Navigator.pop(
                                                                              context);
                                                                        },
                                                                        child: Text(
                                                                            translation(context).cancel),
                                                                      ),
                                                                      TextButton(
                                                                        onPressed:
                                                                            () {
                                                                          homePageProvider
                                                                              .moveFilesToDirectory(
                                                                            targetDirectoryPath:
                                                                                directories[index],
                                                                            filePaths:
                                                                                _selectedItems.toList(),
                                                                          );
                                                                          setState(
                                                                              () {
                                                                            _selectedItems.clear();
                                                                            _isLongPressed =
                                                                                false;
                                                                          });
                                                                          Navigator.pop(
                                                                              context);
                                                                          Navigator.pop(
                                                                              context);
                                                                          allFiles =
                                                                              _loadFiles();
                                                                        },
                                                                        child: Text(
                                                                            translation(context).duplicate),
                                                                      ),
                                                                    ],
                                                                  );
                                                                },
                                                              );
                                                            } else {
                                                              homePageProvider
                                                                  .moveFilesToDirectory(
                                                                targetDirectoryPath:
                                                                    directories[
                                                                        index],
                                                                filePaths:
                                                                    _selectedItems
                                                                        .toList(),
                                                              );
                                                              setState(() {
                                                                _selectedItems
                                                                    .clear();
                                                                _isLongPressed =
                                                                    false;
                                                              });
                                                              Navigator.pop(
                                                                  context);
                                                              allFiles =
                                                                  _loadFiles();
                                                            }

                                                            // homePageProvider.moveFilesToDirectory(
                                                            //   targetDirectoryPath: directories[index],
                                                            //   filePaths: _selectedItems.toList(),
                                                            //   context: context,
                                                            // );
                                                            // setState(() {
                                                            //   _selectedItems.clear();
                                                            //   _isLongPressed = false;
                                                            // });
                                                            // Navigator.pop(context);
                                                            // allFiles = _loadFiles();
                                                          },
                                                        );
                                                      }),
                                                    ),
                                                  )
                                                : Center(
                                                    child: Text(
                                                      translation(context)
                                                          .noDirectoryFound,
                                                    ),
                                                  ),
                                          );
                                        },
                                      );
                                    } else if (_selectedItems.isEmpty) {
                                      ScaffoldMessenger.of(context)
                                          .clearSnackBars();
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            translation(context)
                                                .pleaseSelectFirst,
                                            style: const TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                          duration: const Duration(seconds: 1),
                                        ),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(context)
                                          .clearSnackBars();
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            translation(context)
                                                .pleaseSelectFileOnly,
                                            style: const TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                          duration: const Duration(seconds: 1),
                                        ),
                                      );
                                    }
                                  },
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      SvgPicture.asset(
                                        AppAssets.move,
                                        height: AppHelper.isTablet(context)
                                            ? 24
                                            : 20,
                                        width: AppHelper.isTablet(context)
                                            ? 24
                                            : 20,
                                        fit: BoxFit.fill,
                                        color: _selectedItems.isNotEmpty
                                            ? AppColor.primaryColor
                                            : Colors.black,
                                      ),
                                      Text(
                                        translation(context).move,
                                        style: TextStyle(
                                            color: _selectedItems.isNotEmpty
                                                ? AppColor.primaryColor
                                                : Colors.black,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () async {
                                    if (_selectedItems.isNotEmpty) {
                                      if (_selectedItems.every((element) =>
                                          element
                                              .toLowerCase()
                                              .endsWith('.jpg') ||
                                          element
                                              .toLowerCase()
                                              .endsWith('.pdf') ||
                                          element
                                              .toLowerCase()
                                              .endsWith('.jpeg') ||
                                          element
                                              .toLowerCase()
                                              .endsWith('.png'))) {
                                        if (isShareIng) {
                                          return;
                                        } else {
                                          isShareIng = true;
                                          await Share.shareXFiles(_selectedItems
                                                  .map((e) => XFile(e))
                                                  .toList())
                                              .then((value) {
                                            isShareIng = false;
                                            setState(() {
                                              _selectedItems.clear();
                                              _isLongPressed = false;
                                            });
                                          });
                                        }
                                      } else if (_selectedItems.every(
                                              (element) => element
                                                  .toLowerCase()
                                                  .endsWith('.txt')) &&
                                          _selectedItems.length == 1) {
                                        String text =
                                            await File(_selectedItems.first)
                                                .readAsString();
                                        if (isShareIng) {
                                          return;
                                        } else {
                                          isShareIng = true;
                                          await Share.share(text).then((value) {
                                            isShareIng = false;
                                          });
                                        }
                                      } else if (_selectedItems.every(
                                              (element) => element
                                                  .toLowerCase()
                                                  .endsWith('.txt')) &&
                                          _selectedItems.length > 1) {
                                        ScaffoldMessenger.of(context)
                                            .clearSnackBars();
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            duration: Duration(seconds: 1),
                                            content: Text(
                                              "Please select one text file only",
                                              style: TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        );
                                      } else {
                                        ScaffoldMessenger.of(context)
                                            .clearSnackBars();
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            duration:
                                                const Duration(seconds: 1),
                                            content: Text(
                                              translation(context)
                                                  .pleaseSelectFileOnly,
                                              style: const TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        );
                                      }
                                    } else {
                                      ScaffoldMessenger.of(context)
                                          .clearSnackBars();
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          duration: const Duration(seconds: 1),
                                          content: Text(
                                            translation(context)
                                                .pleaseSelectFirst,
                                            style: const TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      SvgPicture.asset(
                                        AppAssets.share,
                                        height: AppHelper.isTablet(context)
                                            ? 24
                                            : 20,
                                        width: AppHelper.isTablet(context)
                                            ? 24
                                            : 20,
                                        fit: BoxFit.fill,
                                        color: _selectedItems.isNotEmpty
                                            ? AppColor.primaryColor
                                            : Colors.black,
                                      ),
                                      Text(
                                        translation(context).share,
                                        style: TextStyle(
                                            color: _selectedItems.isNotEmpty
                                                ? AppColor.primaryColor
                                                : Colors.black,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ),
                                widget.directoryPath.endsWith("QR Code") ||
                                        widget.directoryPath
                                            .endsWith("Bar Code") ||
                                        isSubfolderOfQRCode(
                                            widget.directoryPath)
                                    ? GestureDetector(
                                        onTap: () async {
                                          if (_selectedItems.isNotEmpty) {
                                            if (_selectedItems.length == 1 &&
                                                _selectedItems.first
                                                    .toLowerCase()
                                                    .endsWith('.txt')) {
                                              String text = await File(
                                                      _selectedItems.first)
                                                  .readAsString();
                                              Clipboard.setData(
                                                      ClipboardData(text: text))
                                                  .then((value) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                    duration: const Duration(
                                                        seconds: 1),
                                                    content: Text(
                                                      translation(context)
                                                          .textCopied,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              });
                                            } else {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  duration: const Duration(
                                                      seconds: 1),
                                                  content: Text(
                                                    translation(context)
                                                        .pleaseSelectOneTextOnly,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }
                                          } else {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                duration:
                                                    const Duration(seconds: 1),
                                                content: Text(
                                                  translation(context)
                                                      .pleaseSelectFirst,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.copy,
                                              size: 20,
                                              color: _selectedItems.length == 1
                                                  ? AppColor.primaryColor
                                                  : Colors.black,
                                            ),
                                            Text(
                                              translation(context).copy,
                                              style: TextStyle(
                                                  color:
                                                      _selectedItems.length == 1
                                                          ? AppColor
                                                              .primaryColor
                                                          : Colors.black,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500),
                                            ),
                                          ],
                                        ),
                                      )
                                    : GestureDetector(
                                        onTap: () async {
                                          if (_selectedItems.isNotEmpty) {
                                            if (_selectedItems.length >= 2) {
                                              if (_selectedItems.every(
                                                  (element) =>
                                                      element
                                                          .toLowerCase()
                                                          .endsWith('.jpg') ||
                                                      element
                                                          .toLowerCase()
                                                          .endsWith('.jpeg') ||
                                                      element
                                                          .toLowerCase()
                                                          .endsWith('.png'))) {
                                                await showDialog(
                                                  context: context,
                                                  builder: (context) {
                                                    TextEditingController
                                                        renameController =
                                                        TextEditingController();
                                                    return AlertDialog(
                                                      title: SizedBox(
                                                        width:
                                                            AppHelper.isTablet(
                                                                    context)
                                                                ? 300
                                                                : 250,
                                                        child:
                                                            const Text("PDF"),
                                                      ),
                                                      content: TextFormField(
                                                        controller:
                                                            renameController,
                                                        keyboardType:
                                                            TextInputType.text,
                                                        textInputAction:
                                                            TextInputAction
                                                                .done,
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
                                                          hintText: translation(
                                                                  context)
                                                              .enterFileName,
                                                          focusedBorder:
                                                              const OutlineInputBorder(
                                                            borderSide: BorderSide(
                                                                color: AppColor
                                                                    .primaryColor),
                                                          ),
                                                          contentPadding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal:
                                                                      10),
                                                        ),
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () {
                                                            Navigator.pop(
                                                                context);
                                                          },
                                                          child: Text(
                                                              translation(
                                                                      context)
                                                                  .cancel),
                                                        ),
                                                        TextButton(
                                                          onPressed: () async {
                                                            if (renameController
                                                                .text
                                                                .isNotEmpty) {
                                                              AppHelper
                                                                  .showTopSnackBar(
                                                                      context,
                                                                      "PDF save successfully in Document Folder");

                                                              Navigator.pop(
                                                                  context); // Close the current dialog
                                                              // Set target path
                                                              String fileName =
                                                                  renameController
                                                                      .text;

                                                              await homePageProvider
                                                                  .createPDFFromImages(
                                                                images: _selectedItems
                                                                    .map((e) =>
                                                                        File(e))
                                                                    .toList(),
                                                                directoryPath:
                                                                    widget
                                                                        .directoryPath,
                                                                context:
                                                                    context,
                                                                fileName:
                                                                    fileName,
                                                              )
                                                                  .then(
                                                                      (value) async {
                                                                if (value !=
                                                                    null) {
                                                                  // Save the PDF in the target folder

                                                                  // Update the UI or perform any additional actions
                                                                  allFiles =
                                                                      _loadFiles();

                                                                  if (widget
                                                                          .directoryPath
                                                                          .split(
                                                                              "/")
                                                                          .last ==
                                                                      "ID Card") {
                                                                    homePageProvider
                                                                        .addIdCardImage(
                                                                            value);
                                                                  } else if (widget
                                                                          .directoryPath
                                                                          .split(
                                                                              "/")
                                                                          .last ==
                                                                      "Document") {
                                                                    homePageProvider
                                                                        .addDocumentImage(
                                                                            value);
                                                                  }
                                                                  // Clear selections and update state
                                                                  setState(() {
                                                                    _selectedItems
                                                                        .clear();
                                                                    _isLongPressed =
                                                                        false;
                                                                  });

                                                                  // Show success popup
                                                                }
                                                              });
                                                            } else {
                                                              ScaffoldMessenger
                                                                      .of(context)
                                                                  .clearSnackBars();
                                                              ScaffoldMessenger
                                                                      .of(context)
                                                                  .showSnackBar(
                                                                SnackBar(
                                                                  duration:
                                                                      const Duration(
                                                                          seconds:
                                                                              1),
                                                                  content: Text(
                                                                    translation(
                                                                            context)
                                                                        .pleaseEnterFileName,
                                                                    style: const TextStyle(
                                                                        color: Colors
                                                                            .white),
                                                                  ),
                                                                ),
                                                              );
                                                            }
                                                          },
                                                          child: Text(
                                                              translation(
                                                                      context)
                                                                  .ok),
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                );
                                              } else {
                                                ScaffoldMessenger.of(context)
                                                    .clearSnackBars();
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                    duration: const Duration(
                                                        seconds: 1),
                                                    content: Text(
                                                      translation(context)
                                                          .pleaseSelectImagesOnly,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }
                                            }
                                          } else {
                                            ScaffoldMessenger.of(context)
                                                .clearSnackBars();
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                duration:
                                                    const Duration(seconds: 1),
                                                content: Text(
                                                  translation(context)
                                                      .pleaseSelectFirst,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            SvgPicture.asset(
                                              AppAssets.merge,
                                              height:
                                                  AppHelper.isTablet(context)
                                                      ? 24
                                                      : 20,
                                              width: AppHelper.isTablet(context)
                                                  ? 24
                                                  : 20,
                                              fit: BoxFit.fill,
                                              color: _selectedItems.length >= 2
                                                  ? AppColor.primaryColor
                                                  : Colors.black,
                                            ),
                                            Text(
                                              translation(context).merge,
                                              style: TextStyle(
                                                  color:
                                                      _selectedItems.length >= 2
                                                          ? AppColor
                                                              .primaryColor
                                                          : Colors.black,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500),
                                            ),
                                          ],
                                        ),
                                      ),
                                GestureDetector(
                                  onTap: () async {
                                    if (_selectedItems.isNotEmpty) {
                                      showNormalAlertDialogue(
                                        context: context,
                                        title: translation(context).alert,
                                        content: translation(context)
                                            .areYouSureYouWantToDeleteTheSelectedItems,
                                        onOkText: translation(context).ok,
                                        onCancelText:
                                            translation(context).cancel,
                                        onOk: () async {
                                          Navigator.pop(context);
                                          setState(() {
                                            isDeleteLoading = true;
                                          });
                                          for (int i = 0;
                                              i < _selectedItems.length;
                                              i++) {
                                            var item =
                                                _selectedItems.elementAt(i);
                                            var fileSystemEntity =
                                                FileSystemEntity.typeSync(item);
                                            if (fileSystemEntity ==
                                                FileSystemEntityType.file) {
                                              try {
                                                File file = File(item);
                                                if (item
                                                    .split("/")
                                                    .contains("Document")) {
                                                  homePageProvider
                                                      .removeDocumentImage(
                                                          item);
                                                } else if (item
                                                    .split("/")
                                                    .contains("ID Card")) {
                                                  homePageProvider
                                                      .removeIdCardImage(item);
                                                } else if (item
                                                    .split("/")
                                                    .contains("QR Code")) {
                                                  homePageProvider
                                                      .removeQrCode(item);
                                                } else {
                                                  homePageProvider
                                                      .removeBarCode(item);
                                                }
                                                file.deleteSync();
                                              } catch (e) {}
                                            } else if (fileSystemEntity ==
                                                FileSystemEntityType
                                                    .directory) {
                                              Directory directory =
                                                  Directory(item);
                                              List<FileSystemEntity> entities =
                                                  directory.listSync();
                                              if (entities.isEmpty) {
                                                directory.deleteSync(
                                                    recursive: true);
                                              } else {
                                                for (var entity in entities) {
                                                  if (entity.path
                                                      .split("/")
                                                      .contains("Document")) {
                                                    homePageProvider
                                                        .removeDocumentImage(
                                                            entity.path);
                                                  } else if (entity.path
                                                      .split("/")
                                                      .contains("ID Card")) {
                                                    homePageProvider
                                                        .removeIdCardImage(
                                                            entity.path);
                                                  } else if (entity.path
                                                      .split("/")
                                                      .contains("QR Code")) {
                                                    homePageProvider
                                                        .removeQrCode(
                                                            entity.path);
                                                  } else {
                                                    homePageProvider
                                                        .removeBarCode(
                                                            entity.path);
                                                  }
                                                }
                                                directory.deleteSync(
                                                    recursive: true);
                                              }
                                            }
                                          }
                                          allFiles = _loadFiles();

                                          setState(() {
                                            _selectedItems.clear();
                                            _isLongPressed = false;
                                            isDeleteLoading = false;
                                          });
                                        },
                                        onCancel: () {
                                          Navigator.pop(context);
                                        },
                                      );
                                    } else {
                                      ScaffoldMessenger.of(context)
                                          .clearSnackBars();
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          duration: const Duration(seconds: 1),
                                          content: Text(
                                            translation(context)
                                                .pleaseSelectFirst,
                                            style: const TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      SvgPicture.asset(
                                        AppAssets.delete,
                                        width: AppHelper.isTablet(context)
                                            ? 29
                                            : 20,
                                        height: AppHelper.isTablet(context)
                                            ? 29
                                            : 20,
                                        color: _selectedItems.isNotEmpty
                                            ? AppColor.primaryColor
                                            : Colors.black,
                                      ),
                                      Text(
                                        translation(context).delete,
                                        style: TextStyle(
                                            color: _selectedItems.isNotEmpty
                                                ? AppColor.primaryColor
                                                : Colors.black,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        BannerAdWidget(
                          adUnitId: AdHelper.directoryViewBannerAdUnitId,
                        ),
                      ],
                    ),
                  ]);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<String> getSubdirectoriesSyncForIos(String directoryPath) {
    Directory directory;
    if (directoryPath.contains("Doc Scanner/Document")) {
      directory = Directory("${rootDirectory.path}/Doc Scanner/Document");
    } else if (directoryPath.contains("Doc Scanner/ID Card")) {
      directory = Directory("${rootDirectory.path}/Doc Scanner/ID Card");
    } else if (directoryPath.contains("Doc Scanner/QR Code")) {
      directory = Directory("${rootDirectory.path}/Doc Scanner/QR Code");
    } else {
      directory = Directory("${rootDirectory.path}/Doc Scanner/Bar Code");
    }
    if (directory.existsSync()) {
      try {
        final subdirectories = [directory.path];
        final entities = directory.listSync();
        subdirectories.addAll(
          entities.whereType<Directory>().map((dir) => dir.path).toList(),
        );
        return subdirectories;
      } catch (e) {
        throw Exception("An error occurred while listing subdirectories: $e");
      }
    } else {
      throw Exception("Directory does not exist");
    }
  }
}
