import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritual/data/models/app_settings.dart';
import 'package:ritual/data/services/app_backup_service.dart';
import 'package:ritual/data/services/routine_csv_service.dart';

/// Pantalla base de ajustes globales de Ritual.
///
/// Arranca con preferencias funcionales ya existentes en la app para que el
/// usuario pueda entender y controlar decisiones que antes estaban ocultas en
/// la implementacion. Tambien sirve como punto inicial para respaldo manual de
/// la biblioteca de rutinas.
class SettingsPage extends StatefulWidget {
  final AppSettings initialSettings;
  final Future<RoutineCsvExportData> Function()? onBuildRoutineCsvExport;
  final Future<RoutineCsvImportData> Function(
    String csv,
    RoutineCsvImportMode mode,
  )? onImportRoutineCsv;
  final Future<AppBackupExportData> Function()? onBuildAppBackupExport;
  final Future<AppBackupImportData> Function(String json)? onImportAppBackup;

  const SettingsPage({
    super.key,
    required this.initialSettings,
    this.onBuildRoutineCsvExport,
    this.onImportRoutineCsv,
    this.onBuildAppBackupExport,
    this.onImportAppBackup,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late bool warnOnOverlaps;
  late bool autoRequestNotificationPermissions;
  late int notificationHorizonDays;
  late bool showCompletedDatedEventsInUpcoming;

  static const List<int> _horizonOptions = [7, 14, 21, 30];

  @override
  void initState() {
    super.initState();
    warnOnOverlaps = widget.initialSettings.warnOnOverlaps;
    autoRequestNotificationPermissions =
        widget.initialSettings.autoRequestNotificationPermissions;
    notificationHorizonDays = widget.initialSettings.notificationHorizonDays;
    showCompletedDatedEventsInUpcoming =
        widget.initialSettings.showCompletedDatedEventsInUpcoming;
  }

  AppSettings get currentSettings => AppSettings(
        warnOnOverlaps: warnOnOverlaps,
        autoRequestNotificationPermissions:
            autoRequestNotificationPermissions,
        notificationHorizonDays: notificationHorizonDays,
        showCompletedDatedEventsInUpcoming:
            showCompletedDatedEventsInUpcoming,
      );

  Future<void> openRoutineCsvExportDialog() async {
    final buildExport = widget.onBuildRoutineCsvExport;
    if (buildExport == null) return;

    final exportData = await buildExport();
    if (!mounted) return;

    final controller = TextEditingController(text: exportData.csv);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Exportar rutinas a CSV'),
          content: SizedBox(
            width: 640,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Este respaldo es compatible con Excel e incluye ${formatRoutineLibrarySummary(exportData.routineCount, exportData.blockCount)}.',
                ),
                const SizedBox(height: 8),
                const Text(
                  'No incluye historial diario ni eventos puntuales. Sirve para mover o restaurar tu biblioteca de rutinas.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  readOnly: true,
                  maxLines: 14,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                    labelText: 'CSV exportado',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cerrar'),
            ),
            FilledButton.tonalIcon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: exportData.csv));
                if (!dialogContext.mounted) return;

                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('CSV copiado al portapapeles.'),
                  ),
                );
              },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copiar'),
            ),
          ],
        );
      },
    );

    controller.dispose();
  }

  Future<void> openRoutineCsvImportDialog() async {
    final importCsv = widget.onImportRoutineCsv;
    if (importCsv == null) return;

    var initialCsv = '';
    var initialMode = RoutineCsvImportMode.merge;
    String? errorMessage;

    while (mounted) {
      final request = await showRoutineCsvImportDialog(
        initialCsv: initialCsv,
        initialMode: initialMode,
        errorMessage: errorMessage,
      );

      if (request == null) return;

      try {
        final importedData = await importCsv(request.csv, request.mode);
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Importacion lista: ${formatRoutineLibrarySummary(importedData.routineCount, importedData.blockCount)}.',
            ),
          ),
        );
        return;
      } on FormatException catch (error) {
        initialCsv = request.csv;
        initialMode = request.mode;
        errorMessage = error.message;
      }
    }
  }

  Future<void> openAppBackupExportDialog() async {
    final buildBackup = widget.onBuildAppBackupExport;
    if (buildBackup == null) return;

    final exportData = await buildBackup();
    if (!mounted) return;

    final controller = TextEditingController(text: exportData.json);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Exportar backup completo'),
          content: SizedBox(
            width: 640,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Incluye ${formatFullBackupSummary(exportData.routineCount, exportData.dailyRecordCount, exportData.datedBlockCount)}.',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Este respaldo sirve para restaurar la app completa en otra instalacion, conservando biblioteca, historial, eventos puntuales y ajustes.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  readOnly: true,
                  maxLines: 14,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                    labelText: 'JSON exportado',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cerrar'),
            ),
            FilledButton.tonalIcon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: exportData.json));
                if (!dialogContext.mounted) return;

                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('Backup copiado al portapapeles.'),
                  ),
                );
              },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copiar'),
            ),
          ],
        );
      },
    );

    controller.dispose();
  }

  Future<void> openAppBackupImportDialog() async {
    final importBackup = widget.onImportAppBackup;
    if (importBackup == null) return;

    var initialJson = '';
    String? errorMessage;

    while (mounted) {
      final request = await showAppBackupImportDialog(
        initialJson: initialJson,
        errorMessage: errorMessage,
      );

      if (request == null) return;

      try {
        final importedData = await importBackup(request);
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Backup restaurado: ${formatFullBackupSummary(importedData.routineCount, importedData.dailyRecordCount, importedData.datedBlockCount)}.',
            ),
          ),
        );
        return;
      } on FormatException catch (error) {
        initialJson = request;
        errorMessage = error.message;
      }
    }
  }

  Future<String?> showAppBackupImportDialog({
    String initialJson = '',
    String? errorMessage,
  }) {
    final controller = TextEditingController(text: initialJson);

    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Importar backup completo'),
          content: SizedBox(
            width: 640,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pega aqui el JSON exportado por Ritual para restaurar biblioteca, historial, eventos puntuales y ajustes.',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Este proceso reemplaza el estado local actual de la app.',
                ),
                const SizedBox(height: 12),
                if (errorMessage != null) ...[
                  Text(
                    errorMessage,
                    style: Theme.of(dialogContext).textTheme.bodySmall
                        ?.copyWith(
                          color: Theme.of(dialogContext).colorScheme.error,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: controller,
                  minLines: 8,
                  maxLines: 14,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                    labelText: 'JSON a importar',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(controller.text.trim());
              },
              child: const Text('Restaurar'),
            ),
          ],
        );
      },
    ).whenComplete(controller.dispose);
  }

  Future<_RoutineCsvImportRequest?> showRoutineCsvImportDialog({
    String initialCsv = '',
    RoutineCsvImportMode initialMode = RoutineCsvImportMode.merge,
    String? errorMessage,
  }) {
    final controller = TextEditingController(text: initialCsv);
    var selectedMode = initialMode;

    return showDialog<_RoutineCsvImportRequest>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Importar rutinas desde CSV'),
              content: SizedBox(
                width: 640,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pega aqui el CSV exportado por Ritual o una version editada en Excel con las mismas columnas.',
                    ),
                    const SizedBox(height: 12),
                    if (errorMessage != null) ...[
                      Text(
                        errorMessage,
                        style: Theme.of(dialogContext).textTheme.bodySmall
                            ?.copyWith(
                              color: Theme.of(dialogContext).colorScheme.error,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: controller,
                      minLines: 8,
                      maxLines: 14,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                        labelText: 'CSV a importar',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Modo de importacion',
                      style: Theme.of(dialogContext).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<RoutineCsvImportMode>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: RoutineCsvImportMode.merge,
                          icon: Icon(Icons.library_add_rounded),
                          label: Text('Agregar'),
                        ),
                        ButtonSegment(
                          value: RoutineCsvImportMode.replace,
                          icon: Icon(Icons.sync_alt_rounded),
                          label: Text('Reemplazar'),
                        ),
                      ],
                      selected: {selectedMode},
                      onSelectionChanged: (selection) {
                        if (selection.isEmpty) return;
                        final nextMode = selection.first;

                        setDialogState(() {
                          selectedMode = nextMode;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      selectedMode == RoutineCsvImportMode.merge
                          ? 'Conserva las rutinas actuales y suma las importadas como nuevas plantillas.'
                          : 'Sustituye la biblioteca actual por la importada. No borra historial pasado.',
                      style: Theme.of(dialogContext).textTheme.bodySmall
                          ?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(
                      _RoutineCsvImportRequest(
                        csv: controller.text.trim(),
                        mode: selectedMode,
                      ),
                    );
                  },
                  child: const Text('Importar'),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(controller.dispose);
  }

  String formatRoutineLibrarySummary(int routineCount, int blockCount) {
    final routineLabel = routineCount == 1 ? '1 rutina' : '$routineCount rutinas';
    final blockLabel = blockCount == 1 ? '1 bloque' : '$blockCount bloques';
    return '$routineLabel y $blockLabel';
  }

  String formatFullBackupSummary(
    int routineCount,
    int dailyRecordCount,
    int datedBlockCount,
  ) {
    final routinesLabel =
        routineCount == 1 ? '1 rutina' : '$routineCount rutinas';
    final historyLabel =
        dailyRecordCount == 1 ? '1 dia de historial' : '$dailyRecordCount dias de historial';
    final eventsLabel = datedBlockCount == 1
        ? '1 evento puntual'
        : '$datedBlockCount eventos puntuales';

    return '$routinesLabel, $historyLabel y $eventsLabel';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajustes'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.tonal(
              onPressed: () => Navigator.of(context).pop(currentSettings),
              child: const Text('Guardar'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _SettingsSection(
            title: 'Planificacion',
            description:
                'Controla reglas globales del dia para que Ritual se comporte como tu prefieres.',
            children: [
              SwitchListTile.adaptive(
                value: warnOnOverlaps,
                contentPadding: EdgeInsets.zero,
                title: const Text('Avisar cuando un bloque se traslapa'),
                subtitle: const Text(
                  'Si lo apagas, Ritual dejara guardar bloques superpuestos sin pedir confirmacion.',
                ),
                onChanged: (value) {
                  setState(() {
                    warnOnOverlaps = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                value: showCompletedDatedEventsInUpcoming,
                contentPadding: EdgeInsets.zero,
                title: const Text('Mostrar puntuales completados en Proximos'),
                subtitle: const Text(
                  'Util si quieres ver agenda y cierre del dia en el mismo bloque visual.',
                ),
                onChanged: (value) {
                  setState(() {
                    showCompletedDatedEventsInUpcoming = value;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SettingsSection(
            title: 'Notificaciones',
            description:
                'Ajustes globales para la agenda local del dispositivo.',
            children: [
              SwitchListTile.adaptive(
                value: autoRequestNotificationPermissions,
                contentPadding: EdgeInsets.zero,
                title: const Text('Solicitar permisos automaticamente'),
                subtitle: const Text(
                  'Cuando actives push en un bloque, Ritual intentara dejar listo el permiso sin esperar otra accion manual.',
                ),
                onChanged: (value) {
                  setState(() {
                    autoRequestNotificationPermissions = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Horizonte de recordatorios',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Define cuantos dias hacia adelante programa Ritual en el dispositivo.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _horizonOptions.map((days) {
                  final isSelected = days == notificationHorizonDays;

                  return ChoiceChip(
                    selected: isSelected,
                    label: Text('$days dias'),
                    onSelected: (_) {
                      setState(() {
                        notificationHorizonDays = days;
                      });
                    },
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SettingsSection(
            title: 'Respaldo de rutinas',
            description:
                'Exporta o importa la biblioteca en CSV compatible con Excel para moverla entre instalaciones o PCs.',
            children: [
              const _SettingsNote(
                icon: Icons.backup_table_rounded,
                title: 'Incluye biblioteca, no historial',
                description:
                    'Se exportan nombre, vigencia y bloques de cada rutina. El historial diario sigue siendo local por ahora.',
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: widget.onBuildRoutineCsvExport == null
                        ? null
                        : openRoutineCsvExportDialog,
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Exportar CSV'),
                  ),
                  OutlinedButton.icon(
                    onPressed: widget.onImportRoutineCsv == null
                        ? null
                        : openRoutineCsvImportDialog,
                    icon: const Icon(Icons.upload_file_rounded),
                    label: const Text('Importar CSV'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SettingsSection(
            title: 'Backup completo',
            description:
                'Respaldo total de la app para restaurar Ritual con historial, eventos puntuales y ajustes incluidos.',
            children: [
              const _SettingsNote(
                icon: Icons.data_object_rounded,
                title: 'JSON versionado',
                description:
                    'Este formato no esta pensado para Excel. Sirve para continuidad real entre instalaciones y futuras APKs.',
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: widget.onBuildAppBackupExport == null
                        ? null
                        : openAppBackupExportDialog,
                    icon: const Icon(Icons.save_alt_rounded),
                    label: const Text('Exportar backup'),
                  ),
                  OutlinedButton.icon(
                    onPressed: widget.onImportAppBackup == null
                        ? null
                        : openAppBackupImportDialog,
                    icon: const Icon(Icons.restore_rounded),
                    label: const Text('Importar backup'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SettingsSection(
            title: 'Direccion actual del producto',
            description:
                'Esto no cambia comportamiento todavia, pero deja clara la filosofia que estamos siguiendo en esta version.',
            children: const [
              _SettingsNote(
                icon: Icons.schedule_rounded,
                title: 'Todos los bloques deben tener hora',
                description:
                    'Ritual busca estructurar el dia en el tiempo, no funcionar como lista generica de tareas.',
              ),
              SizedBox(height: 12),
              _SettingsNote(
                icon: Icons.view_timeline_rounded,
                title: 'Rutina base + eventos puntuales',
                description:
                    'Los eventos por fecha sirven para excepciones reales sin destruir la plantilla principal.',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoutineCsvImportRequest {
  final String csv;
  final RoutineCsvImportMode mode;

  const _RoutineCsvImportRequest({
    required this.csv,
    required this.mode,
  });
}

/// Agrupa visualmente opciones relacionadas dentro de Ajustes.
class _SettingsSection extends StatelessWidget {
  final String title;
  final String description;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.description,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

/// Nota informativa simple para decisiones de producto visibles al usuario.
class _SettingsNote extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _SettingsNote({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
