import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'recent_file_actions.dart';
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
  bool _selecting = false;
  bool _busy = false;
  final _mergeName = TextEditingController();
  final Set<String> _selectedPaths = {};

  void _exitSelection() => setState(() {
        _selecting = false;
        _selectedPaths.clear();
      });

  void _toggleSelection(RecentFile file) => setState(() {
        _selecting = true;
        if (!_selectedPaths.add(file.path)) _selectedPaths.remove(file.path);
      });

  @override
  void dispose() {
    _search.dispose();
    _mergeName.dispose();
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

  List<RecentFile> get _selectedFiles {
    final files = context.read<RecentFilesProvider>().files;
    return [
      for (final selected in _selectedPaths)
        ...files.where((file) => file.path == selected)
    ];
  }

  bool get _canMerge {
    final files = _selectedPaths.toList();
    return !_busy &&
        files.length >= 2 &&
        (files.every((file) => path.extension(file).toLowerCase() == '.pdf') ||
            files.every((file) => const {'.jpg', '.jpeg', '.png'}
                .contains(path.extension(file).toLowerCase())));
  }

  Future<void> _runSelected(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) _exitSelection();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('${translation(context).somethingWentWrong}: $error')));
      }
    } finally {
      // Refresh even after a partial filesystem operation.
      try {
        await widget.onRefresh();
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content:
                  Text('${translation(context).somethingWentWrong}: $error')));
        }
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
  }

  Future<void> _deleteSelected() async {
    final files = _selectedPaths.toList();
    final labels = translation(context);
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              title: Text(labels.delete),
              content: Text(labels.areYouSureYouWantToDeleteTheSelectedItems
                  .trim()
                  .replaceAllMapped(
                      RegExp(r'\s+([?؟？])'), (match) => match[1]!)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: Text(labels.cancel)),
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: Text(labels.delete)),
              ],
            ));
    if (confirmed != true || !mounted) return;
    await _runSelected(() async {
      for (final file in files) {
        if (await File(file).exists()) await File(file).delete();
      }
    });
  }

  Future<void> _shareSelected() async {
    final files = _selectedFiles;
    final box = context.findRenderObject() as RenderBox?;
    await _runSelected(() async {
      if (files.length == 1) {
        await widget.onShare(files.single);
      } else {
        await SharePlus.instance.share(ShareParams(
          files: files.map((file) => XFile(file.path)).toList(),
          sharePositionOrigin:
              box == null ? null : box.localToGlobal(Offset.zero) & box.size,
        ));
      }
    });
  }

  Future<void> _mergeSelected() async {
    if (!_canMerge) return;
    final files = _selectedPaths.toList();
    final labels = translation(context);
    final form = GlobalKey<FormState>();
    _mergeName.clear();
    final name = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              title: Text(labels.renameFile,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w500)),
              content: Form(
                  key: form,
                  child: TextFormField(
                    controller: _mergeName,
                    autofocus: true,
                    decoration: InputDecoration(
                        hintText: labels.enterFileName,
                        border: const OutlineInputBorder(),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 10)),
                    validator: (value) {
                      final name = value?.trim() ?? '';
                      if (name.isEmpty ||
                          name == '.' ||
                          name == '..' ||
                          name.toLowerCase() == '.pdf' ||
                          name.contains(RegExp(r'[/\\\x00-\x1F]'))) {
                        return labels.pleaseEnterFileName;
                      }
                      return null;
                    },
                  )),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: Text(labels.cancel)),
                TextButton(
                    onPressed: () {
                      if (form.currentState!.validate()) {
                        Navigator.pop(dialogContext, _mergeName.text.trim());
                      }
                    },
                    child: Text(labels.ok)),
              ],
            ));
    if (name == null || !mounted) return;
    await _runSelected(() async {
      await mergeRecentFiles(
          files,
          name.toLowerCase().endsWith('.pdf')
              ? name.substring(0, name.length - 4)
              : name);
    });
  }

  Future<void> _moveSelected() async {
    final files = _selectedFiles;
    final labels = translation(context);
    String? destination;
    // Keep each file in its category so it remains discoverable by Recents.
    setState(() => _busy = true);
    try {
      final root = await getApplicationDocumentsDirectory();
      const categories = {
        RecentKind.document: 'Document',
        RecentKind.idCard: 'ID Card',
        RecentKind.qr: 'QR Code',
        RecentKind.barcode: 'Bar Code',
      };
      final category = Directory(
          path.join(root.path, 'Doc Scanner', categories[files.first.kind]!));
      final directories = [category.path];
      await for (final entry
          in category.list(recursive: true, followLinks: false)) {
        if (entry is Directory) directories.add(entry.path);
      }
      directories.removeWhere((directory) => files
          .every((file) => path.equals(path.dirname(file.path), directory)));
      directories.sort();
      if (!mounted) return;
      destination = await showModalBottomSheet<String>(
        context: context,
        useSafeArea: true,
        builder: (sheetContext) => SafeArea(
            child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .5,
          child: Column(children: [
            Padding(
                padding: const EdgeInsets.all(16),
                child: Text(labels.move,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600))),
            Expanded(
                child: directories.isEmpty
                    ? Center(child: Text(labels.noFilesHereYet))
                    : ListView(children: [
                        for (final directory in directories)
                          ListTile(
                            leading: const Icon(Icons.folder, color: _blue),
                            title: Text(path.equals(directory, category.path)
                                ? path.basename(category.path)
                                : path.relative(directory,
                                    from: category.path)),
                            onTap: () => Navigator.pop(sheetContext, directory),
                          )
                      ])),
          ]),
        )),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${labels.somethingWentWrong}: $error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (destination == null || !mounted) return;
    await _runSelected(() =>
        moveRecentFiles(files.map((file) => file.path).toList(), destination!));
  }

  Widget _selectionBar() {
    final labels = translation(context);
    final files = _selectedFiles;
    final enabled = !_busy && files.isNotEmpty;
    Widget action(String label, String asset, VoidCallback? onPressed) =>
        Expanded(
          child: TextButton(
              onPressed: onPressed,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                SvgPicture.asset(asset,
                    width: 24,
                    height: 24,
                    colorFilter: ColorFilter.mode(
                        onPressed == null ? Colors.grey : _ink,
                        BlendMode.srcIn)),
                const SizedBox(height: 4),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12)),
              ])),
        );
    return Material(
        color: Colors.white,
        elevation: 8,
        child: SafeArea(
          top: false,
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
              child: Row(children: [
                action(
                    labels.move,
                    AppAssets.move,
                    enabled &&
                            files.every((file) => file.kind == files.first.kind)
                        ? _moveSelected
                        : null),
                action(labels.share, AppAssets.shareWithFriend,
                    enabled ? _shareSelected : null),
                action(labels.merge, AppAssets.merge,
                    _canMerge ? _mergeSelected : null),
                action(labels.delete, AppAssets.delete,
                    enabled ? _deleteSelected : null),
              ])),
        ));
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
    // Selection stays within the visible filter/search results and drops removed files.
    _selectedPaths.retainAll(files.map((file) => file.path));
    final allSelected =
        files.isNotEmpty && _selectedPaths.length == files.length;
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

    return PopScope(
      canPop: !_selecting && !_busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selecting && !_busy) _exitSelection();
      },
      child: Stack(children: [
        AbsorbPointer(
            absorbing: _busy,
            child: Scaffold(
              bottomNavigationBar: _selecting ? _selectionBar() : null,
              backgroundColor: _blue,
              appBar: AppBar(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
                elevation: 0,
                scrolledUnderElevation: 0,
                systemOverlayStyle: SystemUiOverlayStyle.light,
                leading: _selecting
                    ? IconButton(
                        tooltip: labels.cancel,
                        icon: const Icon(Icons.close),
                        onPressed: _exitSelection,
                      )
                    : null,
                title: _selecting
                    ? Text(_selectedPaths.isEmpty
                        ? labels.select
                        : '${_selectedPaths.length} ${labels.selected}')
                    : _searching
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
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w600)),
                actions: [
                  if (_selecting)
                    TextButton(
                      style:
                          TextButton.styleFrom(foregroundColor: Colors.white),
                      onPressed: files.isEmpty
                          ? null
                          : () => setState(() {
                                _selectedPaths.clear();
                                if (!allSelected) {
                                  _selectedPaths
                                      .addAll(files.map((file) => file.path));
                                }
                              }),
                      child: Text(
                          allSelected ? labels.deselectAll : labels.selectAll),
                    )
                  else
                    IconButton(
                      tooltip: _searching ? labels.cancel : labels.search,
                      icon: _searching
                          ? const Icon(Icons.close, size: 28)
                          : SvgPicture.asset(AppAssets.search,
                              width: 28, height: 28),
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
                  padding: const EdgeInsets.only(top: 14),
                  child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(28)),
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
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 2),
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
                                    labelPadding: const EdgeInsets.symmetric(
                                        horizontal: 2),
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
                                          builder: (context, constraints) =>
                                              ListView(
                                                physics:
                                                    const AlwaysScrollableScrollPhysics(),
                                                children: [
                                                  SizedBox(
                                                      height:
                                                          constraints.maxHeight,
                                                      child: Center(
                                                        child: Text(
                                                            query.isEmpty &&
                                                                    _category ==
                                                                        null
                                                                ? labels
                                                                    .noFilesHereYet
                                                                : labels
                                                                    .noResultFound,
                                                            style:
                                                                const TextStyle(
                                                                    color:
                                                                        _ink)),
                                                      ))
                                                ],
                                              ))
                                      : ListView.separated(
                                          keyboardDismissBehavior:
                                              ScrollViewKeyboardDismissBehavior
                                                  .onDrag,
                                          physics:
                                              const AlwaysScrollableScrollPhysics(),
                                          padding: EdgeInsets.fromLTRB(
                                              20,
                                              0,
                                              20,
                                              MediaQuery.paddingOf(context)
                                                      .bottom +
                                                  12),
                                          itemCount: files.length,
                                          separatorBuilder: (_, __) =>
                                              const Padding(
                                            padding: EdgeInsetsDirectional.only(
                                                start: 74),
                                            child: Divider(
                                                height: 1,
                                                color: Color(0xFFE0E8F5)),
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
            )),
        if (_busy)
          const Positioned.fill(
              child: ColoredBox(
            color: Color(0x33000000),
            child: Center(child: CircularProgressIndicator()),
          )),
      ]),
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
      onTap: () =>
          _selecting ? _toggleSelection(file) : _perform(widget.onOpen, file),
      onLongPress: () {
        FocusScope.of(context).unfocus();
        _toggleSelection(file);
      },
      child: ColoredBox(
        color: _selectedPaths.contains(file.path)
            ? const Color(0xFFE3EDFD)
            : Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(children: [
            if (_selecting)
              SizedBox(
                width: 32,
                child: Checkbox(
                  value: _selectedPaths.contains(file.path),
                  shape: const CircleBorder(),
                  activeColor: _blue,
                  onChanged: (_) => _toggleSelection(file),
                ),
              ),
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
            if (!_selecting)
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
                            SvgPicture.asset(icons[index],
                                width: 18, height: 18),
                            const SizedBox(width: 12),
                            Text(actionLabels[index]),
                          ]),
                        )),
              ),
          ]),
        ),
      ),
    );
  }
}
