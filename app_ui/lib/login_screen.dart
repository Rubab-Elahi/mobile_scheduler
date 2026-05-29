import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'theme.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await _authService.signInWithGoogle();
      if (success) {
        widget.onLoginSuccess();
      } else {
        setState(() {
          _errorMessage = "Sign in was cancelled or failed.";
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "An unexpected error occurred: $e";
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MidnightForestTheme.background,
      body: Stack(
        children: [
          // ── Radial Mesh Gradient Background ──────────────────────
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.8, -0.6),
                  radius: 1.2,
                  colors: [
                    Color(0x33A855F7), // Subtle Amethyst Glow
                    Color(0xFF0F172A),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.8, 0.6),
                  radius: 1.2,
                  colors: [
                    Color(0x1F10B981), // Subtle Emerald Glow
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── Main Layout ──────────────────────────────────────────
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ── Glowing Logo Sphere ────────────────────────
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [
                            MidnightForestTheme.primary,
                            Color(0xFFC084FC),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: MidnightForestTheme.primary.withOpacity(0.4),
                            blurRadius: 30,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        size: 45,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 30),

                    // ── Title & Branding ──────────────────────────
                    const Text(
                      "AETHER",
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 6,
                        color: Colors.white,
                      ),
                    ),
                    const Text(
                      "AGENTIC AI SCHEDULER",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3,
                        color: MidnightForestTheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Welcome to your intelligent, automated day planner. Sync calendars, manage tasks via voice, and optimize your schedule seamlessly.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: MidnightForestTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // ── Glassmorphism Login Card ───────────────────
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: MidnightForestTheme.surface.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.08),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 40,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            "Secure Access",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Log in using your corporate or personal account.",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              color: MidnightForestTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 28),

                          // ── Google Sign In Button ────────────────
                          if (_isLoading)
                            const Center(
                              child: CircularProgressIndicator(
                                color: MidnightForestTheme.primary,
                              ),
                            )
                          else
                            ElevatedButton(
                              onPressed: _handleGoogleSignIn,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black87,
                                surfaceTintColor: Colors.white,
                                elevation: 2,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Styled high-fidelity Google brand-like G icon
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                    ),
                                    child: CustomPaint(
                                      painter: GoogleLogoPainter(),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  const Text(
                                    "Continue with Google",
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // ── Error Feedback ─────────────────────
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 18),
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // ── Footer ─────────────────────────────────────
                    const SizedBox(height: 50),
                    Text(
                      "Protected by AWS Cognito Advanced Security",
                      style: TextStyle(
                        fontSize: 11,
                        color: MidnightForestTheme.textSecondary.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Google Logo Vector Painter ─────────────────────────────────────
class GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double r = w / 2;

    final Paint paint = Paint()..style = PaintingStyle.fill;

    // 🔴 Red segment (Top)
    paint.color = const Color(0xFFEA4335);
    final Path redPath = Path()
      ..moveTo(r, r)
      ..lineTo(0.08 * w, 0.23 * h)
      ..arcToPoint(
        Offset(0.92 * w, 0.23 * h),
        radius: Radius.circular(r),
        largeArc: false,
        clockwise: true,
      )
      ..close();
    canvas.drawPath(redPath, paint);

    // 🟡 Yellow segment (Left)
    paint.color = const Color(0xFFFBBC05);
    final Path yellowPath = Path()
      ..moveTo(r, r)
      ..lineTo(0.08 * w, 0.77 * h)
      ..arcToPoint(
        Offset(0.08 * w, 0.23 * h),
        radius: Radius.circular(r),
        largeArc: false,
        clockwise: true,
      )
      ..close();
    canvas.drawPath(yellowPath, paint);

    // 🟢 Green segment (Bottom)
    paint.color = const Color(0xFF34A853);
    final Path greenPath = Path()
      ..moveTo(r, r)
      ..lineTo(0.92 * w, 0.77 * h)
      ..arcToPoint(
        Offset(0.08 * w, 0.77 * h),
        radius: Radius.circular(r),
        largeArc: false,
        clockwise: true,
      )
      ..close();
    canvas.drawPath(greenPath, paint);

    // 🔵 Blue segment (Right & Middle bar)
    paint.color = const Color(0xFF4285F4);
    final Path bluePath = Path()
      ..moveTo(r, r)
      ..lineTo(0.92 * w, 0.23 * h)
      ..arcToPoint(
        Offset(0.92 * w, 0.77 * h),
        radius: Radius.circular(r),
        largeArc: false,
        clockwise: true,
      )
      ..lineTo(r, 0.77 * h) // Cut slightly back to make room for center bar
      ..lineTo(r, 0.5 * h)
      ..lineTo(0.95 * w, 0.5 * h)
      ..lineTo(0.95 * w, 0.38 * h)
      ..close();
    canvas.drawPath(bluePath, paint);

    // ⚪ Center white masking circle to make it a ring/G shape
    final Paint whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(r, r), 0.32 * r, whitePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
