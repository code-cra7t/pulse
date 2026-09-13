import '../../calendar/models/availability_summary.dart';
import 'schedule_block.dart';
import 'schedule_proposal.dart';
import 'scheduling_preferences.dart';

class SchedulingDayState {
  const SchedulingDayState({
    required this.date,
    required this.preferences,
    required this.calendarSupported,
    required this.calendarAccess,
    required this.acceptedBlocks,
    this.availability,
    this.proposal,
  });

  final DateTime date;
  final SchedulingPreferences preferences;
  final bool calendarSupported;
  final bool calendarAccess;
  final List<ScheduleBlock> acceptedBlocks;
  final AvailabilitySummary? availability;
  final DayScheduleProposal? proposal;

  bool get isConfigured => preferences.isConfigured;
  bool get isEnabledDay => preferences.isEnabledOn(date);
  bool get needsCalendarAccess => calendarSupported && !calendarAccess;
  bool get canPropose =>
      isConfigured &&
      isEnabledDay &&
      !needsCalendarAccess &&
      availability != null;
}
