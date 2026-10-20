import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HealthTrackerApp());
}

class HealthTrackerApp extends StatelessWidget {
  const HealthTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Health Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const HealthTrackerHomePage(),
    );
  }
}

class HealthRecord {
  final String date;
  final String time;
  final int systolic;
  final int diastolic;
  final int pulse;
  final double sugar;
  final String stomaOutput;
  final String dietNotes;

  HealthRecord({
    required this.date,
    required this.time,
    required this.systolic,
    required this.diastolic,
    required this.pulse,
    required this.sugar,
    required this.stomaOutput,
    required this.dietNotes,
  });

  Map<String, dynamic> toJson() => {
        'date': date,
        'time': time,
        'systolic': systolic,
        'diastolic': diastolic,
        'pulse': pulse,
        'sugar': sugar,
        'stomaOutput': stomaOutput,
        'dietNotes': dietNotes,
      };

  factory HealthRecord.fromJson(Map<String, dynamic> json) => HealthRecord(
        date: json['date'] ?? '',
        time: json['time'] ?? '',
        systolic: json['systolic'] ?? 0,
        diastolic: json['diastolic'] ?? 0,
        pulse: json['pulse'] ?? 0,
        sugar: (json['sugar'] ?? 0.0).toDouble(),
        stomaOutput: json['stomaOutput'] ?? '',
        dietNotes: json['dietNotes'] ?? '',
      );
}

class HealthTrackerHomePage extends StatefulWidget {
  const HealthTrackerHomePage({super.key});

  @override
  State<HealthTrackerHomePage> createState() => _HealthTrackerHomePageState();
}

class _HealthTrackerHomePageState extends State<HealthTrackerHomePage> {
  final List<HealthRecord> _records = [];
  final _systolicController = TextEditingController();
  final _diastolicController = TextEditingController();
  final _pulseController = TextEditingController();
  final _sugarController = TextEditingController();
  final _stomaController = TextEditingController();
  final _dietController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final String? recordsData = prefs.getString('saved_health_records_v4');
    if (recordsData != null) {
      final List<dynamic> jsonList = jsonDecode(recordsData);
      setState(() {
        _records.clear();
        _records.addAll(jsonList.map((item) => HealthRecord.fromJson(item)));
        _sortRecords();
      });
    }
  }

  Future<void> _saveRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final String recordsData = jsonEncode(_records.map((e) => e.toJson()).toList());
    await prefs.setString('saved_health_records_v4', recordsData);
  }

  void _sortRecords() {
    _records.sort((a, b) {
      DateTime dtA = DateFormat('yyyy-MM-dd hh:mm a').parse('${a.date} ${a.time}');
      DateTime dtB = DateFormat('yyyy-MM-dd hh:mm a').parse('${b.date} ${b.time}');
      return dtA.compareTo(dtB);
    });
  }

  void _addRecord() {
    if (_systolicController.text.isEmpty &&
        _sugarController.text.isEmpty &&
        _stomaController.text.isEmpty &&
        _dietController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kamm se kamm ek detail darj karein!')),
      );
      return;
    }

    final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, _selectedTime.hour, _selectedTime.minute);
    final formattedTime = DateFormat('hh:mm a').format(dt);

    setState(() {
      _records.add(
        HealthRecord(
          date: formattedDate,
          time: formattedTime,
          systolic: int.tryParse(_systolicController.text) ?? 0,
          diastolic: int.tryParse(_diastolicController.text) ?? 0,
          pulse: int.tryParse(_pulseController.text) ?? 0,
          sugar: double.tryParse(_sugarController.text) ?? 0.0,
          stomaOutput: _stomaController.text,
          dietNotes: _dietController.text,
        ),
      );
      _sortRecords();
    });

    _saveRecords();

    _systolicController.clear();
    _diastolicController.clear();
    _pulseController.clear();
    _sugarController.clear();
    _stomaController.clear();
    _dietController.clear();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _generatePdfWithDateRange() async {
    if (_records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Koi record save nahi hai!')),
      );
      return;
    }

    final DateTimeRange? dateRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Select Date Range for PDF Report',
    );

    if (dateRange == null) return;

    final filteredRecords = _records.where((record) {
      DateTime recordDate = DateFormat('yyyy-MM-dd').parse(record.date);
      DateTime start = DateTime(dateRange.start.year, dateRange.start.month, dateRange.start.day);
      DateTime end = DateTime(dateRange.end.year, dateRange.end.month, dateRange.end.day, 23, 59, 59);
      return recordDate.isAfter(start.subtract(const Duration(seconds: 1))) &&
          recordDate.isBefore(end);
    }).toList();

    if (filteredRecords.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selected dates ke darmiyan koi record nahi mila!')),
        );
      }
      return;
    }

    final pdf = pw.Document();
    final startDateStr = DateFormat('dd-MM-yyyy').format(dateRange.start);
    final endDateStr = DateFormat('dd-MM-yyyy').format(dateRange.end);

    pdf.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Comprehensive Health Report', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Range: $startDateStr to $endDateStr', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Table.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.teal),
                headers: ['Date & Time', 'BP (mmHg)', 'Pulse', 'Sugar', 'Stoma Output', 'Diet / Notes'],
                data: filteredRecords.map((r) => [
                      '${r.date}\n${r.time}',
                      r.systolic > 0 ? '${r.systolic}/${r.diastolic}' : '-',
                      r.pulse > 0 ? '${r.pulse} bpm' : '-',
                      r.sugar > 0 ? '${r.sugar} mg/dL' : '-',
                      r.stomaOutput.isNotEmpty ? r.stomaOutput : '-',
                      r.dietNotes.isNotEmpty ? r.dietNotes : '-'
                    ]).toList(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Professional Health Tracker'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'PDF Report Generator',
            onPressed: _generatePdfWithDateRange,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Enter Patient Health Data', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _systolicController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'BP Systolic', border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _diastolicController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'BP Diastolic', border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _pulseController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Pulse (bpm)', border: OutlineInputBorder()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _sugarController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Sugar (mg/dL)', border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _stomaController,
                            decoration: const InputDecoration(labelText: 'Stoma Output (ml/type)', border: OutlineInputBorder()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _dietController,
                      decoration: const InputDecoration(labelText: 'Diet / Food Consumed Details', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: Text(DateFormat('yyyy-MM-dd').format(_selectedDate)),
                            onPressed: () => _selectDate(context),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.access_time, size: 16),
                            label: Text(_selectedTime.format(context)),
                            onPressed: () => _selectTime(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: _addRecord,
                        icon: const Icon(Icons.save),
                        label: const Text('Save Record', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Saved Patient Records:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _records.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Center(child: Text('Abhi tak koi health record save nahi hai.')),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _records.length,
                    itemBuilder: (context, index) {
                      final record = _records[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          title: Text(
                            'Date: ${record.date} | Time: ${record.time}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.teal),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              '• BP: ${record.systolic > 0 ? "${record.systolic}/${record.diastolic} mmHg" : "N/A"}\n'
                              '• Pulse: ${record.pulse > 0 ? "${record.pulse} bpm" : "N/A"}\n'
                              '• Sugar: ${record.sugar > 0 ? "${record.sugar} mg/dL" : "N/A"}\n'
                              '• Stoma Output: ${record.stomaOutput.isNotEmpty ? record.stomaOutput : "N/A"}\n'
                              '• Diet/Khana: ${record.dietNotes.isNotEmpty ? record.dietNotes : "N/A"}',
                              style: const TextStyle(height: 1.3),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
