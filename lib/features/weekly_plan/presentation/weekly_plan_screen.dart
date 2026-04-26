import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/utils/date_utils.dart';
import '../../../shared/widgets/error_widget.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../domain/visit.dart';
import '../providers/weekly_plan_providers.dart';

class WeeklyPlanScreen extends ConsumerStatefulWidget {
  const WeeklyPlanScreen({super.key});

  @override
  ConsumerState<WeeklyPlanScreen> createState() => _WeeklyPlanScreenState();
}

class _WeeklyPlanScreenState extends ConsumerState<WeeklyPlanScreen>
    with SingleTickerProviderStateMixin {
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];

  late final TabController _tabController;

  // Tracks which visits have an in-flight mark-complete request
  final Set<String> _markingComplete = {};

  @override
  void initState() {
    super.initState();
    // Use local time so the default tab matches the driver's current day
    final weekday = DateTime.now().weekday; // 1=Mon … 5=Fri, 6=Sat, 7=Sun
    final initialIndex = (weekday >= 1 && weekday <= 5) ? weekday - 1 : 0;
    _tabController = TabController(
      length: _days.length,
      vsync: this,
      initialIndex: initialIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _selectedDay => _days[_tabController.index];

  String _visitKey(Visit v) => '${v.accountId}_${v.date}';

  Future<void> _markComplete(Visit visit) async {
    final key = _visitKey(visit);
    setState(() => _markingComplete.add(key));
    try {
      await ref
          .read(weeklyPlanProvider.notifier)
          .markVisitComplete(visit.accountId, visit.date);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _markingComplete.remove(key));
    }
  }

  Future<void> _launchDirections(String address) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(address)}',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Maps.')),
        );
      }
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(weeklyPlanProvider);
    try {
      await ref.read(weeklyPlanProvider.future);
    } catch (_) {
      // Error state handled by the provider
    }
  }

  @override
  Widget build(BuildContext context) {
    final planAsync = ref.watch(weeklyPlanProvider);

    final appBarTitle = planAsync.valueOrNull?.weekStart != null
        ? 'Week of ${formatDisplay(planAsync.valueOrNull!.weekStart)}'
        : 'My Plan';

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _refresh,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: _days.map((d) => Tab(text: d)).toList(),
          onTap: (_) => setState(() {}),
        ),
      ),
      body: planAsync.when(
        // Keep showing data while refreshing; only show spinner on first load
        skipLoadingOnRefresh: false,
        loading: () => const LoadingWidget(message: 'Loading your plan…'),
        error: (e, _) => AppErrorWidget(
          message: 'Could not load plan.\n${e.toString()}',
          onRetry: _refresh,
        ),
        data: (plan) {
          if (plan == null) {
            return const _EmptyPlan();
          }

          final dayVisits = plan.visits
              .where((v) => v.day == _selectedDay)
              .toList()
            ..sort((a, b) => a.order.compareTo(b.order));

          if (dayVisits.isEmpty) {
            return const _EmptyDay();
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              itemCount: dayVisits.length,
              separatorBuilder: (_, i) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final visit = dayVisits[index];
                final key = _visitKey(visit);
                return _VisitCard(
                  visit: visit,
                  isMarkingComplete: _markingComplete.contains(key),
                  onMarkComplete:
                      visit.completed ? null : () => _markComplete(visit),
                  onDirections: visit.address.isNotEmpty
                      ? () => _launchDirections(visit.address)
                      : null,
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Visit card
// ---------------------------------------------------------------------------

class _VisitCard extends StatelessWidget {
  final Visit visit;
  final bool isMarkingComplete;
  final VoidCallback? onMarkComplete;
  final VoidCallback? onDirections;

  const _VisitCard({
    required this.visit,
    required this.isMarkingComplete,
    required this.onMarkComplete,
    required this.onDirections,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completed = visit.completed;

    return Card(
      color: completed
          ? theme.colorScheme.secondaryContainer.withValues(alpha: 0.4)
          : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Account name row + completed badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    visit.accountName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (completed) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.check_circle, color: Colors.green, size: 22),
                ],
              ],
            ),

            // Address
            if (visit.address.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      visit.address,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // Notes
            if (visit.notes.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.notes,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      visit.notes,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 12),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDirections,
                    icon: const Icon(Icons.directions, size: 18),
                    label: const Text('Directions'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: _MarkCompleteButton(
                  completed: completed,
                  isLoading: isMarkingComplete,
                  onTap: onMarkComplete,
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mark Complete button — extracted to keep _VisitCard readable
// ---------------------------------------------------------------------------

class _MarkCompleteButton extends StatelessWidget {
  final bool completed;
  final bool isLoading;
  final VoidCallback? onTap;

  const _MarkCompleteButton({
    required this.completed,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (completed) {
      return ElevatedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.check, size: 18),
        label: const Text('Completed'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 10),
          visualDensity: VisualDensity.compact,
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.green.shade300,
          disabledForegroundColor: Colors.white,
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: isLoading ? null : onTap,
      icon: isLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.check_circle_outline, size: 18),
      label: const Text('Mark Complete'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 10),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty states
// ---------------------------------------------------------------------------

class _EmptyPlan extends StatelessWidget {
  const _EmptyPlan();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_today_outlined,
              size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No plan found for this week.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Contact your manager if a plan should be assigned.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade500,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'No visits for this day',
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey.shade600,
            ),
      ),
    );
  }
}
