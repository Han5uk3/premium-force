/// When a pickup may first be booked, and what the pickers open on.
///
/// The whole window hangs off one number the backend gives per city —
/// `bookingBufferHours` — and off the clock. Both are passed in rather than
/// read here so the rules can be exercised at any hour without waiting for it
/// to be that hour: every function is pure, and `DateTime.now()` appears only
/// at the call sites in the booking screen.
///
/// Everything is wall-clock local time, which is what the pickers deal in.
library;

/// The quarter-hour grid the default pickup is rounded onto.
const int kPickupRoundingMinutes = 15;

/// The earliest instant a pickup may be booked: now plus the city's buffer.
///
/// Seconds are dropped so the result can be compared against a `TimeOfDay`
/// selection without leftover seconds rejecting the very minute the pickers
/// offer.
///
/// Crossing midnight needs no special case — [DateTime.add] carries the date,
/// so 10:00 PM plus a three-hour buffer is 1:00 AM the following day, and the
/// month and year roll over the same way.
DateTime earliestPickupInstant(DateTime now, int bufferHours) {
  final raw = now.add(Duration(hours: bufferHours < 0 ? 0 : bufferHours));
  return DateTime(raw.year, raw.month, raw.day, raw.hour, raw.minute);
}

/// Midnight on the first bookable day — the date picker's lower bound.
///
/// This is the day of [earliestPickupInstant], not today: once the buffer
/// pushes past midnight, today is no longer selectable at all.
DateTime earliestPickupDate(DateTime now, int bufferHours) {
  final earliest = earliestPickupInstant(now, bufferHours);
  return DateTime(earliest.year, earliest.month, earliest.day);
}

/// What the pickers are prefilled with: [earliestPickupInstant] rounded up to
/// the next quarter hour.
///
/// Rounding buys the customer a few minutes to finish the form before the
/// buffer overtakes the default, and reads as a pickup time rather than as the
/// exact minute the screen happened to open.
///
/// Rounding can itself cross midnight — 11:50 PM rounds to 12:00 AM the next
/// day — so this may land on a *later* day than [earliestPickupDate]. Callers
/// must take the date from this result rather than assuming the two agree.
DateTime defaultPickupInstant(DateTime now, int bufferHours) {
  final earliest = earliestPickupInstant(now, bufferHours);
  final overshoot = earliest.minute % kPickupRoundingMinutes;
  return overshoot == 0
      ? earliest
      : earliest.add(Duration(minutes: kPickupRoundingMinutes - overshoot));
}

/// [candidate] moved up to [defaultPickupInstant] when it falls short of the
/// buffer, or returned unchanged when it is already bookable.
///
/// Used where a date and a time are chosen separately: pairing a kept
/// time-of-day with a newly chosen date can land before the buffer, and the
/// replacement has to be a full instant. Taking only the *time* off the
/// default would put the customer on the right clock face but the wrong day
/// whenever the default has rolled past midnight.
DateTime bumpedToBookable(DateTime candidate, DateTime now, int bufferHours) {
  final earliest = earliestPickupInstant(now, bufferHours);
  return candidate.isBefore(earliest)
      ? defaultPickupInstant(now, bufferHours)
      : candidate;
}
