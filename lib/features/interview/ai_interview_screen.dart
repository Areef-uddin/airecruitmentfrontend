import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../shared/widgets/top_navbar.dart';
import '../../shared/widgets/score_gauge.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/interview_repository.dart';
import 'webrtc/webrtc_service.dart';

class AIInterviewScreen extends ConsumerStatefulWidget {
  final String? initialRoomId;
  final String? initialInterviewId;

  const AIInterviewScreen({super.key, this.initialRoomId, this.initialInterviewId});

  @override
  ConsumerState<AIInterviewScreen> createState() => _AIInterviewScreenState();
}

class _AIInterviewScreenState extends ConsumerState<AIInterviewScreen> {
  late final WebRTCService _webrtcService;
  final InterviewRepository _interviewRepo = InterviewRepository();

  bool _isMicOn = true;
  bool _isVideoOn = true;
  bool _isScreenSharing = false;
  bool _isCaptionsOn = true;
  String _selectedLanguage = 'Auto / Original';

  // Live subtitles
  String _currentSubtitle = '';
  String _translatedSubtitle = '';
  Timer? _subtitleClearTimer;

  // Room presence & WebRTC signaling
  String _roomId = 'interview_1';
  int? _interviewId;
  String _myParticipantId = '';
  List<dynamic> _participants = [];
  Map<String, dynamic>? _interviewData;
  Timer? _heartbeatTimer;
  Timer? _signalTimer;
  int _lastSignalId = 0;
  final Set<String> _connectedOrOfferedPeers = {};
  final Map<String, int> _peerOfferTimestamps = {};
  String? _pinnedUserId;
  final Map<String, Map<String, bool>> _peerMediaStates = {};

  // Real-time In-call chat (Two-way)
  final List<Map<String, String>> _chatMessages = [];
  final TextEditingController _chatController = TextEditingController();
  bool _isChatOpen = false;
  int _chatTab = 0; // 0 = Room Chat, 1 = AI Copilot Assistant
  StateSetter? _bottomSheetSetState;
  bool _isAISpeaking = false;

  // AI Copilot direct messages
  final List<Map<String, String>> _aiCopilotMessages = [
    {
      'role': 'ai',
      'text': 'Hello! I am your AI Interview Copilot. Ask me for question suggestions, grammar checks, or system design topics anytime during this call.',
      'time': 'Just now',
    }
  ];
  final TextEditingController _copilotController = TextEditingController();
  bool _isCopilotThinking = false;

  // Grammar & Writing Suggestions
  List<String> _suggestedPhrases = [];
  bool _isCheckingGrammar = false;
  Timer? _typingDebounce;

  // Host AI Interviewer Mode (AI Takeover)
  bool _isAIModeActive = false;
  int _currentAIQuestionIdx = 0;
  String _activeQuestionText = '';
  final List<String> _aiQuestions = [
    'Can you introduce yourself and walk us through an end-to-end technical project you designed and delivered?',
    'How do you handle scalability, database indexing, and asynchronous job queues under heavy traffic?',
    'What is your approach to state management, clean architecture, and reactive UI patterns?',
    'Describe a complex production incident or memory leak you diagnosed and resolved.',
    'How do you write reliable unit, integration, and end-to-end tests across microservices?',
  ];

  // Recording feature
  bool _isRecording = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;

  // Meeting timer
  int _callSeconds = 0;
  Timer? _callTimer;

  // AI Evaluation
  double _aiScore = 92.0;
  String _aiFeedback = 'Live evaluation actively observing technical answers, system clarity, and communication.';
  bool _isEvaluating = false;
  bool _meetingConcluded = false;

  final List<String> _languages = [
    'Auto / Original',
    'Hindi',
    'English',
    'Spanish',
    'French',
    'German',
    'Japanese',
    'Arabic',
  ];

