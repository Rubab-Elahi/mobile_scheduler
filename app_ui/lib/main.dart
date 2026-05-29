import 'package:amplify_api/amplify_api.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_storage_s3/amplify_storage_s3.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'amplifyconfiguration.dart';
import 'login_screen.dart';
import 'providers.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _configureAmplify();
  runApp(const ProviderScope(child: MyApp()));
}

Future<void> _configureAmplify() async {
  try {
    final auth = AmplifyAuthCognito();
    final api = AmplifyAPI();
    final storage = AmplifyStorageS3();

    await Amplify.addPlugins([auth, api, storage]);
    await Amplify.configure(amplifyconfig);
    safePrint('Successfully configured Amplify');
  } on Exception catch (e) {
    safePrint('Error configuring Amplify: $e');
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSignedIn = ref.watch(authStateProvider);

    return MaterialApp(
      title: 'Aether AI Scheduler',
      theme: MidnightForestTheme.darkTheme,
      home: isSignedIn
          ? const DashboardScreen()
          : LoginScreen(
              onLoginSuccess: () => ref.read(authStateProvider.notifier).setLoggedIn(true),
            ),
      debugShowCheckedModeBanner: false,
    );
  }
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  void _showVoiceAssistant(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return const VoiceAssistantSheet();
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userVal = ref.watch(currentUserProvider);
    String displayName = "User";
    if (userVal.value != null) {
      final username = userVal.value!.username;
      if (username.contains('@')) {
        displayName = username.split('@')[0];
      } else {
        displayName = username;
      }
      displayName = displayName[0].toUpperCase() + displayName.substring(1);
    }

    return Scaffold(
      body: Stack(
        children: [
          // ── Main Content ─────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  _buildHeader(context, ref, displayName),
                  const SizedBox(height: 30),
                  _buildBentoSection(ref),
                  const SizedBox(height: 30),
                  const Text(
                    "Midnight Timeline",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Expanded(child: TimelineWidget()),
                ],
              ),
            ),
          ),

          // ── AI Voice Button (Floating) ──────────────────────────
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: _buildVoiceButton(context, ref),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, String name) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Hey $name,",
              style: const TextStyle(
                color: MidnightForestTheme.textSecondary,
                fontSize: 16,
              ),
            ),
            const Text(
              "I've optimized your day.",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: () async {
            // Confirm logout bottom sheet
            showModalBottomSheet(
              context: context,
              backgroundColor: MidnightForestTheme.surface,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (context) => SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Sign Out",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "Are you sure you want to log out of your session?",
                        style: TextStyle(color: MidnightForestTheme.textSecondary),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white24),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text("Cancel", style: TextStyle(color: Colors.white)),
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                Navigator.pop(context);
                                await ref.read(authService).signOut();
                                ref.read(authStateProvider.notifier).setLoggedIn(false);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text("Logout"),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: MidnightForestTheme.primary.withOpacity(0.3), width: 1.5),
            ),
            child: const CircleAvatar(
              backgroundColor: MidnightForestTheme.surface,
              child: Icon(Icons.person, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBentoSection(WidgetRef ref) {
    final tasksAsync = ref.watch(tasksProvider);
    final int count = tasksAsync.value?.length ?? 0;

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _buildBentoCard(
            "AI Insights",
            "$count Active Tasks\nProgress: ${count > 0 ? 'Dynamic' : 'No Data'}",
            MidnightForestTheme.primary,
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          flex: 2,
          child: _buildBentoCard(
            "Focus",
            count > 0 ? "Next: ${tasksAsync.value![0]['title']}" : "Next: Add a task",
            MidnightForestTheme.secondary,
          ),
        ),
      ],
    );
  }

  Widget _buildBentoCard(String title, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MidnightForestTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: MidnightForestTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceButton(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _showVoiceAssistant(context, ref),
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: MidnightForestTheme.primary,
          boxShadow: [
            BoxShadow(
              color: MidnightForestTheme.primary.withOpacity(0.5),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: const Icon(Icons.mic, size: 35, color: Colors.white),
      ),
    );
  }
}

