import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

class DataScreen extends StatelessWidget {
  const DataScreen({super.key});

  Future<void> _export(BuildContext context) async {
    final state = context.read<AppState>();
    try {
      final json = const JsonEncoder.withIndent('  ')
          .convert(state.exportData());
      final dir = await getTemporaryDirectory();
      final name =
          'plotshot-backup-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.json';
      final file = File(p.join(dir.path, name));
      await file.writeAsString(json);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/json')],
          subject: 'PlotShot backup',
        ),
      );
    } catch (e) {
      if (context.mounted) showSnack(context, 'Export failed: $e');
    }
  }

  Future<void> _import(BuildContext context) async {
    final state = context.read<AppState>();
    try {
      final files = await FilePicker.pickFiles(type: FileType.any);
      if (files.isEmpty) return;
      final text = utf8.decode(await files.first.readAsBytes());
      final json = Map<String, Object?>.from(jsonDecode(text) as Map);
      if (!context.mounted) return;
      final counts =
          '${(json['jabs'] as List?)?.length ?? 0} jabs and '
          '${(json['weights'] as List?)?.length ?? 0} weights';
      final ok = await confirm(
        context,
        'Replace all data?',
        'This backup has $counts. Importing replaces everything currently '
            'in PlotShot.',
        action: 'Import',
      );
      if (!ok) return;
      await state.importData(json);
      if (context.mounted) showSnack(context, 'Backup imported');
    } on FormatException catch (e) {
      if (context.mounted) showSnack(context, e.message);
    } catch (e) {
      if (context.mounted) showSnack(context, 'Import failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Manage My Data')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            'Everything is stored only on this phone: ${state.jabs.length} '
            'jabs, ${state.weights.length} weights and '
            '${state.dayLogs.length} daily logs. Export a backup regularly '
            'and keep it somewhere safe (Drive, email, etc.). Uninstalling '
            'the app deletes your data.',
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.upload_file),
                  title: const Text('Export backup'),
                  subtitle: const Text('Save or send a JSON file'),
                  onTap: () => _export(context),
                ),
                const Divider(indent: 56),
                ListTile(
                  leading: const Icon(Icons.download),
                  title: const Text('Import backup'),
                  subtitle: const Text('Replace all data from a backup file'),
                  onTap: () => _import(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
