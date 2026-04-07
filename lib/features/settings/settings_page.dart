import 'package:flutter/material.dart';
import 'package:ritual/data/models/app_settings.dart';

/// Pantalla base de ajustes globales de Ritual.
///
/// Arranca con preferencias funcionales ya existentes en la app para que el
/// usuario pueda entender y controlar decisiones que antes estaban ocultas en
/// la implementacion.
class SettingsPage extends StatefulWidget {
  final AppSettings initialSettings;

  const SettingsPage({
    super.key,
    required this.initialSettings,
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
            title: 'PlanificaciÃ³n',
            description:
                'Controla reglas globales del dÃ­a para que Ritual se comporte como tÃº prefieres.',
            children: [
              SwitchListTile.adaptive(
                value: warnOnOverlaps,
                contentPadding: EdgeInsets.zero,
                title: const Text('Avisar cuando un bloque se traslapa'),
                subtitle: const Text(
                  'Si lo apagas, Ritual dejarÃ¡ guardar bloques superpuestos sin pedir confirmaciÃ³n.',
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
                title: const Text('Mostrar puntuales completados en PrÃ³ximos'),
                subtitle: const Text(
                  'Ãštil si quieres ver agenda y cierre del dÃ­a en el mismo bloque visual.',
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
                title: const Text('Solicitar permisos automÃ¡ticamente'),
                subtitle: const Text(
                  'Cuando actives push en un bloque, Ritual intentarÃ¡ dejar listo el permiso sin esperar otra acciÃ³n manual.',
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
                'Define cuÃ¡ntos dÃ­as hacia adelante programa Ritual en el dispositivo.',
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
                    label: Text('$days dÃ­as'),
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
            title: 'DirecciÃ³n actual del producto',
            description:
                'Esto no cambia comportamiento todavÃ­a, pero deja clara la filosofÃ­a que estamos siguiendo en esta versiÃ³n.',
            children: const [
              _SettingsNote(
                icon: Icons.schedule_rounded,
                title: 'Todos los bloques deben tener hora',
                description:
                    'Ritual busca estructurar el dÃ­a en el tiempo, no funcionar como lista genÃ©rica de tareas.',
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

