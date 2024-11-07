import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  // 플러그인 서비스가 초기화되었는지 확인하여 `availableCameras()`가
  // `runApp()` 전에 호출될 수 있도록 합니다.
  WidgetsFlutterBinding.ensureInitialized();

  // 기기에서 사용 가능한 카메라 목록을 가져옵니다.
  final cameras = await availableCameras();

  // 사용 가능한 카메라 목록에서 특정 카메라를 선택합니다.
  // final firstCamera = cameras.first; // 후면카메라
  // 후면 카메라와 전면 카메라를 분리합니다.
  final backCamera = cameras.firstWhere(
    (camera) => camera.lensDirection == CameraLensDirection.back,
    orElse: () => cameras.first,
  );

  final frontCamera = cameras.firstWhere(
    (camera) => camera.lensDirection == CameraLensDirection.front,
    orElse: () => cameras.first,
  );

  runApp(
    MyApp(
      backCamera: backCamera,
      frontCamera: frontCamera,
    ),
  );
}

class MyApp extends StatelessWidget {
  final CameraDescription backCamera;
  final CameraDescription frontCamera;

  const MyApp({
    super.key,
    required this.backCamera,
    required this.frontCamera,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark(),
      home: TakePictureScreen(
        backCamera: backCamera,
        frontCamera: frontCamera,
      ),
    );
  }
}

// 주어진 카메라를 사용하여 사진을 찍을 수 있는 화면입니다.
class TakePictureScreen extends StatefulWidget {
  const TakePictureScreen({
    super.key,
    required this.backCamera,
    required this.frontCamera,
  });

  final CameraDescription backCamera;
  final CameraDescription frontCamera;

  @override
  TakePictureScreenState createState() => TakePictureScreenState();
}

class TakePictureScreenState extends State<TakePictureScreen> {
  late CameraController _controller; // 카메라 컨트롤러를 선언합니다.
  late Future<void> _initializeControllerFuture; // 컨트롤러 초기화 Future를 선언합니다.
  bool isBackCamera = true; // 현재 사용 중인 카메라 방향을 추적 기본은 후면카메라

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  // 기본으로 맨처음에 초기화되고 _switchCamera()여기에서 호출됨
  void _initializeCamera() {
    final selectedCamera =
        isBackCamera ? widget.backCamera : widget.frontCamera;

    // 카메라의 현재 출력을 표시하기 위해 CameraController를 생성합니다.
    _controller = CameraController(
      selectedCamera, // 사용 가능한 카메라 목록에서 특정 카메라를 가져옵니다.
      ResolutionPreset.medium, // 사용할 해상도를 정의합니다.
    );

    // 다음으로, 컨트롤러를 초기화합니다. 이는 Future를 반환합니다.
    _initializeControllerFuture = _controller.initialize();
    setState(() {});
  }

  @override
  void dispose() {
    // 위젯이 dispose될 때 컨트롤러도 함께 dispose합니다.
    _controller.dispose();
    super.dispose();
  }

  void _switchCamera() {
    setState(() {
      // 카메라를 바꾸면 dispose하고 다시 카메라 초기화
      isBackCamera = !isBackCamera;
      _controller.dispose();
      _initializeCamera();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '사진 찍기',
        ),
        actions: [
          IconButton(
            onPressed: _switchCamera,
            icon: const Icon(
              Icons.switch_camera,
            ),
          )
        ],
      ),
      // 컨트롤러가 초기화될 때까지 기다린 후 카메라 미리보기를 표시해야 합니다.
      // FutureBuilder를 사용하여 컨트롤러 초기화가 완료될 때까지 로딩 스피너를 표시합니다.
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            // Future가 완료되면 카메라 미리보기를 표시합니다.
            return CameraPreview(_controller);
          } else {
            // 그렇지 않으면 로딩 인디케이터를 표시합니다.
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        // onPressed 콜백을 제공합니다.
        onPressed: () async {
          // 사진을 찍는 과정을 try/catch 블록으로 감쌉니다. 오류가 발생하면 catch에서 처리합니다.
          try {
            // 카메라가 초기화되었는지 확인합니다.
            await _initializeControllerFuture;

            // 사진을 찍고 저장된 파일 `image`를 가져옵니다.
            final image = await _controller.takePicture();

            if (!context.mounted) return;

            // 사진이 찍혔다면 새로운 화면에 표시합니다.
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => DisplayPictureScreen(
                  // 자동으로 생성된 경로를 DisplayPictureScreen 위젯에 전달합니다.
                  imagePath: image.path,
                ),
              ),
            );
          } catch (e) {
            // 오류가 발생하면 콘솔에 오류를 출력합니다.
            print(e);
          }
        },
        child: const Icon(Icons.camera_alt), // 카메라 아이콘을 표시합니다.
      ),
    );
  }
}

// 사용자가 찍은 사진을 표시하는 위젯입니다.
class DisplayPictureScreen extends StatelessWidget {
  final String imagePath; // 사진의 파일 경로를 저장합니다.

  const DisplayPictureScreen({
    super.key,
    required this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('사진 표시')),
      // 이미지는 기기에 파일로 저장됩니다. 주어진 경로를 사용하여 `Image.file` 생성자를
      // 사용하여 이미지를 표시합니다.
      body: Image.file(File(imagePath)),
    );
  }
}
