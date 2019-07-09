import 'package:Tunein/models/playback.dart';
import 'package:Tunein/models/playerstate.dart';
import 'package:Tunein/models/songplus.dart';
import 'package:Tunein/services/themeService.dart';
import 'package:flute_music_player/flute_music_player.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'locator.dart';

final themeService = locator<ThemeService>();

class MusicService {
  BehaviorSubject<List<Song>> _songs$;
  BehaviorSubject<MapEntry<PlayerState, Song>> _playerState$;
  BehaviorSubject<MapEntry<List<Song>, List<Song>>>
      _playlist$; //key is normal, value is shuffle
  BehaviorSubject<Duration> _position$;
  BehaviorSubject<List<Playback>> _playback$;
  BehaviorSubject<List<SongPlus>> _favorites$;
  BehaviorSubject<bool> _isAudioSeeking$;
  MusicFinder _audioPlayer;
  Song _defaultSong;

  BehaviorSubject<List<Song>> get songs$ => _songs$;
  BehaviorSubject<MapEntry<PlayerState, Song>> get playerState$ =>
      _playerState$;
  BehaviorSubject<Duration> get position$ => _position$;
  BehaviorSubject<List<Playback>> get playback$ => _playback$;
  BehaviorSubject<List<SongPlus>> get favorites$ => _favorites$;
  BehaviorSubject<MapEntry<List<Song>, List<Song>>> get playlist$ => _playlist$;

  MusicService() {
    _defaultSong = Song(
      null,
      " ",
      " ",
      " ",
      null,
      null,
      null,
      null,
    );
    _initStreams();
    _initAudioPlayer();
  }

  Future<void> fetchSongs() async {
    await MusicFinder.allSongs().then(
      (data) {
        _songs$.add(data);
      },
    );
  }

  void playMusic(Song song) {
    _audioPlayer.play(song.uri);
    updatePlayerState(PlayerState.playing, song);
  }

  void pauseMusic(Song song) {
    _audioPlayer.pause();
    updatePlayerState(PlayerState.paused, song);
  }

  void stopMusic() {
    _audioPlayer.stop();
  }

  void updatePlayerState(PlayerState state, Song song) {
    _playerState$.add(MapEntry(state, song));
    themeService.updateTheme(song.albumArt);
  }

  void updatePosition(Duration duration) {
    _position$.add(duration);
  }

  void updatePlaylist(List<Song> normalPlaylist) {
    List<Song> _shufflePlaylist = []..addAll(normalPlaylist);
    _shufflePlaylist.shuffle();
    _playlist$.add(MapEntry(normalPlaylist, _shufflePlaylist));
  }

  void playNextSong() {
    if (_playerState$.value.key == PlayerState.stopped) {
      return;
    }
    final Song _currentSong = _playerState$.value.value;
    final bool _isShuffle = _playback$.value.contains(Playback.shuffle);
    final List<Song> _playlist =
        _isShuffle ? _playlist$.value.value : _playlist$.value.key;
    int _index = _playlist.indexOf(_currentSong);
    if (_index == _playlist.length - 1) {
      _index = 0;
    } else {
      _index++;
    }
    stopMusic();
    playMusic(_playlist[_index]);
  }

  int getSongIndex(song) {
    final bool _isShuffle = _playback$.value.contains(Playback.shuffle);
    final List<Song> _playlist =
        _isShuffle ? _playlist$.value.value : _playlist$.value.key;
    return _playlist.indexOf(song);
  }

  MapEntry<Song, Song> getNextPrevSong(Song _currentSong) {
    final bool _isShuffle = _playback$.value.contains(Playback.shuffle);
    final List<Song> _playlist =
        _isShuffle ? _playlist$.value.value : _playlist$.value.key;
    int _index = _playlist.indexOf(_currentSong);
    int nextSongIndex = _index + 1;
    int prevSongIndex = _index - 1;

    if (_index == _playlist.length - 1) {
      nextSongIndex = 0;
    }
    if (_index == 0) {
      prevSongIndex = _playlist.length - 1;
    }
    Song nextSong = _playlist[nextSongIndex];
    Song prevSong = _playlist[prevSongIndex];
    return MapEntry(nextSong, prevSong);
  }

  void playPreviousSong() {
    if (_playerState$.value.key == PlayerState.stopped) {
      return;
    }
    final Song _currentSong = _playerState$.value.value;
    final bool _isShuffle = _playback$.value.contains(Playback.shuffle);
    final List<Song> _playlist =
        _isShuffle ? _playlist$.value.value : _playlist$.value.key;
    int _index = _playlist.indexOf(_currentSong);
    if (_index == 0) {
      _index = _playlist.length - 1;
    } else {
      _index--;
    }
    stopMusic();
    playMusic(_playlist[_index]);
  }

  void _playSameSong() {
    final Song _currentSong = _playerState$.value.value;
    stopMusic();
    playMusic(_currentSong);
  }

  void _onSongComplete() {
    final List<Playback> _playback = _playback$.value;
    if (_playback.contains(Playback.repeatSong)) {
      _playSameSong();
      return;
    }
    playNextSong();
  }

  void audioSeek(double seconds) {
    _audioPlayer.seek(seconds);
  }

  void addToFavorites(SongPlus song) async {
    List<SongPlus> _favorites = _favorites$.value;
    _favorites.add(song);
    _favorites$.add(_favorites);
    await saveFavorites();
  }

