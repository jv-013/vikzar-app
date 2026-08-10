/// What a connected music provider reports is currently playing. Shaped
/// now so a real provider implementation has a concrete type to stream,
/// even though nothing produces one yet.
class NowPlaying {
  const NowPlaying({required this.title, required this.artist, required this.isPlaying});

  final String title;
  final String artist;
  final bool isPlaying;
}
