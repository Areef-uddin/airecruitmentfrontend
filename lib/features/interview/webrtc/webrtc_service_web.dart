import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import '../../../../repositories/interview_repository.dart';
import 'webrtc_service_stub.dart';

dynamic allowInterop<F extends Function>(F f) => f;

class WebRTCWebServiceImpl implements WebRTCService {
  html.VideoElement? _localVideoElement;
  late final String _localViewId;
  final Map<String, html.VideoElement> _remoteVideoElements = {};
  final Map<String, String> _remoteViewIds = {};
  final Set<String> _connectedPeers = {};
  String _myUserId = 'me';
  String _currentTargetLang = 'Auto / Original';
  final InterviewRepository _interviewRepo = InterviewRepository();

  WebRTCWebServiceImpl() {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    _localViewId = 'local-video-stream-$timestamp';

    _localVideoElement = html.VideoElement()
      ..autoplay = true
      ..muted = true
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'cover'
      ..style.borderRadius = '16px';

    ui_web.platformViewRegistry.registerViewFactory(
      _localViewId,
      (int id) => _localVideoElement!,
    );
  }

  @override
  bool get hasRemoteStream => _connectedPeers.isNotEmpty;

  @override
  bool hasRemoteStreamFor(String userId) => _connectedPeers.contains(userId);

  String _getOrCreateRemoteViewId(String userId) {
    if (_remoteViewIds.containsKey(userId)) {
      return _remoteViewIds[userId]!;
    }

    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final viewId = 'remote-video-$userId-$timestamp';
    final videoElem = html.VideoElement()
      ..autoplay = true
      ..muted = true // Kept muted so browser does not block video autoplay. Audio is played via dedicated HTMLAudioElement!
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'cover'
      ..style.borderRadius = '16px';

    _remoteViewIds[userId] = viewId;
    _remoteVideoElements[userId] = videoElem;

    ui_web.platformViewRegistry.registerViewFactory(
      viewId,
      (int id) => videoElem,
    );

    try {
      final jsRTC = js.context['TalentAIWebRTC'];
      if (jsRTC != null) {
        jsRTC.callMethod('attachRemoteVideoForUser', [userId, videoElem]);
      }
    } catch (_) {}

    return viewId;
  }

