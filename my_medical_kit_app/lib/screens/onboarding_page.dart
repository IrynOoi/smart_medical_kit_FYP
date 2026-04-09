import 'package:flutter/material.dart';
import 'package:my_medical_kit_app/theme/colors.dart';
import 'landing_page.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingContent> _contents = [
    OnboardingContent(
      title: 'Never Miss a Dose',
      description: 'The Smart Medical Kit reminds you exactly when to take your medication, ensuring you stay healthy.',
      icon: Icons.notifications_active_rounded,
    ),
    OnboardingContent(
      title: 'AI Health Insights',
      description: 'Our advanced AI predicts forgetfulness patterns and provides alerts to keep you and your loved ones safe.',
      icon: Icons.psychology_rounded,
    ),
    OnboardingContent(
      title: 'Stay Connected',
      description: 'Caregivers receive real-time notifications about medication adherence, providing peace of mind.',
      icon: Icons.favorite_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppColors.mainGradient,
        ),
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: _contents.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(30),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _contents[index].icon,
                            size: 100,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 40),
                        Text(
                          _contents[index].title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _contents[index].description,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withValues(alpha: 0.9),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Expanded(
              flex: 1,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _contents.length,
                      (index) => buildDot(index),
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 40.0),
                    child: ElevatedButton(
                      onPressed: () {
                        if (_currentPage == _contents.length - 1) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const LandingPage()),
                          );
                        } else {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primaryPurple,
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 5,
                      ),
                      child: Text(
                        _currentPage == _contents.length - 1 ? 'GET STARTED' : 'NEXT',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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

  Widget buildDot(int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(right: 8),
      height: 10,
      width: _currentPage == index ? 24 : 10,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: _currentPage == index ? 1.0 : 0.4),
        borderRadius: BorderRadius.circular(5),
      ),
    );
  }
}

class OnboardingContent {
  final String title;
  final String description;
  final IconData icon;

  OnboardingContent({
    required this.title,
    required this.description,
    required this.icon,
  });
}
