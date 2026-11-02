/// Source of the current time. Injected everywhere a timestamp is written so
/// tests can control time (sync ordering depends on `updated_at`).
class Clock {
  const Clock();

  /// Current time in UTC. All stored timestamps are UTC.
  DateTime nowUtc() => DateTime.now().toUtc();
}

/// A clock that always returns [current], for tests.
class FixedClock extends Clock {
  FixedClock(this.current);

  DateTime current;

  void advance(Duration duration) => current = current.add(duration);

  @override
  DateTime nowUtc() => current.toUtc();
}
