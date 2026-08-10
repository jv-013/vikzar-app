import '../models/music_provider_type.dart';
import '../models/now_playing.dart';

/// Player-only extension point (Phase 19.5 Part 9) for a future Spotify
/// or Apple Music integration — no coach-facing equivalent exists or is
/// planned, since this is about a player's own training-session
/// listening, not a team-management concern.
///
/// This interface is the entire deliverable this phase; nothing
/// implements it against a real provider yet. See
/// `lib/features/music/README.md` for exactly how a real Spotify/Apple
/// Music implementation would plug in later without changing this file,
/// [NoOpMusicRepository], or any screen that consumes this interface —
/// the same "hardware upgrades RAZ, it never activates it" extension
/// shape `razHardwareContext.ts` already uses for Pods/EMG, applied here
/// to a different kind of not-yet-real integration.
abstract interface class MusicRepository {
  bool get isConnected;
  MusicProviderType? get connectedProvider;
  Stream<NowPlaying?> get nowPlayingStream;

  Future<void> connect(MusicProviderType provider);
  Future<void> disconnect();
}