// ── Live Timeline Widget ───────────────────────────────────────────
class TimelineWidget extends ConsumerWidget {
  const TimelineWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksProvider);

    return tasksAsync.when(
      data: (tasks) {
        if (tasks.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text(
                "No tasks found in AWS DynamoDB.\nTap the microphone below and ask the Agentic AI to schedule your tasks!",
                textAlign: TextAlign.center,
                style: const TextStyle(color: MidnightForestTheme.textSecondary, height: 1.5),
              ),
            ),
          );
        }

        return RefreshIndicator(
          color: MidnightForestTheme.primary,
          backgroundColor: MidnightForestTheme.surface,
          onRefresh: () async {
            ref.invalidate(tasksProvider);
          },
          child: ListView.builder(
            itemCount: tasks.length,
            padding: const EdgeInsets.only(top: 15, bottom: 100),
            itemBuilder: (context, index) {
              final task = tasks[index];
              final String title = task['title'] ?? 'Untitled Task';
              final String dueDate = task['dueDate'] ?? '09:00';
              final String priority = task['priority'] ?? 'NORMAL';
              final String status = task['status'] ?? 'PENDING';

              Color priorityColor;
              if (priority.toUpperCase() == 'HIGH') {
                priorityColor = Colors.redAccent;
              } else if (priority.toUpperCase() == 'LOW') {
                priorityColor = MidnightForestTheme.secondary;
              } else {
                priorityColor = MidnightForestTheme.primary;
              }

              // Extract readable time/date
              String displayTime = dueDate;
              if (dueDate.contains('T')) {
                try {
                  displayTime = dueDate.split('T')[1].substring(0, 5);
                } catch (_) {}
              }

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Text(displayTime, style: const TextStyle(fontSize: 12, color: MidnightForestTheme.textSecondary)),
                        const SizedBox(height: 5),
                        Container(width: 2, height: 60, color: MidnightForestTheme.surface),
                      ],
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: MidnightForestTheme.surface.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: priorityColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: priorityColor.withOpacity(0.3)),
                                  ),
                                  child: Text(
                                    priority.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: priorityColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Status: ${status.toLowerCase()}",
                                  style: const TextStyle(fontSize: 12, color: MidnightForestTheme.textSecondary),
                                ),
                                Text(
                                  dueDate.contains('T') ? dueDate.split('T')[0] : 'Today',
                                  style: TextStyle(fontSize: 10, color: MidnightForestTheme.textSecondary.withOpacity(0.6)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: MidnightForestTheme.primary),
      ),
      error: (err, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            "Error loading tasks: $err",
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.redAccent),
          ),
        ),
      ),
    );
  }
}

// ── Voice Assistant Sheet ──────────────────────────────────────────
class VoiceAssistantSheet extends ConsumerStatefulWidget {
  const VoiceAssistantSheet({super.key});

  @override
  ConsumerState<VoiceAssistantSheet> createState() => _VoiceAssistantSheetState();
}

class _VoiceAssistantSheetState extends ConsumerState<VoiceAssistantSheet> {
  final TextEditingController _promptController = TextEditingController();
  bool _isProcessing = false;
  String? _aiResponse;
  String? _userPromptSent;

  Future<void> _submitPrompt() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _aiResponse = null;
      _userPromptSent = prompt;
    });
    _promptController.clear();
    FocusScope.of(context).unfocus();

    try {
      // Trigger the REST API Gateway endpoint
      await ref.read(taskService).triggerVoiceAI(prompt);
      
      setState(() {
        _aiResponse = "Prompt successfully analyzed! Your schedule has been orchestrated and synced with DynamoDB.";
      });

      // Instantly refresh list of tasks
      ref.invalidate(tasksProvider);
    } catch (e) {
      setState(() {
        _aiResponse = "Error contacting Agentic AI backend service: $e";
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: MidnightForestTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header bar
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 18),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.auto_awesome, color: MidnightForestTheme.primary, size: 20),
                    SizedBox(width: 8),
                    Text(
                      "Agentic AI Assistant",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white54),
                )
              ],
            ),
            const SizedBox(height: 20),

            // AI Status & Conversation Block
            Container(
              padding: const EdgeInsets.all(16),
              constraints: const BoxConstraints(minHeight: 120),
              decoration: BoxDecoration(
                color: MidnightForestTheme.background.withOpacity(0.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.04)),
              ),
              child: _buildChatContent(),
            ),
            const SizedBox(height: 20),

            // Input field & Send button
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _promptController,
                    decoration: InputDecoration(
                      hintText: "Add team sync tomorrow at 9 AM...",
                      hintStyle: const TextStyle(fontSize: 14, color: Colors.white30),
                      filled: true,
                      fillColor: MidnightForestTheme.background,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: const TextStyle(fontSize: 14),
                    onSubmitted: (_) => _submitPrompt(),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _submitPrompt,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: MidnightForestTheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildChatContent() {
    if (_isProcessing) {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: MidnightForestTheme.primary),
          SizedBox(height: 12),
          Text(
            "Agentic AI is organizing your schedule...",
            style: TextStyle(fontSize: 12, color: MidnightForestTheme.textSecondary),
          ),
        ],
      );
    }

    if (_aiResponse == null && _userPromptSent == null) {
      return const Center(
        child: Text(
          "\"Tell me what to schedule, and I will automatically build your calendar timeline.\"",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontStyle: FontStyle.italic,
            color: MidnightForestTheme.textSecondary,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_userPromptSent != null) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.person_outline, size: 16, color: MidnightForestTheme.secondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _userPromptSent!,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white10),
          const SizedBox(height: 12),
        ],
        if (_aiResponse != null)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.auto_awesome, size: 16, color: MidnightForestTheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _aiResponse!,
                  style: const TextStyle(fontSize: 13, color: MidnightForestTheme.textSecondary, height: 1.4),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
