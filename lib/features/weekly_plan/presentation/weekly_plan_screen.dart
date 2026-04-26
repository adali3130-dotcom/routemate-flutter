import 'package:flutter/material.dart';

class WeeklyPlanScreen extends StatelessWidget {
  const WeeklyPlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Plan')),
      body: const Center(
        child: Text('Coming soon', style: TextStyle(fontSize: 18)),
      ),
    );
  }
}
