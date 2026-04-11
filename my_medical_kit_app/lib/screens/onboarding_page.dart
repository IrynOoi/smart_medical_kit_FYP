//onboarding_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/colors.dart';
import 'landing_page.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int currentPage = 0;

  // 🌟 Onboarding pages data
  final List<OnboardingContent> pages = [
    OnboardingContent(
      title: 'Never Miss a Dose',
      description:
          'The Smart Medical Kit reminds you exactly when to take your medication.',
      image: 'assets/images/reminder-icon.svg',
      isWhiteIcon: true, // needs to be converted to white
    ),
    OnboardingContent(
      title: 'AI Health Insights',
      description: 'AI predicts patterns to improve your medication adherence.',
      image: 'assets/images/ai.svg',
      isWhiteIcon: false, // keep original colors
    ),
    OnboardingContent(
      title: 'Stay Connected',
      description: 'Caregivers receive real-time updates instantly.',
      image: 'assets/images/notification.svg',
      isWhiteIcon: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.mainGradient),
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => currentPage = i),
                itemCount: pages.length,
                itemBuilder: (context, index) {
                  final item = pages[index];

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 🌟 Icon container with fixed size
                      SizedBox(
                        width: 220,
                        height: 220,
                        child: SvgPicture.asset(
                          item.image,
                          // 🌟 Apply white color conditionally
                          colorFilter: item.isWhiteIcon
                              ? const ColorFilter.mode(
                                  Colors.white,
                                  BlendMode.srcIn,
                                )
                              : null,
                        ),
                      ),

                      const SizedBox(height: 40),

                      Text(
                        item.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 15),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 30),
                        child: Text(
                          item.description,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.white.withValues(alpha: 0.9),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // dots + button section
            Expanded(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      pages.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.all(4),
                        width: currentPage == i ? 20 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(
                            alpha: currentPage == i ? 1 : 0.4,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),

                  const Spacer(),

                  Padding(
                    padding: const EdgeInsets.all(30),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 55),
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primaryPurple,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: () {
                        if (currentPage == pages.length - 1) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LandingPage(),
                            ),
                          );
                        } else {
                          _controller.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                      child: Text(
                        currentPage == pages.length - 1
                            ? "GET STARTED"
                            : "NEXT",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 🌟 Data model
class OnboardingContent {
  final String title;
  final String description;
  final String image;
  final bool isWhiteIcon;

  OnboardingContent({
    required this.title,
    required this.description,
    required this.image,
    this.isWhiteIcon = false,
  });
}
