// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:developer';
import 'dart:io';
import 'package:doc_scanner/bottom_bar/bottom_bar.dart';
import 'package:doc_scanner/home_page/provider/home_page_provider.dart';
import 'package:doc_scanner/localaization/language_constant.dart';
import 'package:doc_scanner/utils/addHelper.dart';
import 'package:doc_scanner/utils/app_assets.dart';
import 'package:doc_scanner/utils/app_color.dart';
import 'package:doc_scanner/utils/banner_ad_widget.dart';
import 'package:doc_scanner/utils/download_helper.dart';
import 'package:doc_scanner/utils/helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_svg/svg.dart';
import 'package:gal/gal.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/utils.dart';
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

  void _enterSelectionWithItem(String filePath) {
    setState(() {
      _isLongPressed = true;
      _selectedItems.add(filePath);
    });
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
  bool _directoryAlreadyExists = false;
  void _showCenterDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevents dialog from closing by tapping outside
      builder: (BuildContext context) {
        TextEditingController _controller = TextEditingController();

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
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Create Folder",style: TextStyle(
                        fontSize: 15,
                      fontWeight: FontWeight.bold
                    ),),

                    // Align(
                    //   alignment: Alignment.topRight,
                    //   child: IconButton(onPressed: (){
                    //     Navigator.pop(context);
                    //
                    //   }, icon: Icon(Icons.close,size: AppHelper.isIpad(context)?15:12,)),
                    // )
                  ],
                ),
                SizedBox(height: 10,),

                TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    suffixIcon: IconButton(onPressed: (){
                      _controller.clear();
                    }, icon: CircleAvatar(
                      radius: 10,
                        backgroundColor: Colors.grey.withOpacity(0.5),
                        child: Icon(Icons.close,size: 15,))),
                      errorText:  _directoryAlreadyExists
                      ? 'Directory already exists'
                      : null,
                    labelText: 'Enter Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),




                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: TextButton(
                          style: TextButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                            backgroundColor: Colors.grey[300],
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text('Cancel'),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: TextButton(
                          style: TextButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () async {
                            if (_controller.text.trim().isNotEmpty) {
                              FocusScope.of(context).unfocus();
                              bool created = await createDirectory(
                                  targetDirectory: Directory(widget.directoryPath),
                                  directoryName: _controller.text);
                              if (created) {
                                Navigator.pop(context);
                              }
                              setState(() {
                                _directoryAlreadyExists = !created;
                              });

                              if (created) {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => DirectoryDetailsPage(
                                      directoryPath: '${widget.directoryPath}',
                                    ),
                                  ),
                                );
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
                          child: const Text('Create'),
                        ),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
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
  final allPaths = [
    "/.../Doc Scanner/ID Card",
    "/.../Doc Scanner/QR Code",
    "/.../Doc Scanner/Bar Code",
    "/.../Doc Scanner/Document",
  ];

  bool isLastCategory(String directoryPath, List<String> allPaths) {
    final categories = ["ID Card", "QR Code", "Bar Code", "Document"];

    // Extract last segment from each path
    final foundCategories = allPaths.map((path) {
      final parts = path.split('/');
      return parts.isNotEmpty ? parts.last.trim() : '';
    }).where((part) => categories.contains(part)).toList();

    // If no valid category is found, return false
    if (foundCategories.isEmpty) return false;

    // Get the last category found from the list
    final lastCategory = foundCategories.last;

    // Get last segment of current directoryPath
    final current = directoryPath.split('/').last.trim();

    return current == lastCategory;
  }



  @override
  void initState() {
    print("Hello Matching == ${widget.directoryPath.split('/').last}");
    allFiles = Provider.of<HomePageProvider>(context, listen: false)
        .getFileList(widget.directoryPath);

    print("check this file ${widget.directoryPath}");



    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      rootDirectory = await getApplicationDocumentsDirectory();
    });
    super.initState();
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    allFiles = Provider.of<HomePageProvider>(context, listen: false)
        .getFileList(widget.directoryPath);
  }

  @override
  Widget build(BuildContext context) {
    final homePageProvider = Provider.of<HomePageProvider>(context);
    final size = MediaQuery.sizeOf(context);
    return WillPopScope(
      onWillPop: () async {
        if (_isLongPressed) {
          setState(() {
            _isLongPressed = false;
            _selectedItems.clear();
          });
          return false;
        } else {
          return true;
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFECECEC),
        body: homePageProvider.isCreatingPDF || isDeleteLoading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : SafeArea(
                child: FutureBuilder(
                  future: allFiles,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Column(
                        children: [
                          SizedBox(
                            width: size.width,
                            height: 70,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                IconButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                    },
                                    style: IconButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                    ),
                                    icon: const Icon(Icons.arrow_back)),
                                Text(
                                  widget.directoryPath.split('/').last,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),

                              ],
                            ),
                          ),
                          const Expanded(
                            child: Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                        ],
                      );
                    } else if (snapshot.connectionState ==
                        ConnectionState.none) {
                      return Center(
                        child: Text(
                          translation(context).somethingWentWrong,
                        ),
                      );
                    } else if (snapshot.connectionState ==
                        ConnectionState.done) {
                      if (snapshot.hasData) {
                        List<String> fileList = snapshot.data!;
                        directoryList = fileList.where((path) {
                          return Directory(path).existsSync();
                        }).toList();
                        if (fileList.isEmpty) {
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: size.width,
                                height: 70,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        IconButton(
                                            onPressed: () {
                                              Navigator.pop(context);
                                            },
                                            style: IconButton.styleFrom(
                                              padding: EdgeInsets.zero,
                                            ),
                                            icon: Platform.isAndroid
                                                ? const Icon(Icons.arrow_back)
                                                : const Icon(Icons.arrow_back_ios)),
                                        Text(
                                          widget.directoryPath.split('/').last,
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    (widget.directoryPath.endsWith("Document") ||
                                        widget.directoryPath.endsWith("ID Card") ||
                                        widget.directoryPath.endsWith("QR Code") ||
                                        widget.directoryPath.endsWith("Bar Code"))
                                        ?
                                    Padding(
                                      padding:  EdgeInsets.only(right:AppHelper.isIpad(context)? 20:5),
                                      child: GestureDetector(
                                          onTap: () {
                                            _showCenterDialog(context);

                                          },
                                          child: SvgPicture.asset(
                                            AppAssets.create_folder,
                                            height: 28,
                                            width: 28,
                                          )),
                                    ):Container(),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    SvgPicture.asset(
                                      AppAssets.image_not_found,
                                    ),
                                    const SizedBox(
                                      height: 10,
                                    ),
                                    Text(
                                      translation(context).noDataFound,
                                      style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 20,
                                          fontWeight: FontWeight.normal),
                                    )
                                  ],
                                ),
                              )
                            ],
                          );
                        } else {
                          return Column(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xFFECECEC).withOpacity(0.5),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10.0),
                                height: 60,
                                width: size.width,
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    _isLongPressed
                                        ? TextButton(
                                            onPressed: () {
                                              setState(() {
                                                _selectedItems.clear();
                                                _isLongPressed = false;
                                              });
                                            },
                                            style: IconButton.styleFrom(
                                              padding: EdgeInsets.zero,
                                            ),
                                            child: Text(
                                              translation(context).cancel,
                                              style: const TextStyle(
                                                color: Colors.black,
                                                fontSize: 16,
                                              ),
                                            ))
                                        : Row(
                                            children: [
                                              IconButton(
                                                  onPressed: () {
                                                    Navigator.pushAndRemoveUntil(
                                                        context,
                                                        MaterialPageRoute(
                                                            builder: (context) =>
                                                                const BottomBar()),
                                                        (route) {
                                                      return false;
                                                    });
                                                  },
                                                  style: IconButton.styleFrom(
                                                    padding: EdgeInsets.zero,
                                                  ),
                                                  icon: const Icon(
                                                      Icons.arrow_back)),
                                              Text(
                                                widget.directoryPath
                                                    .split('/')
                                                    .last,
                                                style: const TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                    !_isLongPressed
                                        ? const Text("")
                                        : Text(
                                            "${_selectedItems.length.toString()} ${translation(context).selected}",
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                    !_isLongPressed
                                        ? Row(
                                          children: [
                                            (widget.directoryPath.endsWith("Document") ||
                                                widget.directoryPath.endsWith("ID Card") ||
                                                widget.directoryPath.endsWith("QR Code") ||
                                                widget.directoryPath.endsWith("Bar Code"))
                                                ?
                                            GestureDetector(
                                                onTap: () {
                                                  _showCenterDialog(context);

                                                },
                                                child: SvgPicture.asset(
                                                  AppAssets.create_folder,
                                                  height:AppHelper.isIpad(context)?32: 28,
                                                  width: AppHelper.isIpad(context)?32: 28,
                                                )):Container(),
                                            SizedBox(width:AppHelper.isIpad(context)? 20:10,),


                                            TextButton(
                                                style: IconButton.styleFrom(
                                                  padding: EdgeInsets.zero,
                                                ),
                                                onPressed: () {
                                                  setState(() {
                                                    _isLongPressed = true;
                                                  });
                                                },
                                                child: Text(
                                                  translation(context).select,
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                  ),
                                                )),


                                          ],
                                        )
                                        : _isLongPressed &&
                                                _selectedItems.isNotEmpty
                                            ? TextButton(
                                                onPressed: () {
                                                  setState(() {
                                                    _selectedItems.clear();
                                                  });
                                                },
                                                child: Text(
                                                  translation(context)
                                                      .deselectAll,
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                  ),
                                                ))
                                            : TextButton(
                                                style: IconButton.styleFrom(
                                                  padding: EdgeInsets.zero,
                                                ),
                                                onPressed: () {
                                                  setState(() {
                                                    _selectedItems.clear();
                                                    allFiles.then((value) {
                                                      _selectedItems
                                                          .addAll(value);
                                                    });
                                                  });
                                                },
                                                child: Text(
                                                  translation(context)
                                                      .selectAll,
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: GridView.builder(
                                  padding: const EdgeInsets.all(10),
                                  itemCount: fileList.length,
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: size.width >= 600 ? 4 : 3,
                                    // height: size.width >= 600 ? 110 : 100,

                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                    childAspectRatio: AppHelper.isIpad(context)? 1.1:  1.2,

                                  ),
                                  itemBuilder: (context, index) {
                                    String filePath = fileList[index];
                                    subFilePath = filePath;
                                    final isSelected =
                                        _selectedItems.contains(filePath);
                                    if (Directory(filePath).existsSync()) {
                                      return GestureDetector(
                                        onTap: () {
                                          if (_isLongPressed) {
                                            _toggleItemSelection(filePath);
                                            return;
                                          }
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  DirectoryDetailsPage(
                                                directoryPath: filePath,
                                              ),
                                            ),
                                          );
                                        },
                                        onLongPress: () =>
                                            _enterSelectionWithItem(filePath),
                                        child: Stack(
                                          alignment: Alignment.topRight,
                                          children: [
                                            Container(



                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(8.0),
                                              ),
                                              alignment: Alignment.center,
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                children: [
                                                   Icon(
                                                    Icons.folder,
                                                    color:
                                                        AppColor.primaryColor,
                                                    size:AppHelper.isIpad(context)?100: 40,
                                                  ),
                                                  Text(
                                                    filePath.split('/').last,
                                                    style:  TextStyle(
                                                      fontSize:AppHelper.isIpad(context)?18: 12,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            _isLongPressed
                                                ? Positioned(
                                                    child: SizedBox(
                                                      height: 30,
                                                      width: 30,
                                                      child: Transform.scale(
                                                        scale: AppHelper.isIpad(context)?1.3:1,
                                                        child: Checkbox(
                                                          shape:
                                                              const CircleBorder(),
                                                          activeColor: AppColor
                                                              .primaryColor,
                                                          value: isSelected,
                                                          side: const BorderSide(
                                                              color: Color(
                                                                  0xFFBEBEBE)),
                                                          onChanged:
                                                              (bool? value) {
                                                            setState(() {
                                                              if (value == true) {
                                                                _selectedItems
                                                                    .add(
                                                                        filePath);
                                                              } else {
                                                                _selectedItems
                                                                    .remove(
                                                                        filePath);
                                                              }
                                                            });
                                                          },
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                : InkWell(
                                                    child:  Icon(
                                                      Icons.more_vert,
                                                      color: Colors.black,
                                                      size:AppHelper.isIpad(context)?30: 20,
                                                    ),
                                                    onTap: () {
                                                      showGeneralDialog(
                                                        context: context,
                                                        barrierDismissible: true,
                                                        barrierLabel: '',
                                                        transitionDuration: const Duration(milliseconds: 300),
                                                        pageBuilder: (context, animation, secondaryAnimation) {
                                                          return Align(
                                                            alignment: Alignment.bottomCenter,
                                                            child: Container(
                                                              height:AppHelper.isIpad(context)? MediaQuery.sizeOf(context).height * 0.2:MediaQuery.sizeOf(context).height * 0.22,
                                                              width: MediaQuery
                                                                      .sizeOf(
                                                                          context)
                                                                  .width,
                                                              decoration:
                                                                  const BoxDecoration(
                                                                      borderRadius:
                                                                          BorderRadius
                                                                              .only(
                                                                        topLeft: Radius
                                                                            .circular(
                                                                                20),
                                                                        topRight:
                                                                            Radius.circular(
                                                                                20),
                                                                      ),
                                                                      color: Colors
                                                                          .white),
                                                              child: Column(
                                                                children: [
                                                                  Padding(
                                                                    padding: const EdgeInsets
                                                                            .symmetric(
                                                                            horizontal:
                                                                                10)
                                                                        .copyWith(
                                                                            top:
                                                                                20,
                                                                            bottom:
                                                                                10),
                                                                    child: Row(
                                                                      crossAxisAlignment:
                                                                          CrossAxisAlignment
                                                                              .center,
                                                                      mainAxisAlignment:
                                                                          MainAxisAlignment
                                                                              .spaceBetween,
                                                                      children: [
                                                                        const Text(
                                                                            ''),
                                                                        Text(
                                                                          translation(context)
                                                                              .documentFiles,
                                                                          style:
                                                                              const TextStyle(
                                                                                decoration: TextDecoration.none,
                                                                            color:
                                                                                Colors.black,
                                                                            fontSize:
                                                                                20,
                                                                            fontWeight:
                                                                                FontWeight.w500,
                                                                          ),
                                                                        ),
                                                                        Container(
                                                                          height: size.width >=
                                                                                  600
                                                                              ? 40
                                                                              : 30,
                                                                          width: size.width >=
                                                                                  600
                                                                              ? 40
                                                                              : 30,
                                                                          alignment:
                                                                              Alignment.center,
                                                                          decoration:
                                                                              const BoxDecoration(
                                                                            color:
                                                                                Color(0xFFF4F4F4),
                                                                            shape:
                                                                                BoxShape.circle,
                                                                          ),
                                                                          child:
                                                                              Material(
                                                                            color:
                                                                                Colors.transparent,
                                                                            child:
                                                                                InkWell(
                                                                              borderRadius:
                                                                                  BorderRadius.circular(30),
                                                                              onTap:
                                                                                  () {
                                                                                Navigator.pop(context);
                                                                              },
                                                                              child:
                                                                                  Icon(
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
                                                                    color: Colors
                                                                            .grey[
                                                                        200],
                                                                    thickness: 1,
                                                                  ),
                                                                  Material(
                                                                    color: Colors
                                                                        .transparent,
                                                                    child:
                                                                        InkWell(
                                                                      onTap:
                                                                          () async {
                                                                        TextEditingController
                                                                            renameController =
                                                                            TextEditingController(
                                                                                text: filePath.split("/").last);
                                                                        final formKey =
                                                                            GlobalKey<
                                                                                FormState>();
                                                                        Navigator.pop(
                                                                            context);
                                                                        showDialog(
                                                                          context:
                                                                              context,
                                                                          builder:
                                                                              (context) {
                                                                            String
                                                                                errorMessage =
                                                                                '';
                                                                            return StatefulBuilder(builder:
                                                                                (context, setState) {
                                                                              return AlertDialog(
                                                                                title: SizedBox(
                                                                                  width: AppHelper.isIpad(context)?350:300,
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
                                                                                  key: formKey,
                                                                                  child: TextFormField(
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
                                                                                      errorText: errorMessage.isEmpty ? null : errorMessage,
                                                                                      hintText: translation(context).enterFileName,
                                                                                      border: const OutlineInputBorder(
                                                                                        borderSide: BorderSide(color: AppColor.primaryColor),
                                                                                      ),
                                                                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                                actions: [
                                                                                  TextButton(onPressed: () => Navigator.pop(context), child: Text(translation(context).cancel)),
                                                                                  TextButton(
                                                                                    onPressed: () async {
                                                                                      if (formKey.currentState!.validate()) {
                                                                                        String newName = renameController.text;
                                                                                        String parentPath = Directory(filePath).parent.path;
                                                                                        String newPath = "$parentPath/$newName";
                                                                                        String lowerCaseNewPath = "$parentPath/${newName.toLowerCase()}";
                                                                                        String upperCaseNewPath = "$parentPath/${newName.toUpperCase()}";
                                                                                        final Directory newDirectory = Directory(newPath);
                                                                                        if (newDirectory.existsSync() || Directory(lowerCaseNewPath).existsSync() || Directory(upperCaseNewPath).existsSync()) {
                                                                                          setState(() {
                                                                                            errorMessage = translation(context).folderAlreadyExists;
                                                                                          });
                                                                                        } else {
                                                                                          await Directory(filePath).rename(newPath);
                                                                                          Navigator.pop(context);
                                                                                          allFiles = homePageProvider.getFileList(widget.directoryPath);
                                                                                        }
                                                                                      }
                                                                                    },
                                                                                    child: Text(translation(context).save),
                                                                                  ),
                                                                                ],
                                                                              );
                                                                            });
                                                                          },
                                                                        );
                                                                      },
                                                                      child:
                                                                          Padding(
                                                                        padding: const EdgeInsets
                                                                            .symmetric(
                                                                            horizontal:
                                                                                20.0,
                                                                            vertical:
                                                                                5),
                                                                        child:
                                                                            Row(
                                                                          children: [
                                                                            SvgPicture
                                                                                .asset(
                                                                              AppAssets.rename,
                                                                              color:
                                                                                  Colors.black,
                                                                            ),
                                                                            const SizedBox(
                                                                              width:
                                                                                  20,
                                                                            ),
                                                                            const Text(
                                                                              "Rename Folder",
                                                                              style:
                                                                                  TextStyle(
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
                                                                ],
                                                              ),
                                                            ),
                                                          );
                                                        },
                                                      );
                                                    },
                                                  ),
                                          ],
                                        ),
                                      );
                                    } else if (filePath
                                            .toLowerCase()
                                            .endsWith('.jpg') ||
                                        filePath
                                            .toLowerCase()
                                            .endsWith('.jpeg') ||
                                        filePath
                                            .toLowerCase()
                                            .endsWith('.png')) {
                                      return GestureDetector(
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
                                            _enterSelectionWithItem(filePath),
                                        child: Stack(
                                          alignment: Alignment.topRight,
                                          children: [
                                            Container(
                                        width:AppHelper.isIpad(context)? 195:150,
                                        height:AppHelper.isIpad(context)? 177:150,


                                        decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(8.0),
                                              ),
                                              padding:
                                                  const EdgeInsets.all(8.0),
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                children: [
                                                  Image.file(
                                                    File(
                                                      filePath,
                                                    ),
                                                    width:AppHelper.isIpad(context)?150: 100,
                                                    height:AppHelper.isIpad(context)?100: 50,
                                                  ),
                                                  Text(
                                                    filePath.split('/').last,
                                                    style:  TextStyle(
                                                      fontSize:AppHelper.isIpad(context)?15: 12,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  )
                                                ],
                                              ),
                                            ),
                                            _isLongPressed
                                                ? Positioned(
                                                    child: SizedBox(
                                                      height: 30,
                                                      width: 30,
                                                      child: Transform.scale(
                                                        scale: AppHelper.isIpad(context)?1.3:1,
                                                        child: Checkbox(
                                                          side: const BorderSide(
                                                              color: Color(
                                                                  0xFFBEBEBE)),
                                                          shape:
                                                              const CircleBorder(),
                                                          activeColor: AppColor
                                                              .primaryColor,
                                                          value: isSelected,
                                                          onChanged:
                                                              (bool? value) {
                                                            setState(() {
                                                              if (value == true) {
                                                                _selectedItems
                                                                    .add(
                                                                        filePath);
                                                              } else {
                                                                _selectedItems
                                                                    .remove(
                                                                        filePath);
                                                              }
                                                            });
                                                          },
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                : InkWell(
                                                    child:  Icon(
                                                      Icons.more_vert,
                                                      color: Colors.black,
                                                      size:AppHelper.isIpad(context)?30: 20,
                                                    ),
                                                    onTap: () {
                                                      showGeneralDialog(
                                                        context: context,
                                                        barrierDismissible: true,
                                                        barrierLabel: '',
                                                        transitionDuration: const Duration(milliseconds: 300),
                                                        pageBuilder: (context, animation, secondaryAnimation) {
                                                          return Align(
                                                            alignment: Alignment.bottomCenter,
                                                            child: Container(
                                                              height: MediaQuery
                                                                          .sizeOf(
                                                                              context)
                                                                      .height *
                                                                  0.25,
                                                              width: MediaQuery
                                                                      .sizeOf(
                                                                          context)
                                                                  .width,
                                                              decoration:
                                                                  const BoxDecoration(
                                                                      borderRadius:
                                                                          BorderRadius
                                                                              .only(
                                                                        topLeft: Radius
                                                                            .circular(
                                                                                20),
                                                                        topRight:
                                                                            Radius.circular(
                                                                                20),
                                                                      ),
                                                                      color: Colors
                                                                          .white),
                                                              child: Column(
                                                                children: [
                                                                  Padding(
                                                                    padding: const EdgeInsets
                                                                            .symmetric(
                                                                            horizontal:
                                                                                10)
                                                                        .copyWith(
                                                                            top:
                                                                                20,
                                                                            bottom:
                                                                                10),
                                                                    child: Row(
                                                                      crossAxisAlignment:
                                                                          CrossAxisAlignment
                                                                              .center,
                                                                      mainAxisAlignment:
                                                                          MainAxisAlignment
                                                                              .spaceBetween,
                                                                      children: [
                                                                        const Text(
                                                                            ''),
                                                                        Text(
                                                                          translation(context)
                                                                              .documentFiles,
                                                                          style:
                                                                              const TextStyle(
                                                                                decoration: TextDecoration.none,
                                                                            color:

                                                                                Colors.black,
                                                                            fontSize:
                                                                                20,
                                                                            fontWeight:
                                                                                FontWeight.w500,
                                                                          ),
                                                                        ),
                                                                        Container(
                                                                          height: size.width >=
                                                                                  600
                                                                              ? 40
                                                                              : 30,
                                                                          width: size.width >=
                                                                                  600
                                                                              ? 40
                                                                              : 30,
                                                                          alignment:
                                                                              Alignment.center,
                                                                          decoration:
                                                                              const BoxDecoration(
                                                                            color:
                                                                                Color(0xFFF4F4F4),
                                                                            shape:
                                                                                BoxShape.circle,
                                                                          ),
                                                                          child:
                                                                              Material(
                                                                            color:
                                                                                Colors.transparent,
                                                                            child:
                                                                                InkWell(
                                                                              borderRadius:
                                                                                  BorderRadius.circular(30),
                                                                              onTap:
                                                                                  () {
                                                                                Navigator.pop(context);
                                                                              },
                                                                              child:
                                                                                  Icon(
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
                                                                    color: Colors
                                                                            .grey[
                                                                        200],
                                                                    thickness: 1,
                                                                  ),
                                                                  Material(
                                                                    color: Colors
                                                                        .transparent,
                                                                    child:
                                                                        InkWell(
                                                                      onTap:
                                                                          () async {
                                                                        TextEditingController
                                                                            renameController =
                                                                            TextEditingController(
                                                                                text: path.basenameWithoutExtension(filePath));
                                                                        final formKey =
                                                                            GlobalKey<
                                                                                FormState>();
                                                                        Navigator.pop(
                                                                            context);
                                                                        showDialog(
                                                                          context:
                                                                              context,
                                                                          builder:
                                                                              (context) {
                                                                            String
                                                                                errorMessage =
                                                                                '';
                                                                            return StatefulBuilder(builder:
                                                                                (context, setState) {
                                                                              return AlertDialog(
                                                                                title: Text(translation(context).renameFile,
                                                                                    style: const TextStyle(
                                                                                      color: Colors.black,
                                                                                      fontSize: 16,
                                                                                      fontWeight: FontWeight.w500,
                                                                                    )),
                                                                                content: Form(
                                                                                  key: formKey,
                                                                                  child: TextFormField(
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
                                                                                      errorText: errorMessage.isEmpty ? null : errorMessage,
                                                                                      hintText: translation(context).enterFileName,
                                                                                      border: const OutlineInputBorder(
                                                                                        borderSide: BorderSide(color: AppColor.primaryColor),
                                                                                      ),
                                                                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                                actions: [
                                                                                  TextButton(onPressed: () => Navigator.pop(context), child: Text(translation(context).cancel)),
                                                                                  ////ID Card Image File Rename
                                                                                  TextButton(
                                                                                    onPressed: () async {
                                                                                      if (formKey.currentState!.validate()) {
                                                                                        String newName = renameController.text;
                                                                                        String parentPath = Directory(filePath).parent.path;
                                                                                        String newPath = "$parentPath/$newName.jpg";
                                                                                        if (File(newPath).existsSync()) {
                                                                                          setState(() {
                                                                                            errorMessage = translation(context).fileAlreadyExists;
                                                                                          });
                                                                                        } else {
                                                                                          File(filePath).renameSync(newPath);
                                                                                          Navigator.pop(context);
                                                                                          allFiles = homePageProvider.getFileList(widget.directoryPath);
                                                                                        }
                                                                                      }
                                                                                    },
                                                                                    child: Text(translation(context).save),
                                                                                  ),

                                                                                  // TextButton(
                                                                                  //     onPressed: () async {
                                                                                  //       if (_formKey.currentState!.validate()) {
                                                                                  //         String newPath = filePath.replaceAll(path.basenameWithoutExtension(filePath), _renameController.text);
                                                                                  //         File(filePath).renameSync(newPath);
                                                                                  //         Navigator.pop(context);
                                                                                  //         allFiles = homePageProvider.getFileList(widget.directoryPath);
                                                                                  //       }
                                                                                  //     },
                                                                                  //     child: Text(translation(context).save)),
                                                                                ],
                                                                              );
                                                                            });
                                                                          },
                                                                        );
                                                                      },
                                                                      child:
                                                                          Padding(
                                                                        padding: const EdgeInsets
                                                                            .symmetric(
                                                                            horizontal:
                                                                                20.0,
                                                                            vertical:
                                                                                5),
                                                                        child:
                                                                            Row(
                                                                          children: [
                                                                            SvgPicture
                                                                                .asset(
                                                                              AppAssets.rename,
                                                                              color:
                                                                                  Colors.black,
                                                                            ),
                                                                            const SizedBox(
                                                                              width:
                                                                                  20,
                                                                            ),
                                                                            Text(
                                                                              translation(context).renameFile,
                                                                              style:
                                                                                  const TextStyle(
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
                                                                    color: Colors
                                                                            .grey[
                                                                        200],
                                                                    thickness: 1,
                                                                    indent: MediaQuery.sizeOf(
                                                                                context)
                                                                            .width *
                                                                        0.15,
                                                                  ),
                                                                  Material(
                                                                    color: Colors
                                                                        .transparent,
                                                                    child:
                                                                        InkWell(
                                                                      onTap:
                                                                          () async {
                                                                        await Gal.putImage(
                                                                            filePath,
                                                                            album:
                                                                                "Doc Scanner");
                                                                        Navigator.pop(
                                                                            context);
                                                                        AppHelper.showTopSnackBar(
                                                                            context,
                                                                            translation(context)
                                                                                .saveAtGallery);
                                                                      },
                                                                      child:
                                                                          Padding(
                                                                        padding: const EdgeInsets
                                                                            .symmetric(
                                                                            horizontal:
                                                                                20.0,
                                                                            vertical:
                                                                                5),
                                                                        child:
                                                                            Row(
                                                                          children: [
                                                                            const Icon(
                                                                              Icons.ios_share_outlined,
                                                                              color:
                                                                                  Colors.black,
                                                                            ),
                                                                            const SizedBox(
                                                                              width:
                                                                                  20,
                                                                            ),
                                                                            Text(
                                                                              translation(context).saveAtGallery,
                                                                              style:
                                                                                  const TextStyle(
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
                                                                ],
                                                              ),
                                                            ),
                                                          );
                                                        },
                                                      );
                                                    },
                                                  ),
                                          ],
                                        ),
                                      );
                                    } else if (filePath
                                        .toLowerCase()
                                        .endsWith('.txt')) {
                                      return GestureDetector(
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

                                                List<String> parts = urlLink
                                                    .toString()
                                                    .split(';');
                                                for (var part in parts.where(
                                                    (p) => p.isNotEmpty)) {
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
                                                urlLink.toString().startsWith(
                                                            "WIFI") ||
                                                        urlLink
                                                            .toString()
                                                            .startsWith(
                                                                "Wifi") ||
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
                                            _enterSelectionWithItem(filePath),
                                        child: Stack(
                                          alignment: Alignment.topRight,
                                          children: [
                                            Container(
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(8.0),
                                              ),
                                              alignment: Alignment.center,
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                children: [
                                                  SvgPicture.asset(
                                                    AppAssets.txt,
                                                    width:AppHelper.isIpad(context)?150: 100,
                                                    height:AppHelper.isIpad(context)?100: 50,
                                                  ),
                                             AppHelper.isIpad(context)?     SizedBox(height: 10,):Container(),
                                                  Padding(
                                                    padding: const EdgeInsets.all(8.0),
                                                    child: Text(
                                                      filePath.split('/').last,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  )
                                                ],
                                              ),
                                            ),
                                            _isLongPressed
                                                ? Positioned(
                                                    child: SizedBox(
                                                      height: 30,
                                                      width: 30,
                                                      child: Transform.scale(
                                                        scale: AppHelper.isIpad(context)?1.3:1,
                                                        child: Checkbox(
                                                          side: const BorderSide(
                                                              color: Color(
                                                                  0xFFBEBEBE)),
                                                          shape:
                                                              const CircleBorder(),
                                                          activeColor: AppColor
                                                              .primaryColor,
                                                          value: isSelected,
                                                          onChanged:
                                                              (bool? value) {
                                                            setState(() {
                                                              if (value == true) {
                                                                _selectedItems
                                                                    .add(
                                                                        filePath);
                                                              } else {
                                                                _selectedItems
                                                                    .remove(
                                                                        filePath);
                                                              }
                                                            });
                                                          },
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                : InkWell(
                                                    child:  Icon(
                                                      Icons.more_vert,
                                                      color: Colors.black,
                                                      size:AppHelper.isIpad(context)?30: 20,
                                                    ),
                                                    onTap: () {
                                                      showGeneralDialog(
                                                        context: context,
                                                        barrierDismissible: true,
                                                        barrierLabel: "Dismiss",
                                                        barrierColor:
                                                        Colors.black54,
                                                        transitionDuration:
                                                        const Duration(
                                                            milliseconds: 300),
                                                        pageBuilder: (context,
                                                            anim1, anim2) {
                                                          return Align(
                                                            alignment: Alignment.bottomCenter,
                                                            child: Material(
                                                              color: Colors
                                                                  .transparent,

                                                              child: Container(
                                                                height: MediaQuery
                                                                            .sizeOf(
                                                                                context)
                                                                        .height *
                                                                    0.2,
                                                                width: MediaQuery
                                                                        .sizeOf(
                                                                            context)
                                                                    .width,
                                                                decoration:
                                                                    const BoxDecoration(
                                                                        borderRadius:
                                                                            BorderRadius
                                                                                .only(
                                                                          topLeft: Radius
                                                                              .circular(
                                                                                  20),
                                                                          topRight:
                                                                              Radius.circular(
                                                                                  20),
                                                                        ),
                                                                        color: Colors
                                                                            .white),
                                                                child: Column(
                                                                  children: [
                                                                    Padding(
                                                                      padding: const EdgeInsets
                                                                              .symmetric(
                                                                              horizontal:
                                                                                  10)
                                                                          .copyWith(
                                                                              top:
                                                                                  20,
                                                                              bottom:
                                                                                  10),
                                                                      child: Row(
                                                                        crossAxisAlignment:
                                                                            CrossAxisAlignment
                                                                                .center,
                                                                        mainAxisAlignment:
                                                                            MainAxisAlignment
                                                                                .spaceBetween,
                                                                        children: [
                                                                          const Text(
                                                                              ''),
                                                                          Text(
                                                                            translation(context)
                                                                                .documentFiles,
                                                                            style:
                                                                                const TextStyle(
                                                                                  decoration: TextDecoration.none,
                                                                              color:
                                                                                  Colors.black,
                                                                              fontSize:
                                                                                  20,
                                                                              fontWeight:
                                                                                  FontWeight.w500,
                                                                            ),
                                                                          ),
                                                                          Container(
                                                                            height: size.width >=
                                                                                    600
                                                                                ? 40
                                                                                : 30,
                                                                            width: size.width >=
                                                                                    600
                                                                                ? 40
                                                                                : 30,
                                                                            alignment:
                                                                                Alignment.center,
                                                                            decoration:
                                                                                const BoxDecoration(
                                                                              color:
                                                                                  Color(0xFFF4F4F4),
                                                                              shape:
                                                                                  BoxShape.circle,
                                                                            ),
                                                                            child:
                                                                                Material(
                                                                              color:
                                                                                  Colors.transparent,
                                                                              child:
                                                                                  InkWell(
                                                                                borderRadius:
                                                                                    BorderRadius.circular(30),
                                                                                onTap:
                                                                                    () {
                                                                                  Navigator.pop(context);
                                                                                },
                                                                                child:
                                                                                    Icon(
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
                                                                      color: Colors
                                                                              .grey[
                                                                          200],
                                                                      thickness: 1,
                                                                    ),
                                                                    Material(
                                                                      color: Colors
                                                                          .transparent,
                                                                      child:
                                                                          InkWell(
                                                                        onTap:
                                                                            () async {
                                                                          TextEditingController
                                                                              renameController =
                                                                              TextEditingController(
                                                                                  text: path.basenameWithoutExtension(filePath));
                                                                          final formKey =
                                                                              GlobalKey<
                                                                                  FormState>();
                                                                          Navigator.pop(
                                                                              context);
                                                                          showDialog(
                                                                            context:
                                                                                context,
                                                                            builder:
                                                                                (context) {
                                                                              String
                                                                                  errorMessage =
                                                                                  '';
                                                                              return StatefulBuilder(builder:
                                                                                  (context, setState) {
                                                                                return AlertDialog(
                                                                                  title: Text(translation(context).renameFile,
                                                                                      style: const TextStyle(
                                                                                        color: Colors.black,
                                                                                        fontSize: 16,
                                                                                        fontWeight: FontWeight.w500,
                                                                                      )),
                                                                                  content: Form(
                                                                                    key: formKey,
                                                                                    child: TextFormField(
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
                                                                                        errorText: errorMessage.isEmpty ? null : errorMessage,
                                                                                        hintText: translation(context).enterFileName,
                                                                                        border: const OutlineInputBorder(
                                                                                          borderSide: BorderSide(color: AppColor.primaryColor),
                                                                                        ),
                                                                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                                                                                      ),
                                                                                    ),
                                                                                  ),
                                                                                  actions: [
                                                                                    TextButton(onPressed: () => Navigator.pop(context), child: Text(translation(context).cancel)),
                                                                                    TextButton(
                                                                                      onPressed: () async {
                                                                                        if (formKey.currentState!.validate()) {
                                                                                          // String newPath = filePath.replaceAll(path.basenameWithoutExtension(filePath), _renameController.text);
                                                                                          String newName = renameController.text;
                                                                                          String parentPath = Directory(filePath).parent.path;
                                                                                          String newPath = "$parentPath/$newName.txt";

                                                                                          if (File(newPath).existsSync()) {
                                                                                            setState(() {
                                                                                              errorMessage = translation(context).fileAlreadyExists;
                                                                                            });
                                                                                          } else {
                                                                                            File(filePath).renameSync(newPath);
                                                                                            Navigator.pop(context);
                                                                                            allFiles = homePageProvider.getFileList(widget.directoryPath);
                                                                                          }
                                                                                        }
                                                                                      },
                                                                                      child: Text(translation(context).save),
                                                                                    ),
                                                                                  ],
                                                                                );
                                                                              });
                                                                            },
                                                                          );
                                                                        },
                                                                        child:
                                                                            Padding(
                                                                          padding: const EdgeInsets
                                                                              .symmetric(
                                                                              horizontal:
                                                                                  20.0,
                                                                              vertical:
                                                                                  5),
                                                                          child:
                                                                              Row(
                                                                            children: [
                                                                              SvgPicture
                                                                                  .asset(
                                                                                AppAssets.rename,
                                                                                color:
                                                                                    Colors.black,
                                                                              ),
                                                                              const SizedBox(
                                                                                width:
                                                                                    20,
                                                                              ),
                                                                              Text(
                                                                                translation(context).renameFile,
                                                                                style:
                                                                                    const TextStyle(
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
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                          );
                                                        },
                                                      );
                                                    },
                                                  ),
                                          ],
                                        ),
                                      );
                                    } else if (filePath
                                        .toLowerCase()
                                        .endsWith('.pdf')) {
                                      return GestureDetector(
                                        onTap: () async {
                                          if (_isLongPressed) {
                                            _toggleItemSelection(filePath);
                                            return;
                                          }
                                          await OpenFilex.open(filePath);
                                        },
                                        onLongPress: () =>
                                            _enterSelectionWithItem(filePath),
                                        child: Stack(
                                          alignment: Alignment.topRight,
                                          children: [
                                            Container(
                                              width: double.infinity,
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(8.0),
                                              ),
                                              padding:
                                                  const EdgeInsets.all(8.0),
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                children: [
                                                  SvgPicture.asset(
                                                    AppAssets.pdf,
                                                    width:AppHelper.isIpad(context)?150: 100,
                                                    height:AppHelper.isIpad(context)?100: 50,
                                                  ),
                                                  Text(
                                                    filePath.split('/').last,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: AppHelper.isIpad(context)?15:12
                                                    ),
                                                  )
                                                ],
                                              ),
                                            ),
                                            _isLongPressed
                                                ? Positioned(
                                                    child: SizedBox(
                                                      height: 30,
                                                      width: 30,
                                                      child: Transform.scale(
                                                        scale: AppHelper.isIpad(context)?1.3:1,
                                                        child: Checkbox(
                                                          side: const BorderSide(
                                                              color: Color(
                                                                  0xFFBEBEBE)),
                                                          shape:
                                                              const CircleBorder(),
                                                          activeColor: AppColor
                                                              .primaryColor,
                                                          value: isSelected,
                                                          onChanged:
                                                              (bool? value) {
                                                            setState(() {
                                                              if (value == true) {
                                                                _selectedItems
                                                                    .add(
                                                                        filePath);
                                                              } else {
                                                                _selectedItems
                                                                    .remove(
                                                                        filePath);
                                                              }
                                                            });
                                                          },
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                : InkWell(
                                                    child:  Icon(
                                                      Icons.more_vert,
                                                      color: Colors.black,
                                                      size:AppHelper.isIpad(context)?30: 20,
                                                    ),
                                                    onTap: () {
                                                      showGeneralDialog(
                                                        context: context,
                                                        barrierDismissible: true,
                                                        barrierLabel: '',
                                                        transitionDuration: const Duration(milliseconds: 300),
                                                        pageBuilder: (context, animation, secondaryAnimation) {
                                                          return Align(
                                                            alignment: Alignment.bottomCenter,
                                                            child: Material(
                                                              color: Colors.white,
                                                              borderRadius: const BorderRadius.only(
                                                                topLeft: Radius.circular(20),
                                                                topRight: Radius.circular(20),
                                                              ),
                                                              clipBehavior: Clip.antiAlias,
                                                              child: Container(
                                                              height: MediaQuery
                                                                          .sizeOf(
                                                                              context)
                                                                      .height *
                                                                  0.25,
                                                              width: MediaQuery
                                                                      .sizeOf(
                                                                          context)
                                                                  .width,
                                                              decoration:
                                                                  const BoxDecoration(
                                                                      borderRadius:
                                                                          BorderRadius
                                                                              .only(
                                                                        topLeft: Radius
                                                                            .circular(
                                                                                20),
                                                                        topRight:
                                                                            Radius.circular(
                                                                                20),
                                                                      ),
                                                                      color: Colors
                                                                          .white),
                                                              child: Column(
                                                                children: [
                                                                  Padding(
                                                                    padding: const EdgeInsets
                                                                            .symmetric(
                                                                            horizontal:
                                                                                10)
                                                                        .copyWith(
                                                                            top:
                                                                                20,
                                                                            bottom:
                                                                                10),
                                                                    child: Row(
                                                                      crossAxisAlignment:
                                                                          CrossAxisAlignment
                                                                              .center,
                                                                      mainAxisAlignment:
                                                                          MainAxisAlignment
                                                                              .spaceBetween,
                                                                      children: [
                                                                        const Text(
                                                                            ''),
                                                                        Text(
                                                                          translation(context)
                                                                              .documentFiles,
                                                                          style:
                                                                              const TextStyle(
                                                                            decoration: TextDecoration.none,
                                                                            color:
                                                                                Colors.black,
                                                                            fontSize:
                                                                                20,
                                                                            fontWeight:
                                                                                FontWeight.w500,
                                                                          ),
                                                                        ),
                                                                        Container(
                                                                          height: size.width >=
                                                                                  600
                                                                              ? 40
                                                                              : 30,
                                                                          width: size.width >=
                                                                                  600
                                                                              ? 40
                                                                              : 30,
                                                                          alignment:
                                                                              Alignment.center,
                                                                          decoration:
                                                                              const BoxDecoration(
                                                                            color:
                                                                                Color(0xFFF4F4F4),
                                                                            shape:
                                                                                BoxShape.circle,
                                                                          ),
                                                                          child:
                                                                              Material(
                                                                            color:
                                                                                Colors.transparent,
                                                                            child:
                                                                                InkWell(
                                                                              borderRadius:
                                                                                  BorderRadius.circular(30),
                                                                              onTap:
                                                                                  () {
                                                                                Navigator.pop(context);
                                                                              },
                                                                              child:
                                                                                  Icon(
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
                                                                    color: Colors
                                                                            .grey[
                                                                        200],
                                                                    thickness: 1,
                                                                  ),
                                                                  Material(
                                                                    color: Colors
                                                                        .transparent,
                                                                    child:
                                                                        InkWell(
                                                                      onTap:
                                                                          () async {
                                                                        TextEditingController
                                                                            renameController =
                                                                            TextEditingController(
                                                                                text: path.basenameWithoutExtension(filePath));
                                                                        final formKey =
                                                                            GlobalKey<
                                                                                FormState>();
                                                                        Navigator.pop(
                                                                            context);
                                                                        showDialog(
                                                                          context:
                                                                              context,
                                                                          builder:
                                                                              (context) {
                                                                            String
                                                                                errorMessage =
                                                                                '';
                                                                            return StatefulBuilder(builder:
                                                                                (context, setState) {
                                                                              return AlertDialog(
                                                                                title: SizedBox(
                                                                                  width: AppHelper.isIpad(context)?350:300,
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
                                                                                  key: formKey,
                                                                                  child: TextFormField(
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
                                                                                      errorText: errorMessage.isEmpty ? null : errorMessage,
                                                                                      border: const OutlineInputBorder(
                                                                                        borderSide: BorderSide(color: AppColor.primaryColor),
                                                                                      ),
                                                                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                                actions: [
                                                                                  TextButton(
                                                                                    onPressed: () => Navigator.pop(context),
                                                                                    child: Text(translation(context).cancel),
                                                                                  ),
                                                                                  TextButton(
                                                                                      onPressed: () async {
                                                                                        if (formKey.currentState!.validate()) {
                                                                                          //  String newPath = filePath.replaceAll(path.basenameWithoutExtension(filePath), _renameController.text);

                                                                                          String newName = renameController.text;
                                                                                          String parentPath = Directory(filePath).parent.path;
                                                                                          String newPath = "$parentPath/$newName.pdf";

                                                                                          if (File(newPath).existsSync()) {
                                                                                            setState(() {
                                                                                              errorMessage = translation(context).fileAlreadyExists;
                                                                                            });
                                                                                          } else {
                                                                                            File(filePath).renameSync(newPath);
                                                                                            Navigator.pop(context);
                                                                                            allFiles = homePageProvider.getFileList(widget.directoryPath);
                                                                                          }
                                                                                        }
                                                                                      },
                                                                                      child: Text(translation(context).save)),
                                                                                ],
                                                                              );
                                                                            });
                                                                          },
                                                                        );
                                                                      },
                                                                      child:
                                                                          Padding(
                                                                        padding: const EdgeInsets
                                                                            .symmetric(
                                                                            horizontal:
                                                                                20.0,
                                                                            vertical:
                                                                                5),
                                                                        child:
                                                                            Row(
                                                                          children: [
                                                                            SvgPicture
                                                                                .asset(
                                                                              AppAssets.rename,
                                                                              color:
                                                                                  Colors.black,
                                                                            ),
                                                                            const SizedBox(
                                                                              width:
                                                                                  20,
                                                                            ),
                                                                            Text(
                                                                              translation(context).renameFile,
                                                                              style:
                                                                                  const TextStyle(
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
                                                                    color: Colors
                                                                            .grey[
                                                                        200],
                                                                    thickness: 1,
                                                                  ),
                                                                  Material(
                                                                    color: Colors
                                                                        .transparent,
                                                                    child:
                                                                        InkWell(
                                                                      onTap:
                                                                          () async {
                                                                        Navigator.pop(
                                                                            context);
                                                                        try {
                                                                          await DownloadHelper
                                                                              .saveFileToDownloads(
                                                                                  filePath);
                                                                          AppHelper.showTopSnackBar(
                                                                            context,
                                                                            translation(context).fileSavedDownloadFolder,
                                                                          );
                                                                        } catch (e) {
                                                                          AppHelper.showTopSnackBar(
                                                                            context,
                                                                            "Failed to download file: $e",
                                                                          );
                                                                        }
                                                                      },
                                                                      child:
                                                                          Padding(
                                                                        padding: const EdgeInsets
                                                                            .symmetric(
                                                                            horizontal:
                                                                                20.0,
                                                                            vertical:
                                                                                5),
                                                                        child:
                                                                            Row(
                                                                          children: [
                                                                            const Icon(
                                                                              Icons.ios_share_outlined,
                                                                              color:
                                                                                  Colors.black,
                                                                            ),
                                                                            const SizedBox(
                                                                              width:
                                                                                  20,
                                                                            ),
                                                                            Text(
                                                                              translation(context).downloadFile,
                                                                              style:
                                                                                  const TextStyle(
                                                                                decoration: TextDecoration.none,
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
                                                                ],
                                                              ),
                                                            ),
                                                            ),
                                                          );
                                                        },
                                                      );
                                                    },
                                                  ),
                                          ],
                                        ),
                                      );
                                    } else {
                                      return Text(
                                        translation(context).somethingWentWrong,
                                      );
                                    }
                                  },
                                ),
                              ),
                            ],
                          );
                        }
                      } else if (snapshot.hasError) {
                        return Text('Error: ${snapshot.error}');
                      } else {
                        return Text(
                          translation(context).noDataFound,
                        );
                      }
                    } else {
                      return Text(
                        translation(context).somethingWentWrong,
                      );
                    }
                  },
                ),
              ),
        bottomNavigationBar: BottomBarWithBanner(
          adUnitId: AdHelper.directoryViewBannerAdUnitId,
          bannerAbove: true,
          child: Container(
          height: size.width >= 600 ? 100 : 90,
          color: Colors.white,
          padding: const EdgeInsets.symmetric(
              horizontal: 8.0),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment:
            MainAxisAlignment.spaceAround,
            children: [
          AppHelper.isIpad(context)?    GestureDetector(
                onTap: () async {
                  if (_selectedItems.every(
                          (element) =>
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
                              .endsWith(
                              '.jpeg') ||
                          element
                              .toLowerCase()
                              .endsWith(
                              '.png')) &&
                      _selectedItems.isNotEmpty) {
                    await showGeneralDialog(
                      context: context,
                      barrierDismissible: true,
                      barrierLabel: "Dismiss",
                      barrierColor:
                      Colors.black54,
                      transitionDuration:
                      const Duration(
                          milliseconds: 300),
                      pageBuilder: (context,
                          anim1, anim2) {
                        List<String> directories =
                        getSubdirectoriesSyncForIos(
                            widget.directoryPath);
                        directories.remove(
                            widget.directoryPath);
                        log(directories.toString());

                        return Align(
                          alignment: Alignment
                              .bottomCenter,
                          child: Material(
                            color: Colors
                                .white,
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              height: 450,
                              child:
                              directories.isNotEmpty
                                  ? Padding(
                                padding: const EdgeInsets
                                    .symmetric(
                                    horizontal:
                                    20.0,
                                    vertical:
                                    10),
                                child: ListView(
                                  scrollDirection:
                                  Axis.vertical,
                                  children: List.generate(
                                      directories
                                          .length,
                                          (index) {
                                        return ListTile(
                                          leading:
                                          const Icon(
                                            Icons
                                                .folder,
                                            color: AppColor
                                                .primaryColor,
                                            size:
                                            40,
                                          ),
                                          title: Text(directories[
                                          index]
                                              .split(
                                              '/')
                                              .last),
                                          onTap:
                                              () async {
                                            var conflictResult =
                                            homePageProvider.checkIfFilesExistInDirectory(
                                              targetDirectoryPath:
                                              directories[index],
                                              filePaths:
                                              _selectedItems.toList(),
                                            );
                            
                                            if (conflictResult) {
                                              showDialog(
                                                context:
                                                context,
                                                builder:
                                                    (context) {
                                                  return AlertDialog(
                                                    title: Text(translation(context).conflictAlert),
                                                    content: Text(translation(context).fileConflictAlertContent),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () {
                                                          Navigator.pop(context);
                                                        },
                                                        child: Text(translation(context).cancel),
                                                      ),
                                                      TextButton(
                                                        onPressed: () {
                                                          homePageProvider.moveFilesToDirectory(
                                                            targetDirectoryPath: directories[index],
                                                            filePaths: _selectedItems.toList(),
                                                          );
                                                          setState(() {
                                                            _selectedItems.clear();
                                                            _isLongPressed = false;
                                                          });
                                                          Navigator.pop(context);
                                                          Navigator.pop(context);
                                                          allFiles = homePageProvider.getFileList(widget.directoryPath);
                                                        },
                                                        child: Text(translation(context).duplicate),
                                                      ),
                                                    ],
                                                  );
                                                },
                                              );
                                            } else {
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
                                              allFiles =
                                                  homePageProvider.getFileList(widget.directoryPath);
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
                                            // allFiles = homePageProvider.getFileList(widget.directoryPath);
                                          },
                                        );
                                      }),
                                ),
                              )
                                  : Center(
                                child: Text(
                                  translation(
                                      context)
                                      .noDirectoryFound,
                                ),
                              ),
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
                        duration: const Duration(
                            seconds: 1),
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
                        duration: const Duration(
                            seconds: 1),
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
                      AppAssets.move,
                      height:AppHelper.isIpad(context)?28: 20,
                      width:AppHelper.isIpad(context)?28: 20,
                      fit: BoxFit.fill,
                      color: _selectedItems.isNotEmpty
                          ? AppColor.primaryColor
                          : Colors.black,
                    ),
                    Text(
                      translation(context).move,
                      style: TextStyle(
                          color: _selectedItems
                              .isNotEmpty
                              ? AppColor.primaryColor
                              : Colors.black,
                          fontSize: 12,
                          fontWeight:
                          FontWeight.w500),
                    ),
                  ],
                ),
              )
              :  GestureDetector(
            onTap: () async {
              if (_selectedItems.every(
                      (element) =>
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
                          .endsWith(
                          '.jpeg') ||
                      element
                          .toLowerCase()
                          .endsWith(
                          '.png')) &&
                  _selectedItems.isNotEmpty) {
                await showModalBottomSheet(
                  context: context,
                  builder: (context) {
                    List<String> directories =
                    getSubdirectoriesSyncForIos(
                        widget.directoryPath);
                    directories.remove(
                        widget.directoryPath);
                    log(directories.toString());

                    return SizedBox(
                      height:
                      MediaQuery.of(context)
                          .size
                          .height *
                          0.5,
                      child:
                      directories.isNotEmpty
                          ? Padding(
                        padding: const EdgeInsets
                            .symmetric(
                            horizontal:
                            20.0,
                            vertical:
                            10),
                        child: ListView(
                          scrollDirection:
                          Axis.vertical,
                          children: List.generate(
                              directories
                                  .length,
                                  (index) {
                                return ListTile(
                                  leading:
                                  const Icon(
                                    Icons
                                        .folder,
                                    color: AppColor
                                        .primaryColor,
                                    size:
                                    40,
                                  ),
                                  title: Text(directories[
                                  index]
                                      .split(
                                      '/')
                                      .last),
                                  onTap:
                                      () async {
                                    var conflictResult =
                                    homePageProvider.checkIfFilesExistInDirectory(
                                      targetDirectoryPath:
                                      directories[index],
                                      filePaths:
                                      _selectedItems.toList(),
                                    );

                                    if (conflictResult) {
                                      showDialog(
                                        context:
                                        context,
                                        builder:
                                            (context) {
                                          return AlertDialog(
                                            title: Text(translation(context).conflictAlert),
                                            content: Text(translation(context).fileConflictAlertContent),
                                            actions: [
                                              TextButton(
                                                onPressed: () {
                                                  Navigator.pop(context);
                                                },
                                                child: Text(translation(context).cancel),
                                              ),
                                              TextButton(
                                                onPressed: () {
                                                  homePageProvider.moveFilesToDirectory(
                                                    targetDirectoryPath: directories[index],
                                                    filePaths: _selectedItems.toList(),
                                                  );
                                                  setState(() {
                                                    _selectedItems.clear();
                                                    _isLongPressed = false;
                                                  });
                                                  Navigator.pop(context);
                                                  Navigator.pop(context);
                                                  allFiles = homePageProvider.getFileList(widget.directoryPath);
                                                },
                                                child: Text(translation(context).duplicate),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    } else {
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
                                      allFiles =
                                          homePageProvider.getFileList(widget.directoryPath);
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
                                    // allFiles = homePageProvider.getFileList(widget.directoryPath);
                                  },
                                );
                              }),
                        ),
                      )
                          : Center(
                        child: Text(
                          translation(
                              context)
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
                    duration: const Duration(
                        seconds: 1),
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
                    duration: const Duration(
                        seconds: 1),
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
                  AppAssets.move,
                  height: 20,
                  width: 20,
                  fit: BoxFit.fill,
                  color: _selectedItems.isNotEmpty
                      ? AppColor.primaryColor
                      : Colors.black,
                ),
                Text(
                  translation(context).move,
                  style: TextStyle(
                      color: _selectedItems
                          .isNotEmpty
                          ? AppColor.primaryColor
                          : Colors.black,
                      fontSize: 12,
                      fontWeight:
                      FontWeight.w500),
                ),
              ],
            ),
          ),
              GestureDetector(
                onTap: () async {
                  if (_selectedItems.isNotEmpty) {
                    if (_selectedItems.every(
                            (element) =>
                        element.toLowerCase().endsWith('.jpg') ||
                            element.toLowerCase().endsWith('.pdf') ||
                            element.toLowerCase().endsWith('.jpeg') ||
                            element.toLowerCase().endsWith('.png'))) {
                      if (isShareIng) {
                        return;
                      } else {
                        isShareIng = true;

                        // Get the position of the widget for iPad share sheet
                        final box = context.findRenderObject() as RenderBox?;
                        final sharePosition = box!.localToGlobal(Offset.zero) & box!.size;

                        try {
                          await Share.shareXFiles(
                            _selectedItems.map((e) => XFile(e)).toList(),
                            sharePositionOrigin: AppHelper.isIpad(context) ? sharePosition : null,
                          ).then((value) {
                            isShareIng = false;
                            setState(() {
                              _selectedItems.clear();
                              _isLongPressed = false;
                            });
                          });
                        } catch (e) {
                          isShareIng = false;
                          debugPrint('Sharing error: $e');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to share: ${e.toString()}'),
                            ),
                          );
                        }
                      }
                    } else if (_selectedItems.every(
                            (element) => element.toLowerCase().endsWith('.txt')) &&
                        _selectedItems.length == 1) {
                      String text = await File(_selectedItems.first).readAsString();
                      if (isShareIng) {
                        return;
                      } else {
                        isShareIng = true;
                        try {
                          await Share.share(text).then((value) {
                            isShareIng = false;
                          });
                        } catch (e) {
                          isShareIng = false;
                          debugPrint('Sharing error: $e');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to share: ${e.toString()}'),
                            ),
                          );
                        }
                      }
                    } else if (_selectedItems.every(
                            (element) => element.toLowerCase().endsWith('.txt')) &&
                        _selectedItems.length > 1) {
                      ScaffoldMessenger.of(context).clearSnackBars();
                      ScaffoldMessenger.of(context).showSnackBar(
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
                      ScaffoldMessenger.of(context).clearSnackBars();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          duration: const Duration(seconds: 1),
                          content: Text(
                            translation(context).pleaseSelectFileOnly,
                            style: const TextStyle(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      );
                    }
                  } else {
                    ScaffoldMessenger.of(context).clearSnackBars();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        duration: const Duration(seconds: 1),
                        content: Text(
                          translation(context).pleaseSelectFirst,
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
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SvgPicture.asset(
                      AppAssets.share,
                      height: AppHelper.isIpad(context) ? 28 : 20,
                      width: AppHelper.isIpad(context) ? 28 : 20,
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
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              widget.directoryPath
                  .endsWith("QR Code") ||
                  widget.directoryPath
                      .endsWith("Bar Code") ||
                  isSubfolderOfQRCode(
                      widget.directoryPath)
                  ? GestureDetector(
                onTap: () async {
                  if (_selectedItems
                      .isNotEmpty) {
                    if (_selectedItems.length ==
                        1 &&
                        _selectedItems.first
                            .toLowerCase()
                            .endsWith('.txt')) {
                      String text = await File(
                          _selectedItems
                              .first)
                          .readAsString();
                      Clipboard.setData(
                          ClipboardData(
                              text: text))
                          .then((value) {
                        ScaffoldMessenger.of(
                            context)
                            .showSnackBar(
                          SnackBar(
                            duration:
                            const Duration(
                                seconds: 1),
                            content: Text(
                              translation(
                                  context)
                                  .textCopied,
                              style:
                              const TextStyle(
                                color: Colors
                                    .white,
                              ),
                            ),
                          ),
                        );
                      });
                    } else {
                      ScaffoldMessenger.of(
                          context)
                          .showSnackBar(
                        SnackBar(
                          duration:
                          const Duration(
                              seconds: 1),
                          content: Text(
                            translation(context)
                                .pleaseSelectOneTextOnly,
                            style:
                            const TextStyle(
                              color:
                              Colors.white,
                            ),
                          ),
                        ),
                      );
                    }
                  } else {
                    ScaffoldMessenger.of(
                        context)
                        .showSnackBar(
                      SnackBar(
                        duration:
                        const Duration(
                            seconds: 1),
                        content: Text(
                          translation(context)
                              .pleaseSelectFirst,
                          style:
                          const TextStyle(
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
                      size:AppHelper.isIpad(context)?35: 20,
                      color: _selectedItems
                          .length ==
                          1
                          ? AppColor
                          .primaryColor
                          : Colors.black,
                    ),
                    Text(
                      translation(context).copy,
                      style: TextStyle(
                          color: _selectedItems
                              .length ==
                              1
                              ? AppColor
                              .primaryColor
                              : Colors.black,
                          fontSize: 12,
                          fontWeight:
                          FontWeight.w500),
                    ),
                  ],
                ),
              )
                  : GestureDetector(
                onTap: () async {
                  if (_selectedItems
                      .isNotEmpty) {
                    if (_selectedItems.length >=
                        2) {
                      if (_selectedItems.every((element) =>
                      element
                          .toLowerCase()
                          .endsWith(
                          '.jpg') ||
                          element
                              .toLowerCase()
                              .endsWith(
                              '.jpeg') ||
                          element
                              .toLowerCase()
                              .endsWith(
                              '.png'))) {
                        await showDialog(
                          context: context,
                          builder: (context) {
                            TextEditingController
                            renameController =
                            TextEditingController();
                            return AlertDialog(
                              title: SizedBox(
                                width: AppHelper.isIpad(context)?350:300,
                                child: const Text(
                                    "PDF"),
                              ),
                              content:
                              TextFormField(
                                controller:
                                renameController,
                                keyboardType:
                                TextInputType
                                    .text,
                                textInputAction:
                                TextInputAction
                                    .done,
                                autofocus: true,
                                validator:
                                    (value) {
                                  if (value!
                                      .isEmpty) {
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
                                    borderSide:
                                    BorderSide(
                                        color:
                                        AppColor.primaryColor),
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
                                  onPressed:
                                      () {
                                    Navigator.pop(
                                        context);
                                  },
                                  child: Text(
                                      translation(
                                          context)
                                          .cancel),
                                ),
                                TextButton(
                                  onPressed:
                                      () async {
                                    if (renameController
                                        .text
                                        .isNotEmpty) {
                                      AppHelper.showTopSnackBar(
                                          context,
                                          "PDF save successfully in Document Folder");

                                      Navigator.pop(
                                          context); // Close the current dialog
                                      // Set target path
                                      String
                                      fileName =
                                          renameController
                                              .text;

                                      await homePageProvider
                                          .createPDFFromImages(
                                        images: _selectedItems
                                            .map((e) =>
                                            File(e))
                                            .toList(),
                                        directoryPath:
                                        widget.directoryPath,
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
                                                  homePageProvider.getFileList(widget.directoryPath);

                                              if (widget.directoryPath.split("/").last ==
                                                  "ID Card") {
                                                homePageProvider.addIdCardImage(value);
                                              } else if (widget.directoryPath.split("/").last ==
                                                  "Document") {
                                                homePageProvider.addDocumentImage(value);
                                              }
                                              // Clear selections and update state
                                              setState(
                                                      () {
                                                    _selectedItems.clear();
                                                    _isLongPressed =
                                                    false;
                                                  });

                                              // Show success popup
                                            }
                                          });
                                    } else {
                                      ScaffoldMessenger.of(
                                          context)
                                          .clearSnackBars();
                                      ScaffoldMessenger.of(
                                          context)
                                          .showSnackBar(
                                        SnackBar(
                                          duration:
                                          const Duration(seconds: 1),
                                          content:
                                          Text(
                                            translation(context).pleaseEnterFileName,
                                            style:
                                            const TextStyle(color: Colors.white),
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
                        ScaffoldMessenger.of(
                            context)
                            .clearSnackBars();
                        ScaffoldMessenger.of(
                            context)
                            .showSnackBar(
                          SnackBar(
                            duration:
                            const Duration(
                                seconds: 1),
                            content: Text(
                              translation(
                                  context)
                                  .pleaseSelectImagesOnly,
                              style:
                              const TextStyle(
                                color: Colors
                                    .white,
                              ),
                            ),
                          ),
                        );
                      }
                    }
                  } else {
                    ScaffoldMessenger.of(
                        context)
                        .clearSnackBars();
                    ScaffoldMessenger.of(
                        context)
                        .showSnackBar(
                      SnackBar(
                        duration:
                        const Duration(
                            seconds: 1),
                        content: Text(
                          translation(context)
                              .pleaseSelectFirst,
                          style:
                          const TextStyle(
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
                      height:AppHelper.isIpad(context)?25: 18,
                      width:AppHelper.isIpad(context)?25: 18,
                      fit: BoxFit.fill,
                      color: _selectedItems
                          .length >=
                          2
                          ? AppColor
                          .primaryColor
                          : Colors.black,
                    ),
                    Text(
                      translation(context)
                          .merge,
                      style: TextStyle(
                          color: _selectedItems
                              .length >=
                              2
                              ? AppColor
                              .primaryColor
                              : Colors.black,
                          fontSize: 12,
                          fontWeight:
                          FontWeight.w500),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () async {
                  if (_selectedItems.isNotEmpty) {
                    showNormalAlertDialogue(
                      context: context,
                      title:
                      translation(context).alert,
                      content: translation(context)
                          .areYouSureYouWantToDeleteTheSelectedItems,
                      onOkText:
                      translation(context).ok,
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
                          var item = _selectedItems
                              .elementAt(i);
                          var fileSystemEntity =
                          FileSystemEntity
                              .typeSync(item);
                          if (fileSystemEntity ==
                              FileSystemEntityType
                                  .file) {
                            try {
                              File file = File(item);
                              if (item
                                  .split("/")
                                  .contains(
                                  "Document")) {
                                homePageProvider
                                    .removeDocumentImage(
                                    item);
                              } else if (item
                                  .split("/")
                                  .contains(
                                  "ID Card")) {
                                homePageProvider
                                    .removeIdCardImage(
                                    item);
                              } else if (item
                                  .split("/")
                                  .contains(
                                  "QR Code")) {
                                homePageProvider
                                    .removeQrCode(
                                    item);
                              } else {
                                homePageProvider
                                    .removeBarCode(
                                    item);
                              }
                              file.deleteSync();
                            } catch (e) {
                              print(
                                  "Error deleting file $item: $e");
                            }
                          } else if (fileSystemEntity ==
                              FileSystemEntityType
                                  .directory) {
                            Directory directory =
                            Directory(item);
                            List<FileSystemEntity>
                            entities =
                            directory.listSync();
                            if (entities.isEmpty) {
                              directory.deleteSync(
                                  recursive: true);
                            } else {
                              for (var entity
                              in entities) {
                                if (entity.path
                                    .split("/")
                                    .contains(
                                    "Document")) {
                                  homePageProvider
                                      .removeDocumentImage(
                                      entity
                                          .path);
                                } else if (entity.path
                                    .split("/")
                                    .contains(
                                    "ID Card")) {
                                  homePageProvider
                                      .removeIdCardImage(
                                      entity
                                          .path);
                                } else if (entity.path
                                    .split("/")
                                    .contains(
                                    "QR Code")) {
                                  homePageProvider
                                      .removeQrCode(
                                      entity
                                          .path);
                                } else {
                                  homePageProvider
                                      .removeBarCode(
                                      entity
                                          .path);
                                }
                              }
                              directory.deleteSync(
                                  recursive: true);
                            }
                          }
                        }
                        allFiles = homePageProvider
                            .getFileList(
                            widget.directoryPath);

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
                        duration: const Duration(
                            seconds: 1),
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
                      AppAssets.delete,
                      width:AppHelper.isIpad(context)?35: 24,
                      height:AppHelper.isIpad(context)?35: 24,
                      color: _selectedItems.isNotEmpty
                          ? AppColor.primaryColor
                          : Colors.black,
                    ),
                    Text(
                      translation(context).delete,
                      style: TextStyle(
                          color: _selectedItems
                              .isNotEmpty
                              ? AppColor.primaryColor
                              : Colors.black,
                          fontSize: 12,
                          fontWeight:
                          FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
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