  @override
  Future<bool> initMedia({
    Function(String signalJson, String? toUser)? onSignal,
    Function(String userId, bool connected)? onRemoteTrack,
    String? myUserId,
  }) async {
    _myUserId = myUserId ?? 'me';
    try {
      final jsRTC = js.context['TalentAIWebRTC'];
      if (jsRTC != null) {
        final onSignalJs = (dynamic sig, dynamic toUser) {
          if (onSignal != null && sig != null) {
            onSignal(sig.toString(), toUser?.toString());
          }
        };

        final onRemoteTrackJs = (dynamic remoteUser, dynamic connected) {
          final uId = remoteUser?.toString() ?? 'default';
          _connectedPeers.add(uId);

          if (_remoteVideoElements.containsKey(uId)) {
            jsRTC.callMethod('attachRemoteVideoForUser', [uId, _remoteVideoElements[uId]]);
          }

          if (onRemoteTrack != null) {
            onRemoteTrack(uId, true);
          }
        };

        final promise = jsRTC.callMethod('init', [
          allowInterop(onSignalJs),
          allowInterop(onRemoteTrackJs),
          _myUserId,
        ]);

        // Await promise if possible
        if (promise != null && js.JsObject.fromBrowserObject(promise).hasProperty('then')) {
          final completer = Completer<void>();
          js.JsObject.fromBrowserObject(promise).callMethod('then', [
            allowInterop((_) {
              if (!completer.isCompleted) completer.complete();
            }),
            allowInterop((err) {
              if (!completer.isCompleted) completer.complete();
            }),
          ]);
          try {
            await completer.future.timeout(const Duration(seconds: 5));
          } catch (_) {}
        }

        if (_localVideoElement != null) {
          jsRTC.callMethod('attachLocalVideo', [_localVideoElement]);
        }
        return true;
      }
    } catch (e) {
      // Fallback direct html getUserMedia
      try {
        final mediaDevices = html.window.navigator.mediaDevices;
        if (mediaDevices != null) {
          final stream = await mediaDevices.getUserMedia({'video': true, 'audio': true});
          if (_localVideoElement != null) {
            _localVideoElement!.srcObject = stream;
          }
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  @override
  Widget buildVideoView({
    required bool isLocal,
    required bool isVideoOn,
    required String userName,
    required String userRole,
    String? userId,
  }) {
    if (isLocal) {
      if (isVideoOn) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: HtmlElementView(viewType: _localViewId),
        );
      }
    } else {
      final targetUserId = userId ?? 'default';
      final viewId = _getOrCreateRemoteViewId(targetUserId);

      // Re-trigger attachment in case element rendered after track
      try {
        final jsRTC = js.context['TalentAIWebRTC'];
        if (jsRTC != null && _remoteVideoElements.containsKey(targetUserId)) {
          jsRTC.callMethod('attachRemoteVideoForUser', [targetUserId, _remoteVideoElements[targetUserId]]);
        }
      } catch (_) {}

      if (isVideoOn) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: HtmlElementView(viewType: viewId),
        );
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF13141F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2E324D)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFD946EF).withOpacity(0.4), width: 2),
                  ),
                ),
                CircleAvatar(
                  radius: 36,
                  backgroundColor: const Color(0xFF8B5CF6).withOpacity(0.25),
                  child: Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFFD946EF)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(userName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2030),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(userRole, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
            ),
            if (!isVideoOn) ...[
              const SizedBox(height: 8),
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.videocam_off, size: 14, color: Color(0xFF64748B)),
                  SizedBox(width: 4),
                  Text('Camera is off', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void createOffer() {
    try {
      final jsRTC = js.context['TalentAIWebRTC'];
      if (jsRTC != null) {
        jsRTC.callMethod('createOffer');
      }
    } catch (_) {}
  }

  @override
  void createOfferForUser(String targetUserId) {
    try {
      final jsRTC = js.context['TalentAIWebRTC'];
      if (jsRTC != null) {
        jsRTC.callMethod('createOfferForUser', [targetUserId]);
      }
    } catch (_) {}
  }

  @override
  void handleSignal(String signalJson, {String? fromUser}) {
    try {
      final jsRTC = js.context['TalentAIWebRTC'];
      if (jsRTC != null) {
        jsRTC.callMethod('handleSignal', [signalJson, fromUser]);
      }
    } catch (_) {}
  }

  @override
  void toggleCamera(bool enabled) {
    try {
      final jsRTC = js.context['TalentAIWebRTC'];
      if (jsRTC != null) {
        jsRTC.callMethod('toggleCamera', [enabled]);
      }
    } catch (_) {}
  }

  @override
  void toggleMic(bool enabled) {
    try {
      final jsRTC = js.context['TalentAIWebRTC'];
      if (jsRTC != null) {
        jsRTC.callMethod('toggleMic', [enabled]);
      }
    } catch (_) {}
  }

  @override
  Future<bool> startScreenShare() async {
    try {
      final jsRTC = js.context['TalentAIWebRTC'];
      if (jsRTC != null) {
        final onAttached = (dynamic stream) {
          if (_localVideoElement != null && stream != null) {
            _localVideoElement!.srcObject = stream;
          }
        };
        final res = jsRTC.callMethod('startScreenShare', [allowInterop(onAttached)]);
        return res == true;
      }
    } catch (_) {}
    return false;
  }

  @override
  void stopScreenShare() {
    try {
      final jsRTC = js.context['TalentAIWebRTC'];
      if (jsRTC != null) {
        jsRTC.callMethod('stopScreenShare');
        if (_localVideoElement != null) {
          jsRTC.callMethod('attachLocalVideo', [_localVideoElement]);
        }
      }
    } catch (_) {}
  }

  @override
  void startSpeechRecognition({
    required String targetLang,
    required Function(String text, String translated) onResult,
  }) {
    _currentTargetLang = targetLang;
    try {
      final jsSpeech = js.context['TalentAISpeech'];
      if (jsSpeech != null) {
        final onTranscript = (dynamic spoken, dynamic isFinal) async {
          final transcript = spoken?.toString() ?? '';
          final isFinalBool = isFinal == true;

          if (transcript.isNotEmpty) {
            String translated = '';
            if (_currentTargetLang != 'Auto / Original' && _currentTargetLang != 'English') {
              if (isFinalBool) {
                translated = await _interviewRepo.translateText(transcript, _currentTargetLang);
              }
            }
            onResult(transcript, translated);
          }
        };

        jsSpeech.callMethod('start', [
          targetLang,
          allowInterop(onTranscript),
        ]);
      }
    } catch (_) {}
  }

  @override
  void stopSpeechRecognition() {
    try {
      final jsSpeech = js.context['TalentAISpeech'];
      if (jsSpeech != null) {
        jsSpeech.callMethod('stop');
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    stopSpeechRecognition();
    stopScreenShare();
    try {
      final jsRTC = js.context['TalentAIWebRTC'];
      if (jsRTC != null) {
        jsRTC.callMethod('close');
      }
    } catch (_) {}
    if (_localVideoElement != null) {
      _localVideoElement!.remove();
      _localVideoElement = null;
    }
    for (final elem in _remoteVideoElements.values) {
      try { elem.remove(); } catch (_) {}
    }
    _remoteVideoElements.clear();
    _remoteViewIds.clear();
    _connectedPeers.clear();
  }
}

WebRTCService getWebRTCService() => WebRTCWebServiceImpl();
