import 'dart:developer';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_ion/flutter_ion.dart' as ion;
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:uuid/uuid.dart';

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
  RTCVideoRenderer renderer;
}

class _MyHomePageState extends State<MyHomePage> {
  List<Participant> plist = <Participant>[];
  bool isPub = false;

  RTCVideoRenderer _localRender = RTCVideoRenderer();
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

  getUrl() {
    if (kIsWeb) {
      return ion.GRPCWebSignal('http://localhost:9090');
    } else {
      setState(() {
        isPub = true;
      });
      return ion.GRPCWebSignal('http://10.0.2.16:9090');
    }
  }

  ion.Signal? _signal;
  ion.Client? _client;
  ion.LocalStream? _localStream;
  final String _uuid = Uuid().v4();

  initSfu() async {
    final _signal = await getUrl();
    _client =
        await ion.Client.create(sid: "test room", uid: _uuid, signal: _signal);
    if (isPub == false) {
      _client?.ontrack = (track, ion.RemoteStream remoteStream) async {
        if (track.kind == 'video') {
          print('ontrack: remote stream => ${remoteStream.id}');
          setState(() {
            _remoteRender.srcObject = remoteStream.stream;
          });
        }
      };
    }
  }

  // pushlish function
  void publish() async {
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
    if (isPub == false) {
      return Container();
    } else {
      return FloatingActionButton(
        onPressed: publish,
        child: Icon(Icons.video_call),
      );
    }
  }
}