  void removeFromFavorites(SongPlus _song) async {
    List<SongPlus> _favorites = _favorites$.value;
    final int index = _favorites.indexWhere((song) => song.id == _song.id);
    _favorites.removeAt(index);
    _favorites$.add(_favorites);
    await saveFavorites();
  }

  void invertSeekingState() {
    final _value = _isAudioSeeking$.value;
    _isAudioSeeking$.add(!_value);
  }

  void updatePlayback(Playback playback) {
    List<Playback> _value = playback$.value;
    if (playback == Playback.shuffle) {
      final List<Song> _normalPlaylist = _playlist$.value.key;
      updatePlaylist(_normalPlaylist);
    }
    _value.add(playback);
    _playback$.add(_value);
  }

  void removePlayback(Playback playback) {
    List<Playback> _value = playback$.value;
    _value.remove(playback);
    _playback$.add(_value);
  }

  void _initAudioPlayer() {
    _audioPlayer = MusicFinder();
    _audioPlayer.setPositionHandler(
      (Duration duration) {
        final bool _isAudioSeeking = _isAudioSeeking$.value;
        if (!_isAudioSeeking) {
          updatePosition(duration);
        }
      },
    );
    _audioPlayer.setCompletionHandler(
      () {
        _onSongComplete();
      },
    );
  }

  Future<void> saveFavorites() async {
    SharedPreferences _prefs = await SharedPreferences.getInstance();
    final List<SongPlus> _favorites = _favorites$.value;
    List<String> _encodedStrings = [];
    for (SongPlus song in _favorites) {
      _encodedStrings.add(_encodeSongPlusToJson(song));
    }
    _prefs.setStringList("favorites", _encodedStrings);
  }

  Future<void> saveFiles() async {
    SharedPreferences _prefs = await SharedPreferences.getInstance();
    final List<Song> _songs = _songs$.value;
    List<String> _encodedStrings = [];
    for (Song song in _songs) {
      _encodedStrings.add(_encodeSongToJson(song));
    }
    _prefs.setStringList("songs", _encodedStrings);
  }

  Future<List<Song>> retrieveFiles() async {
    SharedPreferences _prefs = await SharedPreferences.getInstance();
    List<String> _savedStrings = _prefs.getStringList("songs") ?? [];
    List<Song> _songs = [];
    for (String data in _savedStrings) {
      final Song song = _decodeSongFromJson(data);
      _songs.add(song);
    }
    _songs$.add(_songs);
    return _songs$.value;
  }

  void retrieveFavorites() async {
    SharedPreferences _prefs = await SharedPreferences.getInstance();
    final List<Song> _fetchedSongs = _songs$.value;
    List<String> _savedStrings = _prefs.getStringList("favorites") ?? [];
    List<SongPlus> _favorites = [];
    for (String data in _savedStrings) {
      final SongPlus song = _decodeSongPlusFromJson(data);
      for (var fetchedSong in _fetchedSongs) {
        if (song.id == fetchedSong.id) {
          _favorites.add(SongPlus(fetchedSong, song.colors));
        }
      }
    }
    _favorites$.add(_favorites);
  }

  String _encodeSongToJson(Song song) {
    final _songMap = songToMap(song);
    final data = json.encode(_songMap);
    return data;
  }

  String _encodeSongPlusToJson(SongPlus song) {
    final _songMap = songPlusToMap(song);
    final data = json.encode(_songMap);
    return data;
  }

  Song _decodeSongFromJson(String ecodedSong) {
    final _songMap = json.decode(ecodedSong);
    final Song _song = Song.fromMap(_songMap);
    return _song;
  }

  SongPlus _decodeSongPlusFromJson(String ecodedSong) {
    final _songMap = json.decode(ecodedSong);
    final SongPlus _song = SongPlus.fromMap(_songMap);
    return _song;
  }

  Map<String, dynamic> songToMap(Song song) {
    Map<String, dynamic> _map = {};
    _map["album"] = song.album;
    _map["id"] = song.id;
    _map["artist"] = song.artist;
    _map["title"] = song.title;
    _map["albumId"] = song.albumId;
    _map["duration"] = song.duration;
    _map["uri"] = song.uri;
    _map["albumArt"] = song.albumArt;
    return _map;
  }

  Map<String, dynamic> songPlusToMap(SongPlus song) {
    Map<String, dynamic> _map = {};
    _map["album"] = song.album;
    _map["id"] = song.id;
    _map["artist"] = song.artist;
    _map["title"] = song.title;
    _map["albumId"] = song.albumId;
    _map["duration"] = song.duration;
    _map["uri"] = song.uri;
    _map["albumArt"] = song.albumArt;
    _map["colors"] = song.colors;
    return _map;
  }

  void _initStreams() {
    _isAudioSeeking$ = BehaviorSubject<bool>.seeded(false);
    _songs$ = BehaviorSubject<List<Song>>();
    _position$ = BehaviorSubject<Duration>();
    _playlist$ = BehaviorSubject<MapEntry<List<Song>, List<Song>>>();
    _playback$ = BehaviorSubject<List<Playback>>.seeded([]);
    _favorites$ = BehaviorSubject<List<SongPlus>>.seeded([]);
    _playerState$ = BehaviorSubject<MapEntry<PlayerState, Song>>.seeded(
      MapEntry(
        PlayerState.stopped,
        _defaultSong,
      ),
    );
  }

  void dispose() {
    stopMusic();
    _isAudioSeeking$.close();
    _songs$.close();
    _playerState$.close();
    _playlist$.close();
    _position$.close();
    _playback$.close();
    _favorites$.close();
  }
}