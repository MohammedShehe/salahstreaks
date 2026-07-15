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
  // For Salah - track individual prayers
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
  
  // Quran fields - now with mode selection
  String _quranLogMode = 'Verses'; // 'Verses' or 'Pages'
  String _selectedSurah = 'Al-Fatihah';
  int _verseStart = 1;
  int _verseEnd = 1;
  int _pageStart = 1;
  int _pageEnd = 1;
  
  String _sadaqatType = 'Money';
  final TextEditingController _noteController = TextEditingController();
  double _sadaqatAmount = 10.0;

  bool _isAlreadyLogged = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentState();
  }

  void _loadCurrentState() {
    final provider = Provider.of<AppProvider>(context, listen: false);
    
    if (widget.type == 'Salah') {
      final prayedSet = provider.getTodayPrayedSalah();
      
      setState(() {
        _salahTicked['Fajr'] = prayedSet.contains('Fajr');
        _salahTicked['Dhuhr'] = prayedSet.contains('Dhuhr');
        _salahTicked['Asr'] = prayedSet.contains('Asr');
        _salahTicked['Maghrib'] = prayedSet.contains('Maghrib');
        _salahTicked['Isha'] = prayedSet.contains('Isha');
        _isAlreadyLogged = prayedSet.length >= 5;
      });
    } else {
      setState(() {
        _isAlreadyLogged = provider.isLoggedToday(widget.type);
      });
    }
  }

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
              Row(
                children: [
                  Text(
                    widget.type,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  if (widget.type == 'Salah' && _isAlreadyLogged) ...[
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green[700],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 14,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'All Prayed ✅',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (widget.type != 'Salah' && _isAlreadyLogged) ...[
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green[700],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 14,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Logged Today ✅',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
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
            onPressed: _isAlreadyLogged ? null : _submitLog,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isAlreadyLogged ? Colors.grey[700] : Colors.green[700],
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

  // ============ SALAH FIELDS - UPDATED FOR INDEPENDENT TOGGLING ============
  List<Widget> _buildSalahFields() {
    final prayerOrder = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    final prayerTimes = ['5:00 AM', '1:00 PM', '4:30 PM', '6:45 PM', '8:00 PM'];
    final prayerIcons = [
      Icons.nights_stay,
      Icons.wb_sunny,
      Icons.brightness_5,
      Icons.wb_twilight,
      Icons.bedtime,
    ];

    return [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green[900]!.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green[700]!.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Today\'s Prayers',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green[800],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_salahTicked.values.where((v) => v).length}/5',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...List.generate(5, (index) {
              final prayer = prayerOrder[index];
              final isLogged = _salahTicked[prayer]!;
              
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isLogged 
                      ? Colors.green[800]!.withOpacity(0.3)
                      : Colors.grey[800]!.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isLogged 
                        ? Colors.green[600]!.withOpacity(0.5)
                        : Colors.grey[600]!.withOpacity(0.3),
                  ),
                ),
                child: ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isLogged 
                          ? Colors.green[700] 
                          : Colors.grey[700],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      prayerIcons[index],
                      color: isLogged ? Colors.white : Colors.grey[400],
                      size: 20,
                    ),
                  ),
                  title: Text(
                    prayer,
                    style: TextStyle(
                      color: isLogged ? Colors.white : Colors.grey[300],
                      fontWeight: isLogged ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    prayerTimes[index],
                    style: TextStyle(
                      color: isLogged ? Colors.green[300] : Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                  trailing: isLogged
                      ? GestureDetector(
                          onTap: () => _toggleSalah(prayer),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red[700],
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        )
                      : ElevatedButton(
                          onPressed: () => _toggleSalah(prayer),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[700],
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Mark',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                  onTap: () => _toggleSalah(prayer),
                ),
              );
            }),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[800]!.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.grey[400],
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tap on any prayer to mark/unmark it independently',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ].animate(interval: 100.ms);
  }

  void _toggleSalah(String prayerName) async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    
    // Toggle the prayer (mark/unmark)
    await provider.toggleSalah(prayerName);
    
    // Update local state
    final prayedSet = provider.getTodayPrayedSalah();
    setState(() {
      _salahTicked['Fajr'] = prayedSet.contains('Fajr');
      _salahTicked['Dhuhr'] = prayedSet.contains('Dhuhr');
      _salahTicked['Asr'] = prayedSet.contains('Asr');
      _salahTicked['Maghrib'] = prayedSet.contains('Maghrib');
      _salahTicked['Isha'] = prayedSet.contains('Isha');
      _isAlreadyLogged = prayedSet.length >= 5;
    });
    
    final isNowLogged = prayedSet.contains(prayerName);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isNowLogged ? '✅ $prayerName marked as prayed!' : '❌ $prayerName unmarked',
        ),
        backgroundColor: isNowLogged ? Colors.green : Colors.orange,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
    
    // Close if all 5 prayers are done
    if (prayedSet.length >= 5) {
      Future.delayed(const Duration(seconds: 1), () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 All 5 prayers completed today! Masha\'Allah!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
      });
    }
  }

  // ============ SAWM FIELDS ============
  List<Widget> _buildSawmFields() {
    if (_isAlreadyLogged) {
      return [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green[900]!.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green[700]!.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 48),
              const SizedBox(height: 8),
              Text(
                '✅ ${widget.type} logged today',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              Text(
                'Come back tomorrow to log again',
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              ),
            ],
          ),
        ),
      ];
    }

    return [
      const Text('Select Fasting Type:', style: TextStyle(color: Colors.white, fontSize: 16)),
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

  // ============ QIYYAM FIELDS ============
  List<Widget> _buildQiyyamFields() {
    if (_isAlreadyLogged) {
      return [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green[900]!.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green[700]!.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 48),
              const SizedBox(height: 8),
              Text(
                '✅ ${widget.type} logged today',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              Text(
                'Come back tomorrow to log again',
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              ),
            ],
          ),
        ),
      ];
    }

    return [
      const Text('Tahajjud Rak\'ah:', style: TextStyle(color: Colors.white, fontSize: 16)),
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
      const Text('Witr Rak\'ah:', style: TextStyle(color: Colors.white, fontSize: 16)),
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

  // ============ QURAN FIELDS ============
  List<Widget> _buildQuranFields() {
    if (_isAlreadyLogged) {
      return [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green[900]!.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green[700]!.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 48),
              const SizedBox(height: 8),
              Text(
                '✅ ${widget.type} logged today',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              Text(
                'Come back tomorrow to log again',
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              ),
            ],
          ),
        ),
      ];
    }

    final versesCount = _verseEnd - _verseStart + 1;
    final pagesCount = _pageEnd - _pageStart + 1;
    final isVersesMode = _quranLogMode == 'Verses';

    return [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green[900]!.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green[700]!.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            const Text(
              'Log by:',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('📖 Verses'),
                    selected: _quranLogMode == 'Verses',
                    onSelected: (selected) {
                      if (selected) setState(() => _quranLogMode = 'Verses');
                    },
                    selectedColor: Colors.green[700],
                    backgroundColor: Colors.grey[800],
                    labelStyle: TextStyle(
                      color: _quranLogMode == 'Verses' ? Colors.white : Colors.grey[400],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('📄 Pages'),
                    selected: _quranLogMode == 'Pages',
                    onSelected: (selected) {
                      if (selected) setState(() => _quranLogMode = 'Pages');
                    },
                    selectedColor: Colors.green[700],
                    backgroundColor: Colors.grey[800],
                    labelStyle: TextStyle(
                      color: _quranLogMode == 'Pages' ? Colors.white : Colors.grey[400],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),

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

      if (_quranLogMode == 'Verses') ...[
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
          'Verses recited: $versesCount',
          style: TextStyle(
            color: versesCount > 0 ? Colors.green[300] : Colors.red[300],
            fontWeight: FontWeight.bold,
          ),
        ),
        if (versesCount == 0)
          Text(
            '⚠️ Please enter valid verse range',
            style: TextStyle(color: Colors.red[300], fontSize: 12),
          ),
      ],

      if (_quranLogMode == 'Pages') ...[
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  labelText: 'Start Page',
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
                  setState(() => _pageStart = int.tryParse(value) ?? 1);
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  labelText: 'End Page',
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
                  setState(() => _pageEnd = int.tryParse(value) ?? 1);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Pages recited: $pagesCount',
          style: TextStyle(
            color: pagesCount > 0 ? Colors.green[300] : Colors.red[300],
            fontWeight: FontWeight.bold,
          ),
        ),
        if (pagesCount == 0)
          Text(
            '⚠️ Please enter valid page range',
            style: TextStyle(color: Colors.red[300], fontSize: 12),
          ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green[900]!.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '💡 1 Juz = 20 pages',
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
        ),
      ],
    ];
  }

  // ============ SADAQAT FIELDS ============
  List<Widget> _buildSadaqatFields() {
    if (_isAlreadyLogged) {
      return [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green[900]!.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green[700]!.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 48),
              const SizedBox(height: 8),
              Text(
                '✅ ${widget.type} logged today',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              Text(
                'Come back tomorrow to log again',
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              ),
            ],
          ),
        ),
      ];
    }

    return [
      const Text('Type of Sadaqah:', style: TextStyle(color: Colors.white, fontSize: 16)),
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
      if (_sadaqatAmount <= 0)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            '⚠️ Please enter a valid amount',
            style: TextStyle(color: Colors.red[300], fontSize: 12),
          ),
        ),
    ];
  }

  String _getSubmitLabel() {
    if (_isAlreadyLogged) {
      return '✅ Already Logged Today';
    }
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
    
    // For Salah, we handle it differently
    if (widget.type == 'Salah') {
      int count = _salahTicked.values.where((v) => v).length;
      if (count == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Please mark at least one prayer'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      
      // Check which prayers are ticked
      final prayed = <String>[];
      if (_salahTicked['Fajr']!) prayed.add('Fajr');
      if (_salahTicked['Dhuhr']!) prayed.add('Dhuhr');
      if (_salahTicked['Asr']!) prayed.add('Asr');
      if (_salahTicked['Maghrib']!) prayed.add('Maghrib');
      if (_salahTicked['Isha']!) prayed.add('Isha');
      
      final note = 'prayed:${prayed.join(',')}';
      
      final log = IbadatLog(
        type: 'Salah',
        date: now,
        salahCount: count,
        sawmType: '',
        rakahCount: 0,
        versesCount: 0,
        surahName: '',
        sadaqatType: '',
        note: note,
        amount: 0.0,
      );
      
      provider.logIbadat(log);
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${count}/5 Salah logged!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    // For non-Salah types
    if (provider.isLoggedToday(widget.type)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Already logged today!'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
      return;
    }
    
    int versesCount = 0;
    if (widget.type == 'Quran') {
      if (_quranLogMode == 'Verses') {
        versesCount = _verseEnd - _verseStart + 1;
        if (versesCount <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Please enter valid verse range (start < end)'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
      } else {
        final pagesCount = _pageEnd - _pageStart + 1;
        if (pagesCount <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Please enter valid page range (start < end)'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
        versesCount = pagesCount * 20;
      }
    }
    
    if (widget.type == 'Sadaqat' && _sadaqatAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Please enter a valid amount'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    final log = IbadatLog(
      type: widget.type,
      date: now,
      salahCount: 0,
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