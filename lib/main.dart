import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter_ion/flutter_ion.dart' as ion;
import 'package:uuid/uuid.dart';
import 'dart:developer';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Pion/ion One to Many Broadcast'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class Participant {
  Participant(this.title, this.renderer, this.stream);
  MediaStream? stream;
  String title;
  RTCVideoRenderer renderer; // we can use it without package
}

class _MyHomePageState extends State<MyHomePage> {
  List<Participant> plist = <Participant>[];
  bool isPub = false;

  RTCVideoRenderer _localRender = RTCVideoRenderer(); // this is from ion sdk
  RTCVideoRenderer _remoteRender = RTCVideoRenderer();

  @override
  void initState() {
    super.initState();
    initRender();
    initSfu();
  }

  initRender() async {
    await _localRender.initialize();
    await _remoteRender.initialize();
  }

  getUrl() { // check whether it is web or native client
    if (kIsWeb) { // it is from flutter foundation sdk
      return ion.GRPCWebSignal('http://localhost:9090'); // web
    } else {
      setState(() {
        isPub = true;
      });
      return ion.GRPCWebSignal('http://10.157.226.109:9090'); //mobile(native) machine ip address?
    }
  }

  ion.Signal? _signal;
  ion.Client? _client;
  ion.LocalStream? _localStream;
  final String _uuid = Uuid().v4();

  initSfu() async { //when using android in a web, local host doesn't work, so we need to check
    // because android use their own localhost instead of the web(my) local host
    final _signal = await getUrl();
    _client = // sid = room id, uid = variable that we make up side
        await ion.Client.create(sid: "test room", uid: _uuid, signal: _signal);
    if (isPub == false) {
      _client?.ontrack = (track, ion.RemoteStream remoteStream) async {
        if (track.kind == 'video') {
          print('onTrack: remote stream => ${remoteStream.id}'); // log
          setState(() {
            _remoteRender.srcObject = remoteStream.stream; // remoteStream is come from _client.onTrack
          });
        }
      };
    }
  }

  void publish() async { // when hit the button we can get the camera stream
    log("publish");
    _localStream = await ion.LocalStream.getUserMedia(
        constraints: ion.Constraints.defaults..simulcast = false);

    await _client?.publish(_localStream!);

    setState(() {
      _localRender.srcObject = _localStream?.stream;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[getVideoView()],
        ),
      ),
      floatingActionButton:
          getFab(), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  // video view
  Widget getVideoView() {
    if (isPub == true) {
      return Expanded(
        child: RTCVideoView(_localRender),
      );
    } else {
      return Expanded(
        child: RTCVideoView(_remoteRender),
      );
    }
  }

// publish button
  Widget getFab() {
    if (isPub == false) { // which is subscriber
      return Container();
    } else {
      return FloatingActionButton(
        onPressed: publish,
        child: Icon(Icons.video_call),
      );
    }
  }
}
