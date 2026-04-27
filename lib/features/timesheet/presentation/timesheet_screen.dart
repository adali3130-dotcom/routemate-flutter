import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/utils/date_utils.dart';
import '../../../shared/utils/time_utils.dart';
import '../../../shared/widgets/error_widget.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../auth/providers/auth_providers.dart';
import '../domain/timesheet.dart';
import '../providers/timesheet_providers.dart';

class TimesheetScreen extends ConsumerStatefulWidget {
  const TimesheetScreen({super.key});

  @override
  ConsumerState<TimesheetScreen> createState() => _TimesheetScreenState();
}

class _TimesheetScreenState extends ConsumerState<TimesheetScreen> {
  late final String _weekStart;
  late final List<DateTime> _weekDates; // Mon–Fri of current week (UTC)
  late String _selectedDate; // ISO "YYYY-MM-DD"

  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  final _mileageController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isSaving = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _weekStart = currentWeekStart();

    final now = DateTime.now().toUtc();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    _weekDates = List.generate(
      5,
      (i) => DateTime.utc(monday.year, monday.month, monday.day + i),
    );

    // Default to today's chip if it's a weekday (use local time for UI)
    final localWeekday = DateTime.now().weekday; // 1=Mon … 5=Fri, 6–7=weekend
    final defaultIndex =
        (localWeekday >= 1 && localWeekday <= 5) ? localWeekday - 1 : 0;
    _selectedDate = toIsoDate(_weekDates[defaultIndex]);
  }

  @override
  void dispose() {
    _mileageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Form helpers
  // ---------------------------------------------------------------------------

  void _populateFormForDate(Timesheet? timesheet, String date) {
    DailyEntry? entry;
    if (timesheet != null) {
      for (final d in timesheet.days) {
        if (d.date == date) {
          entry = d;
          break;
        }
      }
    }
    setState(() {
      _startTime = (entry != null && entry.startTime.isNotEmpty)
          ? parseTime(entry.startTime)
          : null;
      _endTime = (entry != null && entry.endTime.isNotEmpty)
          ? parseTime(entry.endTime)
          : null;
      _mileageController.text =
          (entry != null && entry.mileage > 0) ? _fmtMileage(entry.mileage) : '';
      _notesController.text = entry?.notes ?? '';
    });
  }

  String _fmtMileage(double m) =>
      m % 1 == 0 ? m.toInt().toString() : m.toString();

  void _selectDate(String isoDate) {
    final timesheet = ref.read(timesheetProvider).valueOrNull;
    _populateFormForDate(timesheet, isoDate);
    // setState already called inside _populateFormForDate
    setState(() => _selectedDate = isoDate);
  }

  String get _totalTime {
    if (_startTime == null || _endTime == null) return '';
    return computeTotalTime(_startTime!, _endTime!);
  }

  // ---------------------------------------------------------------------------
  // Time pickers
  // ---------------------------------------------------------------------------

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? const TimeOfDay(hour: 8, minute: 0),
      helpText: 'Select start time',
    );
    if (picked != null) setState(() => _startTime = picked);
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime:
          _endTime ?? _startTime ?? const TimeOfDay(hour: 17, minute: 0),
      helpText: 'Select end time',
    );
    if (picked != null) setState(() => _endTime = picked);
  }

  // ---------------------------------------------------------------------------
  // Save entry
  // ---------------------------------------------------------------------------

  Future<void> _save() async {
    if (_startTime == null || _endTime == null) {
      _snack('Please set both start and end times.');
      return;
    }
    final total = _totalTime;
    if (total.isEmpty) {
      _snack('End time must be after start time.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      // company_id must come from token claims — never Firestore
      final user = ref.read(authStateProvider).valueOrNull!;
      final tokenResult = await user.getIdTokenResult(true);
      final companyId = tokenResult.claims?['company_id'] as String? ?? '';
      final driverEmail = user.email ?? '';

      final mileage =
          double.tryParse(_mileageController.text.trim()) ?? 0.0;

      final entry = DailyEntry(
        date: _selectedDate,
        startTime: formatTime(_startTime!),
        endTime: formatTime(_endTime!),
        mileage: mileage,
        totalTime: total,
        notes: _notesController.text.trim(),
      );

      await ref.read(timesheetRepositoryProvider).saveDailyEntry(
            driverEmail: driverEmail,
            weekStart: _weekStart,
            companyId: companyId,
            entry: entry,
          );

      // Reload so ref.listen re-populates the form with confirmed saved data
      ref.invalidate(timesheetProvider);
      _snack('Entry saved.', success: true);
    } catch (e) {
      _snack('Failed to save: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Submit timesheet
  // ---------------------------------------------------------------------------

  Future<void> _submit() async {
    final timesheet = ref.read(timesheetProvider).valueOrNull;
    if (timesheet == null || timesheet.days.isEmpty) {
      _snack('No entries to submit yet. Save at least one day first.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final user = ref.read(authStateProvider).valueOrNull!;
      final idToken = await user.getIdToken();

      await ref.read(timesheetRepositoryProvider).submitTimesheetEmail(
            idToken: idToken!,
            driverEmail: user.email ?? '',
            weekStart: _weekStart,
            days: timesheet.days,
          );

      _snack('Timesheet submitted!', success: true);
    } catch (e) {
      _snack('Submit failed: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _snack(String message, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: success ? Colors.green : null,
    ));
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Populate the form whenever the provider emits fresh data
    // (initial load and after each save/invalidation)
    ref.listen<AsyncValue<Timesheet?>>(timesheetProvider, (prev, next) {
      if (next.hasValue && mounted) {
        _populateFormForDate(next.valueOrNull, _selectedDate);
      }
    });

    final timesheetAsync = ref.watch(timesheetProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Timesheet — Week of ${formatDisplay(_weekStart)}'),
      ),
      body: Column(
        children: [
          _DateSelector(
            weekDates: _weekDates,
            selectedDate: _selectedDate,
            onDateSelected: _selectDate,
          ),
          const Divider(height: 1),
          Expanded(
            child: timesheetAsync.when(
              // Keep form visible while refreshing after save
              skipLoadingOnRefresh: true,
              loading: () =>
                  const LoadingWidget(message: 'Loading timesheet…'),
              error: (e, _) => AppErrorWidget(
                message: 'Could not load timesheet.',
                onRetry: () => ref.invalidate(timesheetProvider),
              ),
              data: (timesheet) => _TimesheetForm(
                startTime: _startTime,
                endTime: _endTime,
                totalTime: _totalTime,
                mileageController: _mileageController,
                notesController: _notesController,
                isSaving: _isSaving,
                isSubmitting: _isSubmitting,
                onPickStart: _pickStartTime,
                onPickEnd: _pickEndTime,
                onSave: _save,
                onSubmit: _submit,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Date selector
// =============================================================================

class _DateSelector extends StatelessWidget {
  final List<DateTime> weekDates;
  final String selectedDate;
  final ValueChanged<String> onDateSelected;

  const _DateSelector({
    required this.weekDates,
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final todayIso = toIsoDate(DateTime.now().toUtc());
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];

    return SizedBox(
      height: 74,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: weekDates.length,
        separatorBuilder: (_, i) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final date = weekDates[index];
          final isoDate = toIsoDate(date);
          final isSelected = isoDate == selectedDate;
          final isToday = isoDate == todayIso;

          Color bgColor;
          Color fgColor;
          if (isSelected) {
            bgColor = theme.colorScheme.primary;
            fgColor = theme.colorScheme.onPrimary;
          } else if (isToday) {
            bgColor = theme.colorScheme.primaryContainer;
            fgColor = theme.colorScheme.onPrimaryContainer;
          } else {
            bgColor = theme.colorScheme.surfaceContainerHighest;
            fgColor = theme.colorScheme.onSurface;
          }

          return GestureDetector(
            onTap: () => onDateSelected(isoDate),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 56,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
                border: isToday && !isSelected
                    ? Border.all(
                        color: theme.colorScheme.primary,
                        width: 1.5,
                      )
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    dayNames[index],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: fgColor.withValues(alpha: 0.75),
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    date.day.toString(),
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: fgColor,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// =============================================================================
// Timesheet form (stateless — all state lives in the parent)
// =============================================================================

class _TimesheetForm extends StatelessWidget {
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final String totalTime;
  final TextEditingController mileageController;
  final TextEditingController notesController;
  final bool isSaving;
  final bool isSubmitting;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;
  final VoidCallback onSave;
  final VoidCallback onSubmit;

  const _TimesheetForm({
    required this.startTime,
    required this.endTime,
    required this.totalTime,
    required this.mileageController,
    required this.notesController,
    required this.isSaving,
    required this.isSubmitting,
    required this.onPickStart,
    required this.onPickEnd,
    required this.onSave,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Start / End time ──────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _TimeTile(
                  label: 'Start Time',
                  time: startTime,
                  onTap: onPickStart,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TimeTile(
                  label: 'End Time',
                  time: endTime,
                  onTap: onPickEnd,
                ),
              ),
            ],
          ),

          // ── Total time chip ───────────────────────────────────────────────
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: totalTime.isNotEmpty
                ? Padding(
                    key: const ValueKey('total'),
                    padding: const EdgeInsets.only(top: 12),
                    child: _TotalTimeChip(total: totalTime),
                  )
                : const SizedBox(key: ValueKey('empty'), height: 12),
          ),

          const SizedBox(height: 20),

          // ── Mileage ───────────────────────────────────────────────────────
          TextFormField(
            controller: mileageController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            decoration: const InputDecoration(
              labelText: 'Mileage (km)',
              prefixIcon: Icon(Icons.directions_car_outlined),
              hintText: '0',
            ),
          ),

          const SizedBox(height: 16),

          // ── Notes ─────────────────────────────────────────────────────────
          TextFormField(
            controller: notesController,
            maxLines: 3,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Notes',
              alignLabelWithHint: true,
              hintText: 'Any notes for this day…',
            ),
          ),

          const SizedBox(height: 28),

          // ── Save ──────────────────────────────────────────────────────────
          ElevatedButton.icon(
            onPressed: isSaving ? null : onSave,
            icon: isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('Save Entry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            ),
          ),

          const SizedBox(height: 12),

          // ── Submit ────────────────────────────────────────────────────────
          OutlinedButton.icon(
            onPressed: isSubmitting ? null : onSubmit,
            icon: isSubmitting
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.primary,
                    ),
                  )
                : const Icon(Icons.send_outlined),
            label: const Text('Submit Timesheet'),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Time tile
// =============================================================================

class _TimeTile extends StatelessWidget {
  final String label;
  final TimeOfDay? time;
  final VoidCallback onTap;

  const _TimeTile({
    required this.label,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSet = time != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: BoxDecoration(
          color: isSet
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: isSet
              ? Border.all(color: theme.colorScheme.primary, width: 1.5)
              : Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isSet ? formatTime(time!) : '––:––',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: isSet
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Total time chip
// =============================================================================

class _TotalTimeChip extends StatelessWidget {
  final String total;
  const _TotalTimeChip({required this.total});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.green.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.timer_outlined, size: 16, color: Colors.green),
            const SizedBox(width: 6),
            Text(
              'Total: $total',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.green.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
