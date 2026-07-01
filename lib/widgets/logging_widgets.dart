import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:salahstreaks/providers/app_provider.dart';
import 'package:salahstreaks/models/ibadat_model.dart';
import 'package:salahstreaks/utils/constants.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';

class LoggingWidget extends StatefulWidget {
  final String type;

  const LoggingWidget({super.key, required this.type});

  @override
  State<LoggingWidget> createState() => _LoggingWidgetState();
}

class _LoggingWidgetState extends State<LoggingWidget> {
  final Map<String, bool> _salahTicked = {
    'Fajr': false,
    'Dhuhr': false,
    'Asr': false,
    'Maghrib': false,
    'Isha': false,
  };
  
  String _sawmType = 'Fardh';
  int _tahajjudRakah = 2;
  int _witrRakah = 1;
  String _selectedSurah = 'Al-Fatihah';
  int _verseStart = 1;
  int _verseEnd = 1;
  String _sadaqatType = 'Money';
  final TextEditingController _noteController = TextEditingController();
  double _sadaqatAmount = 10.0;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateFormat = DateFormat('d MMMM yyyy');

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.type,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                dateFormat.format(now),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[400],
                ),
              ),
            ],
          ),
          const Divider(color: Colors.green, height: 30),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: _buildLoggingFields(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _submitLog,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              _getSubmitLabel(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  List<Widget> _buildLoggingFields() {
    switch (widget.type) {
      case 'Salah':
        return _buildSalahFields();
      case 'Sawm':
        return _buildSawmFields();
      case 'Qiyyam':
        return _buildQiyyamFields();
      case 'Quran':
        return _buildQuranFields();
      case 'Sadaqat':
        return _buildSadaqatFields();
      default:
        return [];
    }
  }

  List<Widget> _buildSalahFields() {
    return [
      ..._salahTicked.keys.map((prayer) {
        return Card(
          color: Colors.green[900]!.withOpacity(0.3),
          margin: const EdgeInsets.only(bottom: 8),
          child: CheckboxListTile(
            value: _salahTicked[prayer],
            onChanged: (value) {
              setState(() {
                _salahTicked[prayer] = value ?? false;
              });
            },
            title: Text(
              prayer,
              style: const TextStyle(color: Colors.white),
            ),
            activeColor: Colors.green,
            checkboxShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    ].animate(interval: 100.ms);
  }

  List<Widget> _buildSawmFields() {
    return [
      const Text(
        'Select Fasting Type:',
        style: TextStyle(color: Colors.white, fontSize: 16),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: RadioListTile<String>(
              title: const Text('Fardh (Ramadan)', style: TextStyle(color: Colors.white)),
              value: 'Fardh',
              groupValue: _sawmType,
              onChanged: (value) => setState(() => _sawmType = value!),
              activeColor: Colors.green,
            ),
          ),
          Expanded(
            child: RadioListTile<String>(
              title: const Text('Sunnah', style: TextStyle(color: Colors.white)),
              value: 'Sunnah',
              groupValue: _sawmType,
              onChanged: (value) => setState(() => _sawmType = value!),
              activeColor: Colors.green,
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildQiyyamFields() {
    return [
      const Text(
        'Tahajjud Rak\'ah:',
        style: TextStyle(color: Colors.white, fontSize: 16),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        children: [2, 4, 6, 8, 10].map((rakah) {
          return ChoiceChip(
            label: Text('$rakah'),
            selected: _tahajjudRakah == rakah,
            onSelected: (selected) {
              if (selected) setState(() => _tahajjudRakah = rakah);
            },
            selectedColor: Colors.green[700],
            backgroundColor: Colors.grey[800],
            labelStyle: TextStyle(
              color: _tahajjudRakah == rakah ? Colors.white : Colors.grey[400],
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: 20),
      const Text(
        'Witr Rak\'ah:',
        style: TextStyle(color: Colors.white, fontSize: 16),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        children: [1, 3, 5].map((rakah) {
          return ChoiceChip(
            label: Text('$rakah'),
            selected: _witrRakah == rakah,
            onSelected: (selected) {
              if (selected) setState(() => _witrRakah = rakah);
            },
            selectedColor: Colors.green[700],
            backgroundColor: Colors.grey[800],
            labelStyle: TextStyle(
              color: _witrRakah == rakah ? Colors.white : Colors.grey[400],
            ),
          );
        }).toList(),
      ),
    ];
  }

  List<Widget> _buildQuranFields() {
    return [
      DropdownButtonFormField<String>(
        value: _selectedSurah,
        decoration: InputDecoration(
          labelText: 'Select Surah',
          labelStyle: const TextStyle(color: Colors.white),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.green[700]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.green[700]!.withOpacity(0.3)),
          ),
        ),
        dropdownColor: const Color(0xFF1A1F2E),
        style: const TextStyle(color: Colors.white),
        items: quranSurahList.map((surah) {
          return DropdownMenuItem(
            value: surah,
            child: Text(surah, style: const TextStyle(color: Colors.white)),
          );
        }).toList(),
        onChanged: (value) => setState(() => _selectedSurah = value!),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Start Verse',
                labelStyle: const TextStyle(color: Colors.white),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.green[700]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.green[700]!.withOpacity(0.3)),
                ),
              ),
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                setState(() => _verseStart = int.tryParse(value) ?? 1);
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                labelText: 'End Verse',
                labelStyle: const TextStyle(color: Colors.white),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.green[700]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.green[700]!.withOpacity(0.3)),
                ),
              ),
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                setState(() => _verseEnd = int.tryParse(value) ?? 1);
              },
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        'Verses recited: ${_verseEnd - _verseStart + 1}',
        style: TextStyle(color: Colors.green[300], fontWeight: FontWeight.bold),
      ),
    ];
  }

  List<Widget> _buildSadaqatFields() {
    return [
      const Text(
        'Type of Sadaqah:',
        style: TextStyle(color: Colors.white, fontSize: 16),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        children: ['Money', 'Food', 'Other'].map((type) {
          return ChoiceChip(
            label: Text(type),
            selected: _sadaqatType == type,
            onSelected: (selected) {
              if (selected) setState(() => _sadaqatType = type);
            },
            selectedColor: Colors.green[700],
            backgroundColor: Colors.grey[800],
            labelStyle: TextStyle(
              color: _sadaqatType == type ? Colors.white : Colors.grey[400],
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _noteController,
        decoration: InputDecoration(
          labelText: 'Note (Optional)',
          labelStyle: const TextStyle(color: Colors.white),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.green[700]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.green[700]!.withOpacity(0.3)),
          ),
        ),
        style: const TextStyle(color: Colors.white),
        maxLines: 3,
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Amount (${_sadaqatType == 'Money' ? '💰' : '📦'})',
                labelStyle: const TextStyle(color: Colors.white),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.green[700]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.green[700]!.withOpacity(0.3)),
                ),
              ),
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                setState(() => _sadaqatAmount = double.tryParse(value) ?? 0);
              },
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.green[800]!.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green[700]!.withOpacity(0.3)),
            ),
            child: Text(
              _sadaqatType == 'Money' ? '💰' : '📦',
              style: const TextStyle(fontSize: 20),
            ),
          ),
        ],
      ),
    ];
  }

  String _getSubmitLabel() {
    switch (widget.type) {
      case 'Salah':
        return 'Prayed';
      case 'Sawm':
        return 'Fasting';
      case 'Qiyyam':
        return 'Prayed';
      case 'Quran':
        return 'Recited';
      case 'Sadaqat':
        return 'Sadaqah Given';
      default:
        return 'Submit';
    }
  }

  void _submitLog() {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final now = DateTime.now();
    
    int salahCount = _salahTicked.values.where((v) => v).length;
    int versesCount = _verseEnd - _verseStart + 1;
    
    final log = IbadatLog(
      type: widget.type,
      date: now,
      salahCount: widget.type == 'Salah' ? salahCount : 0,
      sawmType: widget.type == 'Sawm' ? _sawmType : '',
      rakahCount: widget.type == 'Qiyyam' ? _tahajjudRakah + _witrRakah : 0,
      versesCount: widget.type == 'Quran' ? versesCount : 0,
      surahName: widget.type == 'Quran' ? _selectedSurah : '',
      sadaqatType: widget.type == 'Sadaqat' ? _sadaqatType : '',
      note: _noteController.text,
      amount: widget.type == 'Sadaqat' ? _sadaqatAmount : 0,
    );
    
    provider.logIbadat(log);
    Navigator.pop(context);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ ${widget.type} logged successfully!'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}