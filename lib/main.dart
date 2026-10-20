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
        primarySwatch: Colors.blue,
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

  HealthRecord({
    required this.date,
    required this.time,
    required this.systolic,
    required this.diastolic,
    required this.pulse,
  });

  Map<String, dynamic> toJson() => {
        'date': date,
        'time': time,
        'systolic': systolic,
        'diastolic': diastolic,
        'pulse': pulse,
      };

  factory HealthRecord.fromJson(Map<String, dynamic> json) => HealthRecord(
        date: json['date'],
        time: json['time'],
        systolic: json['systolic'],
        diastolic: json['diastolic'],
        pulse: json['pulse'],
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

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final String? recordsData = prefs.getString('saved_health_records');
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
    final String recordsData =
        jsonEncode(_records.map((e) => e.toJson()).toList());
    await prefs.setString('saved_health_records', recordsData);
  }

  void _sortRecords() {
    _records.sort((a, b) {
      DateTime dtA = DateFormat('yyyy-MM-dd hh:mm a')
          .parse('${a.date} ${a.time}');
      DateTime dtB = DateFormat('yyyy-MM-dd hh:mm a')
          .parse('${b.date} ${b.time}');
      return dtA.compareTo(dtB);
    });
  }

  void _addRecord() {
    if (_systolicController.text.isEmpty ||
        _diastolicController.text.isEmpty ||
        _pulseController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter all values')),
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
          systolic: int.parse(_systolicController.text),
          diastolic: int.parse(_diastolicController.text),
          pulse: int.parse(_pulseController.text),
        ),
      );
      _sortRecords();
    });

    _saveRecords();

    _systolicController.clear();
    _diastolicController.clear();
    _pulseController.clear();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
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
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _generatePdfWithDateRange() async {
    if (_records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No records available to export')),
      );
      return;
    }

    final DateTimeRange? dateRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Select Date Range for PDF',
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
          const SnackBar(content: Text('No records found in selected range')),
        );
      }
      return;
    }

    final pdf = pw.Document();
    final startDateStr = DateFormat('dd-MM-yyyy').format(dateRange.start);
    final endDateStr = DateFormat('dd-MM-yyyy').format(dateRange.end);

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Health Tracker Report',
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Text('Date Range: $startDateStr to $endDateStr',
                  style: const pw.TextStyle(fontSize: 14)),
              pw.SizedBox(height: 16),
              pw.Table.fromTextArray(
                headers: ['Date', 'Time', 'Systolic', 'Diastolic', 'Pulse'],
                data: filteredRecords.map((r) => [r.date, r.time, r.systolic, r.diastolic, r.pulse]).toList(),
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
        title: const Text('Health Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _generatePdfWithDateRange,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _systolicController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Systolic'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _diastolicController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Diastolic'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _pulseController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Pulse'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.calendar_today),
                  label: Text(DateFormat('yyyy-MM-dd').format(_selectedDate)),
                  onPressed: () => _selectDate(context),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.access_time),
                  label: Text(_selectedTime.format(context)),
                  onPressed: () => _selectTime(context),
                ),
                ElevatedButton(
                  onPressed: _addRecord,
                  child: const Text('Add Record'),
                ),
              ],
            ),
            const Divider(height: 32),
            Expanded(
              child: _records.isEmpty
                  ? const Center(child: Text('No records saved yet'))
                  : ListView.builder(
                      itemCount: _records.length,
                      itemBuilder: (context, index) {
                        final record = _records[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            title: Text(
                                'BP: ${record.systolic}/${record.diastolic} mmHg'),
                            subtitle: Text(
                                'Pulse: ${record.pulse} bpm | Date: ${record.date} | Time: ${record.time}'),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
