import 'playback_smoke_test.dart' as playback;
import 'playlist_smoke_test.dart' as playlist;

// One device launch avoids reinstalling between playback and fullscreen checks.
void main() {
  playback.main();
  playlist.main();
}
