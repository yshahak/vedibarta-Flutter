import 'dart:async';
import 'package:rxdart/rxdart.dart';
import 'package:vedibarta/parashot.dart';
import 'package:audioplayer/audioplayer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:tuple/tuple.dart';

class ParashotBloc {

  final String _urlBase = "http://www.vedibarta.org/Rashi_Tora_MP3/";
  FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = new FlutterLocalNotificationsPlugin();
  final AudioPlayer _audioPlayer = AudioPlayer();
  Par _currentParasha;
  String _currentBook;
  var _currentTrackIndex;
  bool _isPlaying = false;
  String _currentUri;
  Duration _currentDuration;
  Map<String, Map<String, Par>> _pars;

  Sink<Tuple2<String, Par>> get onParClick => _onParClickController.sink;

  Sink<PlayActionType> get onPlayActionClick => _onPlayActionController.sink;

  final _playerStateSubject = BehaviorSubject<PlayerState>();
  final _parashotSubject = PublishSubject<Map<String, Map<String, Par>>>();
  final _currentTimeSubject = BehaviorSubject<String>();
  final _currentTrackSubject = BehaviorSubject<String>();
  final _currentProgressSubject = BehaviorSubject<double>();

  Stream<Map<String, Map<String, Par>>> get parashot => _parashotSubject.stream;

  Stream<PlayerState> get playerState => _playerStateSubject.stream;

  Stream<String> get currentTime => _currentTimeSubject.stream;

  Stream<String> get currentTrack => _currentTrackSubject.stream;

  Stream<double> get currentProgress => _currentProgressSubject.stream;

  final _onParClickController = StreamController<Tuple2<String, Par>>();
  final _onPlayActionController = StreamController<PlayActionType>();

  ParashotBloc() {
    print("ParashotBloc constructed!");
    var initializationSettingsAndroid = new AndroidInitializationSettings('ic_play');
    var initializationSettingsIOS = new IOSInitializationSettings(defaultPresentSound: false);
    var initializationSettings = new InitializationSettings(initializationSettingsAndroid, initializationSettingsIOS);
    _flutterLocalNotificationsPlugin = new FlutterLocalNotificationsPlugin();
    _flutterLocalNotificationsPlugin.initialize(initializationSettings, onSelectNotification: onSelectNotification);

    _onParClickController.stream.listen((tuple) async {
      _currentBook = tuple.item1;
      _currentParasha = tuple.item2;
      _currentTrackIndex = 0;
      _prepareTrack();
      await _playTrack();
    });
    _onPlayActionController.stream.listen((playAction) async {
      switch (playAction) {
        case PlayActionType.play_pause:
          _isPlaying ? _pauseTrack() : _resumeTrack();
          break;
        case PlayActionType.next:
          _currentTrackIndex++;
          _prepareTrack();
          await _playTrack();
          break;
        case PlayActionType.previous:
          _currentTrackIndex--;
          _prepareTrack();
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
      _currentTimeSubject.add(
          "${_getTime(duration)}/${_getTime(_audioPlayer.duration)}");
      _currentProgressSubject.add(
          _currentDuration.inSeconds / _audioPlayer.duration.inSeconds);
    });
    _audioPlayer.onPlayerStateChanged.listen((AudioPlayerState state) {
      switch (state) {
        case AudioPlayerState.COMPLETED:
          onPlayActionClick.add(PlayActionType.next);
          _isPlaying = false;
          break;
        case AudioPlayerState.PLAYING:
          _playerStateSubject.add(PlayerState.playing);
          _isPlaying = true;
          break;
        case AudioPlayerState.PAUSED:
        case AudioPlayerState.STOPPED:
        _playerStateSubject.add(PlayerState.pausing);
        _savePlayerState();
        _isPlaying = false;
          break;
      }
    });
    _getParashot().then((_) async {
      _parashotSubject.add(_pars);
      await _restorePlayerState();
    });
  }

  _savePlayerState() async {
    if (_currentBook != null && _currentParasha != null) {
      var prefs = await SharedPreferences.getInstance();
      prefs.setString("currentBook", _currentBook);
      prefs.setString("currentParash", _currentParasha.latName);
      prefs.setInt("currentIndex", _currentTrackIndex);
      prefs.setInt("currentPosition", _currentDuration.inSeconds);
      prefs.setInt("totalPosition", _audioPlayer.duration.inSeconds);
      print("saveing state: currentIndex=$_currentTrackIndex\tcurrentPosition=${_currentDuration.inSeconds}");
    }
  }

  _restorePlayerState() async {
    var prefs = await SharedPreferences.getInstance();
    var currentBook = prefs.getString("currentBook");
    var currentParasha = prefs.getString("currentParash");
    if (currentBook != null && currentParasha != null) {
      var currentPar = _pars[currentBook][currentParasha];
      if (currentPar != null) {
        _currentBook = currentBook;
        _currentParasha = currentPar;
        _currentTrackIndex = prefs.getInt("currentIndex");
        var position = prefs.getInt("currentPosition");
        var totalDuration = prefs.getInt("totalPosition");
        if (totalDuration == null) {
          String durationInString = _currentParasha.mp3List[_currentTrackIndex][2];
          int minutes = int.tryParse(durationInString.split(":")[0]);
          int seconds = int.tryParse(durationInString.split(":")[1]);
          totalDuration = minutes * 60 + seconds;
        }
        print("player has restored!\tposition=$position");
        _prepareTrack();
        _currentDuration = Duration(seconds: position);
        var total = Duration(seconds: totalDuration);
        _currentTimeSubject.add(
            "${_getTime(_currentDuration)}/${_getTime(total)}");
        _currentProgressSubject.add(_currentDuration.inSeconds / total.inSeconds);
//        await _audioPlayer.seek(position.toDouble());
//        await _pauseTrack();
        _playerStateSubject.add(PlayerState.restored);
      }
    }
  }

  Future onSelectNotification(String payload) async {
    if (payload != null) {
      print('notification payload: ' + payload);
    }
  }

  Future<Null> _getParashot() async {
    _pars = await AllParashot.getPars();
  }

  void _prepareTrack() {
    _currentDuration = Duration.zero;
    if (_currentTrackIndex < 0) {
      _currentTrackIndex = 0;
      _audioPlayer.seek(0);
    } else if (_currentTrackIndex >= _currentParasha.mp3List.length - 1) {
      endSession();
      return;
    }
    List segments = Uri
        .parse("$_urlBase${_currentParasha.zipFiles}")
        .pathSegments;
    _currentUri = "http://www.vedibarta.org/${segments[0]}/${segments[1]}/${segments[2]}/${_currentParasha
        .mp3List[_currentTrackIndex][0]}";
//    _isPlaying = true;
    var currentTrackLabel = " פרשת ${_currentParasha.hebName} ${_currentTrackIndex + 1}/${_currentParasha.mp3List.length}";
    _currentTrackSubject.add(currentTrackLabel);
  }

