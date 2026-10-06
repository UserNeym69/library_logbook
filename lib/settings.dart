import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'widgets.dart';

enum StudentOrder { name, level, program }

// The choices saved in Settings. They are remembered on this device.
class AppSettings extends ChangeNotifier {
  ThemeMode themeMode = ThemeMode.light;
  StudentOrder studentOrder = StudentOrder.name;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    themeMode =
        p.getString('themeMode') == 'dark' ? ThemeMode.dark : ThemeMode.light;
    final o = p.getString('studentOrder');
    studentOrder = StudentOrder.values
            .where((e) => e.name == o)
            .firstOrNull ??
        StudentOrder.name;
  }

  Future<void> setTheme(ThemeMode m) async {
    themeMode = m;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString('themeMode', m.name);
  }

  Future<void> setOrder(StudentOrder o) async {
    studentOrder = o;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString('studentOrder', o.name);
  }
}

final appSettings = AppSettings();

// The menu that opens from the burger (3 lines) icon.
class AppDrawer extends StatelessWidget {
  final List<Widget> extra;
  const AppDrawer({super.key, this.extra = const []});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            ListTile(
              leading: ClipOval(child: safeImage(logoAsset, width: 40, height: 40)),
              title: const Text('Library Logbook',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('ICCT Taytay Satellite Campus'),
            ),
            const Divider(),
            ...extra,
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static const _orders = {
    StudentOrder.name: ('Name (A to Z)', 'One simple list, no groups.'),
    StudentOrder.level: (
      'Senior High or College',
      'Splits the list into Senior High and College.'
    ),
    StudentOrder.program: (
      'Strand or college',
      'Groups Senior High by strand and College by college.'
    ),
  };

  Widget _label(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appSettings,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _label(context, 'Appearance'),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode_outlined),
                    label: Text('Light')),
                ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode_outlined),
                    label: Text('Dark')),
              ],
              selected: {appSettings.themeMode},
              onSelectionChanged: (s) => appSettings.setTheme(s.first),
            ),
            const SizedBox(height: 24),
            _label(context, 'How the Students list is organized'),
            Card(
              child: Column(
                children: [
                  for (final o in StudentOrder.values)
                    ListTile(
                      title: Text(_orders[o]!.$1),
                      subtitle: Text(_orders[o]!.$2),
                      trailing: appSettings.studentOrder == o
                          ? Icon(Icons.check,
                              color: Theme.of(context).colorScheme.primary)
                          : null,
                      onTap: () => appSettings.setOrder(o),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
