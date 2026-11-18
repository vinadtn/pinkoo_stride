import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/localization/app_locales.dart';
import '../../../../core/localization/locale_cubit.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/theme_cubit.dart';
import '../../../activity_mode/domain/calorie_estimate.dart';
import '../../../backup/presentation/widgets/backup_section.dart';
import '../../../recording/domain/split_alert.dart';
import '../../../map/data/map_style_store.dart';
import '../../../map/domain/map_style_choice.dart';

/// Cài đặt: giao diện, ngôn ngữ, kiểu bản đồ mặc định, cân nặng (để tính calo).
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _storage = sl<LocalStorage>();
  late double _weight = _storage.getDouble(StorageKeys.weightKg) ?? defaultWeightKg;

  late SplitAlertMode _splitAlert = SplitAlertMode.fromId(
    _storage.getString(StorageKeys.splitAlertMode),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.appColors;
    final styleStore = sl<MapStyleStore>();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppDimens.lg),
        children: [
          _Section(title: l10n.appearance),
          SegmentedButton<ThemeMode>(
            segments: [
              ButtonSegment(value: ThemeMode.system, label: Text(l10n.themeSystem)),
              ButtonSegment(value: ThemeMode.light, label: Text(l10n.themeLight)),
              ButtonSegment(value: ThemeMode.dark, label: Text(l10n.themeDark)),
            ],
            selected: {context.watch<ThemeCubit>().state},
            showSelectedIcon: false,
            onSelectionChanged: (s) => context.read<ThemeCubit>().setThemeMode(s.first),
          ),

          const SizedBox(height: AppDimens.xl),
          _Section(title: l10n.language),
          RadioGroup<Locale?>(
            groupValue: context.watch<LocaleCubit>().state,
            onChanged: context.read<LocaleCubit>().setLocale,
            child: Column(
              children: [
                for (final locale in AppLocales.all)
                  RadioListTile<Locale?>(
                    value: locale,
                    title: Text(AppLocales.displayName(locale)),
                  ),
                // null = theo ngôn ngữ thiết bị
                RadioListTile<Locale?>(value: null, title: Text(l10n.languageSystem)),
              ],
            ),
          ),

          const SizedBox(height: AppDimens.xl),
          _Section(title: l10n.mapStyleLabel),
          ValueListenableBuilder<MapStyleChoice>(
            valueListenable: styleStore,
            builder: (context, current, _) => RadioGroup<MapStyleChoice>(
              groupValue: current,
              onChanged: (v) {
                if (v != null) styleStore.select(v);
              },
              child: Column(
                children: [
                  for (final style in MapStyleChoice.values)
                    RadioListTile<MapStyleChoice>(
                      value: style,
                      title: Text(switch (style) {
                        MapStyleChoice.streets => l10n.mapStyleStreets,
                        MapStyleChoice.satellite => l10n.mapStyleSatellite,
                        MapStyleChoice.outdoors => l10n.mapStyleOutdoors,
                        MapStyleChoice.dark => l10n.mapStyleDark,
                      }),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppDimens.xl),
          _Section(title: l10n.profileWeight),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _weight,
                  min: 30,
                  max: 150,
                  divisions: 120,
                  label: '${_weight.round()} ${l10n.profileWeightUnit}',
                  onChanged: (v) => setState(() => _weight = v),
                  onChangeEnd: (v) => _storage.setDouble(StorageKeys.weightKg, v),
                ),
              ),
              SizedBox(
                width: 64,
                child: Text(
                  '${_weight.round()} ${l10n.profileWeightUnit}',
                  textAlign: TextAlign.right,
                  style: context.textTheme.labelLarge,
                ),
              ),
            ],
          ),
          Text(
            'Calo là ước lượng theo công thức MET, không phải số đo.',
            style: context.textTheme.bodySmall?.copyWith(color: c.ink3),
          ),

          const SizedBox(height: AppDimens.xl),
          _Section(title: l10n.splitAlertSection),
          Text(
            l10n.splitAlertHint,
            style: context.textTheme.bodySmall?.copyWith(color: c.ink2),
          ),
          const SizedBox(height: AppDimens.sm),
          SegmentedButton<SplitAlertMode>(
            segments: [
              ButtonSegment(value: SplitAlertMode.off, label: Text(l10n.splitAlertOff)),
              ButtonSegment(
                value: SplitAlertMode.haptic,
                label: Text(l10n.splitAlertHaptic),
              ),
              ButtonSegment(
                value: SplitAlertMode.voice,
                label: Text(l10n.splitAlertVoice),
              ),
            ],
            selected: {_splitAlert},
            showSelectedIcon: false,
            onSelectionChanged: (s) {
              setState(() => _splitAlert = s.first);
              _storage.setString(StorageKeys.splitAlertMode, s.first.id);
            },
          ),
          if (_splitAlert == SplitAlertMode.voice)
            Padding(
              padding: const EdgeInsets.only(top: AppDimens.xs),
              child: Text(
                l10n.splitAlertVoiceNote,
                style: context.textTheme.bodySmall?.copyWith(color: c.ink3),
              ),
            ),

          const SizedBox(height: AppDimens.xl),
          _Section(title: l10n.backupSection),
          const BackupSection(),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppDimens.sm),
    child: Text(
      title.toUpperCase(),
      style: context.textTheme.labelSmall?.copyWith(
        color: context.appColors.ink3,
        letterSpacing: 1.4,
      ),
    ),
  );
}
