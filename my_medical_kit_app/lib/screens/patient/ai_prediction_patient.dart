// screens/ai_prediction_patient.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:my_medical_kit_app/services/api/patient_service.dart';
import 'package:my_medical_kit_app/theme/colors.dart';
import 'package:my_medical_kit_app/services/api/prediction_service.dart';
import 'package:my_medical_kit_app/models/ai_prediction.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class AIPredictionPatientPage extends StatefulWidget {
  const AIPredictionPatientPage({super.key});

  @override
  State<AIPredictionPatientPage> createState() =>
      _AIPredictionPatientPageState();
}

class _AIPredictionPatientPageState extends State<AIPredictionPatientPage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  AIPrediction? _prediction;
  int _patientId = 0;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _loadPatientId();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadPatientId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt('patient_id');
    if (id != null && id > 0) {
      _patientId = id;
      await _loadPrediction();
    } else {
      setState(() => _isLoading = false);
    }
  }

  // This loads data from PostgreSQL (does not run AI model)
  // 🌟 FIX: 改为每次打开页面时，强制让后端重新运行 AI 模型！
  Future<void> _loadPrediction({bool showLoading = true}) async {
    if (showLoading) setState(() => _isLoading = true);
    try {
      // 👇 关键修改：调用重新计算的 API，确保永远获取包含最新 Miss/Take 的结果
      final prediction = await PredictionService().recalculatePrediction(
        _patientId,
      );

      setState(() {
        _prediction = prediction;
        _isLoading = false;
      });
      if (prediction != null) {
        _animationController.forward(from: 0.0);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error running AI prediction: $e')),
        );
      }
    }
  }

  // 🌟 NEW: This triggers the Python Backend to run the Hybrid AI Model
  Future<void> _recalculatePrediction() async {
    setState(() => _isLoading = true);
    try {
      final prediction = await PredictionService().recalculatePrediction(
        _patientId,
      );
      if (prediction != null) {
        setState(() {
          _prediction = prediction;
        });
        _animationController.forward(from: 0.0);
      } else {
        // No prediction (possibly insufficient data)
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Info'),
              content: const Text('No adherence data for prediction.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      // If the backend returned a meaningful error message (e.g., "No adherence data")
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Color _getRiskColor() {
    if (_prediction == null) return Colors.grey;
    switch (_prediction!.riskLevel) {
      case RiskLevel.high:
        return Colors.redAccent;
      case RiskLevel.medium:
        return Colors.orange;
      case RiskLevel.low:
        return Colors.green;
    }
  }

  String _getRiskText() {
    if (_prediction == null) return '';
    switch (_prediction!.riskLevel) {
      case RiskLevel.high:
        return 'High Risk';
      case RiskLevel.medium:
        return 'Moderate Risk';
      case RiskLevel.low:
        return 'Low Risk';
    }
  }

  IconData _getRiskIcon() {
    if (_prediction == null) return Icons.help_outline;
    switch (_prediction!.riskLevel) {
      case RiskLevel.high:
        return Icons.warning_amber_rounded;
      case RiskLevel.medium:
        return Icons.info_outline_rounded;
      case RiskLevel.low:
        return Icons.check_circle_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.premiumLight.withOpacity(0.1),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () => _loadPrediction(showLoading: false),
          color: AppColors.primaryPurple,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 20),
                      if (_isLoading)
                        const SizedBox(
                          height: 300,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primaryPurple,
                            ),
                          ),
                        )
                      else if (_prediction == null)
                        _buildEmptyState()
                      else ...[
                        _buildMainScoreCard(),
                        const SizedBox(
                          height: 24,
                        ), // optional spacing before button
                        // Personalized Advice card removed
                        // Analysis Context card removed
                        const SizedBox(height: 32),
                        ElevatedButton.icon(
                          onPressed: _recalculatePrediction,
                          icon: const Icon(Icons.online_prediction_rounded),
                          label: const Text(
                            'Predict Again',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryPurple,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 55),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, topPadding + 16, 24, 32),
      decoration: const BoxDecoration(
        gradient: AppColors.mainGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'AI Forecast',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'HEALTH INSIGHTS',
            style: TextStyle(
              fontSize: 16,
              letterSpacing: 1.5,
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'My AI Prediction',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(24),
            ),
            // 🌟 FIXED: Overflows by removing mainAxisSize: min and using Expanded
            child: const Row(
              children: [
                Icon(Icons.psychology_rounded, size: 16, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Powered by LSTM Model and Random Forest Model',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
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

  Widget _buildEmptyState() {
    return Column(
      children: [
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primaryPurple.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 48,
                  color: AppColors.primaryPurple,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Awaiting AI Analysis',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.premiumDark,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Your medication adherence data is being collected. Our AI will analyze your patterns and generate personalized insights soon to help you stay on track.',
                style: TextStyle(fontSize: 15, color: Colors.grey, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed:
                    _recalculatePrediction, // 🌟 Updated to trigger calculation
                icon: const Icon(Icons.online_prediction_rounded, size: 20),
                label: const Text(
                  'Run Initial Prediction',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primaryPurple.withValues(alpha: 0.05),
                Colors.white,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.primaryPurple.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryPurple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.info_outline_rounded,
                      color: AppColors.primaryPurple,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'How it works',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.premiumDark,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'The AI model uses your past medication logs, schedules, and daily routines to predict the probability of missing your next dose. This helps you and your caregiver take preventive actions before a dose is missed.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: AppColors.textLight,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  // 🌟 NEW FUNCTION: Fetches the REAL history live from the database
  Future<List<int>> _fetchMyHistory() async {
    try {
      final logs = await PatientService().getAdherenceLogs(
        _patientId,
        limit: 10,
      );
      final history = <int>[];

      for (var log in logs) {
        // Adapt this if your log.status is mapped differently!
        final status = log.status.toString().toUpperCase();
        if (status == 'TAKEN' || status.contains('TAKEN')) {
          history.add(1);
        } else if (status == 'MISSED' || status.contains('MISSED')) {
          history.add(0);
        }
        if (history.length == 3) break;
      }

      while (history.length < 3) {
        history.insert(0, -1); // -1 is for grey/unknown dots
      }
      return history.reversed.toList();
    } catch (e) {
      return [-1, -1, -1];
    }
  }

  // 🌟 UPDATED FUNCTION: Async dialog that matches Caregiver App
  Future<void> _showExplanationDialog() async {
    // 1. Show loading spinner while fetching history

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.primaryPurple),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 200));

    // 2. Fetch the real history
    List<int> history = await _fetchMyHistory();

    // 3. Close the loading spinner
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    // 4. Extract features directly (it is already a Map!)
    final parsedFeatures = _prediction?.featuresUsed ?? {};

    final age = parsedFeatures['age']?.toString() ?? 'Unknown';
    final day = parsedFeatures['day_of_week'] ?? _getCurrentDayOfWeek();
    final time = parsedFeatures['time_of_day'] ?? _getCurrentTimeOfDay();
    
    final predictionDate = _prediction != null ? _prediction!.predictedAt : DateTime.now();
    final exactDate = DateFormat('MMM dd, yyyy').format(predictionDate);
    final exactTime = DateFormat('hh:mm a').format(predictionDate);

    // 5. Show the UI Dialog
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.psychology, color: AppColors.primaryPurple),
              SizedBox(width: 8),
              Expanded(child: Text('AI Analysis Details', softWrap: true)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Our Hybrid AI (LSTM + Random Forest) evaluated the following live data:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your Context:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow('Age', '$age years'),
                      _buildInfoRow('Date', '$exactDate ($day)'),
                      _buildInfoRow('Time', '$exactTime ($time)'),
                      const SizedBox(height: 8),
                      const Divider(),
                      const SizedBox(height: 8),
                      const Text(
                        'Recent Adherence History:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: history.asMap().entries.map((entry) {
                          final index = entry.key;
                          final value = entry.value;
                          return Column(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: value == 1
                                      ? Colors.green
                                      : (value == 0 ? Colors.red : Colors.grey),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Icon(
                                    value == 1
                                        ? Icons.check
                                        : (value == 0
                                              ? Icons.close
                                              : Icons.remove),
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                index == 0
                                    ? 'Oldest'
                                    : index == 2
                                    ? 'Most Recent'
                                    : '',
                                style: const TextStyle(fontSize: 10),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Got it',
                style: TextStyle(
                  color: AppColors.primaryPurple,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  // Helper widget required for the dialog above
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              '$label:',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 16)),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _buildMainScoreCard() {
    // ✅ FIX 1: The DB now stores Forget Probability directly! No more 100 - score.
    final chanceOfMissing = _prediction!.predictionScore;
    final riskColor = _getRiskColor();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Non-Adherence Probability',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _showExplanationDialog,
                child: const Icon(
                  Icons.info_outline,
                  size: 18,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 180,
                    height: 180,
                    child: CircularProgressIndicator(
                      value:
                          (chanceOfMissing / 100) * _animationController.value,
                      strokeWidth: 16,
                      backgroundColor: Colors.grey.shade100,
                      valueColor: AlwaysStoppedAnimation<Color>(riskColor),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Column(
                    children: [
                      Text(
                        // ✅ FIX 2: Ensure it shows 2 decimal places
                        '${(chanceOfMissing * _animationController.value).toStringAsFixed(2)}%',
                        style: const TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                          color: AppColors.premiumDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Chance of\nMissing Next Dose',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 30),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: riskColor.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(24),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_getRiskIcon(), color: riskColor),
                const SizedBox(width: 8),
                Text(
                  _getRiskText(),
                  style: TextStyle(
                    color: riskColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskInsightCard() {
    String message = '';
    switch (_prediction!.riskLevel) {
      case RiskLevel.high:
        message =
            "Our AI suggests you have a high probability of missing your upcoming dose based on recent patterns. We highly recommend activating smart reminders or asking a caregiver for support.";
        break;
      case RiskLevel.medium:
        message =
            "Your schedule shows a moderate risk of missing a dose. Try to align your medication time with daily habits like meals or brushing your teeth.";
        break;
      case RiskLevel.low:
        message =
            "Fantastic! Your adherence patterns indicate a very low chance of missing your next dose. Keep up the great routine!";
        break;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryPurple.withValues(alpha: 0.05),
            Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primaryPurple.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryPurple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.tips_and_updates_rounded,
                  color: AppColors.primaryPurple,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Personalized Advice',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.premiumDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 15,
              height: 1.6,
              color: AppColors
                  .textLight, // Might want to ensure this isn't white on white. AppColors.textDark is safer.
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFactorsCard() {
    final features = _prediction!.featuresUsed;

    // Fallback static info if backend doesn't provide detailed features
    String timeOfDay = features?['time_of_day'] ?? _getCurrentTimeOfDay();
    String dayOfWeek = features?['day_of_week'] ?? _getCurrentDayOfWeek();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Analysis Context',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.premiumDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Factors considered for this prediction:',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildFactorItem(
                  icon: Icons.calendar_today_rounded,
                  label: 'Day',
                  value: dayOfWeek,
                  color: Colors.blue,
                ),
              ),
              Expanded(
                child: _buildFactorItem(
                  icon: Icons.access_time_rounded,
                  label: 'Time',
                  value: timeOfDay,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.history_rounded, color: Colors.grey.shade600),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Recent Adherence History',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Past 3 doses behavior pattern',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Last Updated: ${DateFormat('MMM dd, yyyy - hh:mm a').format(_prediction!.predictedAt)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFactorItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppColors.premiumDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _getCurrentDayOfWeek() {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[DateTime.now().weekday - 1];
  }

  String _getCurrentTimeOfDay() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Morning';
    if (hour >= 12 && hour < 18) return 'Afternoon';
    return 'Evening';
  }
}
