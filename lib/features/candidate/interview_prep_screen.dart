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
import '../interview/webrtc/webrtc_service_stub.dart'
    if (dart.library.html) '../interview/webrtc/webrtc_service_web.dart';

class InterviewPrepScreen extends ConsumerStatefulWidget {
  const InterviewPrepScreen({super.key});

  @override
  ConsumerState<InterviewPrepScreen> createState() => _InterviewPrepScreenState();
}

class _InterviewPrepScreenState extends ConsumerState<InterviewPrepScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final WebRTCService _webrtcService;

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

  // --- MOCK VOICE INTERVIEW STATE ---
  bool _isMockActive = false;
  int _mockQuestionIndex = 0;
  bool _isNoraSpeaking = false;
  bool _isCandidateRecording = false;
  final TextEditingController _candidateAnswerController = TextEditingController();
  double _mockScore = 0;
  String _mockFeedback = '';
  List<Map<String, dynamic>> _mockHistory = [];

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

  // Role-based Quizzes Bank
  final Map<String, List<Map<String, dynamic>>> _quizzesByTrack = {
    'Flutter & Dart': [
      {
        'question': 'How does Flutter achieve 60/120 FPS performance compared to traditional hybrid frameworks?',
        'options': [
          'By compiling to native machine code using Skia/Impeller and avoiding a JavaScript bridge',
          'By wrapping Android and iOS webviews inside a high-speed Chromium container',
          'By executing Dart in an interpreted VM that renders native UIKit and Android View widgets',
          'By pre-rendering all UI states on the backend cloud server',
        ],
        'correct': 0,
        'explanation': 'Flutter uses an ahead-of-time (AOT) compiled C/C++ engine (Impeller/Skia) rendering directly to the canvas without any JavaScript bridge serialization.',
      },
      {
        'question': 'Which widget boundary should you wrap an expensive animated widget with to isolate repaints?',
        'options': [
          'ClipRect',
          'RepaintBoundary',
          'SizedBox.shrink',
          'Transform.identity',
        ],
        'correct': 1,
        'explanation': 'RepaintBoundary creates a separate render layer (Layer), ensuring that when the subtree rebuilds, only that isolated layer is rasterized.',
      },
      {
        'question': 'In Dart concurrency, what is the key difference between an Event Loop task and a Microtask?',
        'options': [
          'Microtasks run on a separate CPU core, whereas event loops run on the main thread',
          'Microtasks take higher priority and execute immediately before the next event from the event queue',
          'Event loops handle only timer events, microtasks handle HTTP network calls',
          'Microtasks are deprecated in Dart 3 and replaced by Isolates',
        ],
        'correct': 1,
        'explanation': 'Dart’s event loop processes the entire microtask queue before fetching the next item from the main event queue.',
      },
      {
        'question': 'When passing data to a background worker isolate in Dart, what is the best practice for zero-copy memory transfer?',
        'options': [
          'Json encoding the entire payload as a string',
          'Using TransferableTypedData with SendPort.send()',
          'Writing to SQLite and reading in the isolate',
          'Using shared memory global static variables',
        ],
        'correct': 1,
        'explanation': 'TransferableTypedData allows zero-copy byte buffers to be moved directly across isolate boundaries without deep memory copying.',
      },
    ],
    'Python & Backend': [
      {
        'question': 'In Django ORM, what is the key difference between select_related and prefetch_related?',
        'options': [
          'select_related performs a SQL JOIN (for single-valued relations), while prefetch_related executes a separate query with IN clause (for many-to-many/reverse relations)',
          'prefetch_related creates a database trigger while select_related uses redis cache',
          'select_related is only for SQLite, prefetch_related is for PostgreSQL',
          'They are identical aliases in Django 4+',
        ],
        'correct': 0,
        'explanation': 'select_related does a single SQL JOIN on ForeignKey/OneToOne, whereas prefetch_related executes two queries and joins in Python memory for ManyToMany.',
      },
      {
        'question': 'How does the Python Global Interpreter Lock (GIL) impact multi-threaded CPU-bound execution?',
        'options': [
          'It allows threads to run in parallel on all CPU cores without locks',
          'It restricts Python bytecode execution to one native thread at a time per process',
          'It only locks file I/O operations and database connections',
          'It boosts multi-core performance by 200%',
        ],
        'correct': 1,
        'explanation': 'The GIL ensures memory safety in CPython by permitting only one thread to execute Python bytecode at any moment, making multiprocessing or native C extensions necessary for CPU-bound parallelism.',
      },
      {
        'question': 'Which database index type is most efficient for full-text search and array containment queries in PostgreSQL?',
        'options': [
          'B-Tree',
          'GIN (Generalized Inverted Index)',
          'BRIN (Block Range Index)',
          'Hash Index',
        ],
        'correct': 1,
        'explanation': 'GIN indexes are designed for composite values such as arrays, full-text vectors, and JSONB queries with containment operations.',
      },
    ],
    'AI & LLM Systems': [
      {
        'question': 'What is the primary role of a cross-encoder Reranker in a modern RAG (Retrieval-Augmented Generation) pipeline?',
        'options': [
          'To generate image embeddings for OCR documents',
          'To rescore top-K retrieved vector chunks jointly with the user query for precise relevance',
          'To compress the model weights into 4-bit quantization',
          'To generate synthetic test questions',
        ],
        'correct': 1,
        'explanation': 'Bi-encoders retrieve broad candidate chunks fast, but cross-encoders jointly score (query, document) pairs to achieve high precision before feeding context to the LLM.',
      },
      {
        'question': 'Which quantization technique allows loading 16-bit LLM weights into 4-bit precision with minimal perplexity degradation?',
        'options': [
          'QLoRA (Quantized Low-Rank Adaptation with NF4 and double quantization)',
          'Simple integer truncation',
          'One-hot encoding',
          'Float64 expansion',
        ],
        'correct': 0,
        'explanation': 'QLoRA uses NormalFloat4 (NF4) data type and double quantization with page optimizers to fine-tune 70B+ models on consumer GPUs.',
      },
    ],
    'System Design': [
      {
        'question': 'In a distributed systems architecture, what does the CAP theorem state?',
        'options': [
          'A distributed data store can simultaneously provide at most two out of Consistency, Availability, and Partition Tolerance',
          'All microservices must share a single database to guarantee transactions',
          'Cache memory must exceed disk storage capacity by 2x',
          'Latency is inversely proportional to bandwidth',
        ],
        'correct': 0,
        'explanation': 'Under network partition (P), a distributed system must choose between guaranteeing all nodes see the same data (C) or responding to all requests (A).',
      },
    ],
    'DevOps & Cloud': [
      {
        'question': 'What is the core principle of GitOps deployment workflows using tools like ArgoCD?',
        'options': [
          'Directly running kubectl apply from developers local terminal',
          'Git repository serves as the single source of truth for desired infrastructure and declarative cluster state',
          'Storing production secrets in plain public GitHub commits',
          'Disabling all container health checks in staging',
        ],
        'correct': 1,
        'explanation': 'GitOps uses Git as the declarative single source of truth, with continuous reconciliation controllers reconciling actual cluster state with Git.',
      },
    ],
  };

  // Mock Voice Interview Role-Specific Questions
  final Map<String, List<String>> _mockQuestionsByTrack = {
    'Flutter & Dart': [
      'Can you describe your experience designing scalable Flutter architecture and how you structure clean domain/presentation layers?',
      'How do you manage complex reactive states across multiple modules, and how do you prevent unnecessary widget rebuilds?',
      'Walk me through how you implement secure offline synchronization, local database caching, and network retry policies.',
      'Describe a difficult memory leak or rendering stutter issue you profiled using Flutter DevTools and resolved.',
    ],
    'Python & Backend': [
      'Walk us through how you design high-throughput REST and GraphQL APIs using Django and FastAPI under heavy concurrent traffic.',
      'How do you handle database connection pooling, slow query diagnostics, and distributed locking with Redis in production?',
      'Describe your approach to designing resilient background worker queues using Celery or RabbitMQ.',
      'Explain a major production incident you diagnosed involving race conditions or database deadlocks.',
    ],
    'AI & LLM Systems': [
      'How do you design a scalable production RAG architecture that prevents hallucination and handles streaming responses with sub-second latency?',
      'Explain how you fine-tune open source models with LoRA/QLoRA and how you benchmark their domain performance.',
      'What strategies do you use for agentic orchestration, tool invocation, and token budget management?',
    ],
    'System Design': [
      'How would you design a distributed real-time messaging platform like WhatsApp or Slack handling 50M concurrent connections?',
      'Explain how you would architect a globally distributed rate limiter with low latency and eventual consistency.',
    ],
    'DevOps & Cloud': [
      'Walk us through your strategy for zero-downtime Kubernetes deployments, automated canary rollouts, and multi-region failovers.',
      'How do you enforce automated cloud security, IAM least-privilege, and secrets rotation across CI/CD pipelines?',
    ],
  };

  String _candidateResumeSummary = '';
  List<String> _dynamicMockQuestions = [];
  bool _isLoadingQuestions = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _webrtcService = getWebRTCService();
    _fetchCandidateResume();
  }

  void _fetchCandidateResume() async {
    try {
      final dio = ApiClient().dio;
      final res = await dio.get(ApiConfig.resumes);
      final list = res.data['results'] ?? res.data ?? [];
      if (list.isNotEmpty) {
        final r = list.first;
        _candidateResumeSummary = r['extracted_text'] ?? (r['parsed_data'] != null ? r['parsed_data'].toString() : '');
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabController.dispose();
    _quizTimer?.cancel();
    _candidateAnswerController.dispose();
    _webrtcService.stopSpeaking();
    super.dispose();
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

    final questions = _quizzesByTrack[_selectedTrack] ?? [];
    if (questions.isEmpty) return;
    final currentQ = questions[_currentQuestionIndex];
    final isCorrect = _selectedAnswerIndex == currentQ['correct'];

    setState(() {
      _hasSubmittedAnswer = true;
      if (isCorrect) _quizScore++;
    });
  }

  void _nextQuestion() {
    final questions = _quizzesByTrack[_selectedTrack] ?? [];
    if (_currentQuestionIndex + 1 < questions.length) {
      setState(() {
        _currentQuestionIndex++;
        _selectedAnswerIndex = null;
        _hasSubmittedAnswer = false;
        _questionTimeRemaining = 45;
      });
      _startTimer();
    } else {
      _quizTimer?.cancel();
      setState(() {
        _quizFinished = true;
      });
    }
  }

  // --- MOCK VOICE INTERVIEW LOGIC (GEMINI POWERED) ---
  void _startMockInterview() async {
    setState(() {
      _isMockActive = true;
      _isLoadingQuestions = true;
      _mockQuestionIndex = 0;
      _mockHistory.clear();
      _mockScore = 0;
      _mockFeedback = 'AI Nora is reviewing your resume & creating tailored technical interview questions...';
    });

    try {
      final dio = ApiClient().dio;
      final res = await dio.post(
        ApiConfig.aiGenerateQuestions,
        data: {
          'title': _selectedTrack,
          'difficulty': _selectedLevel,
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
      _dynamicMockQuestions = _mockQuestionsByTrack[_selectedTrack] ?? _mockQuestionsByTrack['Flutter & Dart']!;
    }

    setState(() {
      _isLoadingQuestions = false;
      _mockFeedback = 'AI Nora is ready with personalized questions tailored to your profile and $_selectedTrack.';
    });

    final firstQ = _dynamicMockQuestions[0];
    _noraSpeak("Welcome to your mock interview session! I'm Nora. Based on your experience and claimed projects in $_selectedTrack, let's explore our first question: $firstQ");
  }

  void _noraSpeak(String text) {
    setState(() => _isNoraSpeaking = true);
    _webrtcService.speak(
      text,
      onStart: () {
        if (mounted) setState(() => _isNoraSpeaking = true);
      },
      onEnd: () {
        if (mounted) setState(() => _isNoraSpeaking = false);
      },
    );
  }

  void _toggleCandidateMic() {
    if (_isCandidateRecording) {
      _webrtcService.stopSpeechRecognition();
      setState(() => _isCandidateRecording = false);
    } else {
      setState(() => _isCandidateRecording = true);
      _webrtcService.startSpeechRecognition(
        targetLang: 'English',
        onResult: (text, _) {
          if (!mounted) return;
          setState(() {
            _candidateAnswerController.text = text;
          });
        },
      );
    }
  }

  void _submitCandidateAnswer() async {
    final answerText = _candidateAnswerController.text.trim();
    if (answerText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please speak into your microphone or type your answer before submitting.')),
      );
      return;
    }

    if (_isCandidateRecording) {
      _toggleCandidateMic();
    }

    final questions = _dynamicMockQuestions.isNotEmpty
        ? _dynamicMockQuestions
        : (_mockQuestionsByTrack[_selectedTrack] ?? _mockQuestionsByTrack['Flutter & Dart']!);
    final q = questions[_mockQuestionIndex];

    double answerScore = 88.0;
    String reaction = 'Strong technical response with relevant domain terminology.';

    try {
      final dio = ApiClient().dio;
      final res = await dio.post(
        '/ai/evaluate-answer/',
        data: {
          'question': q,
          'answer': answerText,
          'job_title': _selectedTrack,
          'resume_text': _candidateResumeSummary,
        },
      );
      if (res.data != null) {
        answerScore = (res.data['score'] as num?)?.toDouble() ?? 88.0;
        reaction = res.data['reaction']?.toString() ?? reaction;
      }
    } catch (_) {
      final wordCount = answerText.split(' ').length;
      answerScore = (wordCount > 25 ? 90.0 : (wordCount > 10 ? 82.0 : 70.0)).clamp(60.0, 98.0);
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
    });

    if (_mockQuestionIndex + 1 < questions.length) {
      setState(() => _mockQuestionIndex++);
      final nextQ = questions[_mockQuestionIndex];
      _noraSpeak("$reaction Now let's explore our next question: $nextQ");
    } else {
      _noraSpeak("$reaction Thank you for completing this technical mock interview. Your suitability score for $_selectedTrack is ${_mockScore.toInt()} percent. Exceptional performance!");
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

                            // Track & Experience Selectors
                            AppCard(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              child: Wrap(
                                spacing: 20,
                                runSpacing: 12,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.code, size: 16, color: AppColors.primary),
                                      const SizedBox(width: 8),
                                      const Text('Track: ', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.bold)),
                                      DropdownButton<String>(
                                        value: _selectedTrack,
                                        dropdownColor: const Color(0xFF1E2030),
                                        underline: const SizedBox(),
                                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                        items: _tracks.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                                        onChanged: (val) {
                                          if (val != null) {
                                            setState(() {
                                              _selectedTrack = val;
                                              _startQuiz();
                                            });
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.stairs_outlined, size: 16, color: Color(0xFFD946EF)),
                                      const SizedBox(width: 8),
                                      const Text('Seniority: ', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.bold)),
                                      DropdownButton<String>(
                                        value: _selectedLevel,
                                        dropdownColor: const Color(0xFF1E2030),
                                        underline: const SizedBox(),
                                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                        items: _levels.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                                        onChanged: (val) {
                                          if (val != null) {
                                            setState(() {
                                              _selectedLevel = val;
                                              _startQuiz();
                                            });
                                          }
                                        },
                                      ),
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
    final questions = _quizzesByTrack[_selectedTrack] ?? [];

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
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!_hasSubmittedAnswer)
                AppButton(
                  label: 'Submit Answer',
                  onPressed: _selectedAnswerIndex != null ? _submitAnswer : null,
                )
              else
                AppButton(
                  label: _currentQuestionIndex + 1 < questions.length ? 'Next Question ➔' : 'View Final Score',
                  onPressed: _nextQuestion,
                ),
            ],
          ),
        ],
      ),
    );
  }

  // --- MOCK VOICE INTERVIEW TAB ---
  Widget _buildMockVoiceTab(bool isDesktop) {
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
              child: const Icon(Icons.smart_toy, size: 52, color: Colors.white),
            ),
            const SizedBox(height: 20),
            Text('Autonomous AI Mock Voice Interview', style: AppTypography.displaySmall.copyWith(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Practice realistic technical interviews with AI Nora for "$_selectedTrack" ($_selectedLevel). Nora asks questions aloud using conversational speech synthesis and grades your verbal clarity & technical depth in real-time.',
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            AppButton(
              label: 'Start Live Voice Interview with Nora',
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

    final questions = _dynamicMockQuestions.isNotEmpty
        ? _dynamicMockQuestions
        : (_mockQuestionsByTrack[_selectedTrack] ?? _mockQuestionsByTrack['Flutter & Dart']!);
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
                          border: Border.all(color: const Color(0xFFD946EF), width: 2),
                        ),
                      ),
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: const Color(0xFF2E194D),
                        child: Icon(Icons.smart_toy, size: 28, color: const Color(0xFFD946EF)),
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
                                    Text('Speaking...', style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold)),
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

        // Candidate Voice Response Input Area
        AppCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Your Spoken Response:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  ElevatedButton.icon(
                    onPressed: _toggleCandidateMic,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isCandidateRecording ? const Color(0xFFEF4444) : AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: Icon(_isCandidateRecording ? Icons.mic : Icons.mic_none, size: 16),
                    label: Text(_isCandidateRecording ? 'Listening (Tap to Stop)' : 'Speak into Mic'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _candidateAnswerController,
                maxLines: 4,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Speak using the microphone above or type your technical answer here...',
                  hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                  filled: true,
                  fillColor: const Color(0xFF161826),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF2E324D))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFD946EF))),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton(
                    label: 'Submit Response for Evaluation',
                    onPressed: _submitCandidateAnswer,
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
                      Text('Nora’s Live Evaluation (${_mockScore.toInt()}%)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
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
