import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../config/app_config.dart';
import '../../services/gemini_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/quiz_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../widgets/responsive_layout.dart';

class AiQuizGeneratorScreen extends ConsumerStatefulWidget {
  const AiQuizGeneratorScreen({super.key});

  @override
  ConsumerState<AiQuizGeneratorScreen> createState() => _AiQuizGeneratorScreenState();
}

enum _GenerationState { initial, loading, success, error }

class _AiQuizGeneratorScreenState extends ConsumerState<AiQuizGeneratorScreen> with SingleTickerProviderStateMixin {
  final List<PlatformFile> _selectedFiles = [];
  double _questionCount = 10;
  late final TextEditingController _countInputCtrl;
  String _difficulty = 'Medium';
  final TextEditingController _instructionController = TextEditingController();
  _GenerationState _state = _GenerationState.initial;
  String _errorMessage = '';

  // Question types to include in generation (flashcard is always automatic)
  final Set<String> _selectedTypes = {'mcq', 'identification', 'enumeration'};

  late final AnimationController _animationController;

  // To hold generated quiz models
  dynamic _generatedQuiz;
  dynamic _generatedQuestions;

  @override
  void initState() {
    super.initState();
    _countInputCtrl = TextEditingController(text: _questionCount.toInt().toString());
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _instructionController.dispose();
    _countInputCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'txt', 'docx', 'pptx', 'ppt'],
      allowMultiple: true,
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final validFiles = <PlatformFile>[];
      final maxBytes = AppConfig.maxUploadBytes;
      for (final file in result.files) {
        if (file.bytes != null && file.size <= maxBytes) {
          validFiles.add(file);
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${file.name} exceeds the 20MB limit.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }

      setState(() {
        _selectedFiles.addAll(validFiles);
        _state = _GenerationState.initial;
      });
    }
  }

  void _removeFile(int index) {
    setState(() {
      if (index >= 0 && index < _selectedFiles.length) {
        _selectedFiles.removeAt(index);
      }
      _state = _GenerationState.initial;
    });
  }

  Future<void> _generateQuiz() async {
    final isOnline = await ref.read(connectivityServiceProvider).isOnline;
    if (!isOnline) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI generation requires internet connection'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (_selectedFiles.isEmpty) return;

    setState(() {
      _state = _GenerationState.loading;
    });

    try {
      final filesPayload = _selectedFiles
          .where((f) => f.bytes != null)
          .map((f) => (bytes: f.bytes!, fileName: f.name))
          .toList();

      final count = _questionCount.toInt();

      final result = await GeminiService().generateQuizFromMultipleFiles(
        files: filesPayload,
        questionCount: count,
        difficulty: _difficulty,
        selectedTypes: _selectedTypes.toList(),
        customInstruction: _instructionController.text.trim().isEmpty
            ? null
            : _instructionController.text.trim(),
      );

      final user = ref.read(currentUserProvider).valueOrNull;
      final userId = user?.id ?? 'anonymous';
      final quizId = const Uuid().v4();

      final (quiz, questions) = GeminiService.toModels(result, userId, quizId);

      setState(() {
        _generatedQuiz = quiz;
        _generatedQuestions = questions;
        _state = _GenerationState.success;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _state = _GenerationState.error;
      });
    }
  }

  Future<void> _saveAndOpenQuiz() async {
    if (_generatedQuiz == null || _generatedQuestions == null) return;

    final user = ref.read(currentUserProvider).valueOrNull;
    final userId = user?.id ?? 'anonymous';

    await ref.read(userQuizzesProvider(userId).notifier).saveGeneratedQuiz(
      _generatedQuiz,
      _generatedQuestions,
    );

    if (mounted) {
      context.go('/quiz/${_generatedQuiz.id}');
    }
  }

  Color _getFileTypeColor(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf': return Colors.redAccent;
      case 'txt': return Colors.blueAccent;
      case 'docx': return Colors.teal;
      case 'pptx':
      case 'ppt': return Colors.orangeAccent;
      default: return Colors.grey;
    }
  }

  Widget _buildGlassCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: padding ?? const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildInitialState() {
    final isDesktop = ResponsiveBreakpoints.isDesktop(context);

    final formWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildGlassCard(
          child: Column(
            children: [
              if (_selectedFiles.isEmpty) ...[
                Icon(Icons.upload_file, size: 64, color: Colors.white.withValues(alpha: 0.7)),
                const SizedBox(height: 16),
                const Text(
                  'Upload documents',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Supported formats: PDF, TXT, DOCX, PPTX\nSelect multiple files at once • Max 20MB per file',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Browse Files'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ] else ...[
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _selectedFiles.length,
                  separatorBuilder: (context, index) => const Divider(color: Colors.white24, height: 16),
                  itemBuilder: (context, index) {
                    final f = _selectedFiles[index];
                    return Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: _getFileTypeColor(f.extension ?? ''),
                          child: Text(
                            f.extension?.toUpperCase() ?? 'DOC',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                f.name,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${(f.size / 1024 / 1024).toStringAsFixed(2)} MB',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => _removeFile(index),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('Add More Files', style: TextStyle(color: Colors.white)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white38),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 360;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Number of Questions',
                              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isNarrow ? 'Slide or type (1-50)' : 'Type a number or slide (1 - 50)',
                              style: const TextStyle(color: Colors.white60, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Minus Button
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: _questionCount > 1
                                  ? () {
                                      setState(() {
                                        _questionCount = (_questionCount - 1).clamp(1, 50);
                                        _countInputCtrl.text = _questionCount.toInt().toString();
                                      });
                                    }
                                  : null,
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  Icons.remove_circle_outline_rounded,
                                  size: 24,
                                  color: _questionCount > 1 ? const Color(0xFF8B5CF6) : Colors.white24,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Editable Input Field
                          Container(
                            width: 52,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.6), width: 1.5),
                            ),
                            child: Center(
                              child: TextField(
                                controller: _countInputCtrl,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                  border: InputBorder.none,
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(2),
                                ],
                                onChanged: (val) {
                                  final parsed = int.tryParse(val);
                                  if (parsed != null) {
                                    final clamped = parsed.clamp(1, 50);
                                    setState(() {
                                      _questionCount = clamped.toDouble();
                                    });
                                  }
                                },
                                onSubmitted: (val) {
                                  final parsed = int.tryParse(val) ?? 10;
                                  final clamped = parsed.clamp(1, 50);
                                  setState(() {
                                    _questionCount = clamped.toDouble();
                                    _countInputCtrl.text = clamped.toString();
                                  });
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Plus Button
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: _questionCount < 50
                                  ? () {
                                      setState(() {
                                        _questionCount = (_questionCount + 1).clamp(1, 50);
                                        _countInputCtrl.text = _questionCount.toInt().toString();
                                      });
                                    }
                                  : null,
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  Icons.add_circle_outline_rounded,
                                  size: 24,
                                  color: _questionCount < 50 ? const Color(0xFF8B5CF6) : Colors.white24,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: const Color(0xFF6C63FF),
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
                  thumbColor: Colors.white,
                  overlayColor: const Color(0xFF6C63FF).withValues(alpha: 0.2),
                ),
                child: Slider(
                  value: _questionCount,
                  min: 1,
                  max: 50,
                  divisions: 49,
                  label: '${_questionCount.toInt()} questions',
                  onChanged: (val) {
                    setState(() {
                      _questionCount = val;
                      _countInputCtrl.text = val.toInt().toString();
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Difficulty Level',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['Easy', 'Medium', 'High', 'Extreme'].map((level) {
                    final isSelected = _difficulty == level;
                    Color chipColor;
                    switch (level) {
                      case 'Easy': chipColor = Colors.green; break;
                      case 'Medium': chipColor = Colors.blue; break;
                      case 'High': chipColor = Colors.orange; break;
                      case 'Extreme': chipColor = Colors.red; break;
                      default: chipColor = const Color(0xFF6C63FF);
                    }
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(level),
                        selected: isSelected,
                        selectedColor: chipColor,
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _difficulty = level);
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Question Types Included',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Flashcards are always created automatically for every question set.',
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildTypeChip('mcq', 'Multiple Choice', Icons.list_alt_rounded, const Color(0xFF6C63FF)),
                  _buildTypeChip('identification', 'Identification', Icons.edit_note_rounded, const Color(0xFF8B5CF6)),
                  _buildTypeChip('enumeration', 'Enumeration', Icons.format_list_numbered_rounded, const Color(0xFF06B6D4)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Custom Prompt / Instructions (Optional)',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _instructionController,
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'e.g. Focus on Chapter 3 key terms, or emphasize definitions...',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                  filled: true,
                  fillColor: Colors.black.withValues(alpha: 0.2),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _generateQuiz,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6C63FF),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 8,
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_awesome_rounded, size: 22),
              SizedBox(width: 10),
              Text(
                'Generate Quiz with AI',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );

    if (isDesktop) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 60, child: formWidget),
            const SizedBox(width: 24),
            Expanded(
              flex: 40,
              child: _buildGlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.lightbulb_rounded, color: Colors.amber, size: 28),
                        SizedBox(width: 10),
                        Text(
                          'AI Quiz Tips',
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Upload your lecture slides, notes, or chapter PDFs. Google Gemini AI will automatically convert your study materials into interactive study cards.',
                      style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Supported Features:',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 12),
                    _buildTipItem(Icons.style_rounded, 'Automatic Flashcards for instant review'),
                    const SizedBox(height: 10),
                    _buildTipItem(Icons.quiz_rounded, 'Multiple Choice & Identification questions'),
                    const SizedBox(height: 10),
                    _buildTipItem(Icons.format_list_bulleted_rounded, 'Enumeration lists with instant answer scoring'),
                    const SizedBox(height: 10),
                    _buildTipItem(Icons.sync_rounded, 'Available on both Web and Mobile devices'),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: formWidget,
    );
  }

  Widget _buildTipItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF6C63FF), size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeChip(String type, String label, IconData icon, Color color) {
    final isSelected = _selectedTypes.contains(type);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            // Don't allow deselecting if it's the last one
            if (_selectedTypes.length > 1) {
              _selectedTypes.remove(type);
            }
          } else {
            _selectedTypes.add(type);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.white.withValues(alpha: 0.15),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? Icons.check_box_rounded : icon,
              color: isSelected ? color : Colors.white54,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white54,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: _buildGlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return ShaderMask(
                  shaderCallback: (bounds) {
                    return LinearGradient(
                      colors: const [Color(0xFF6C63FF), Colors.purpleAccent, Color(0xFF6C63FF)],
                      stops: const [0.0, 0.5, 1.0],
                      transform: GradientRotation(_animationController.value * 2 * 3.14159),
                    ).createShader(bounds);
                  },
                  child: const Icon(Icons.auto_awesome, size: 80, color: Colors.white),
                );
              },
            ),
            const SizedBox(height: 32),
            const Text(
              'AI is reading your document...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'This might take a minute depending on the document size.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: _buildGlassCard(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
            const SizedBox(height: 24),
            const Text(
              'Oops! Something went wrong.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() => _state = _GenerationState.initial);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessState() {
    final title = _generatedQuiz?.title ?? 'Generated Quiz';
    final qCount = _generatedQuestions?.length ?? _questionCount.toInt();
    
    return Center(
      child: _buildGlassCard(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, size: 48, color: Colors.greenAccent),
            ),
            const SizedBox(height: 24),
            const Text(
              'Quiz Ready!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$qCount Questions Generated',
                    style: const TextStyle(
                      color: Color(0xFF6C63FF),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saveAndOpenQuiz,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Save & Open Quiz'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('AI Quiz Generator', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A1A2E), // Deep Purple
              Color(0xFF16213E), // Indigo
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: switch (_state) {
                _GenerationState.initial => _buildInitialState(),
                _GenerationState.loading => _buildLoadingState(),
                _GenerationState.success => _buildSuccessState(),
                _GenerationState.error => _buildErrorState(),
              },
            ),
          ),
        ),
      ),
    );
  }
}
