import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/music_provider_type.dart';
import '../models/now_playing.dart';
import 'music_repository.dart';

/// The only [MusicRepository] implementation today — always disconnected,
/// same honesty convention as `podConnected`/`emgConnected` always being
/// `false` in `razHardwareContext.ts` until a real pipeline exists.
/// `connect()` is intentionally a no-op rather than throwing: the
/// placeholder "Coming soon" UI this backs never actually calls it (see
/// `lib/features/music/README.md`), but a silent no-op is safer than an
/// exception if a future caller does, before a real implementation
/// exists to replace this one.
class NoOpMusicRepository implements MusicRepository {
  const NoOpMusicRepository();

  @override
  bool get isConnected => false;

  @override
  MusicProviderType? get connectedProvider => null;

  @override
  Stream<NowPlaying?> get nowPlayingStream => Stream.value(null);

  @override
  Future<void> connect(MusicProviderType provider) async {}

  @override
  Future<void> disconnect() async {}
}

final musicRepositoryProvider = Provider<MusicRepository>((ref) {
  return const NoOpMusicRepository();
});
