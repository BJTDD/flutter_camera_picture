import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart'; // 녹화된 비디오 재생을 위한 패키지

Future<void> main() async {
  // 플러그인 서비스가 초기화되었는지 확인하여 `availableCameras()`가
  // `runApp()` 전에 호출될 수 있도록 합니다.
  WidgetsFlutterBinding.ensureInitialized();

  // 기기에서 사용 가능한 카메라 목록을 가져옵니다.
  final cameras = await availableCameras();

  // 사용 가능한 카메라 목록에서 후면 카메라와 전면 카메라를 선택합니다.
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
      home: TakeVideoScreen(
        backCamera: backCamera,
        frontCamera: frontCamera,
      ),
    );
  }
}

// 비디오 촬영을 위한 화면
class TakeVideoScreen extends StatefulWidget {
  const TakeVideoScreen({
    super.key,
    required this.backCamera,
    required this.frontCamera,
  });

  final CameraDescription backCamera;
  final CameraDescription frontCamera;

  @override
  TakeVideoScreenState createState() => TakeVideoScreenState();
}

class TakeVideoScreenState extends State<TakeVideoScreen> {
  late CameraController _controller; // 카메라 컨트롤러를 선언합니다.
  late Future<void> _initializeControllerFuture; // 컨트롤러 초기화 Future를 선언합니다.
  bool isBackCamera = true; // 현재 사용 중인 카메라 방향
  bool isRecording = false; // 현재 녹화 상태

  @override
  void initState() {
    super.initState();
    _initializeCamera(); // 카메라 초기화
  }

  // 카메라 초기화 메서드 _switchCamera()여기에서 호출됨
  void _initializeCamera() {
    final selectedCamera =
        isBackCamera ? widget.backCamera : widget.frontCamera;

    // 카메라의 현재 출력을 표시하기 위해 CameraController를 생성합니다.
    _controller = CameraController(
      selectedCamera, // 선택된 카메라
      ResolutionPreset.medium, // 해상도 설정
      enableAudio: true, // 오디오 녹음을 활성화
    );

    _initializeControllerFuture =
        _controller.initialize(); // 컨트롤러 초기화 Future를 반환
    setState(() {}); // 상태 업데이트
  }

  @override
  void dispose() {
    // 위젯이 dispose될 때 컨트롤러도 함께 dispose합니다.
    _controller.dispose();
    super.dispose();
  }

  void _switchCamera() {
    setState(() {
      isBackCamera = !isBackCamera; // 카메라 방향 변경
      _controller.dispose(); // 기존 컨트롤러 dispose
      _initializeCamera(); // 새로운 카메라 초기화
    });
  }

  // 동영상 녹화 시작 메서드
  Future<void> _startVideoRecording() async {
    try {
      await _initializeControllerFuture; // 컨트롤러 초기화 대기

      // 최신 camera 패키지에서는 startVideoRecording()에 파일 경로를 전달하지 않음
      // 비디오는 임시 경로에 저장되며, 녹화 종료 후 파일 경로를 받음
      await _controller.startVideoRecording();

      setState(() {
        isRecording = true; // 녹화 상태 업데이트
      });
    } catch (e) {
      print('비디오 녹화 시작 오류: $e');
    }
  }

  // 동영상 녹화 중지 및 저장 메서드
  Future<void> _stopVideoRecording() async {
    try {
      final XFile video =
          await _controller.stopVideoRecording(); // 녹화 중지 및 파일 받기

      setState(() {
        isRecording = false; // 녹화 상태 업데이트
      });

      if (!context.mounted) return; // State가 마운트 되어 있는지 확인

      // 녹화된 비디오를 재생할 화면으로 이동
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => DisplayVideoScreen(
            videoPath: video.path, // 비디오 파일 경로 전달
          ),
        ),
      );
    } catch (e) {
      print('비디오 녹화 중지 오류: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('동영상 촬영'),
        actions: [
          IconButton(
            onPressed: _switchCamera, // 카메라 전환 버튼
            icon: const Icon(Icons.switch_camera),
          )
        ],
      ),
      // 카메라 초기화가 완료될 때까지 로딩 인디케이터 표시
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            // Future가 완료되면 카메라 미리보기를 표시
            return CameraPreview(_controller);
          } else {
            // 그렇지 않으면 로딩 인디케이터를 표시
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        // 녹화 시작 및 중지를 위한 콜백
        onPressed: isRecording ? _stopVideoRecording : _startVideoRecording,
        backgroundColor: isRecording ? Colors.red : Colors.blue,
        child: Icon(isRecording ? Icons.stop : Icons.videocam),
      ),
    );
  }
}

// 녹화된 비디오를 표시하는 화면
class DisplayVideoScreen extends StatefulWidget {
  final String videoPath; // 비디오 파일 경로

  const DisplayVideoScreen({
    super.key,
    required this.videoPath,
  });

  @override
  DisplayVideoScreenState createState() => DisplayVideoScreenState();
}

class DisplayVideoScreenState extends State<DisplayVideoScreen> {
  late VideoPlayerController _videoPlayerController; // 비디오 플레이어 컨트롤러
  late Future<void> _initializeVideoPlayerFuture; // 비디오 플레이어 초기화 Future

  @override
  void initState() {
    super.initState();
    // 비디오 플레이어 컨트롤러 초기화
    _videoPlayerController = VideoPlayerController.file(File(widget.videoPath));
    _initializeVideoPlayerFuture =
        _videoPlayerController.initialize().then((_) {
      if (!mounted) return; // State가 마운트 되어 있는지 확인
      setState(() {}); // 상태 업데이트
      _videoPlayerController.play(); // 비디오 자동 재생
    }).catchError((e) {
      print('비디오 플레이어 초기화 오류: $e');
    });
  }

  @override
  void dispose() {
    _videoPlayerController.dispose(); // 비디오 플레이어 컨트롤러 dispose
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('녹화된 비디오'),
      ),
      body: Center(
        child: FutureBuilder<void>(
          future: _initializeVideoPlayerFuture, // 비디오 플레이어 초기화 Future 사용
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              // 비디오 재생 화면 표시
              return AspectRatio(
                aspectRatio: _videoPlayerController.value.aspectRatio,
                child: VideoPlayer(_videoPlayerController),
              );
            } else if (snapshot.hasError) {
              // 초기화 중 오류 발생 시 메시지 표시
              return const Text('비디오를 로드할 수 없습니다.');
            } else {
              // 초기화 중 로딩 인디케이터 표시
              return const CircularProgressIndicator();
            }
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).pop(); // 이전 화면으로 돌아감
        },
        child: const Icon(Icons.arrow_back),
      ),
    );
  }
}
