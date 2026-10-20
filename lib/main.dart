import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

void main() {
  runApp(const HealthTrackerApp());
}

class HealthTrackerApp extends StatelessWidget {
  const HealthTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Health Tracker',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        useMaterial3: true,
      ),
      home: const HealthHomeScreen(),
    );
  }
}

class HealthEntry {
  final DateTime dateTime;
  final String bp;
  final String sugar;
  final String stomaOutput;
  final String foodEaten;
  final String mealTime;

  HealthEntry({
    required this.dateTime,
    required this.bp,
    required this.sugar,
    required this.stomaOutput,
    required this.foodEaten,
    required this.mealTime,
  });
}

class HealthHomeScreen extends StatefulWidget {
  const HealthHomeScreen({super.key});

  @override
  State<HealthHomeScreen> createState() => _HealthHomeScreenState();
}

class _HealthHomeScreenState extends State<HealthHomeScreen> {
  final List<HealthEntry> _entries = [];

  final _bpController = TextEditingController();
  final _sugarController = TextEditingController();
  final _stomaController = TextEditingController();
  final _foodController = TextEditingController();
  final _mealTimeController = TextEditingController();

  DateTime _selectedDate = DateTime.now();

  void _addEntry() {
    if (_bpController.text.isEmpty &&
        _sugarController.text.isEmpty &&
        _stomaController.text.isEmpty &&
        _foodController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kam az kam ek field bharein!')),
      );
      return;
    }

    setState(() {
      _entries.insert(
        0,
        HealthEntry(
          dateTime: _selectedDate,
          bp: _bpController.text,
          sugar: _sugarController.text,
          stomaOutput: _stomaController.text,
          foodEaten: _foodController.text,
          mealTime: _mealTimeController.text,
        ),
      );
    });

    _bpController.clear();
    _sugarController.clear();
    _stomaController.clear();
    _foodController.clear();
    _mealTimeController.clear();

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Data save ho gaya!')),
    );
  }

  Future<void> _exportToPDF() async {
    if (_entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF banane ke liye koi data nahi hai!')),
      );
      return;
    }

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            cross: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Text('Health Log Report',
                    style: pw.TextStyle(
                        fontSize: 24, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 10),
              pw.Table.fromTextArray(
                headers: [
                  'Date/Time',
                  'BP (mmHg)',
                  'Sugar (mg/dL)',
                  'Stoma Output',
                  'Diet / Food',
                  'Meal Time'
                ],
                data: _entries.map((entry) {
                  return [
                    DateFormat('yyyy-MM-dd HH:mm').format(entry.dateTime),
                    entry.bp,
                    entry.sugar,
                    entry.stomaOutput,
                    entry.foodEaten,
                    entry.mealTime,
                  ];
                }).toList(),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  void _showAddDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          top: 16,
          left: 16,
          right: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Nayi Entry Shamil Karein',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _bpController,
                decoration: const InputDecoration(
                    labelText: 'Blood Pressure (e.g. 120/80)'),
              ),
              TextField(
                controller: _sugarController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Sugar Level (e.g. 110)'),
              ),
              TextField(
                controller: _stomaController,
                decoration: const InputDecoration(
                    labelText: 'Stoma Output (Quantity / Note)'),
              ),
              TextField(
                controller: _foodController,
                decoration:
                    const InputDecoration(labelText: 'Kya Khaya (Diet)'),
              ),
              TextField(
                controller: _mealTimeController,
                decoration: const InputDecoration(
                    labelText: 'Khane Ka Time (e.g. 2:30 PM)'),
              ),
              const SizedBox(height: 15),
              ElevatedButton(
                onPressed: _addEntry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Save Karein'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health & Stoma Tracker'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _exportToPDF,
            tooltip: 'PDF Export Karein',
          ),
        ],
      ),
      body: _entries.isEmpty
          ? const Center(
              child: Text(
                'Abhi tak koi data entry nahi hui.\nNeeche "+" button par click kar ke add karein.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: _entries.length,
              itemBuilder: (ctx, index) {
                final item = _entries[index];
                return Card(
                  margin:
                      const EdgeInsets.horizontal(10, vertical: 6),
                  child: ListTile(
                    title: Text(
                      DateFormat('EEE, dd MMM yyyy - hh:mm a')
                          .format(item.dateTime),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.teal),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Column(
                        cross: CrossAxisAlignment.start,
                        children: [
                          if (item.bp.isNotEmpty) Text('• BP: ${item.bp}'),
                          if (item.sugar.isNotEmpty)
                            Text('• Sugar: ${item.sugar} mg/dL'),
                          if (item.stomaOutput.isNotEmpty)
                            Text('• Stoma Output: ${item.stomaOutput}'),
                          if (item.foodEaten.isNotEmpty)
                            Text('• Diet: ${item.foodEaten} (${item.mealTime})'),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
