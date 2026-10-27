import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../shared/widgets/top_navbar.dart';
import '../../shared/widgets/sidebar_navigation.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/score_gauge.dart';
import '../../providers/auth_provider.dart';
import '../../core/network/api_client.dart';
import '../../core/config/api_config.dart';
import '../interview/webrtc/webrtc_service.dart';

class InterviewPrepScreen extends ConsumerStatefulWidget {
  const InterviewPrepScreen({super.key});

  @override
  ConsumerState<InterviewPrepScreen> createState() => _InterviewPrepScreenState();
}

class _InterviewPrepScreenState extends ConsumerState<InterviewPrepScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final WebRTCService _webrtcService;

  // --- CUSTOM USER TYPED ROLE & SENIORITY (GEMINI GROUNDED) ---
  final TextEditingController _customRoleController = TextEditingController(text: 'Senior Full Stack Flutter & Django Engineer');
  final TextEditingController _customSeniorityController = TextEditingController(text: 'Senior (5+ yrs)');
  List<Map<String, dynamic>> _dynamicQuizzes = [];
  bool _isGeneratingQuizzes = false;

  // --- QUIZ STATE ---
  String _selectedTrack = 'Flutter & Dart';
  String _selectedLevel = 'Senior (5+ yrs)';
  int _currentQuestionIndex = 0;
  int? _selectedAnswerIndex;
  bool _hasSubmittedAnswer = false;
  int _quizScore = 0;
  bool _quizFinished = false;
  int _questionTimeRemaining = 45;
  Timer? _quizTimer;

  // --- MOCK VOICE INTERVIEW STATE (Siri / Hey Google Hands-Free) ---
  bool _isMockActive = false;
  bool _isMockFinished = false;
  int _mockQuestionIndex = 0;
  bool _isNoraSpeaking = false;
  bool _isListening = false;
  Timer? _speechSilenceTimer;
  Timer? _noraSpeechFallbackTimer;
  String _candidateSpokenText = '';
  final TextEditingController _candidateAnswerController = TextEditingController();
  double _mockScore = 0;
  String _mockFeedback = '';
  List<Map<String, dynamic>> _mockHistory = [];
  Map<String, dynamic>? _mockScorecard;
  bool _isLoadingScorecard = false;

  final List<String> _tracks = [
    'Flutter & Dart',
    'Python & Backend',
    'AI & LLM Systems',
    'System Design',
    'DevOps & Cloud',
  ];

  final List<String> _levels = [
    'Junior (0-2 yrs)',
    'Mid-Level (3-5 yrs)',
    'Senior (5+ yrs)',
    'Lead / Architect',
  ];

  String _candidateResumeSummary = '';
  List<String> _dynamicMockQuestions = [];
  bool _isLoadingQuestions = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _webrtcService = createWebRTCService();
    _fetchCandidateResumeAndInitQuizzes();
  }

  void _fetchCandidateResumeAndInitQuizzes() async {
    try {
      final dio = ApiClient().dio;
      final res = await dio.get(ApiConfig.resumes);
      final list = res.data['results'] ?? res.data ?? [];
      if (list.isNotEmpty) {
        final r = list.first;
        _candidateResumeSummary = r['extracted_text'] ?? (r['parsed_data'] != null ? r['parsed_data'].toString() : '');
      }
    } catch (_) {}
    if (mounted) {
      _generateGeminiQuizzes();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _quizTimer?.cancel();
    _speechSilenceTimer?.cancel();
    _noraSpeechFallbackTimer?.cancel();
    _customRoleController.dispose();
    _customSeniorityController.dispose();
    _candidateAnswerController.dispose();
    _webrtcService.stopSpeaking();
    _webrtcService.stopSpeechRecognition();
    super.dispose();
  }

  List<Map<String, dynamic>> _getActiveQuizList() {
    return _dynamicQuizzes;
  }

  Future<void> _generateGeminiQuizzes({bool append = false}) async {
    final role = _customRoleController.text.trim().isNotEmpty
        ? _customRoleController.text.trim()
        : _selectedTrack;
    final seniority = _customSeniorityController.text.trim().isNotEmpty
        ? _customSeniorityController.text.trim()
        : _selectedLevel;

    setState(() => _isGeneratingQuizzes = true);

    try {
      final dio = ApiClient().dio;
      final res = await dio.post(
        ApiConfig.aiGenerateQuizzes,
        data: {
          'role': role,
          'seniority': seniority,
          'resume_text': _candidateResumeSummary,
        },
      );

      final list = res.data['quizzes'] as List? ?? [];
      if (list.isNotEmpty) {
        final parsed = list.map((item) {
          final qMap = item as Map<String, dynamic>;
          final rawOptions = qMap['options'] as List? ?? [];
          final options = rawOptions.map((o) => o.toString()).toList();
          return {
            'question': qMap['question']?.toString() ?? '',
            'options': options,
            'correct': (qMap['correct'] as num?)?.toInt() ?? 0,
            'explanation': qMap['explanation']?.toString() ?? '',
          };
        }).where((q) => (q['question'] as String).isNotEmpty && (q['options'] as List).isNotEmpty).toList();

        if (parsed.isNotEmpty) {
          setState(() {
            if (append) {
              _dynamicQuizzes.addAll(parsed);
              _isGeneratingQuizzes = false;
              _currentQuestionIndex++;
              _selectedAnswerIndex = null;
              _hasSubmittedAnswer = false;
              _questionTimeRemaining = 45;
            } else {
              _dynamicQuizzes = parsed;
              _isGeneratingQuizzes = false;
              _startQuiz();
            }
          });
          if (append) {
            _startTimer();
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: const Color(0xFF10B981),
                content: Text(append
                    ? '✨ Gemini generated 5 more MCQs for continuous practice!'
                    : '✨ Gemini generated ${parsed.length} tailored technical MCQs for "$role"!'),
              ),
            );
          }
          return;
        }
      }
    } catch (_) {}

    setState(() => _isGeneratingQuizzes = false);
    if (!append) _startQuiz();
  }

  void _startQuiz() {
    setState(() {
      _currentQuestionIndex = 0;
      _selectedAnswerIndex = null;
      _hasSubmittedAnswer = false;
      _quizScore = 0;
      _quizFinished = false;
      _questionTimeRemaining = 45;
    });
    _startTimer();
  }

  void _startTimer() {
    _quizTimer?.cancel();
    _quizTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_questionTimeRemaining > 0) {
        setState(() => _questionTimeRemaining--);
      } else {
        _submitAnswer();
      }
    });
  }

  void _selectOption(int idx) {
    if (_hasSubmittedAnswer) return;
    setState(() {
      _selectedAnswerIndex = idx;
    });
  }

  void _submitAnswer() {
    if (_hasSubmittedAnswer) return;
    _quizTimer?.cancel();

    final questions = _getActiveQuizList();
    if (questions.isEmpty) return;
    final currentQ = questions[_currentQuestionIndex];
    final isCorrect = _selectedAnswerIndex == currentQ['correct'];

    setState(() {
      _hasSubmittedAnswer = true;
      if (isCorrect) _quizScore++;
    });
  }

  void _nextQuestion() {
    final questions = _getActiveQuizList();
    if (_currentQuestionIndex + 1 < questions.length) {
      setState(() {
        _currentQuestionIndex++;
        _selectedAnswerIndex = null;
        _hasSubmittedAnswer = false;
        _questionTimeRemaining = 45;
      });
      _startTimer();
    } else {
      // Dynamic Gemini continuous question generation until user clicks "Finish Quiz"
      _generateGeminiQuizzes(append: true);
    }
  }

  void _finishQuiz() {
    _quizTimer?.cancel();
    setState(() {
      _quizFinished = true;
    });
  }

  // --- MOCK VOICE INTERVIEW LOGIC (Siri / Hey Google Hands-Free) ---
  void _startMockInterview() async {
    final role = _customRoleController.text.trim().isNotEmpty
        ? _customRoleController.text.trim()
        : _selectedTrack;
    final seniority = _customSeniorityController.text.trim().isNotEmpty
        ? _customSeniorityController.text.trim()
        : _selectedLevel;

    setState(() {
      _isMockActive = true;
      _isMockFinished = false;
      _isLoadingQuestions = true;
      _mockQuestionIndex = 0;
      _mockHistory.clear();
      _mockScorecard = null;
      _mockScore = 0;
      _mockFeedback = 'AI Nora is reviewing your resume & tailoring live voice questions for $role ($seniority)...';
    });

    try {
      final dio = ApiClient().dio;
      final res = await dio.post(
        ApiConfig.aiGenerateQuestions,
        data: {
          'title': role,
          'difficulty': seniority,
          'resume_text': _candidateResumeSummary,
        },
      );
      final list = res.data['questions'] as List? ?? [];
      if (list.isNotEmpty) {
        _dynamicMockQuestions = list
            .map((q) => q is Map ? (q['question']?.toString() ?? '') : q.toString())
            .where((q) => q.isNotEmpty)
            .toList();
      }
    } catch (_) {}

    if (_dynamicMockQuestions.isEmpty) {
      _dynamicMockQuestions = [
        'Can you walk us through a recent production system you architected for  (), and the key engineering tradeoffs you made?',
        'How do you handle scalability, high concurrency, and performance bottlenecks in your daily work as a ',
        'Describe a critical production bug or outage you diagnosed in  and the steps you took to remediate and prevent it.',
        'How do you ensure test coverage, CI/CD pipeline reliability, and code quality across your engineering team?',
      ];
    }

    setState(() {
      _isLoadingQuestions = false;
      _mockFeedback = 'AI Nora is ready with personalized questions tailored to your profile and $role.';
    });

    final firstQ = _dynamicMockQuestions[0];
    _noraSpeak(
      "Hello! I am Nora, your autonomous AI technical interviewer. Based on your submitted profile and experience in $role, let's begin: $firstQ",
    );
  }

  void _noraSpeak(String text, {VoidCallback? onEnd}) {
    _speechSilenceTimer?.cancel();
    _noraSpeechFallbackTimer?.cancel();
    _webrtcService.stopSpeechRecognition();
    setState(() {
      _isNoraSpeaking = true;
      _isListening = false;
    });

    void triggerDone() {
      _noraSpeechFallbackTimer?.cancel();
      if (!mounted) return;
      setState(() => _isNoraSpeaking = false);
      if (onEnd != null) {
        onEnd();
      } else {
        // Siri / Hey Google Mode: Automatically listen to candidate hands-free!
        _startHandsFreeListening();
      }
    }

    // Safety fallback timer so speech state never hangs if browser synthesizes slowly or pauses
    final words = text.split(' ').length;
    final maxSec = (words / 2.0).ceil() + 4;
    _noraSpeechFallbackTimer = Timer(Duration(seconds: maxSec), () {
      if (mounted && _isNoraSpeaking) {
        triggerDone();
      }
    });

    _webrtcService.speak(
      text,
      onStart: () {
        if (mounted) setState(() => _isNoraSpeaking = true);
      },
      onEnd: () {
        triggerDone();
      },
    );
  }

  void _startHandsFreeListening() {
    if (_isMockFinished || !_isMockActive) return;
    setState(() {
      _isListening = true;
      _candidateSpokenText = '';
      _candidateAnswerController.clear();
    });
    _webrtcService.startSpeechRecognition(
      targetLang: 'English',
      onResult: (text, _) {
        if (!mounted || text.isEmpty) return;
        setState(() {
          _candidateSpokenText = text;
          _candidateAnswerController.text = text;
        });
        // 2.5s silence auto-submit like Siri/Hey Google
        _speechSilenceTimer?.cancel();
        _speechSilenceTimer = Timer(const Duration(milliseconds: 2500), () {
          if (mounted && _isListening && _candidateSpokenText.trim().isNotEmpty) {
            _submitCandidateAnswer();
          }
        });
      },
    );
  }

  void _submitCandidateAnswer({String? overrideText}) async {
    _speechSilenceTimer?.cancel();
    _webrtcService.stopSpeechRecognition();

    final answerText = (overrideText ?? (_candidateSpokenText.isNotEmpty ? _candidateSpokenText : _candidateAnswerController.text)).trim();
    if (answerText.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please speak into your microphone to answer.')),
        );
      }
      return;
    }

    setState(() {
      _isListening = false;
      _mockFeedback = 'AI Nora is evaluating your response with Gemini...';
    });

    final questions = _dynamicMockQuestions;
    if (questions.isEmpty) return;
    final q = questions[_mockQuestionIndex];

    double answerScore = 88.0;
    String reaction = 'Strong technical explanation.';

    try {
      final dio = ApiClient().dio;
      final res = await dio.post(
        '/ai/evaluate-answer/',
        data: {
          'question': q,
          'answer': answerText,
          'job_title': _customRoleController.text.trim().isNotEmpty ? _customRoleController.text.trim() : _selectedTrack,
          'resume_text': _candidateResumeSummary,
        },
      );
      if (res.data != null) {
        answerScore = (res.data['score'] as num?)?.toDouble() ?? 88.0;
        reaction = res.data['reaction']?.toString() ?? reaction;
      }
    } catch (_) {
      final wordCount = answerText.split(' ').length;
      answerScore = (wordCount > 25 ? 92.0 : (wordCount > 10 ? 84.0 : 72.0)).clamp(60.0, 98.0);
    }

    setState(() {
      _mockScore = answerScore;
      _mockFeedback = reaction;
      _mockHistory.add({
        'question': q,
        'answer': answerText,
        'score': answerScore,
      });
      _candidateAnswerController.clear();
      _candidateSpokenText = '';
    });

    if (_mockQuestionIndex + 1 < questions.length && _mockHistory.length < 5) {
      setState(() => _mockQuestionIndex++);
      final nextQ = questions[_mockQuestionIndex];
      _noraSpeak("$reaction Now let's explore our next question: $nextQ");
    } else {
      _concludeMockInterview();
    }
  }

  void _concludeMockInterview() async {
    _speechSilenceTimer?.cancel();
    _webrtcService.stopSpeechRecognition();

    setState(() {
      _isListening = false;
      _isMockFinished = true;
      _isLoadingScorecard = true;
    });

    _noraSpeak(
      "Thank you for completing this technical mock interview session. I am compiling your performance evaluation, ranking, strengths, and recommendations now.",
      onEnd: () {},
    );

    try {
      final dio = ApiClient().dio;
      final res = await dio.post(
        ApiConfig.aiMockSummary,
        data: {
          'role': _customRoleController.text.trim().isNotEmpty ? _customRoleController.text.trim() : _selectedTrack,
          'seniority': _customSeniorityController.text.trim().isNotEmpty ? _customSeniorityController.text.trim() : _selectedLevel,
          'history': _mockHistory,
          'resume_text': _candidateResumeSummary,
        },
      );
      if (mounted) {
        setState(() {
          _mockScorecard = res.data;
          _isLoadingScorecard = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingScorecard = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final isDesktop = ResponsiveLayout.isDesktop(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const TopNavbar(),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isDesktop)
                  SidebarNavigation(user: user, currentRoute: '/candidate/prep'),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isDesktop ? 32 : 16),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1040),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFD946EF).withOpacity(0.18),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Icon(Icons.psychology, color: Color(0xFFD946EF), size: 24),
                                        ),
                                        const SizedBox(width: 12),
                                        Text('Interview Preparation Hub', style: AppTypography.displaySmall.copyWith(fontSize: isDesktop ? 26 : 22)),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text('Practice role-specific technical quizzes and experience live voice mock interviews with AI Nora.', style: AppTypography.bodySmall),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Tab Bar
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: TabBar(
                                controller: _tabController,
                                indicatorColor: AppColors.primary,
                                indicatorWeight: 3,
                                labelColor: Colors.white,
                                unselectedLabelColor: AppColors.textSecondary,
                                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                tabs: const [
                                  Tab(icon: Icon(Icons.quiz_outlined, size: 18), text: 'Technical Quizzes & MCQs'),
                                  Tab(icon: Icon(Icons.record_voice_over_outlined, size: 18), text: 'AI Mock Voice Interview (Nora)'),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Custom Typed Target Role & Seniority Selectors (Gemini Grounded)
                            AppCard(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFD946EF).withOpacity(0.18),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.auto_awesome, color: Color(0xFFD946EF), size: 18),
                                      ),
                                      const SizedBox(width: 10),
                                      const Text(
                                        'Target Role & Seniority Configuration',
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _tabController.index == 0
                                        ? 'Type any technical role and experience level. Google Gemini analyzes your submitted resume and dynamically generates custom technical MCQs.'
                                        : 'Type your target technical role and seniority. AI Nora conducts a live, hands-free conversational voice interview customized to your profile.',
                                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                  ),
                                  const SizedBox(height: 16),

                                  // Inputs Row
                                  if (isDesktop)
                                    Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: TextField(
                                            controller: _customRoleController,
                                            style: const TextStyle(color: Colors.white, fontSize: 13),
                                            decoration: InputDecoration(
                                              labelText: 'Target Job Role / Title',
                                              hintText: 'e.g. Lead Flutter Architect, Python Backend Lead...',
                                              labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                              prefixIcon: const Icon(Icons.work_outline, color: AppColors.primary, size: 18),
                                              filled: true,
                                              fillColor: const Color(0xFF13141F),
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF2E324D))),
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          flex: 2,
                                          child: TextField(
                                            controller: _customSeniorityController,
                                            style: const TextStyle(color: Colors.white, fontSize: 13),
                                            decoration: InputDecoration(
                                              labelText: 'Seniority Level / Experience',
                                              hintText: 'e.g. Senior (5+ yrs), Lead...',
                                              labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                              prefixIcon: const Icon(Icons.stairs_outlined, color: Color(0xFFD946EF), size: 18),
                                              filled: true,
                                              fillColor: const Color(0xFF13141F),
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF2E324D))),
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                            ),
                                          ),
                                        ),
                                        if (_tabController.index == 0) ...[
                                          const SizedBox(width: 14),
                                          ElevatedButton.icon(
                                            onPressed: _isGeneratingQuizzes ? null : _generateGeminiQuizzes,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFFD946EF),
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            ),
                                            icon: _isGeneratingQuizzes
                                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                                : const Icon(Icons.auto_awesome, size: 16),
                                            label: Text(_isGeneratingQuizzes ? 'Generating...' : '✨ Generate with Gemini', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                          ),
                                        ],
                                      ],
                                    )
                                  else
                                    Column(
                                      children: [
                                        TextField(
                                          controller: _customRoleController,
                                          style: const TextStyle(color: Colors.white, fontSize: 13),
                                          decoration: InputDecoration(
                                            labelText: 'Target Job Role / Title',
                                            hintText: 'e.g. Lead Flutter Architect...',
                                            labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                            prefixIcon: const Icon(Icons.work_outline, color: AppColors.primary, size: 18),
                                            filled: true,
                                            fillColor: const Color(0xFF13141F),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        TextField(
                                          controller: _customSeniorityController,
                                          style: const TextStyle(color: Colors.white, fontSize: 13),
                                          decoration: InputDecoration(
                                            labelText: 'Seniority Level / Experience',
                                            hintText: 'e.g. Senior (5+ yrs)...',
                                            labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                            prefixIcon: const Icon(Icons.stairs_outlined, color: Color(0xFFD946EF), size: 18),
                                            filled: true,
                                            fillColor: const Color(0xFF13141F),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                        ),
                                        if (_tabController.index == 0) ...[
                                          const SizedBox(height: 12),
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton.icon(
                                              onPressed: _isGeneratingQuizzes ? null : _generateGeminiQuizzes,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFFD946EF),
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(vertical: 14),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                              ),
                                              icon: _isGeneratingQuizzes
                                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                                  : const Icon(Icons.auto_awesome, size: 16),
                                              label: Text(_isGeneratingQuizzes ? 'Generating with Gemini...' : '✨ Generate Quizzes with Gemini', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),

                                  const SizedBox(height: 14),
                                  // Quick role suggestion tags
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      const Text('Popular Roles:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold)),
                                      ..._tracks.map((t) {
                                        return ActionChip(
                                          backgroundColor: const Color(0xFF1E2030),
                                          side: BorderSide(color: const Color(0xFF38BDF8).withOpacity(0.3)),
                                          label: Text(t, style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11)),
                                          onPressed: () {
                                            setState(() {
                                              _selectedTrack = t;
                                              _customRoleController.text = t;
                                            });
                                            if (_tabController.index == 0) {
                                              _generateGeminiQuizzes();
                                            }
                                          },
                                        );
                                      }),
                                      const SizedBox(width: 8),
                                      const Text('Seniority:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold)),
                                      ..._levels.map((l) {
                                        return ActionChip(
                                          backgroundColor: const Color(0xFF1E2030),
                                          side: BorderSide(color: const Color(0xFFD946EF).withOpacity(0.3)),
                                          label: Text(l, style: const TextStyle(color: Color(0xFFD946EF), fontSize: 11)),
                                          onPressed: () {
                                            setState(() {
                                              _selectedLevel = l;
                                              _customSeniorityController.text = l;
                                            });
                                            if (_tabController.index == 0) {
                                              _generateGeminiQuizzes();
                                            }
                                          },
                                        );
                                      }),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Tab Views
                            AnimatedBuilder(
                              animation: _tabController,
                              builder: (ctx, _) {
                                return _tabController.index == 0
                                    ? _buildQuizTab(isDesktop)
                                    : _buildMockVoiceTab(isDesktop);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- QUIZ TAB CONTENT ---
  Widget _buildQuizTab(bool isDesktop) {
    if (_isGeneratingQuizzes && _dynamicQuizzes.isEmpty) {
      final targetRole = _customRoleController.text.trim().isNotEmpty ? _customRoleController.text.trim() : _selectedTrack;
      final targetSeniority = _customSeniorityController.text.trim().isNotEmpty ? _customSeniorityController.text.trim() : _selectedLevel;
      return AppCard(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(color: Color(0xFFD946EF), strokeWidth: 3),
              ),
              const SizedBox(height: 18),
              Text(
                '✨ Gemini AI is crafting custom technical MCQs for "$targetRole" ($targetSeniority)...',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Generating realistic scenarios, options, correct answers, and architectural explanations...',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final questions = _getActiveQuizList();

    if (questions.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text('No quizzes configured for $_selectedTrack yet. Please pick another track above.', style: AppTypography.bodyMedium),
        ),
      );
    }

    if (_quizFinished) {
      final total = questions.length;
      final percent = ((_quizScore / total) * 100).toInt();
      return AppCard(
        padding: const EdgeInsets.all(36),
        child: Column(
          children: [
            ScoreGauge(score: percent.toDouble(), size: 110, strokeWidth: 10),
            const SizedBox(height: 20),
            Text('Quiz Completed!', style: AppTypography.titleLarge.copyWith(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'You scored $_quizScore out of $total questions ($percent%).',
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppButton(
                  label: 'Retake Quiz',
                  icon: const Icon(Icons.refresh, size: 16),
                  onPressed: _startQuiz,
                ),
                const SizedBox(width: 14),
                OutlinedButton(
                  onPressed: () => _tabController.animateTo(1),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFD946EF),
                    side: const BorderSide(color: Color(0xFFD946EF)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Try Mock Voice Interview ➔', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final q = questions[_currentQuestionIndex];
    final options = q['options'] as List<String>;

    return AppCard(
      padding: EdgeInsets.all(isDesktop ? 28 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Question ${_currentQuestionIndex + 1} of ${questions.length}',
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _questionTimeRemaining <= 10 ? const Color(0xFFEF4444).withOpacity(0.2) : const Color(0xFF1E2030),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _questionTimeRemaining <= 10 ? const Color(0xFFEF4444) : const Color(0xFF2E324D)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.timer_outlined, size: 14, color: _questionTimeRemaining <= 10 ? const Color(0xFFEF4444) : Colors.white),
                    const SizedBox(width: 4),
                    Text('${_questionTimeRemaining}s', style: TextStyle(color: _questionTimeRemaining <= 10 ? const Color(0xFFEF4444) : Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(q['question'] as String, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold, height: 1.4)),
          const SizedBox(height: 24),

          // Options
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: options.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (ctx, idx) {
              final isSelected = _selectedAnswerIndex == idx;
              final isCorrect = q['correct'] == idx;

              Color borderColor = const Color(0xFF2E324D);
              Color bgColor = const Color(0xFF161826);

              if (_hasSubmittedAnswer) {
                if (isCorrect) {
                  borderColor = const Color(0xFF10B981);
                  bgColor = const Color(0xFF10B981).withOpacity(0.15);
                } else if (isSelected) {
                  borderColor = const Color(0xFFEF4444);
                  bgColor = const Color(0xFFEF4444).withOpacity(0.15);
                }
              } else if (isSelected) {
                borderColor = AppColors.primary;
                bgColor = AppColors.primary.withOpacity(0.12);
              }

              return InkWell(
                onTap: () => _selectOption(idx),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor, width: isSelected ? 1.8 : 1),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? AppColors.primary : const Color(0xFF222538),
                          border: Border.all(color: borderColor),
                        ),
                        child: Center(
                          child: Text(
                            String.fromCharCode(65 + idx),
                            style: TextStyle(color: isSelected ? Colors.white : const Color(0xFF94A3B8), fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(options[idx], style: const TextStyle(color: Colors.white, fontSize: 14)),
                      ),
                      if (_hasSubmittedAnswer) ...[
                        if (isCorrect)
                          const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 20)
                        else if (isSelected)
                          const Icon(Icons.cancel, color: Color(0xFFEF4444), size: 20),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // Explanation Banner after submission
          if (_hasSubmittedAnswer) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1C2C),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF2E324D)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 18, color: Color(0xFF10B981)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Explanation:', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(q['explanation'] as String, style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, height: 1.4)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton.icon(
                onPressed: _finishQuiz,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                  side: const BorderSide(color: Color(0xFFEF4444)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.check_circle_outline, size: 16),
                label: const Text('I am Completed / Finish Quiz', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              if (!_hasSubmittedAnswer)
                AppButton(
                  label: 'Submit Answer',
                  onPressed: _selectedAnswerIndex != null ? _submitAnswer : null,
                )
              else
                AppButton(
                  label: _currentQuestionIndex + 1 < questions.length ? 'Next Question ➔' : 'Generate More Questions ➔',
                  isLoading: _isGeneratingQuizzes,
                  onPressed: _nextQuestion,
                ),
            ],
          ),
        ],
      ),
    );
  }

  // --- MOCK VOICE INTERVIEW TAB (Hands-free Voice-to-Voice Siri / Hey Google Mode) ---
  Widget _buildMockVoiceTab(bool isDesktop) {
    // 1. If mock interview is completed, display the full Gemini Scorecard
    if (_isMockFinished) {
      if (_isLoadingScorecard) {
        return const AppCard(
          padding: EdgeInsets.all(40),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFFD946EF)),
                SizedBox(height: 18),
                Text('Gemini AI is compiling your detailed Mock Interview Scorecard...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                SizedBox(height: 8),
                Text('Synthesizing your rank, verbal clarity, strengths, and weaknesses...', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
              ],
            ),
          ),
        );
      }

      final card = _mockScorecard ?? {};
      final rank = card['rank']?.toString() ?? 'Top 10% Candidate';
      final suitability = (card['suitability_percentage'] as num?)?.toDouble() ?? 88.0;
      final strengths = (card['strengths'] as List?)?.map((e) => e.toString()).toList() ?? [
        'Demonstrates clear technical communication',
        'Strong grasp of core architecture patterns',
      ];
      final weaknesses = (card['weaknesses'] as List?)?.map((e) => e.toString()).toList() ?? [
        'Can provide deeper quantifiable metrics on production scaling',
      ];
      final suggestions = (card['improvement_suggestions'] as List?)?.map((e) => e.toString()).toList() ?? [
        'Practice STAR method when detailing past production incidents',
      ];

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card with Suitability & Rank
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E1435), Color(0xFF131525)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFD946EF), width: 1.8),
              boxShadow: [
                BoxShadow(color: const Color(0xFFD946EF).withOpacity(0.25), blurRadius: 24, spreadRadius: 2),
              ],
            ),
            child: Row(
              children: [
                ScoreGauge(score: suitability, size: 85, strokeWidth: 8),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD946EF).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFD946EF)),
                        ),
                        child: Text(
                          rank,
                          style: const TextStyle(color: Color(0xFFF472B6), fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Mock Voice Interview Evaluation',
                        style: AppTypography.displaySmall.copyWith(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Role: ${_customRoleController.text.trim().isNotEmpty ? _customRoleController.text.trim() : _selectedTrack} (${_customSeniorityController.text.trim().isNotEmpty ? _customSeniorityController.text.trim() : _selectedLevel})',
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isMockFinished = false;
                      _isMockActive = false;
                      _mockScorecard = null;
                      _mockHistory.clear();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD946EF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Start New Mock'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Strengths & Weaknesses 2-Column layout
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Strengths
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121E1C),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.check_circle, color: Color(0xFF10B981), size: 20),
                          SizedBox(width: 8),
                          Text('Key Strengths', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 15)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...strengths.map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                            Expanded(child: Text(s, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4))),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Weaknesses
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22171A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 20),
                          SizedBox(width: 8),
                          Text('Areas for Improvement', style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 15)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...weaknesses.map((w) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ', style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold)),
                            Expanded(child: Text(w, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4))),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Actionable Suggestions
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF141A29),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: Color(0xFF38BDF8), size: 20),
                    SizedBox(width: 8),
                    Text('Actionable Improvement Guidance', style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
                const SizedBox(height: 12),
                ...suggestions.map((sg) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('➔ ', style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold)),
                      Expanded(child: Text(sg, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4))),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ],
      );
    }

    // 2. Initial state before starting mock interview
    if (!_isMockActive) {
      return AppCard(
        padding: EdgeInsets.all(isDesktop ? 36 : 20),
        child: Column(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(colors: [Color(0xFFD946EF), Color(0xFF8B5CF6)]),
                boxShadow: [
                  BoxShadow(color: const Color(0xFFD946EF).withOpacity(0.4), blurRadius: 24, spreadRadius: 4),
                ],
              ),
              child: const Icon(Icons.record_voice_over, size: 52, color: Colors.white),
            ),
            const SizedBox(height: 20),
            Text('Autonomous AI Mock Voice Interview', style: AppTypography.displaySmall.copyWith(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF10B981)),
              ),
              child: const Text('🎙️ 100% Hands-Free Siri / Hey Google Mode (Zero Quizzes)', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            const SizedBox(height: 14),
            Text(
              'Have a direct, natural voice conversation with AI Nora for "${_customRoleController.text.trim().isNotEmpty ? _customRoleController.text.trim() : _selectedTrack}" (${_customSeniorityController.text.trim().isNotEmpty ? _customSeniorityController.text.trim() : _selectedLevel}). Nora asks you questions aloud, waits for you to finish speaking hands-free, and dynamically responds before ranking your performance.',
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            AppButton(
              label: 'Start Live Hands-Free Voice Interview with Nora',
              icon: const Icon(Icons.mic, size: 18),
              onPressed: _startMockInterview,
            ),
          ],
        ),
      );
    }

    if (_isLoadingQuestions) {
      return const AppCard(
        padding: EdgeInsets.all(40),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFFD946EF)),
              SizedBox(height: 16),
              Text('AI Nora is reviewing your resume & tailoring questions with Gemini...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    final questions = _dynamicMockQuestions;
    if (questions.isEmpty) {
      return const AppCard(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Text('AI Nora is preparing dynamic questions with Gemini...', style: TextStyle(color: Colors.white)),
        ),
      );
    }
    final currentQ = questions[_mockQuestionIndex];

    return Column(
      children: [
        // Nora Avatar Tile
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF161826),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFD946EF), width: 1.8),
            boxShadow: [
              BoxShadow(color: const Color(0xFFD946EF).withOpacity(0.2), blurRadius: 16),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _isNoraSpeaking ? const Color(0xFF10B981) : const Color(0xFFD946EF),
                            width: _isNoraSpeaking ? 3 : 2,
                          ),
                        ),
                      ),
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: const Color(0xFF2E194D),
                        child: Icon(Icons.smart_toy, size: 28, color: _isNoraSpeaking ? const Color(0xFF10B981) : const Color(0xFFD946EF)),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('AI Nora (Lead Interviewer)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(width: 8),
                            if (_isNoraSpeaking)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFF10B981)),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.volume_up, size: 11, color: Color(0xFF10B981)),
                                    SizedBox(width: 4),
                                    Text('Nora Speaking...', style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              )
                            else if (_isListening)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD946EF).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFD946EF)),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.mic, size: 11, color: Color(0xFFD946EF)),
                                    SizedBox(width: 4),
                                    Text('Listening to You...', style: TextStyle(color: Color(0xFFD946EF), fontSize: 10, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('Question ${_mockQuestionIndex + 1} of ${questions.length} • $_selectedTrack', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _noraSpeak(currentQ),
                    icon: const Icon(Icons.replay, color: Color(0xFFD946EF)),
                    tooltip: 'Repeat Question',
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F101A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2E324D)),
                ),
                child: Text(
                  currentQ,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Live Siri / Hey Google Visual Wave & Candidate Speech
        AppCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isListening ? const Color(0xFF10B981) : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isListening ? 'Siri / Hey Google Mode Active (Speak naturally)' : (_isNoraSpeaking ? 'Listen to Nora...' : 'Mic Ready'),
                        style: TextStyle(
                          color: _isListening ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  if (_isListening)
                    ElevatedButton.icon(
                      onPressed: () => _submitCandidateAnswer(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Done Speaking (Send)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: _startHandsFreeListening,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD946EF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.mic, size: 16),
                      label: const Text('Tap to Speak', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Live Real-Time Speech Text Bubble
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 80),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F101A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isListening ? const Color(0xFFD946EF) : const Color(0xFF2E324D),
                    width: _isListening ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  _candidateSpokenText.isNotEmpty
                      ? _candidateSpokenText
                      : (_isListening ? 'Listening to your voice... (Auto-submits after 2.5s of silence)' : 'Waiting for Nora to finish speaking...'),
                  style: TextStyle(
                    color: _candidateSpokenText.isNotEmpty ? Colors.white : const Color(0xFF64748B),
                    fontSize: 14,
                    fontStyle: _candidateSpokenText.isEmpty ? FontStyle.italic : FontStyle.normal,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    onPressed: _concludeMockInterview,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFEF4444)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.stop_circle_outlined, size: 16),
                    label: const Text('Conclude & Get Final Rank'),
                  ),
                  if (_mockHistory.isNotEmpty)
                    Text(
                      'Completed ${_mockHistory.length} response(s)',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    ),
                ],
              ),
            ],
          ),
        ),

        // Live AI Evaluation Feedback
        if (_mockScore > 0) ...[
          const SizedBox(height: 20),
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                ScoreGauge(score: _mockScore, size: 60, strokeWidth: 6),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Nora’s Live Reaction (${_mockScore.toInt()}%)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text(_mockFeedback, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
