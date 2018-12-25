import 'package:flutter/material.dart';
import 'package:vedibarta/parasot_bloc.dart';

//import 'package:shared_preferences/shared_preferences.dart';
import 'parashot.dart';

void main() {
  final parashotBloc = ParashotBloc();
  runApp(MyApp(parashotBloc));
}

class MyApp extends StatelessWidget {
  final ParashotBloc parashotBloc;

  MyApp(this.parashotBloc);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(
          title: 'ודיברת - שיעורי רש״י על התורה',
          parashotBloc: this.parashotBloc),
    );
  }
}

@immutable
class MyHomePage extends StatefulWidget {
  final ParashotBloc parashotBloc;

  MyHomePage({Key key, this.title, this.parashotBloc}) : super(key: key);
  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  VoidCallback _showBottomSheetCallback;

  @override
  void initState() {
    super.initState();
    _showBottomSheetCallback = _showBottomSheet;
  }

  void _showBottomSheet() {
    _scaffoldKey.currentState.showBottomSheet<void>((BuildContext context) {
      final ThemeData themeData = Theme.of(context);
      const edgeInsets = const EdgeInsets.fromLTRB(12, 2, 12, 2);
      return Container(
          decoration: BoxDecoration(
              border: Border(top: BorderSide(color: themeData.disabledColor))
          ),
        child: Padding(
            padding: EdgeInsets.all(5.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    StreamBuilder<String>(
                      stream: widget.parashotBloc.currentTime,
                      initialData: "_",
                      builder: (context, snapshot) {
                        return Padding(
                          padding: edgeInsets,
                          child: Text(
                            snapshot.data,
                            textAlign: TextAlign.center,
                            textScaleFactor: 1.5,
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        );
                      },
                    ),
                    StreamBuilder<String>(
                      stream: widget.parashotBloc.currentTrack,
                      initialData: "0",
                      builder: (context, snapshot) {
                        return Padding(
                          padding: edgeInsets,
                          child: Text(
                            snapshot.data,
                            textAlign: TextAlign.right,
                            textScaleFactor: 1.5,
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        );
                      },
                    )
                  ],
                ),
                StreamBuilder<double>(
                  stream: widget.parashotBloc.currentProgress,
                  initialData: 0,
                  builder: (context, snapshot) {
                    return Padding(
                      padding: edgeInsets,
                      child: LinearProgressIndicator(
                       value: snapshot.data,
                      ),
                    );
                  },
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    Expanded(
                      child: MaterialButton(
                        onPressed: () => widget.parashotBloc.onPlayActionClick.add(PlayActionType.previous),
                        child: Icon(Icons.skip_previous)),
                    ),
                    Expanded(
                      child: MaterialButton(
                        onPressed: () => widget.parashotBloc.onPlayActionClick.add(PlayActionType.rewind),
                        child: Icon(Icons.fast_rewind)),
                    ),
                    Expanded(
                      child: StreamBuilder<PlayerState>(
                        stream: widget.parashotBloc.playerState,
                        initialData: PlayerState.pausing,
                        builder: (context, snapshot) {
                          bool isPlaying = snapshot.data == PlayerState.playing;
                          print("isPlaying=${snapshot.data}");
                          return MaterialButton(
                            onPressed: () => widget.parashotBloc.onPlayActionClick.add(PlayActionType.play_pause),
                            child: Icon(isPlaying ?  Icons.pause : Icons.play_arrow),
                          );
                        },
                      ),
                    ),
                    Expanded(
                      child: MaterialButton(
                        onPressed: () => widget.parashotBloc.onPlayActionClick.add(PlayActionType.forward),
                        child: Icon(Icons.fast_forward),
                      ),
                    ),
                    Expanded(
                      child: MaterialButton(
                        onPressed: () => widget.parashotBloc.onPlayActionClick.add(PlayActionType.next),
                        child: Icon(Icons.skip_next),
                      ),
                    ),
                  ],
                ),
              ],
            )),
      );
    });
//        .closed.whenComplete(() {
//      if (mounted) {
//        setState(() { // re-enable the button
//          _showBottomSheetCallback = _showBottomSheet;
//        });
//      }
//    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: StreamBuilder<Map<String, Map<String, Par>>>(
        stream: widget.parashotBloc.parashot,
        initialData: Map(),
        builder: (context, snapshot) {
          var titles = snapshot.data.keys.toList();
          var pars = snapshot.data.values.toList();
          return ListView.builder(
              physics: ScrollPhysics(),
              shrinkWrap: true,
              itemCount: snapshot.data.length,
              itemBuilder: (BuildContext context, int position) =>
                  ExpansionTile(
                    title: Text(titles[position],
                        textDirection: TextDirection.rtl),
                    children: <Widget>[_getBookListView(pars[position])],
                  ));
        },
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    widget.parashotBloc.close();
  }

  Widget _getBookListView(Map<String, Par> book) {
    var toList = book.values.toList();
    return ListView.builder(
        physics: ScrollPhysics(),
        shrinkWrap: true,
        itemCount: book.length,
        itemBuilder: (BuildContext context, int position) {
          return getRow(toList[position]);
        });
  }

  Widget getRow(Par parasha) {
    return GestureDetector(
      child: Padding(
          padding: EdgeInsets.fromLTRB(20.0, 5.0, 20.0, 5.0),
          child: Row(
            textDirection: TextDirection.rtl,
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              Expanded(child: Text(parasha.hebName, textDirection: TextDirection.rtl,)),
              Expanded(
                child: MaterialButton(
                  onPressed: () => _showBottomSheet(),
                  child: Icon(
                      parasha.isDownloaded ? Icons.check : Icons.cloud_download),
                ),
              ),
              Expanded(
                child: MaterialButton(
                  onPressed: () {
                    widget.parashotBloc.onParClick.add(parasha);
                    _showBottomSheet();
                  },
                  child: Icon(Icons.play_circle_outline),
                ),
              )
            ],
          )),
      onTap: () {},
    );
  }

  void _onDownloadClicked(Par parasha) {
    //todo
  }

}
