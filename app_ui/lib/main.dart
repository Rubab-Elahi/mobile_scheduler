import 'package:amplify_api/amplify_api.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_storage_s3/amplify_storage_s3.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'amplifyconfiguration.dart';
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aether AI Scheduler',
      theme: MidnightForestTheme.darkTheme,
      home: const DashboardScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  _buildHeader(),
                  const SizedBox(height: 30),
                  _buildBentoSection(),
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
              child: _buildVoiceButton(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Hey Rubab,",
              style: TextStyle(
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
        const CircleAvatar(
          backgroundColor: MidnightForestTheme.surface,
          child: Icon(Icons.person, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildBentoSection() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _buildBentoCard(
            "AI Insights",
            "4.8h Productive Time\nProgress: 85%",
            MidnightForestTheme.primary,
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          flex: 2,
          child: _buildBentoCard(
            "Focus",
            "Next: Product Strategy",
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

  Widget _buildVoiceButton() {
    return Container(
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
    );
  }
}

class TimelineWidget extends StatelessWidget {
  const TimelineWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 5,
      padding: const EdgeInsets.only(top: 15, bottom: 100),
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Column(
                children: [
                  Text("09:00", style: TextStyle(fontSize: 12, color: MidnightForestTheme.textSecondary)),
                  SizedBox(height: 5),
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
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Team Sync", style: TextStyle(fontWeight: FontWeight.bold)),
                      Text("Project Omega • 45m", style: TextStyle(fontSize: 12, color: MidnightForestTheme.textSecondary)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