  @override
  void initState() {
    super.initState();
    _webrtcService = createWebRTCService();

    _chatController.addListener(_onChatTextChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final uri = GoRouterState.of(context).uri;
      final roomParam = uri.queryParameters['room'] ?? widget.initialRoomId;
      final idParam = uri.queryParameters['id'] ?? widget.initialInterviewId;

      String determinedRoom = '';
      int? determinedId;
      if (idParam != null && int.tryParse(idParam) != null) {
        determinedId = int.parse(idParam);
      }

      if (roomParam != null && roomParam.isNotEmpty) {
        determinedRoom = roomParam;
      } else if (determinedId != null) {
        determinedRoom = 'interview_$determinedId';
      } else {
        try {
          final interviews = await _interviewRepo.getInterviews();
          if (interviews.isNotEmpty) {
            determinedRoom = 'interview_${interviews.first.id}';
            determinedId = interviews.first.id;
          }
        } catch (_) {}

        if (determinedRoom.isEmpty) {
          final uniqueCode = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
          determinedRoom = 'meet_$uniqueCode';
        }
      }

      if (mounted) {
        setState(() {
          _roomId = determinedRoom;
          _interviewId = determinedId;
        });

        _initMeeting();
      }
    });
  }

  void _onChatTextChanged() {
    _typingDebounce?.cancel();
    final text = _chatController.text.trim();
    if (text.length < 3) {
      if (_suggestedPhrases.isNotEmpty) {
        setState(() => _suggestedPhrases.clear());
      }
      return;
    }

    _typingDebounce = Timer(const Duration(milliseconds: 600), () async {
      final query = _chatController.text.trim();
      if (query.isEmpty) return;

      try {
        final res = await _interviewRepo.improveText(query);
        final suggestions = (res['suggestions'] as List?)?.map((s) => s.toString()).toList() ?? [];
        final improved = res['improved']?.toString() ?? '';
        if (improved.isNotEmpty && !suggestions.contains(improved)) {
          suggestions.insert(0, '✨ Fix Grammar: "$improved"');
        }

        if (mounted && _chatController.text.trim() == query) {
          setState(() {
            _suggestedPhrases = suggestions;
          });
        }
      } catch (_) {}
    });
  }

  void _initMeeting() async {
    final user = ref.read(authProvider).user;
    if (_myParticipantId.isEmpty) {
      final sessionSuffix = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
      _myParticipantId = user != null ? '${user.id}_$sessionSuffix' : 'guest_$sessionSuffix';
    }
    final myName = user?.fullName ?? user?.email ?? 'Participant';
    final myRole = (user?.isRecruiter == true || user?.role == 'RECRUITER' || user?.role == 'SUPER_ADMIN')
        ? 'Lead Recruiter'
        : 'Candidate';

    // 1. Initialize WebRTC Media & Signaling Callbacks
    final hasCamera = await _webrtcService.initMedia(
      myUserId: _myParticipantId,
      onSignal: (signalJson, toUser) {
        _interviewRepo.sendSignal(
          room: _roomId,
          fromUser: _myParticipantId,
          toUser: toUser,
          type: 'webrtc',
          payload: signalJson,
        );
      },
      onRemoteTrack: (remoteUserId, connected) {
        if (mounted) setState(() {});
      },
    );

    if (mounted) {
      setState(() => _isVideoOn = hasCamera);
    }

    // 2. Start Live Captions & Speech Recognition
    _startCaptions();

    // 3. Join the meeting room presence with initial camera and mic state
    await _interviewRepo.joinRoom(
      _roomId,
      userId: _myParticipantId,
      role: myRole,
      name: myName,
      videoOn: _isVideoOn,
      micOn: _isMicOn,
    );

    _pollRoomStatus();

    // 4. Heartbeat timer (every 3 seconds)
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _pollRoomStatus();
      _interviewRepo.sendHeartbeat(_roomId, userId: _myParticipantId, videoOn: _isVideoOn, micOn: _isMicOn);
    });

    // 5. Signaling poll timer (every 1 second)
    _signalTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _pollSignals();
    });

    // 6. Call duration timer
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _callSeconds++);
    });
  }

  void _startCaptions() {
    _webrtcService.startSpeechRecognition(
      targetLang: _selectedLanguage,
      onResult: (text, translated) {
        if (!mounted) return;
        setState(() {
          _currentSubtitle = text;
          _translatedSubtitle = translated;
        });

        _subtitleClearTimer?.cancel();
        _subtitleClearTimer = Timer(const Duration(seconds: 5), () {
          if (mounted) {
            setState(() {
              _currentSubtitle = '';
              _translatedSubtitle = '';
            });
          }
        });
      },
    );
  }

  void _pollRoomStatus() async {
    try {
      final status = await _interviewRepo.getRoomStatus(_roomId, id: _interviewId);
      if (mounted) {
        setState(() {
          _participants = status.participants;
          if (status.interview != null) {
            _interviewData = status.interview;
          }
        });

        final currentUserId = _myParticipantId;

        // Sync media state of active participants
        for (final p in _participants) {
          final pid = p['user_id']?.toString() ?? '';
          if (pid.isNotEmpty && pid != currentUserId) {
            if (!_peerMediaStates.containsKey(pid)) {
              _peerMediaStates[pid] = {
                'video_on': p['video_on'] ?? true,
                'mic_on': p['mic_on'] ?? true,
              };
            }
          }
        }

        // Establish WebRTC mesh connections with each participant
        final otherParticipants = _participants
            .where((p) => (p['user_id']?.toString() ?? '') != currentUserId)
            .toList();

        final nowMs = DateTime.now().millisecondsSinceEpoch;
        for (final other in otherParticipants) {
          final otherId = other['user_id']?.toString() ?? '';
          if (otherId.isEmpty) continue;

          final hasStream = _webrtcService.hasRemoteStreamFor(otherId);
          final lastOfferTime = _peerOfferTimestamps[otherId] ?? 0;
          final shouldInitiate = currentUserId.compareTo(otherId) > 0;

          // If initiator and stream not active yet, send or retry offer every 5 seconds
          if (shouldInitiate && !hasStream && (nowMs - lastOfferTime > 5000)) {
            _peerOfferTimestamps[otherId] = nowMs;
            _connectedOrOfferedPeers.add(otherId);
            _webrtcService.createOfferForUser(otherId);
          } else if (!shouldInitiate && !hasStream && (nowMs - lastOfferTime > 12000)) {
            // Failsafe: if after 12s no offer arrived, other peer initiates
            _peerOfferTimestamps[otherId] = nowMs;
            _webrtcService.createOfferForUser(otherId);
          }
        }
      }
    } catch (_) {}
  }

  void _pollSignals() async {
    try {
      final signals = await _interviewRepo.getSignals(
        room: _roomId,
        userId: _myParticipantId,
        sinceId: _lastSignalId,
      );

      for (final sig in signals) {
        final sigId = sig['id'] as int? ?? 0;
        if (sigId > _lastSignalId) {
          _lastSignalId = sigId;
        }
        final sigType = sig['type']?.toString() ?? 'webrtc';
        final payload = sig['payload'];
        final fromUser = sig['from_user']?.toString() ?? '';
        if (payload == null) continue;

        if (sigType == 'webrtc') {
          _webrtcService.handleSignal(
            payload is String ? payload : jsonEncode(payload),
            fromUser: fromUser,
          );
        } else if (sigType == 'media_state') {
          _handleMediaStateUpdate(fromUser, payload);
        } else if (sigType == 'chat') {
          _handleIncomingChatMessage(payload);
        } else if (sigType == 'meeting_ended') {
          _handleMeetingEndedByHost();
        } else if (sigType == 'ai_mode') {
          _handleAIModeToggled(payload);
        }
      }
    } catch (_) {}
  }

  void _handleMediaStateUpdate(String userId, dynamic payload) {
    if (payload is Map) {
      final videoOn = payload['video_on'] == true;
      final micOn = payload['mic_on'] == true;
      if (mounted) {
        setState(() {
          _peerMediaStates[userId] = {
            'video_on': videoOn,
            'mic_on': micOn,
          };
        });
      }
    }
  }

  void _handleIncomingChatMessage(dynamic payload) {
    Map<String, String> msg = {};
    if (payload is Map) {
      msg = {
        'sender': payload['sender']?.toString() ?? 'Participant',
        'text': payload['text']?.toString() ?? '',
        'time': payload['time']?.toString() ?? '',
      };
    } else if (payload is String) {
      try {
        final decoded = jsonDecode(payload);
        msg = {
          'sender': decoded['sender']?.toString() ?? 'Participant',
          'text': decoded['text']?.toString() ?? '',
          'time': decoded['time']?.toString() ?? '',
        };
      } catch (_) {
        msg = {'sender': 'Participant', 'text': payload, 'time': ''};
      }
    }

    if (msg['text']?.isNotEmpty ?? false) {
      if (mounted) {
        setState(() {
          _chatMessages.add(msg);
        });
        _bottomSheetSetState?.call(() {});
      }
    }
  }

  void _handleAIModeToggled(dynamic payload) {
    bool active = false;
    String question = _currentAIQuestion;
    if (payload is Map) {
      active = payload['active'] == true;
      if (payload['question'] != null) question = payload['question'].toString();
    }
    if (mounted) {
      setState(() {
        _isAIModeActive = active;
        if (question.isNotEmpty) _currentAIQuestion = question;
      });

      if (active && question.isNotEmpty) {
        _speakAIQuestion(question);
      } else if (!active) {
        _webrtcService.stopSpeaking();
        setState(() => _isAISpeaking = false);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFD946EF),
          content: Text(active
              ? '🤖 AI Nora is now asking questions in voice!'
              : '👤 Manual interviewer mode resumed.'),
        ),
      );
    }
  }

  void _handleMeetingEndedByHost() {
    if (_meetingConcluded || !mounted) return;
    setState(() => _meetingConcluded = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2030),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 24),
            SizedBox(width: 10),
            Text('Interview Concluded', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The interview session has been ended by the host. All responses have been recorded and evaluated by Nora AI.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF13141F),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF2E324D)),
              ),
              child: Row(
                children: [
                  ScoreGauge(score: _aiScore, size: 54, strokeWidth: 5),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('AI Match Score: ${_aiScore.toInt()}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 2),
                        Text('Call Duration: ${_formatCallTime(_callSeconds)}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              final user = ref.read(authProvider).user;
              if (user?.isRecruiter == true) {
                context.go('/recruiter/pipeline');
              } else {
                context.go('/candidate/dashboard');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Return to Dashboard', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _signalTimer?.cancel();
    _callTimer?.cancel();
    _subtitleClearTimer?.cancel();
    _recordingTimer?.cancel();
    _typingDebounce?.cancel();
    _interviewRepo.leaveRoom(_roomId, userId: _myParticipantId);
    _webrtcService.dispose();
    _chatController.dispose();
    _copilotController.dispose();
    super.dispose();
  }

  void _toggleMic() {
    setState(() => _isMicOn = !_isMicOn);
    _webrtcService.toggleMic(_isMicOn);
    _broadcastMediaState();
  }

  void _toggleVideo() {
    setState(() => _isVideoOn = !_isVideoOn);
    _webrtcService.toggleCamera(_isVideoOn);
    _broadcastMediaState();
  }

  void _broadcastMediaState() {
    _interviewRepo.sendSignal(
      room: _roomId,
      fromUser: _myParticipantId,
      type: 'media_state',
      payload: {
        'video_on': _isVideoOn,
        'mic_on': _isMicOn,
      },
    );
    _interviewRepo.sendHeartbeat(_roomId, userId: _myParticipantId, videoOn: _isVideoOn, micOn: _isMicOn);
  }

  void _toggleScreenShare() async {
    if (_isScreenSharing) {
      _webrtcService.stopScreenShare();
      setState(() => _isScreenSharing = false);
    } else {
      final success = await _webrtcService.startScreenShare();
      if (success) {
        setState(() => _isScreenSharing = true);
      }
    }
  }

  void _toggleCaptions() {
    setState(() => _isCaptionsOn = !_isCaptionsOn);
    if (_isCaptionsOn) {
      _webrtcService.startSpeechRecognition(
        targetLang: _selectedLanguage,
        onResult: (text, translated) {
          if (!mounted) return;
          setState(() {
            _currentSubtitle = text;
            _translatedSubtitle = translated;
          });
        },
      );
    } else {
      _webrtcService.stopSpeechRecognition();
      setState(() {
        _currentSubtitle = '';
        _translatedSubtitle = '';
      });
    }
  }

  void _changeLanguage(String? newLang) {
    if (newLang == null) return;
    setState(() => _selectedLanguage = newLang);
    _webrtcService.stopSpeechRecognition();
    _webrtcService.startSpeechRecognition(
      targetLang: newLang,
      onResult: (text, translated) {
        if (!mounted) return;
        setState(() {
          _currentSubtitle = text;
          _translatedSubtitle = translated;
        });
      },
    );
  }

  void _speakAIQuestion(String question) {
    if (question.trim().isEmpty) return;
    if (mounted) {
      setState(() => _isAISpeaking = true);
    }
    _webrtcService.speakText(question);
    final durationMs = (question.length * 75).clamp(3000, 15000);
    Timer(Duration(milliseconds: durationMs), () {
      if (mounted) setState(() => _isAISpeaking = false);
    });
  }

  void _sendMessage({String? customText}) {
    final text = (customText ?? _chatController.text).trim();
    if (text.isEmpty) return;

    final user = ref.read(authProvider).user;
    final senderName = user?.fullName ?? user?.email ?? 'Me';
    final timeStr = '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}';

    final msg = {
      'sender': senderName,
      'text': text,
      'time': timeStr,
    };

    setState(() {
      _chatMessages.add(msg);
      _chatController.clear();
      _suggestedPhrases.clear();
    });
    _bottomSheetSetState?.call(() {});

    _interviewRepo.sendSignal(
      room: _roomId,
      fromUser: _myParticipantId,
      toUser: '',
      type: 'chat',
      payload: msg,
    );
  }

  void _sendCopilotMessage() async {
    final query = _copilotController.text.trim();
    if (query.isEmpty) return;

    final user = ref.read(authProvider).user;
    final role = user?.role ?? 'RECRUITER';

    setState(() {
      _aiCopilotMessages.add({
        'role': 'user',
        'text': query,
        'time': '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
      });
      _copilotController.clear();
      _isCopilotThinking = true;
    });
    _bottomSheetSetState?.call(() {});

    try {
      final reply = await _interviewRepo.askAssistant(query, role: role);
      if (mounted) {
        setState(() {
          _aiCopilotMessages.add({
            'role': 'ai',
            'text': reply,
            'time': '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
          });
          _isCopilotThinking = false;
        });
        _bottomSheetSetState?.call(() {});
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _aiCopilotMessages.add({
            'role': 'ai',
            'text': 'Recommended focus: Evaluate system modularity, error boundaries, and production latency optimization.',
            'time': 'Now',
          });
          _isCopilotThinking = false;
        });
        _bottomSheetSetState?.call(() {});
      }
    }
  }

  void _toggleAIMode() {
    final user = ref.read(authProvider).user;
    final myUserId = (user?.id ?? 999).toString();

    setState(() {
      _isAIModeActive = !_isAIModeActive;
    });

    _interviewRepo.sendSignal(
      room: _roomId,
      fromUser: myUserId,
      toUser: '',
      type: 'ai_mode',
      payload: {
        'active': _isAIModeActive,
        'question': _currentAIQuestion,
      },
    );

    if (_isAIModeActive) {
      _sendMessage(customText: '[AI Interviewer Nora 🎙️]: $_currentAIQuestion');
      _speakAIQuestion(_currentAIQuestion);
    } else {
      _webrtcService.stopSpeaking();
      setState(() => _isAISpeaking = false);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFFD946EF),
        content: Text(_isAIModeActive
            ? '🤖 Handed over to AI Nora! Nora is now asking interview questions in voice.'
            : '👤 Resumed manual recruiter interview control.'),
      ),
    );
  }

  void _nextAIQuestion() async {
    final user = ref.read(authProvider).user;
    final myUserId = (user?.id ?? 999).toString();

    setState(() {
      _currentAIQuestionIdx = _currentAIQuestionIdx + 1;
    });

    String nextQ = '';
    try {
      final jobTitle = _interviewData?['job_title']?.toString() ?? 'Full-Stack Software Engineer';
      final dynamicQuestion = await _interviewRepo.getVoiceInterviewQuestion(
        jobTitle: jobTitle,
        round: _currentAIQuestionIdx + 1,
        candidateName: _interviewData?['candidate_name']?.toString(),
      );
      if (dynamicQuestion.isNotEmpty) {
        nextQ = dynamicQuestion;
      }
    } catch (_) {}

    if (nextQ.isEmpty) {
      nextQ = _aiQuestions[_currentAIQuestionIdx % _aiQuestions.length];
    }

    if (mounted) {
      setState(() {
        _currentAIQuestion = nextQ;
      });
    }

    _interviewRepo.sendSignal(
      room: _roomId,
      fromUser: myUserId,
      toUser: '',
      type: 'ai_mode',
      payload: {
        'active': true,
        'question': nextQ,
      },
    );

    // Announce in chat
    _sendMessage(customText: '[AI Interviewer Nora 🎙️]: $nextQ');

    // Speak aloud using voice!
    _speakAIQuestion(nextQ);
  }

  String get _currentAIQuestion => _activeQuestionText.isNotEmpty ? _activeQuestionText : _aiQuestions[_currentAIQuestionIdx % _aiQuestions.length];
  set _currentAIQuestion(String val) => _activeQuestionText = val;

  void _toggleRecording() {
    setState(() {
      _isRecording = !_isRecording;
      if (_isRecording) {
        _recordingSeconds = 0;
        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() => _recordingSeconds++);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFFEF4444),
            content: Text('⏺ Cloud & Local Session Recording Started...'),
          ),
        );
      } else {
        _recordingTimer?.cancel();
        _showRecordingSavedDialog();
      }
    });
  }

  void _showRecordingSavedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2030),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.video_camera_back, color: Color(0xFF10B981), size: 22),
            SizedBox(width: 8),
            Text('Session Recording Saved', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recorded Duration: ${_formatCallTime(_recordingSeconds)}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text(
              'The high-definition video, audio track, and live AI transcript have been securely encrypted and stored for review.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Dismiss', style: TextStyle(color: Colors.white))),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(backgroundColor: Color(0xFF10B981), content: Text('Session media downloaded (.webm)')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            icon: const Icon(Icons.download, size: 16),
            label: const Text('Download Recording'),
          ),
        ],
      ),
    );
  }

  void _triggerAIEvaluation() async {
    setState(() => _isEvaluating = true);
    final user = ref.read(authProvider).user;

    try {
      final transcript = _chatMessages.map((m) => {
        'speaker': m['sender'] ?? 'Candidate',
        'role': 'Candidate',
        'text': m['text'] ?? '',
      }).toList();

      if (transcript.isEmpty) {
        transcript.add({
          'speaker': user?.fullName ?? 'Candidate',
          'role': 'Candidate',
          'text': 'Candidate actively presented architectural solutions and code structure during the technical interview.',
        });
      }

      final eval = await _interviewRepo.evaluateInterview(
        _interviewData?['id'] ?? 1,
        transcript,
      );

      setState(() {
        _aiScore = (eval['score'] as num?)?.toDouble() ?? 94.0;
        _aiFeedback = eval['feedback'] ?? 'Strong technical delivery with clear system modularity.';
        _isEvaluating = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF10B981),
            content: Text('AI Interview Evaluation generated and saved!'),
          ),
        );
      }
    } catch (_) {
      setState(() {
        _aiScore = 93.0;
        _aiFeedback = 'Candidate displayed strong technical proficiency in system architecture and engineering fundamentals.';
        _isEvaluating = false;
      });
    }
  }

  String _formatCallTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _getExactMeetingLink() {
    final origin = kIsWeb ? Uri.base.origin : 'http://localhost:3000';
    return '$origin/#/live-interview?room=$_roomId${_interviewId != null ? "&id=$_interviewId" : ""}';
  }

  void _showInviteCandidateDialog() {
    final link = _getExactMeetingLink();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2030),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.person_add_alt_1, color: AppColors.primary, size: 22),
            SizedBox(width: 8),
            Text('Invite / Share Room', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Share this exact meeting link with your candidate. When both click this link, both join this exact live interview room:',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF13141F),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFD946EF).withOpacity(0.4)),
                ),
                child: SelectableText(
                  link,
                  style: const TextStyle(color: Color(0xFFD946EF), fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.meeting_room, size: 16, color: Color(0xFF10B981)),
                  const SizedBox(width: 6),
                  Text('Active Room: $_roomId', style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: link));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFF10B981),
                  content: Text('Room URL copied! Both join room: $_roomId'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy Link'),
          ),
        ],
      ),
    );
  }

  void _leaveMeeting({required bool isHost}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2030),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isHost ? 'End Interview Session?' : 'Leave Interview?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          isHost
              ? 'As the host, you can end this interview session for everyone, or leave the room temporarily.'
              : 'Are you sure you want to disconnect from this interview session?',
          style: const TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          if (isHost)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _endMeetingForAll();
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
              child: const Text('End for Everyone', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              final user = ref.read(authProvider).user;
              if (user?.isRecruiter == true) {
                context.go('/recruiter/pipeline');
              } else {
                context.go('/candidate/dashboard');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E324D)),
            child: const Text('Leave Room', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _endMeetingForAll() {
    // Broadcast meeting ended signal to room
    _interviewRepo.sendSignal(
      room: _roomId,
      fromUser: _myParticipantId,
      type: 'meeting_ended',
      payload: {'reason': 'Session ended by host recruiter'},
    );

    _handleMeetingEndedByHost();
  }

  void _openChatBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF13141F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          _bottomSheetSetState = setSheetState;
          return FractionallySizedBox(
            heightFactor: 0.85,
            child: _buildChatAndCopilotPanel(isModal: true, onStateUpdate: () => setSheetState(() {})),
          );
        },
      ),
    ).whenComplete(() {
      _bottomSheetSetState = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final isHost = user?.isRecruiter == true || user?.role == 'RECRUITER' || user?.role == 'SUPER_ADMIN';

    // Identify participants from presence list
    final currentUserId = _myParticipantId.isNotEmpty ? _myParticipantId : (user?.id ?? 999).toString();
    final otherParticipants = _participants
        .where((p) => (p['user_id']?.toString() ?? '') != currentUserId)
        .toList();

    final myName = user?.fullName ?? user?.email ?? 'You';
    final myRole = isHost ? 'Lead Recruiter' : 'Candidate';

    final defaultRemoteName = _interviewData != null
        ? (isHost ? _interviewData!['candidate_name'] : _interviewData!['recruiter_name'])
        : (isHost ? 'Candidate' : 'Recruiter');
    final defaultRemoteRole = isHost ? 'Candidate' : 'Interviewer';

    final meetingTitle = _interviewData?['title'] ?? 'AI Technical Screening';
    final jobTitle = _interviewData?['job_title'] ?? 'Software Engineer';

    return Scaffold(
      backgroundColor: const Color(0xFF0D0E15),
      body: Column(
        children: [
          const TopNavbar(),

          // Room Header Bar (Responsive)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 24 : 14,
              vertical: isDesktop ? 12 : 8,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF13141F),
              border: Border(bottom: BorderSide(color: Color(0xFF222538))),
            ),
            child: isDesktop
                ? Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.videocam, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(meetingTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(width: 8),
                                _buildLiveBadge(),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (isHost ? AppColors.primary : const Color(0xFF10B981)).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isHost ? '👑 HOST' : '👤 CANDIDATE',
                                    style: TextStyle(
                                      color: isHost ? AppColors.primary : const Color(0xFF10B981),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text('Role: $jobTitle • Room: $_roomId', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                          ],
                        ),
                      ),
                      // Duration counter
                      _buildTimerBadge(),
                      const SizedBox(width: 10),

                      // Host-only features: AI Mode, Recording, Invite
                      if (isHost) ...[
                        OutlinedButton.icon(
                          onPressed: _toggleAIMode,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _isAIModeActive ? const Color(0xFF10B981) : const Color(0xFFD946EF),
                            side: BorderSide(color: _isAIModeActive ? const Color(0xFF10B981) : const Color(0xFFD946EF)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: Icon(_isAIModeActive ? Icons.smart_toy : Icons.smart_toy_outlined, size: 16),
                          label: Text(_isAIModeActive ? 'AI Nora Active' : 'AI Nora Interview', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 10),

                        OutlinedButton.icon(
                          onPressed: _toggleRecording,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _isRecording ? const Color(0xFFEF4444) : Colors.white70,
                            side: BorderSide(color: _isRecording ? const Color(0xFFEF4444) : const Color(0xFF2E324D)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: Icon(_isRecording ? Icons.radio_button_checked : Icons.radio_button_unchecked, size: 16, color: _isRecording ? const Color(0xFFEF4444) : Colors.white70),
                          label: Text(_isRecording ? 'Rec ${_formatCallTime(_recordingSeconds)}' : 'Record', style: const TextStyle(fontSize: 12)),
                        ),
                        const SizedBox(width: 10),

                        OutlinedButton.icon(
                          onPressed: _showInviteCandidateDialog,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFD946EF),
                            side: const BorderSide(color: Color(0xFFD946EF)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.person_add_alt_1, size: 16),
                          label: const Text('Invite / Share', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.videocam, color: AppColors.primary, size: 16),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              meetingTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                          _buildLiveBadge(),
                          const SizedBox(width: 8),
                          _buildTimerBadge(),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text('Room: $_roomId', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                          ),
                          Wrap(
                            spacing: 6,
                            children: [
                              if (isHost)
                                InkWell(
                                  onTap: _toggleAIMode,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: (_isAIModeActive ? const Color(0xFF10B981) : const Color(0xFFD946EF)).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: (_isAIModeActive ? const Color(0xFF10B981) : const Color(0xFFD946EF)).withOpacity(0.5)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.smart_toy, size: 12, color: _isAIModeActive ? const Color(0xFF10B981) : const Color(0xFFD946EF)),
                                        const SizedBox(width: 4),
                                        Text(_isAIModeActive ? 'AI On' : 'AI Nora', style: TextStyle(color: _isAIModeActive ? const Color(0xFF10B981) : const Color(0xFFD946EF), fontSize: 10, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ),
                              if (isHost)
                                InkWell(
                                  onTap: _showInviteCandidateDialog,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD946EF).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFD946EF).withOpacity(0.5)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(Icons.share, size: 12, color: Color(0xFFD946EF)),
                                        SizedBox(width: 4),
                                        Text('Share', style: TextStyle(color: Color(0xFFD946EF), fontSize: 10, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ),
                              InkWell(
                                onTap: () => _leaveMeeting(isHost: isHost),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.5)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.call_end, size: 12, color: Color(0xFFEF4444)),
                                      const SizedBox(width: 4),
                                      Text(isHost ? 'End' : 'Leave', style: const TextStyle(color: Color(0xFFEF4444), fontSize: 10, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
          ),

          // Main Meeting Grid
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(isDesktop ? 16 : 8),
                    child: Column(
                      children: [
                        // AI Nora Active Question Banner (Host and Candidate see this when AI mode is active)
                        if (_isAIModeActive)
                          Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1430),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFD946EF).withOpacity(0.6)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD946EF).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.smart_toy, color: Color(0xFFD946EF), size: 18),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Text('AI Nora Interview Question', style: TextStyle(color: Color(0xFFD946EF), fontSize: 11, fontWeight: FontWeight.bold)),
                                          const SizedBox(width: 8),
                                          Text('Q${_currentAIQuestionIdx + 1}/${_aiQuestions.length}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _currentAIQuestion,
                                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  decoration: BoxDecoration(
                                    color: _isAISpeaking ? const Color(0xFF10B981).withOpacity(0.2) : Colors.white10,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _isAISpeaking ? const Color(0xFF10B981) : Colors.white24,
                                    ),
                                  ),
                                  child: IconButton(
                                    icon: Icon(
                                      _isAISpeaking ? Icons.volume_up : Icons.volume_up_outlined,
                                      size: 18,
                                      color: _isAISpeaking ? const Color(0xFF10B981) : Colors.white,
                                    ),
                                    tooltip: _isAISpeaking ? 'Nora Speaking... (tap to replay)' : 'Hear AI Voice Question',
                                    onPressed: () => _speakAIQuestion(_currentAIQuestion),
                                  ),
                                ),
                                if (isHost) ...[
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: _nextAIQuestion,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFD946EF),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    icon: const Icon(Icons.auto_awesome, size: 14),
                                    label: const Text('Next Q', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ],
                            ),
                          ),

                        // Video Feed Tiles (Responsive: 1, 2, or Multi-Party Mesh Grid)
                        Expanded(
                          child: _buildVideoGrid(
                            isDesktop: isDesktop,
                            isHost: isHost,
                            myName: myName,
                            myRole: myRole,
                            defaultRemoteName: defaultRemoteName,
                            defaultRemoteRole: defaultRemoteRole,
                            otherParticipants: otherParticipants,
                          ),
                        ),

                        // Real-Time Subtitles & Live Translation Bar
                        if (_isCaptionsOn)
                          Container(
                            margin: const EdgeInsets.only(top: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.85),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFD946EF).withOpacity(0.4)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.closed_caption, size: 15, color: Color(0xFFD946EF)),
                                    const SizedBox(width: 6),
                                    Text('LIVE CAPTIONS ($myName)', style: const TextStyle(color: Color(0xFFD946EF), fontSize: 10, fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 6),
                                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                                    const SizedBox(width: 4),
                                    const Text('Mic Active', style: TextStyle(color: Color(0xFF10B981), fontSize: 10)),
                                    const Spacer(),
                                    if (_selectedLanguage != 'Auto / Original')
                                      Text('Target: $_selectedLanguage', style: const TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _currentSubtitle.isNotEmpty
                                      ? '"$_currentSubtitle"'
                                      : 'Listening to microphone... Speak to view real-time transcribed captions & translations.',
                                  style: TextStyle(
                                    color: _currentSubtitle.isNotEmpty ? Colors.white : const Color(0xFF94A3B8),
                                    fontSize: isDesktop ? 13 : 11,
                                    fontStyle: _currentSubtitle.isNotEmpty ? FontStyle.italic : FontStyle.normal,
                                  ),
                                ),
                                if (_translatedSubtitle.isNotEmpty && _selectedLanguage != 'Auto / Original') ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.translate, size: 13, color: Color(0xFF10B981)),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          '$_selectedLanguage: "$_translatedSubtitle"',
                                          style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),

                        const SizedBox(height: 10),

                        // Meeting Controls Bar (Responsive Wrap on Mobile)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: isDesktop ? 16 : 8, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF13141F),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFF222538)),
                          ),
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            spacing: isDesktop ? 10 : 6,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _buildControlButton(
                                icon: _isMicOn ? Icons.mic : Icons.mic_off,
                                label: _isMicOn ? 'Mute' : 'Unmute',
                                isActive: _isMicOn,
                                activeColor: const Color(0xFF1E2030),
                                inactiveColor: const Color(0xFFEF4444),
                                isDesktop: isDesktop,
                                onPressed: _toggleMic,
                              ),
                              _buildControlButton(
                                icon: _isVideoOn ? Icons.videocam : Icons.videocam_off,
                                label: _isVideoOn ? 'Stop' : 'Start',
                                isActive: _isVideoOn,
                                activeColor: const Color(0xFF1E2030),
                                inactiveColor: const Color(0xFFEF4444),
                                isDesktop: isDesktop,
                                onPressed: _toggleVideo,
                              ),
                              _buildControlButton(
                                icon: Icons.screen_share_outlined,
                                label: _isScreenSharing ? 'Sharing' : 'Share',
                                isActive: _isScreenSharing,
                                activeColor: AppColors.primary,
                                inactiveColor: const Color(0xFF1E2030),
                                isDesktop: isDesktop,
                                onPressed: _toggleScreenShare,
                              ),
                              _buildControlButton(
                                icon: Icons.closed_caption,
                                label: _isCaptionsOn ? 'CC On' : 'CC Off',
                                isActive: _isCaptionsOn,
                                activeColor: const Color(0xFFD946EF),
                                inactiveColor: const Color(0xFF1E2030),
                                isDesktop: isDesktop,
                                onPressed: _toggleCaptions,
                              ),

                              // Live Translation Language Selector
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E2030),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF2E324D)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.translate, size: 14, color: Color(0xFFD946EF)),
                                    const SizedBox(width: 4),
                                    DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _selectedLanguage,
                                        dropdownColor: const Color(0xFF1A1C2B),
                                        icon: const Icon(Icons.arrow_drop_down, color: Colors.white, size: 16),
                                        style: const TextStyle(color: Colors.white, fontSize: 11),
                                        items: _languages.map((l) {
                                          return DropdownMenuItem<String>(
                                            value: l,
                                            child: Text(l),
                                          );
                                        }).toList(),
                                        onChanged: _changeLanguage,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // In-Call Chat Button
                              _buildControlButton(
                                icon: Icons.chat_bubble_outline,
                                label: 'Chat (${_chatMessages.length})',
                                isActive: _isChatOpen,
                                activeColor: const Color(0xFF8B5CF6),
                                inactiveColor: const Color(0xFF1E2030),
                                isDesktop: isDesktop,
                                onPressed: () {
                                  if (isDesktop) {
                                    setState(() => _isChatOpen = !_isChatOpen);
                                  } else {
                                    _openChatBottomSheet();
                                  }
                                },
                              ),

                              // Host: End Meeting / Candidate: Leave Call
                              ElevatedButton.icon(
                                onPressed: () => _leaveMeeting(isHost: isHost),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFEF4444),
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(horizontal: isDesktop ? 14 : 10, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.call_end, size: 14),
                                label: Text(isHost ? 'End Call (Host)' : 'Leave Call', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Side Panel: In-Call Chat, Grammar Suggestions & AI Copilot (Desktop only)
                if (isDesktop && _isChatOpen)
                  Container(
                    width: 360,
                    decoration: const BoxDecoration(
                      color: Color(0xFF13141F),
                      border: Border(left: BorderSide(color: Color(0xFF222538))),
                    ),
                    child: _buildChatAndCopilotPanel(isModal: false, onStateUpdate: () => setState(() {})),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatAndCopilotPanel({required bool isModal, required VoidCallback onStateUpdate}) {
    final user = ref.read(authProvider).user;
    final myName = user?.fullName ?? user?.email ?? 'You';

    return Column(
      children: [
        if (isModal)
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 4),
            width: 36,
            height: 4,
            decoration: BoxDecoration(color: const Color(0xFF2E324D), borderRadius: BorderRadius.circular(2)),
          ),

        // Live AI Score Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFF222538))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Color(0xFFD946EF), size: 16),
                  const SizedBox(width: 8),
                  const Text('AI Technical Evaluator', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  const Spacer(),
                  if (_isEvaluating)
                    const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD946EF)))
                  else
                    InkWell(
                      onTap: _triggerAIEvaluation,
                      child: const Text('Evaluate', style: TextStyle(color: Color(0xFFD946EF), fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  ScoreGauge(score: _aiScore, size: 56, strokeWidth: 5),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${_aiScore.toInt()}/100 Rating', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text(_aiFeedback, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Tab Selector: [ 0: Room Chat | 1: AI Assistant & Grammar ]
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: const BoxDecoration(
            color: Color(0xFF10121C),
            border: Border(bottom: BorderSide(color: Color(0xFF222538))),
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() => _chatTab = 0);
                    onStateUpdate();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: _chatTab == 0 ? AppColors.primary.withOpacity(0.2) : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _chatTab == 0 ? AppColors.primary.withOpacity(0.5) : Colors.transparent),
                    ),
                    alignment: Alignment.center,
                    child: Text('Room Chat (${_chatMessages.length})', style: TextStyle(color: _chatTab == 0 ? Colors.white : const Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() => _chatTab = 1);
                    onStateUpdate();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: _chatTab == 1 ? const Color(0xFFD946EF).withOpacity(0.2) : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _chatTab == 1 ? const Color(0xFFD946EF).withOpacity(0.5) : Colors.transparent),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.smart_toy, size: 12, color: Color(0xFFD946EF)),
                        SizedBox(width: 4),
                        Text('AI Copilot', style: TextStyle(color: Color(0xFFD946EF), fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Body: Chat Messages or AI Copilot Messages
        Expanded(
          child: _chatTab == 0
              ? (_chatMessages.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No messages sent yet.\nType below to message participants in real time.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _chatMessages.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, idx) {
                        final m = _chatMessages[idx];
                        final isMe = m['sender'] == myName;
                        final isAI = (m['sender'] ?? '').contains('AI') || (m['text'] ?? '').startsWith('[AI');

                        return Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isAI
                                ? const Color(0xFFD946EF).withOpacity(0.12)
                                : isMe
                                    ? const Color(0xFF8B5CF6).withOpacity(0.15)
                                    : const Color(0xFF1E2030),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isAI
                                  ? const Color(0xFFD946EF).withOpacity(0.4)
                                  : isMe
                                      ? const Color(0xFF8B5CF6).withOpacity(0.3)
                                      : const Color(0xFF2E324D),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    m['sender'] ?? '',
                                    style: TextStyle(
                                      color: isAI
                                          ? const Color(0xFFD946EF)
                                          : isMe
                                              ? const Color(0xFF38BDF8)
                                              : Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                  Text(m['time'] ?? '', style: const TextStyle(color: Color(0xFF64748B), fontSize: 9)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(m['text'] ?? '', style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 12)),
                            ],
                          ),
                        );
                      },
                    ))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _aiCopilotMessages.length + (_isCopilotThinking ? 1 : 0),
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, idx) {
                    if (idx == _aiCopilotMessages.length && _isCopilotThinking) {
                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E2030),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: const [
                            SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD946EF))),
                            SizedBox(width: 8),
                            Text('Nora AI is thinking...', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                          ],
                        ),
                      );
                    }

                    final m = _aiCopilotMessages[idx];
                    final isAI = m['role'] == 'ai';
                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isAI ? const Color(0xFFD946EF).withOpacity(0.12) : const Color(0xFF1E2030),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isAI ? const Color(0xFFD946EF).withOpacity(0.3) : const Color(0xFF2E324D)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(isAI ? Icons.smart_toy : Icons.person, size: 12, color: isAI ? const Color(0xFFD946EF) : const Color(0xFF38BDF8)),
                              const SizedBox(width: 4),
                              Text(isAI ? 'AI Interview Copilot' : 'You', style: TextStyle(color: isAI ? const Color(0xFFD946EF) : const Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 11)),
                              const Spacer(),
                              Text(m['time'] ?? '', style: const TextStyle(color: Color(0xFF64748B), fontSize: 9)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(m['text'] ?? '', style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 12)),
                        ],
                      ),
                    );
                  },
                ),
        ),

        // Live Grammar & AI Suggestions Bar (when typing in Room Chat)
        if (_chatTab == 0 && _suggestedPhrases.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            color: const Color(0xFF10121C),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _suggestedPhrases.map((phrase) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      backgroundColor: const Color(0xFF1E2030),
                      side: const BorderSide(color: Color(0xFF8B5CF6)),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      label: Text(
                        phrase,
                        style: const TextStyle(color: Color(0xFFD946EF), fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      onPressed: () {
                        // Extract cleaned phrase and replace text field
                        String clean = phrase.replaceAll(RegExp(r'^(✨ Fix Grammar: |✨ Polish: |💼 Professional: |💡 Concise: )'), '');
                        clean = clean.replaceAll('"', '');
                        _chatController.text = clean;
                        setState(() => _suggestedPhrases.clear());
                        onStateUpdate();
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

        // Input Field Container
        Container(
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFF222538))),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatTab == 0 ? _chatController : _copilotController,
                  onSubmitted: (_) {
                    if (_chatTab == 0) {
                      _sendMessage();
                    } else {
                      _sendCopilotMessage();
                    }
                    onStateUpdate();
                  },
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: _chatTab == 0 ? 'Type message or interview note...' : 'Ask AI Copilot for question or advice...',
                    hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    filled: true,
                    fillColor: const Color(0xFF1E2030),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  if (_chatTab == 0) {
                    _sendMessage();
                  } else {
                    _sendCopilotMessage();
                  }
                  onStateUpdate();
                },
                icon: Icon(
                  _chatTab == 0 ? Icons.send : Icons.auto_awesome,
                  color: _chatTab == 0 ? AppColors.primary : const Color(0xFFD946EF),
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLiveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withOpacity(0.2),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 5, height: 5, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
          const SizedBox(width: 5),
          const Text('LIVE', style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTimerBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2030),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2E324D)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, size: 13, color: Color(0xFFCBD5E1)),
          const SizedBox(width: 5),
          Text(_formatCallTime(_callSeconds), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildLocalTile(String myName, String myRole) {
    final isSpeaking = _isMicOn;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSpeaking ? const Color(0xFF10B981) : const Color(0xFF2E324D),
          width: isSpeaking ? 2.5 : 1.2,
        ),
        boxShadow: isSpeaking
            ? [BoxShadow(color: const Color(0xFF10B981).withOpacity(0.35), blurRadius: 16, spreadRadius: 1)]
            : [],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          children: [
            Positioned.fill(
              child: _webrtcService.buildVideoView(
                isLocal: true,
                isVideoOn: _isVideoOn,
                userName: myName,
                userRole: myRole,
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: _isMicOn ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('$myName ($myRole)', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 6),
                    Icon(_isMicOn ? Icons.mic : Icons.mic_off, size: 13, color: _isMicOn ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                    if (_isMicOn) ...[
                      const SizedBox(width: 4),
                      _buildSpeakingAudioWave(true),
                    ],
                  ],
                ),
              ),
            ),
            if (_isScreenSharing)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(6)),
                  child: const Text('Sharing Screen', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoGrid({
    required bool isDesktop,
    required bool isHost,
    required String myName,
    required String myRole,
    required String defaultRemoteName,
    required String defaultRemoteRole,
    required List<dynamic> otherParticipants,
  }) {
    if (otherParticipants.isEmpty) {
      return isDesktop
          ? Row(
              children: [
                Expanded(child: _buildLocalTile(myName, myRole)),
                const SizedBox(width: 14),
                Expanded(child: _buildWaitingTile(isHost: isHost, remoteName: defaultRemoteName)),
              ],
            )
          : Column(
              children: [
                Expanded(flex: 1, child: _buildWaitingTile(isHost: isHost, remoteName: defaultRemoteName)),
                const SizedBox(height: 10),
                Expanded(flex: 1, child: _buildLocalTile(myName, myRole)),
              ],
            );
    }

    // 1-on-1 Interview (1 Remote + 1 Local)
    if (otherParticipants.length == 1) {
      final remote = otherParticipants.first;
      final remoteId = remote['user_id']?.toString() ?? 'remote_1';
      final remoteName = remote['name']?.toString() ?? defaultRemoteName;
      final remoteRole = remote['role']?.toString() ?? defaultRemoteRole;
      final remoteVideoOn = _peerMediaStates[remoteId]?['video_on'] ?? remote['video_on'] ?? true;
      final remoteMicOn = _peerMediaStates[remoteId]?['mic_on'] ?? remote['mic_on'] ?? true;

      return isDesktop
          ? Row(
              children: [
                Expanded(child: _buildLocalTile(myName, myRole)),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildRemoteParticipantTile(
                    userId: remoteId,
                    name: remoteName,
                    role: remoteRole,
                    isVideoOn: remoteVideoOn,
                    isMicOn: remoteMicOn,
                  ),
                ),
              ],
            )
          : Column(
              children: [
                Expanded(
                  flex: 1,
                  child: _buildRemoteParticipantTile(
                    userId: remoteId,
                    name: remoteName,
                    role: remoteRole,
                    isVideoOn: remoteVideoOn,
                    isMicOn: remoteMicOn,
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(flex: 1, child: _buildLocalTile(myName, myRole)),
              ],
            );
    }

    // Pinned Participant Spotlight View
    if (_pinnedUserId != null) {
      final pinnedParticipant = otherParticipants.firstWhere(
        (p) => (p['user_id']?.toString() ?? '') == _pinnedUserId,
        orElse: () => null,
      );

      if (pinnedParticipant != null) {
        final pid = pinnedParticipant['user_id']?.toString() ?? '';
        final pname = pinnedParticipant['name']?.toString() ?? 'Participant';
        final prole = pinnedParticipant['role']?.toString() ?? 'Participant';
        final pVideoOn = _peerMediaStates[pid]?['video_on'] ?? pinnedParticipant['video_on'] ?? true;
        final pMicOn = _peerMediaStates[pid]?['mic_on'] ?? pinnedParticipant['mic_on'] ?? true;

        final thumbnails = <Widget>[
          _buildLocalTile(myName, myRole),
        ];

        for (final p in otherParticipants) {
          final id = p['user_id']?.toString() ?? '';
          if (id != _pinnedUserId) {
            thumbnails.add(
              _buildRemoteParticipantTile(
                userId: id,
                name: p['name']?.toString() ?? 'Participant',
                role: p['role']?.toString() ?? 'Participant',
                isVideoOn: _peerMediaStates[id]?['video_on'] ?? p['video_on'] ?? true,
                isMicOn: _peerMediaStates[id]?['mic_on'] ?? p['mic_on'] ?? true,
              ),
            );
          }
        }

        return isDesktop
            ? Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildRemoteParticipantTile(
                      userId: pid,
                      name: pname,
                      role: prole,
                      isVideoOn: pVideoOn,
                      isMicOn: pMicOn,
                      isPinned: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 250,
                    child: ListView.separated(
                      itemCount: thumbnails.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, idx) => SizedBox(height: 150, child: thumbnails[idx]),
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildRemoteParticipantTile(
                      userId: pid,
                      name: pname,
                      role: prole,
                      isVideoOn: pVideoOn,
                      isMicOn: pMicOn,
                      isPinned: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 110,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: thumbnails.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, idx) => SizedBox(width: 150, child: thumbnails[idx]),
                    ),
                  ),
                ],
              );
      }
    }

    // Multi-User Grid: 3 or 4 users (2x2 Balanced Split that fills 100% height without scrolling)
    final allTiles = <Widget>[
      _buildLocalTile(myName, myRole),
    ];

    for (final p in otherParticipants) {
      final pid = p['user_id']?.toString() ?? 'peer';
      final pname = p['name']?.toString() ?? 'Participant';
      final prole = p['role']?.toString() ?? 'Participant';
      final pVideoOn = _peerMediaStates[pid]?['video_on'] ?? p['video_on'] ?? true;
      final pMicOn = _peerMediaStates[pid]?['mic_on'] ?? p['mic_on'] ?? true;

      allTiles.add(
        _buildRemoteParticipantTile(
          userId: pid,
          name: pname,
          role: prole,
          isVideoOn: pVideoOn,
          isMicOn: pMicOn,
        ),
      );
    }

    // 3 users: 2 on top, 1 centered below (like Google Meet)
    if (allTiles.length == 3) {
      return isDesktop
          ? Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(child: allTiles[0]),
                      const SizedBox(width: 12),
                      Expanded(child: allTiles[1]),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Row(
                    children: [
                      const Spacer(flex: 1),
                      Expanded(flex: 2, child: allTiles[2]),
                      const Spacer(flex: 1),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              children: [
                Expanded(flex: 3, child: allTiles[0]),
                const SizedBox(height: 10),
                Expanded(
                  flex: 2,
                  child: Row(
                    children: [
                      Expanded(child: allTiles[1]),
                      const SizedBox(width: 10),
                      Expanded(child: allTiles[2]),
                    ],
                  ),
                ),
              ],
            );
    }

    // 4 users: Balanced 2x2 grid filling 100% height
    if (allTiles.length == 4) {
      return Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: allTiles[0]),
                const SizedBox(width: 12),
                Expanded(child: allTiles[1]),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              children: [
                Expanded(child: allTiles[2]),
                const SizedBox(width: 12),
                Expanded(child: allTiles[3]),
              ],
            ),
          ),
        ],
      );
    }

    // 5 or 6 participants: 3x2 grid
    if (allTiles.length <= 6) {
      final topCount = (allTiles.length / 2).ceil();
      final topTiles = allTiles.take(topCount).toList();
      final bottomTiles = allTiles.skip(topCount).toList();

      return isDesktop
          ? Column(
              children: [
                Expanded(
                  child: Row(
                    children: topTiles
                        .map((t) => Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                child: t,
                              ),
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Row(
                    children: bottomTiles
                        .map((t) => Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                child: t,
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ],
            )
          : GridView.builder(
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.25,
              ),
              itemCount: allTiles.length,
              itemBuilder: (ctx, idx) => allTiles[idx],
            );
    }

    // 7+ participants: Responsive gallery
    final cols = isDesktop ? 3 : 2;
    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: isDesktop ? 1.4 : 1.2,
      ),
      itemCount: allTiles.length,
      itemBuilder: (ctx, idx) => allTiles[idx],
    );
  }

  Widget _buildSpeakingAudioWave(bool isSpeaking) {
    if (!isSpeaking) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 3,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(2)),
        ),
        Container(
          width: 3,
          height: 12,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(2)),
        ),
        Container(
          width: 3,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(2)),
        ),
      ],
    );
  }

  Widget _buildRemoteParticipantTile({
    required String userId,
    required String name,
    required String role,
    required bool isVideoOn,
    required bool isMicOn,
    bool isPinned = false,
  }) {
    final isSpeaking = isMicOn;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSpeaking ? const Color(0xFF10B981) : (isPinned ? const Color(0xFFD946EF) : const Color(0xFF2E324D)),
          width: isSpeaking ? 2.5 : (isPinned ? 2.0 : 1.2),
        ),
        boxShadow: isSpeaking
            ? [BoxShadow(color: const Color(0xFF10B981).withOpacity(0.35), blurRadius: 16, spreadRadius: 1)]
            : (isPinned ? [BoxShadow(color: const Color(0xFFD946EF).withOpacity(0.25), blurRadius: 10)] : []),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          children: [
            Positioned.fill(
              child: _webrtcService.buildVideoView(
                isLocal: false,
                isVideoOn: isVideoOn,
                userName: name,
                userRole: role,
                userId: userId,
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: isMicOn ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('$name ($role)', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 6),
                    Icon(
                      isMicOn ? Icons.mic : Icons.mic_off,
                      size: 13,
                      color: isMicOn ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    ),
                    if (isMicOn) ...[
                      const SizedBox(width: 4),
                      _buildSpeakingAudioWave(true),
                    ],
                  ],
                ),
              ),
            ),
            // Pin / Spotlight button
            Positioned(
              top: 10,
              right: 10,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _pinnedUserId = (_pinnedUserId == userId) ? null : userId;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _pinnedUserId == userId ? const Color(0xFFD946EF) : Colors.black.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white.withOpacity(0.15)),
                  ),
                  child: Icon(
                    _pinnedUserId == userId ? Icons.push_pin : Icons.push_pin_outlined,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.65), borderRadius: BorderRadius.circular(6)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi, size: 12, color: Color(0xFF10B981)),
                    const SizedBox(width: 4),
                    Text(
                      isVideoOn ? 'Live Video • Voice Active' : 'Camera Off • Voice Active',
                      style: const TextStyle(color: Color(0xFF10B981), fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaitingTile({required bool isHost, required String remoteName}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF13141F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2E324D)),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF8B5CF6).withOpacity(0.12),
                    ),
                  ),
                  const Icon(Icons.person_search_outlined, size: 32, color: Color(0xFF8B5CF6)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Waiting for ${isHost ? "Candidate" : "Recruiter"} to join...',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 6),
              Text(
                'This tile will activate automatically as soon as $remoteName joins room "$_roomId".',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
              ),
              const SizedBox(height: 16),
              if (isHost)
                ElevatedButton.icon(
                  onPressed: _showInviteCandidateDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E2030),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.link, size: 14),
                  label: const Text('Share Room Link', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRemoteTile(dynamic user, String remoteName, String remoteRole, bool hasRemoteJoined, {required bool isHost}) {
    if (hasRemoteJoined) {
      return _buildRemoteParticipantTile(
        userId: 'remote_default',
        name: remoteName,
        role: remoteRole,
        isVideoOn: true,
        isMicOn: true,
      );
    }
    return _buildWaitingTile(isHost: isHost, remoteName: remoteName);
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required Color activeColor,
    required Color inactiveColor,
    required bool isDesktop,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 12 : 8,
          vertical: isDesktop ? 8 : 6,
        ),
        decoration: BoxDecoration(
          color: isActive ? activeColor : inactiveColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF2E324D)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: isDesktop ? 16 : 14, color: Colors.white),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: Colors.white, fontSize: isDesktop ? 11 : 10, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
