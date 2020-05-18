import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:path/path.dart' show join;
import 'package:path_provider/path_provider.dart';
import 'package:camera/camera.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:assorted_layout_widgets/assorted_layout_widgets.dart';
import 'package:http/http.dart' as http;

import 'img_fix.dart';

const API_URL = "http://192.168.0.26:5123/";

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Obtain a list of the available cameras on the device.
  availableCameras().then((cameras) {
    // Get cameras from the list of available cameras.
    final firstCamera = cameras.first;
    final secondCamera = cameras.length > 1 ? cameras[1] : null;

    runApp(
      OverlaySupport(
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: TakePictureScreen(
            // Pass the appropriate cameras to the TakePictureScreen widget.
            cameraBack: firstCamera,
            cameraFront: secondCamera,
          ),
        ),
      ),
    );
  });
}

// A screen that allows users to take a picture using a given camera.
class TakePictureScreen extends StatefulWidget {
  final CameraDescription cameraBack;
  final CameraDescription cameraFront;

  const TakePictureScreen({
    Key key,
    @required this.cameraBack,
    @required this.cameraFront,
  }) : super(key: key);

  @override
  TakePictureScreenState createState() => TakePictureScreenState();
}

class TakePictureScreenState extends State<TakePictureScreen>
    with WidgetsBindingObserver {
  CameraController _controller;
  Future<void> _initializeControllerFuture;
  bool whichCam;
  double aspectRatio;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    aspectRatio = 2 / 3;
    whichCam = true;
    initCamera(whichCam);
  }

  void initCamera(bool camBool) {
    // To display the current output from the Camera,
    // create a CameraController.
    if (widget.cameraFront == null) {
      camBool = true;
    }
    _controller = CameraController(
      // Get a specific camera from the list of available cameras.
      camBool ? widget.cameraBack : widget.cameraFront,
      // Define the resolution to use.
      ResolutionPreset.medium,
    );

    // Next, initialize the controller. This returns a Future.
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    // Dispose of the controller when the widget is disposed.
    _controller.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print(state);
    if (state == AppLifecycleState.resumed) {
      initCamera(whichCam);
      setState(() {});
    } else {
      _controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    AppBar appBar = AppBar(title: Text('Take a picture!'));
    return Scaffold(
      appBar: appBar,
      body: ColumnSuper(
          innerDistance:
              (1 - 1 / aspectRatio) * MediaQuery.of(context).size.width,
          children: <Widget>[
            FutureBuilder<void>(
              future: _initializeControllerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  // If the Future is complete, display the preview.
                  aspectRatio = _controller.value.aspectRatio;
                  return AspectRatio(
                    aspectRatio: aspectRatio,
                    child: CameraPreview(_controller),
                  );
                } else {
                  // Otherwise, display a loading indicator
                  return Container(
                    height: MediaQuery.of(context).size.width / aspectRatio,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
              },
            ),
            Container(
                color: Colors.black,
                height: MediaQuery.of(context).size.height -
                    appBar.preferredSize.height -
                    MediaQuery.of(context).size.width -
                    MediaQuery.of(context).padding.top,
                width: MediaQuery.of(context).size.width,
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      Container(
                        height: ICON_SIZE,
                        width: ICON_SIZE,
                        child: FloatingActionButton(
                          heroTag: "btn2",
                          backgroundColor: Colors.lightBlueAccent,
                          child: Icon(Icons.switch_camera, size: ICON_SIZE / 2),
                          // Provide an onPressed callback.
                          onPressed: () {
                            _controller.dispose().then((arg) {
                              setState(() {
                                whichCam = !whichCam;
                                initCamera(whichCam);
                              });
                            });
                          },
                        ),
                      ),
                      Container(
                        height: ICON_SIZE,
                        width: ICON_SIZE,
                        child: FloatingActionButton(
                          heroTag: "btn1",
                          backgroundColor: Colors.blueAccent,
                          child: Icon(Icons.camera_alt, size: ICON_SIZE / 2),
                          // Provide an onPressed callback.
                          onPressed: () async {
                            // Take the Picture in a try / catch block. If anything goes wrong,
                            // catch the error.
                            try {
                              // Ensure that the camera is initialized.
                              await _initializeControllerFuture;

                              // Construct the path where the image should be saved using the
                              // pattern package.
                              final name = '${DateTime.now()}.png';
                              final path = join(
                                // Store the picture in the temp directory.
                                // Find the temp directory using the `path_provider` plugin.
                                (await getTemporaryDirectory()).path,
                                name,
                              );

                              // Attempt to take a picture and log where it's been saved.
                              await _controller.takePicture(path);

                              // If the picture was taken, display it on a new screen.
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DisplayPictureScreen(
                                    imagePath: path,
                                    aspectRatio: aspectRatio,
                                    fixedImage:
                                        fixExifRotation(path, !whichCam),
                                  ),
                                ),
                              );
                            } catch (e) {
                              // If an error occurs, log the error to the console.
                              print(e);
                            }
                          },
                        ),
                      ),
                    ])),
          ]),
    );
  }
}

