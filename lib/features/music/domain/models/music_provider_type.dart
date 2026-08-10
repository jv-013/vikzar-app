/// Which external music service, if any, a player has connected. `none`
/// is the honest default for every account today — no provider is wired
/// up yet (see `MusicRepository`'s own doc comment). Extensible: a future
/// provider is a new enum value plus a new `data/repositories/` class
/// implementing [MusicRepository], never a change to this type's
/// existing values.
enum MusicProviderType {
  none,
  spotify,
  appleMusic;

  String get label => switch (this) {
    MusicProviderType.none => 'Not connected',
    MusicProviderType.spotify => 'Spotify',
    MusicProviderType.appleMusic => 'Apple Music',
  };
}
