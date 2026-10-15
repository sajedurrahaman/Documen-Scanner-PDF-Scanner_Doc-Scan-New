import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
// ignore: depend_on_referenced_packages
import 'package:path/path.dart' as path;

import '../localaization/language_constant.dart';
import '../utils/app_assets.dart';
import 'provider/recent_files_provider.dart';

/// Uses the same files and actions as Home, without limiting the list length.
class RecentFileSeeAllScreen extends StatefulWidget {
  const RecentFileSeeAllScreen({
    super.key,
    required this.onOpen,
    required this.onRename,
    required this.onDownload,
    required this.onShare,
    required this.onDelete,
    required this.onRefresh,
    required this.timeAgo,
    required this.sizeLabel,
  });

  final Future<void> Function(RecentFile) onOpen;
  final Future<void> Function(RecentFile) onRename;
  final Future<void> Function(RecentFile) onDownload;
  final Future<void> Function(RecentFile) onShare;
  final Future<void> Function(RecentFile) onDelete;
  final Future<void> Function() onRefresh;
  final String Function(DateTime) timeAgo;
  final String Function(int) sizeLabel;

  @override
  State<RecentFileSeeAllScreen> createState() => _RecentFileSeeAllScreenState();
}

class _RecentFileSeeAllScreenState extends State<RecentFileSeeAllScreen> {
  static const _blue = Color(0xFF1C58BE);
  static const _ink = Color(0xFF0D2C66);
  static const _surface = Color(0xFFF4F7FC);
  final _search = TextEditingController();
  RecentKind? _category;
  bool _searching = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _perform(
      Future<void> Function(RecentFile) action, RecentFile file) async {
    try {
      await action(file);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final labels = translation(context);
    final provider = context.watch<RecentFilesProvider>();
    final query = _search.text.trim().toLowerCase();
    final files = provider.files
        .where((file) =>
            (_category == null || file.kind == _category) &&
            path.basename(file.path).toLowerCase().contains(query))
        .toList();
    final filters = <RecentKind?, String>{
      null: MaterialLocalizations.of(context).selectAllButtonLabel,
      RecentKind.document: labels.document,
      RecentKind.idCard: labels.idCard,
      RecentKind.qr: labels.qrCode,
      RecentKind.barcode: labels.barCode,
    };
    // The compact English label matches the design; other locales use Flutter's translation.
    if (Localizations.localeOf(context).languageCode == 'en') {
      filters[null] = 'All';
    }

    return Scaffold(
      backgroundColor: _blue,
      appBar: AppBar(
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: _searching
            ? TextField(
                controller: _search,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                cursorColor: Colors.white,
                decoration: InputDecoration(
                  hintText: labels.searchHere,
                  hintStyle: const TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
                onChanged: (_) => setState(() {}),
              )
            : Text(labels.recentFiles,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            tooltip: _searching ? labels.cancel : labels.search,
            icon: Icon(_searching ? Icons.close : Icons.search, size: 28),
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) {
                _search.clear();
                FocusScope.of(context).unfocus();
              }
            }),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: ColoredBox(
              color: _surface,
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                  child: Row(
                    children: filters.entries.map((filter) {
                      final selected = _category == filter.key;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: ChoiceChip(
                            label: SizedBox(
                              width: double.infinity,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(filter.value),
                              ),
                            ),
                            selected: selected,
                            showCheckmark: false,
                            onSelected: (_) =>
                                setState(() => _category = filter.key),
                            backgroundColor: Colors.white,
                            selectedColor: _blue,
                            labelStyle: TextStyle(
                              color: selected ? Colors.white : _ink,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                            labelPadding:
                                const EdgeInsets.symmetric(horizontal: 2),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 2, vertical: 6),
                            side: BorderSide(
                              color: selected
                                  ? const Color(0xFFD4E2FA)
                                  : const Color(0xFFE1E5ED),
                            ),
                            shape: const StadiumBorder(),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                Expanded(
                  child: provider.loading
                      ? const Center(child: CircularProgressIndicator())
                      : RefreshIndicator(
                          onRefresh: widget.onRefresh,
                          child: files.isEmpty
                              ? LayoutBuilder(
                                  builder: (context, constraints) => ListView(
                                        physics:
                                            const AlwaysScrollableScrollPhysics(),
                                        children: [
                                          SizedBox(
                                              height: constraints.maxHeight,
                                              child: Center(
                                                child: Text(
                                                    query.isEmpty &&
                                                            _category == null
                                                        ? labels.noFilesHereYet
                                                        : labels.noResultFound,
                                                    style: const TextStyle(
                                                        color: _ink)),
                                              ))
                                        ],
                                      ))
                              : ListView.separated(
                                  keyboardDismissBehavior:
                                      ScrollViewKeyboardDismissBehavior.onDrag,
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: EdgeInsets.fromLTRB(
                                      20,
                                      0,
                                      20,
                                      MediaQuery.paddingOf(context).bottom +
                                          12),
                                  itemCount: files.length,
                                  separatorBuilder: (_, __) => const Padding(
                                    padding:
                                        EdgeInsetsDirectional.only(start: 74),
                                    child: Divider(
                                        height: 1, color: Color(0xFFE0E8F5)),
                                  ),
                                  itemBuilder: (context, index) =>
                                      _fileTile(files[index]),
                                ),
                        ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fileTile(RecentFile file) {
    final labels = translation(context);
    final extension =
        path.extension(file.path).replaceFirst('.', '').toUpperCase();
    final pdf = extension == 'PDF';
    final code = file.kind == RecentKind.qr || file.kind == RecentKind.barcode;
    final actions = [
      widget.onRename,
      widget.onDownload,
      widget.onShare,
      widget.onDelete
    ];
    final actionLabels = [
      labels.renameFile,
      labels.downloadFile,
      labels.share,
      labels.delete
    ];
    final icons = [
      AppAssets.recentMenuRename,
      AppAssets.recentMenuDownload,
      AppAssets.recentMenuShare,
      AppAssets.recentMenuDelete
    ];
    return InkWell(
      key: ValueKey(file.path),
      onTap: () => _perform(widget.onOpen, file),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: pdf ? const Color(0xFFFFF1F3) : Colors.white,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: const Color(0xFFE0E8F5)),
            ),
            padding: const EdgeInsets.all(10),
            child: SvgPicture.asset(pdf
                ? AppAssets.homePdfThumb
                : code
                    ? AppAssets.homeQrBarThumb
                    : AppAssets.homeImageThumb),
          ),
          const SizedBox(width: 18),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(path.basename(file.path),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(
                    '$extension • ${widget.sizeLabel(file.size)} • ${widget.timeAgo(file.modified)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Color(0xFF7183A2), fontSize: 13)),
              ])),
          PopupMenuButton<int>(
            tooltip: MaterialLocalizations.of(context).showMenuTooltip,
            icon: const Icon(Icons.more_vert, color: Color(0xFF455774)),
            color: Colors.white,
            onSelected: (index) => _perform(actions[index], file),
            itemBuilder: (_) => List.generate(
                actions.length,
                (index) => PopupMenuItem(
                      value: index,
                      child: Row(children: [
                        SvgPicture.asset(icons[index], width: 18, height: 18),
                        const SizedBox(width: 12),
                        Text(actionLabels[index]),
                      ]),
                    )),
          ),
        ]),
      ),
    );
  }
}
