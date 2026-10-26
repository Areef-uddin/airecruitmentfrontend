import 'package:flutter/material.dart';

abstract class WebRTCService {
  static WebRTCService create() => throw UnsupportedError('Cannot create WebRTCService without implementation');

  Future<bool> initMedia({
    Function(String signalJson, String? toUser)? onSignal,
    Function(String userId, bool connected)? onRemoteTrack,
    String? myUserId,
  });
  Widget buildVideoView({
    required bool isLocal,
    required bool isVideoOn,
    required String userName,
    required String userRole,
    String? userId,
  });
  void createOffer();
  void createOfferForUser(String targetUserId);
  void handleSignal(String signalJson, {String? fromUser});
  void toggleCamera(bool enabled);
  void toggleMic(bool enabled);
  Future<bool> startScreenShare();
  void stopScreenShare();
  void startSpeechRecognition({required String targetLang, required Function(String text, String translated) onResult});
  void stopSpeechRecognition();
  void speakText(String text, {String? lang});
  void stopSpeaking();
  bool get hasRemoteStream;
  bool hasRemoteStreamFor(String userId);
  void dispose();
}

class WebRTCServiceImpl implements WebRTCService {
  @override
  bool get hasRemoteStream => false;

  @override
  bool hasRemoteStreamFor(String userId) => false;

  @override
  Future<bool> initMedia({
    Function(String signalJson, String? toUser)? onSignal,
    Function(String userId, bool connected)? onRemoteTrack,
    String? myUserId,
  }) async => false;

  @override
  void createOffer() {}

  @override
  void createOfferForUser(String targetUserId) {}

  @override
  void handleSignal(String signalJson, {String? fromUser}) {}

  @override
  Widget buildVideoView({
    required bool isLocal,
    required bool isVideoOn,
    required String userName,
    required String userRole,
    String? userId,
  }) {
    return Container(
      color: const Color(0xFF13141F),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: const Color(0xFF8B5CF6).withOpacity(0.2),
              child: Text(
                userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6)),
              ),
            ),
            const SizedBox(height: 12),
            Text(userName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text(userRole, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
          ],
        ),
      ),
    );
  }

  @override
  void toggleCamera(bool enabled) {}

  @override
  void toggleMic(bool enabled) {}

  @override
  Future<bool> startScreenShare() async => false;

  @override
  void stopScreenShare() {}

  @override
  void startSpeechRecognition({required String targetLang, required Function(String text, String translated) onResult}) {}

  @override
  void stopSpeechRecognition() {}

  @override
  void speakText(String text, {String? lang}) {}

  @override
  void stopSpeaking() {}

  @override
  void dispose() {}
}

WebRTCService getWebRTCService() => WebRTCServiceImpl();