// A widget that displays the picture taken by the user.
class DisplayPictureScreen extends StatelessWidget {
  final String imagePath;
  final double aspectRatio;
  final Future<List<int>> fixedImage;

  const DisplayPictureScreen({
    Key key,
    this.imagePath,
    this.aspectRatio,
    this.fixedImage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    AppBar appBar = AppBar(title: Text('Convert Image?'));

    return Scaffold(
        appBar: appBar,
        body: Column(children: <Widget>[
          Container(
            height: MediaQuery.of(context).size.width,
            child: FutureBuilder<List<int>>(
              future: fixedImage,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Image.memory(snapshot.data);
                } else {
                  // Otherwise, display a loading indicator
                  return Container(
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
              },
            ),
          ),
          Container(
              color: Colors.black,
              height: MediaQuery.of(context).size.height -
                  appBar.preferredSize.height -
                  MediaQuery.of(context).size.width -
                  MediaQuery.of(context).padding.top,
              width: MediaQuery.of(context).size.width,
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    Container(
                        height: ICON_SIZE,
                        width: ICON_SIZE,
                        child: FloatingActionButton(
                            heroTag: "btn3",
                            backgroundColor: Colors.red,
                            child: Icon(Icons.arrow_back, size: ICON_SIZE / 2),
                            // Provide an onPressed callback.
                            onPressed: () {
                              Navigator.maybePop(context);
                            })),
                    Container(
                        height: ICON_SIZE,
                        width: ICON_SIZE,
                        child: FloatingActionButton(
                            heroTag: "btn4",
                            backgroundColor: Colors.yellowAccent,
                            child:
                                Icon(Icons.arrow_upward, size: ICON_SIZE / 2),
                            // Provide an onPressed callback.
                            onPressed: () async {
                              try {
                                var uri = Uri.parse(API_URL);
                                var request = http.MultipartRequest('POST', uri)
                                  ..files.add(await http.MultipartFile.fromPath(
                                    'image',
                                    imagePath,
                                  ));

                                var response = await request.send();
                                if (response.statusCode == 200) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          DisplayGeneratedScreen(
                                        imagePath: imagePath,
                                        aspectRatio: aspectRatio,
                                        convImage: response.stream.toBytes(),
                                      ),
                                    ),
                                  );
                                } else {
                                  showSimpleNotification(
                                    Text(
                                        "Upload failed, is the API running on the network?"),
                                    background: Colors.redAccent,
                                  );
                                  print('Uh');
                                }
                              } catch (e) {
                                print(e);
                                showSimpleNotification(
                                  Text(
                                      "Upload failed, is the API running on the network?"),
                                  background: Colors.redAccent,
                                );
                              }
                            }))
                  ]))
        ]));
  }
}

class DisplayGeneratedScreen extends StatelessWidget {
  final String imagePath;
  final double aspectRatio;
  final Future<List<int>> convImage;

  const DisplayGeneratedScreen({
    Key key,
    this.imagePath,
    this.aspectRatio,
    this.convImage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    AppBar appBar = AppBar(title: Text('Convert Image?'));

    return Scaffold(
        appBar: appBar,
        body: Column(children: <Widget>[
          Container(
            height: MediaQuery.of(context).size.width,
            child: FutureBuilder<List<int>>(
              future: resizeConv(
                  convImage, MediaQuery.of(context).size.width.round()),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Image.memory(snapshot.data);
                } else {
                  // Otherwise, display a loading indicator
                  return Container(
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
              },
            ),
          ),
          Container(
              color: Colors.black,
              height: MediaQuery.of(context).size.height -
                  appBar.preferredSize.height -
                  MediaQuery.of(context).size.width -
                  MediaQuery.of(context).padding.top,
              width: MediaQuery.of(context).size.width,
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    Container(
                        height: ICON_SIZE,
                        width: ICON_SIZE,
                        child: FloatingActionButton(
                            heroTag: "btn5",
                            backgroundColor: Colors.red,
                            child: Icon(Icons.arrow_back, size: ICON_SIZE / 2),
                            // Provide an onPressed callback.
                            onPressed: () {
                              Navigator.maybePop(context);
                            })),
                    Container(
                        height: ICON_SIZE,
                        width: ICON_SIZE,
                        child: FloatingActionButton(
                            heroTag: "btn6",
                            backgroundColor: Colors.greenAccent,
                            child: Icon(Icons.save, size: ICON_SIZE / 2),
                            // Provide an onPressed callback.
                            onPressed: () {
                              saveToPath(imagePath, convImage)
                                  .then((success) => print(success));
                              showSimpleNotification(
                                Text("Saved!"),
                                background: Colors.green,
                              );
                              Navigator.maybePop(context);
                            }))
                  ]))
        ]));
  }
}

const double ICON_SIZE = 100;
