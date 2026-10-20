import 'dart:io';

import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:path/path.dart' as path;

import '../localaization/language_constant.dart';

class RecentFileRenameDialog extends StatefulWidget {
  const RecentFileRenameDialog({super.key, required this.filePath});

  final String filePath;

  @override
  State<RecentFileRenameDialog> createState() => _RecentFileRenameDialogState();
}

class _RecentFileRenameDialogState extends State<RecentFileRenameDialog> {
  late final _controller = TextEditingController(
    text: path.basenameWithoutExtension(widget.filePath),
  );
  final _formKey = GlobalKey<FormState>();
  String? _errorMessage;
  bool _saving = false;

  @override
  void dispose() {
    // Keep the controller alive throughout the dialog's exit animation.
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final newPath = path.join(
      File(widget.filePath).parent.path,
      '${_controller.text.trim()}${path.extension(widget.filePath)}',
    );
    if (newPath == widget.filePath) {
      Navigator.pop(context, false);
      return;
    }
    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      final exists = await File(newPath).exists();
      if (!mounted) return;
      if (exists) {
        setState(() => _errorMessage = translation(context).fileAlreadyExists);
        return;
      }
      await File(widget.filePath).rename(newPath);
      if (mounted) Navigator.pop(context, true);
    } on FileSystemException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final labels = translation(context);
    return AlertDialog(
      constraints: BoxConstraints.tightFor(
        width: MediaQuery.sizeOf(context).shortestSide >= 600 ? 398 : 348,
      ),
      title: Text(labels.renameFile,
          style: const TextStyle(
              color: Colors.black, fontSize: 16, fontWeight: FontWeight.w500)),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          readOnly: _saving,
          textInputAction: TextInputAction.done,
          validator: (value) => value == null || value.trim().isEmpty
              ? labels.pleaseEnterFileName
              : null,
          decoration: InputDecoration(
            hintText: labels.enterFileName,
            errorText: _errorMessage,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: Text(labels.cancel),
        ),
        TextButton(
          onPressed: _saving ? null : _save,
          child: Text(labels.save),
        ),
      ],
    );
  }
}