  Future _playTrack() async {
    var currentTrackLabel = " פרשת ${_currentParasha.hebName} ${_currentTrackIndex + 1}/${_currentParasha.mp3List.length}";
    displayNotification(" פרשת ${_currentParasha.hebName}", currentTrackLabel);
    print("will start play $_currentUri\t_currentDuration=${_currentDuration.inSeconds}");
    await _audioPlayer.play(_currentUri, prepareSync: true);
    await _audioPlayer.seek(_currentDuration.inSeconds.toDouble());
  }

  _seekTo(int positionInSeconds) async {
    var newPosition = _currentDuration.inSeconds + positionInSeconds;
    print("new position $newPosition\t_audioPlayer.duration=${_audioPlayer.duration}");
    if (newPosition < 0) {
      await _audioPlayer.seek(0);
    } else if (_audioPlayer.duration != null && newPosition >= _audioPlayer.duration.inSeconds) {
      return;
    } else {
      await _audioPlayer.seek(newPosition.toDouble());
    }
  }

  _pauseTrack() async {
    await _audioPlayer.pause();
    cancelNotification();
  }

  _resumeTrack() {
    _playTrack();
    var currentTrackLabel = " פרשת ${_currentParasha
        .hebName} ${_currentTrackIndex + 1}/${_currentParasha.mp3List.length}";
    displayNotification(" פרשת ${_currentParasha.hebName}", currentTrackLabel);
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
//    _isPlaying = false;
  }

  void displayNotification(var title, var body) async {
    var androidPlatformChannelSpecifics = new AndroidNotificationDetails(
        'dibarta_42', 'vedibarta', 'playpack controller',
        icon: 'ic_play',
        importance: Importance.Max,
        priority: Priority.High,
        autoCancel: false,
        enableVibration: false,
        onlyAlertOnce : true,
        playSound: false);
    var iOSPlatformChannelSpecifics = new IOSNotificationDetails(presentSound: false, presentBadge: false);
    var platformChannelSpecifics = new NotificationDetails(androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);
    await _flutterLocalNotificationsPlugin.show(
        0, title, body, platformChannelSpecifics,
        payload: 'item id 2');
  }

  void cancelNotification() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }
}

enum PlayerState {
  playing,
  pausing,
  restored,
}

enum PlayActionType {
  play_pause,
  next,
  forward,
  previous,
  rewind
}