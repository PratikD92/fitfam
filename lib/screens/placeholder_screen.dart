import 'package:flutter/material.dart';
import '../widgets/app_scaffold.dart';

/// Temporary stand-in until each screen is built.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen(this.title, {super.key});
  final String title;

  @override
  Widget build(BuildContext context) => AppScaffold(
        title: title,
        body: Center(child: Text('$title screen coming soon')),
      );
}
