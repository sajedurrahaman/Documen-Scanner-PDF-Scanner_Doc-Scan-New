import 'dart:io';

import 'package:doc_scanner/home_page/provider/recent_files_provider.dart';
import 'package:doc_scanner/localaization/language_constant.dart';
import 'package:doc_scanner/utils/app_assets.dart';
import 'package:doc_scanner/utils/app_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:pdfx/pdfx.dart';
import 'package:provider/provider.dart';

String _fileName(String path) {
  final parts = path.split(RegExp(r'[/\\]'));
  return parts.isEmpty ? path : parts.last;
}

String _fileNameWithoutExt(String path) {
  final name = _fileName(path);
  final dot = name.lastIndexOf('.');
  if (dot <= 0) return name;
  return name.substring(0, dot);
}

enum TargetDocumentAction { copy, move }

/// Picker shown after Copy/Move from grid selection mode.
class SelectTargetDocumentScreen extends StatefulWidget {
  const SelectTargetDocumentScreen({
    super.key,
    required this.action,
  });

  final TargetDocumentAction action;

  @override
  State<SelectTargetDocumentScreen> createState() =>
      _SelectTargetDocumentScreenState();
}

class _SelectTargetDocumentScreenState
    extends State<SelectTargetDocumentScreen> {
  final _search = TextEditingController();
  bool _searching = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RecentFilesProvider>().load();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<RecentFile> _filtered(List<RecentFile> files) {
    final docs = files
        .where((f) =>
            f.kind == RecentKind.document || f.kind == RecentKind.idCard)
        .toList();
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return docs;
    return docs
        .where((f) => _fileName(f.path).toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final labels = translation(context);
    final recent = context.watch<RecentFilesProvider>();
    final files = _filtered(recent.files);

    return Scaffold(
      backgroundColor: const Color(0xFF131314),
      appBar: AppBar(
        backgroundColor: const Color(0xff1E1F20),
        toolbarHeight: 49,
        titleSpacing: 0,
        leadingWidth: 40,
        leading: IconButton(
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 23),
        ),
        title: _searching
            ? TextField(
                controller: _search,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                cursorColor: AppColor.primaryColor,
                decoration: InputDecoration(
                  hintText: labels.searchHere,
                  hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45), fontSize: 15),
                  border: InputBorder.none,
                  isDense: true,
                ),
                onChanged: (value) => setState(() => _query = value),
              )
            : Text(
                labels.selectATargetDocument,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
        actions: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () {
              setState(() {
                if (_searching) {
                  _searching = false;
                  _query = '';
                  _search.clear();
                } else {
                  _searching = true;
                }
              });
            },
            icon: Icon(
              _searching ? Icons.close : Icons.search,
              color: Colors.white,
              size: 22,
            ),
          ),
        ],
      ),
      body: recent.loading
          ? const Center(child: CircularProgressIndicator())
          : files.isEmpty
              ? Center(
                  child: Text(
                    labels.noResultFound,
                    style: const TextStyle(color: Colors.white70),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: files.length,
                  separatorBuilder: (_, __) => const Divider(
                    height: 1,
                    color: Color(0xFF2A2B2C),
                  ),
                  itemBuilder: (context, index) {
                    final file = files[index];
                    return _TargetDocumentTile(
                      file: file,
                      onTap: () => Navigator.pop(context, file),
                    );
                  },
                ),
    );
  }
}

class _TargetDocumentTile extends StatelessWidget {
  const _TargetDocumentTile({
    required this.file,
    required this.onTap,
  });

  final RecentFile file;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = _fileNameWithoutExt(file.path);
    final lower = file.path.toLowerCase();
    final isPdf = lower.endsWith('.pdf');
    final isImage = lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png');
    final dateLabel =
        DateFormat('dd MMM yyyy, hh:mm a').format(file.modified.toLocal());

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 52,
                height: 64,
                child: isImage
                    ? Image.file(
                        File(file.path),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _fallbackThumb(isPdf),
                      )
                    : _fallbackThumb(isPdf),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FutureBuilder<int>(
                    future: _pageCount(file.path),
                    builder: (context, snap) {
                      final pages = snap.data;
                      final pageText = pages == null
                          ? '…'
                          : '$pages ${translation(context).pages}';
                      return Text(
                        '$dateLabel  ·  $pageText',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallbackThumb(bool isPdf) {
    return ColoredBox(
      color: isPdf ? const Color(0xFFFFEEF1) : const Color(0xFFF3E9FD),
      child: Center(
        child: SvgPicture.asset(
          isPdf ? AppAssets.homePdfThumb : AppAssets.homeImageThumb,
          width: 28,
          height: 28,
        ),
      ),
    );
  }

  Future<int> _pageCount(String path) async {
    final lower = path.toLowerCase();
    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png')) {
      return 1;
    }
    if (!lower.endsWith('.pdf')) return 1;
    try {
      final doc = await PdfDocument.openFile(path);
      final count = doc.pagesCount;
      await doc.close();
      return count;
    } catch (_) {
      return 1;
    }
  }
}
