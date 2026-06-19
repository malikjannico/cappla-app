import 'package:flutter/material.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Align(
        alignment: Alignment.topLeft,
        child: Text('User Settings', key: Key('settings_page')),
      ),
    );
  }
}
