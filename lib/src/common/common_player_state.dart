/// Unified player lifecycle states shared by GSY and SG backends.
enum CommonPlayerState {
  idle,
  buffering,
  ready,
  playing,
  paused,
  completed,
  error,
}
