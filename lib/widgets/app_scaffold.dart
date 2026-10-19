import 'package:flutter/material.dart';
import 'discard_dialog.dart';

/// Shared Back / Done pattern.
/// - Back arrow: if [isDirty], asks "Discard changes?" first. Never saves.
/// - Done (optional): the screen saves, then pops.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.showBack = true,
    this.isDirty = false,
    this.onDone,
    this.doneLabel = 'Done',
  });

  final String title;
  final Widget body;
  final bool showBack;
  final bool isDirty;
  final VoidCallback? onDone;
  final String doneLabel;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !isDirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final discard = await showDiscardDialog(context);
        if (discard && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: showBack
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).maybePop(),
                )
              : null,
          title: Text(title),
          actions: [
            if (onDone != null)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: FilledButton(
                  onPressed: onDone,
                  style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 8)),
                  child: Text(doneLabel),
                ),
              ),
          ],
        ),
        body: SafeArea(child: body),
      ),
    );
  }
}
