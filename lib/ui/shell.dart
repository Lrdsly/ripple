import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import 'fixed_page.dart';
import 'home_page.dart';
import 'removed_page.dart';

/// Root scaffold: sections always one tap away, no discovery needed.
class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final folder = context.watch<AppState>().folder;
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          const HomePage(),
          const FixedPage(),
          folder == null
              ? _NoFolder(
                  key: const ValueKey('no-folder'),
                  onPick: _pickFolder,
                )
              : RemovedPage(
                  key: ValueKey(folder),
                  folder: folder,
                ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (v) => setState(() => _index = v),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'خانه',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_repeat_outlined),
            selectedIcon: Icon(Icons.event_repeat),
            label: 'ثابت‌ها',
          ),
          NavigationDestination(
            icon: Icon(Icons.delete_outline),
            selectedIcon: Icon(Icons.delete),
            label: 'حذف‌شده‌ها',
          ),
        ],
      ),
    );
  }

  Future<void> _pickFolder() async {
    final p = await FilePicker.platform.getDirectoryPath();
    if (p == null || !mounted) return;
    await context.read<AppState>().setFolder(p);
  }
}

class _NoFolder extends StatelessWidget {
  final VoidCallback onPick;
  const _NoFolder({super.key, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('حذف‌شده‌ها')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open,
                size: 56, color: cs.onSurfaceVariant),
            const SizedBox(height: 12),
            const Text('اول پوشه یادداشت‌ها را انتخاب کنید'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onPick,
              child: const Text('انتخاب پوشه'),
            ),
          ],
        ),
      ),
    );
  }
}
