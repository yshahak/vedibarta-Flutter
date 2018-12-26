import 'dart:async';
import 'package:rxdart/rxdart.dart';
import 'package:vedibarta/parashot.dart';
//import 'package:audioplayers/audioplayers.dart';
import 'package:audioplayer/audioplayer.dart';

class ParashotBloc {

  final String _urlBase = "http://www.vedibarta.org/Rashi_Tora_MP3/";

  final AudioPlayer _audioPlayer = AudioPlayer();
  Par _currentParasha;
  var _currentTrackIndex;
  var _isPlaying;
  Duration _currentDuration;
  Map<String, Map<String, Par>> _pars;

  Sink<Par> get onParClick => _onParClickController.sink;
  Sink<PlayActionType> get onPlayActionClick => _onPlayActionController.sink;

  Stream<Map<String, Map<String, Par>>> get parashot => _parashotSubject.stream;
  Stream<PlayerState> get playerState => _playerStateSubject.stream;
  Stream<String> get currentTime => _currentTimeSubject.stream;
  Stream<String> get currentTrack => _currentTrackSubject.stream;
  Stream<double> get currentProgress => _currentProgressSubject.stream;

  final _onParClickController = StreamController<Par>();
  final _onPlayActionController = StreamController<PlayActionType>();

  ParashotBloc(){
    _onParClickController.stream.listen((parasha) async {
      _currentParasha = parasha;
      _currentTrackIndex = 0;
      await _playTrack();
    });
    _onPlayActionController.stream.listen((playAction) async {
      switch(playAction) {
          case PlayActionType.play_pause:
            _isPlaying ? _pauseTrack() : _resumeTrack();
            break;
          case PlayActionType.next:
            _currentTrackIndex++;
            await _playTrack();
          break;
          case PlayActionType.previous:
            _currentTrackIndex--;
            await _playTrack();
          break;
        case PlayActionType.forward:
          _seekTo(10);
          break;
        case PlayActionType.rewind:
          _seekTo(-10);
          break;
      }
    });
    _audioPlayer.onAudioPositionChanged.listen((Duration duration) {
        _currentDuration = duration;
        _currentTimeSubject.add("${_getTime(duration)}/${_getTime(_audioPlayer.duration)}");
        _currentProgressSubject.add(_currentDuration.inSeconds / _audioPlayer.duration.inSeconds);
    });
    _audioPlayer.onPlayerStateChanged.listen((AudioPlayerState state) {
      switch (state) {
        case AudioPlayerState.COMPLETED:
          onPlayActionClick.add(PlayActionType.next);
          break;
        case AudioPlayerState.PLAYING:
          break;
        case AudioPlayerState.PAUSED:
        case AudioPlayerState.STOPPED:
      }
    });
    _getParashot().then((_) {
      _parashotSubject.add(_pars);
    });
  }

  final _playerStateSubject = BehaviorSubject<PlayerState>();
  final _parashotSubject = PublishSubject<Map<String, Map<String, Par>>>();
  final _currentTimeSubject = BehaviorSubject<String>();
  final _currentTrackSubject = BehaviorSubject<String>();
  final _currentProgressSubject = BehaviorSubject<double>();

  Future<Null> _getParashot() async {
    _pars = await AllParashot.getPars();
  }


  Future _playTrack() async {
    if (_currentTrackIndex < 0) {
      _currentTrackIndex = 0;
      _audioPlayer.seek(0);
    } else if (_currentTrackIndex >= _currentParasha.mp3List.length - 1){
      endSession();
      return;
    }
    List segments = Uri
        .parse("$_urlBase${_currentParasha.zipFiles}")
        .pathSegments;
    String uri = "http://www.vedibarta.org/${segments[0]}/${segments[1]}/${segments[2]}/${_currentParasha.mp3List[_currentTrackIndex][0]}";
    _isPlaying = true;
    _playerStateSubject.add(PlayerState.playing);
    _currentTrackSubject.add("${_currentTrackIndex + 1}/${_currentParasha.mp3List.length}");
    await _audioPlayer.play(uri);
  }

  _seekTo(int positionInSeconds) {
    var newPosition = _currentDuration.inSeconds + positionInSeconds;
    if (newPosition < 0) {
      _audioPlayer.seek(0);
    } else if (_audioPlayer.duration != null && newPosition >= _audioPlayer.duration.inSeconds) {
      return;
    } else {
      _audioPlayer.seek(newPosition.toDouble());
    }
  }

  _pauseTrack() {
    _audioPlayer.pause();
    _isPlaying = false;
    _playerStateSubject.add(PlayerState.pausing);
  }

  _resumeTrack() {
    _playTrack();
//    _audioPlayer.resume();
//    _isPlaying = true;
//    _playerStateSubject.add(PlayerState.playing);
  }

  void close() {
    onParClick.close();
    _onParClickController.close();
    _onPlayActionController.close();
    _playerStateSubject.close();
    _currentTimeSubject.close();
    _currentTrackSubject.close();
    _currentProgressSubject.close();
  }

  String _getTime(Duration data) {
    String twoDigitMinutes = _twoDigits(data.inMinutes.remainder(60));
    String twoDigitSeconds = _twoDigits(data.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  String _twoDigits(int n) {
    if (n >= 10) return "$n";
    return "0$n";
  }

  void endSession() {
    _currentProgressSubject.add(0);
    _currentTrackSubject.add("");
    _isPlaying = false;
    _playerStateSubject.add(PlayerState.pausing);
  }
}

enum PlayerState {
  playing,
  pausing,
}

enum PlayActionType {
  play_pause,
  next,
  forward,
  previous,
  rewind
}