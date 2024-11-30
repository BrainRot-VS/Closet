import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';

class WardrobeApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Closet',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final List<Widget> _pages = [
    CalendarRecommendationPage(),
    WardrobeManagementPage()
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: [
          const BottomNavigationBarItem(
              icon: const Icon(Icons.calendar_today), label: 'Calendar'),
          const BottomNavigationBarItem(
              icon: const Icon(Icons.storage), label: 'Wardrobe')
        ],
      ),
    );
  }
}

class CalendarRecommendationPage extends StatefulWidget {
  @override
  _CalendarRecommendationPageState createState() =>
      _CalendarRecommendationPageState();
}

class _CalendarRecommendationPageState
    extends State<CalendarRecommendationPage> {
  CalendarFormat _calendarFormat = CalendarFormat.week;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // Store recommendations for a week
  Map<DateTime, Map<String, dynamic>> _weekRecommendations = {};

  final Dio _dio =
      Dio(BaseOptions(baseUrl: 'https://sr87qdzr-8000.inc1.devtunnels.ms/'));
  final List<String> _occasions = [
    'casual',
    'formal',
    'business',
    'workout',
    'date'
  ];

  @override
  void initState() {
    super.initState();
    _fetchWeekRecommendations();
  }

  Future<void> _fetchWeekRecommendations() async {
    // Clear previous recommendations
    _weekRecommendations.clear();

    // Fetch recommendations for 7 days starting from today
    for (int i = 0; i < 7; i++) {
      DateTime currentDay = _focusedDay.add(Duration(days: i));
      String occasion = _selectOccasionForDay(currentDay);

      try {
        final response = await _dio.get('/recommend',
            queryParameters: {'occasion': occasion, 'location': 'New York'});

        setState(() {
          _weekRecommendations[currentDay] = {
            'recommendation': response.data,
            'occasion': occasion
          };
        });
      } catch (e) {
        print('Failed to fetch recommendation for ${currentDay}: $e');
      }
    }
  }

  String _selectOccasionForDay(DateTime day) {
    // Simple logic to assign occasions
    switch (day.weekday) {
      case DateTime.monday:
        return 'business';
      case DateTime.tuesday:
        return 'casual';
      case DateTime.wednesday:
        return 'workout';
      case DateTime.thursday:
        return 'date';
      case DateTime.friday:
        return 'formal';
      case DateTime.saturday:
        return 'casual';
      case DateTime.sunday:
        return 'casual';
      default:
        return 'casual';
    }
  }

  Color _getColorForOccasion(String occasion) {
    switch (occasion) {
      case 'business':
        return Colors.grey.shade700;
      case 'formal':
        return Colors.purple.shade700;
      case 'workout':
        return Colors.green.shade700;
      case 'date':
        return Colors.pink.shade700;
      case 'casual':
      default:
        return Colors.blue.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Closet')),
      body: RefreshIndicator(
        onRefresh: _fetchWeekRecommendations,
        child: ListView(
          children: [
            TableCalendar(
              firstDay: DateTime.utc(2010, 10, 16),
              lastDay: DateTime.utc(2030, 3, 14),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: Colors.blue.shade200,
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: Colors.blue.shade400,
                  shape: BoxShape.circle,
                ),
              ),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              onFormatChanged: (format) {
                setState(() {
                  _calendarFormat = format;
                });
              },
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, day, focusedDay) {
                  // Check if we have a recommendation for this day
                  final recommendation = _weekRecommendations[day];
                  if (recommendation != null) {
                    return Container(
                      margin: const EdgeInsets.all(4.0),
                      decoration: BoxDecoration(
                        color: _getColorForOccasion(recommendation['occasion']),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${day.day}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    );
                  }
                  return null;
                },
              ),
            ),

            // Display selected day's recommendation
            if (_selectedDay != null &&
                _weekRecommendations[_selectedDay] != null)
              _buildRecommendationWidget(_weekRecommendations[_selectedDay]!),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationWidget(Map<String, dynamic> dayRecommendation) {
    final recommendation = dayRecommendation['recommendation'];
    final occasion = dayRecommendation['occasion'];

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Occasion: ${occasion.toString().toUpperCase()}',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _getColorForOccasion(occasion)),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text('Top: ${recommendation['top']['category']}'),
                      recommendation['top']['image'] != null
                          ? Image.memory(
                              base64Decode(recommendation['top']['image']),
                              height: 150,
                              width: 150,
                              fit: BoxFit.cover,
                            )
                          : Container(),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text('Bottom: ${recommendation['bottom']['category']}'),
                      recommendation['bottom']['image'] != null
                          ? Image.memory(
                              base64Decode(recommendation['bottom']['image']),
                              height: 150,
                              width: 150,
                              fit: BoxFit.cover,
                            )
                          : Container(),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Weather: ${recommendation['weather']}'),
          ],
        ),
      ),
    );
  }
}

class WardrobeManagementPage extends StatefulWidget {
  @override
  _WardrobeManagementPageState createState() => _WardrobeManagementPageState();
}

class _WardrobeManagementPageState extends State<WardrobeManagementPage> {
  final Dio _dio =
      Dio(BaseOptions(baseUrl: 'https://sr87qdzr-8000.inc1.devtunnels.ms/'));
  final ImagePicker _picker = ImagePicker();
  final List<String> _categories = [
    'T-Shirt',
    'Shirt',
    'Pants',
    'Jeans',
    'Shorts'
  ];
  List<dynamic> _wardrobeItems = [];

  @override
  void initState() {
    super.initState();
    _loadWardrobe();
  }

  Future<void> _loadWardrobe() async {
    try {
      final response = await _dio.get('/wardrobe');
      setState(() {
        _wardrobeItems = response.data['items'];
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: const Text('Failed to load wardrobe')));
    }
  }

  Future<void> _addItem() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      String? category = await _showCategoryDialog();
      if (category != null) {
        try {
          FormData formData = FormData.fromMap({
            'file': await MultipartFile.fromFile(image.path),
            'category': category,
          });

          await _dio.post('/add_item', data: formData);
          _loadWardrobe();
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: const Text('Failed to add item')));
        }
      }
    }
  }

  Future<String?> _showCategoryDialog() async {
    return await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Category'),
        children: _categories
            .map((category) => SimpleDialogOption(
                  child: Text(category),
                  onPressed: () => Navigator.pop(context, category),
                ))
            .toList(),
      ),
    );
  }

  Future<void> _removeItem(int index) async {
    try {
      await _dio.delete('/remove_item/$index');
      _loadWardrobe();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: const Text('Failed to remove item')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wardrobe Management')),
      body: RefreshIndicator(
        onRefresh: _loadWardrobe,
        child: ListView.builder(
          itemCount: _wardrobeItems.length,
          itemBuilder: (context, index) {
            var item = _wardrobeItems[index];
            return ListTile(
              title: Text(item['category']),
              trailing: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => _removeItem(index),
              ),
              leading: item['image'] != null
                  ? Image.memory(item['image'],
                      width: 50, height: 50, fit: BoxFit.cover)
                  : null,
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addItem,
        child: const Icon(Icons.add),
      ),
    );
  }
}

void main() {
  runApp(WardrobeApp());
}
