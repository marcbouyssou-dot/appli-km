import 'dart:convert';
import 'dart:html' as html;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:table_calendar/table_calendar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR', null);
  runApp(const MyApp());
}

class Entry {
  final DateTime date;
  double km;

  Entry(this.date, this.km);

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'km': km,
      };

  factory Entry.fromJson(Map<String, dynamic> json) {
    return Entry(
      DateTime.parse(json['date']),
      (json['km'] as num).toDouble(),
    );
  }
}

class Trip {
  final String name;
  final double km;

  Trip(this.name, this.km);

  Map<String, dynamic> toJson() => {
        'name': name,
        'km': km,
      };

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      json['name'],
      (json['km'] as num).toDouble(),
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final kmController = TextEditingController();
  final tripNameController = TextEditingController();
  final tripKmController = TextEditingController();

  final userNameController = TextEditingController();
  final userAddressController = TextEditingController();
  final userCityController = TextEditingController();
  final vehicleController = TextEditingController();
  final vehiclePowerController = TextEditingController();
  final taxOfficeNameController = TextEditingController();
  final taxOfficeAddressController = TextEditingController();

  final departureController = TextEditingController();
  final arrivalController = TextEditingController();

  List<Entry> entries = [];
  List<Trip> trips = [
    Trip('Bureau', 24),
    Trip('Client', 18),
  ];
  List<DateTime> vacations = [];

  DateTime selectedDate = DateTime.now();
  DateTime focusedDay = DateTime.now();

  bool vacationMode = false;
  bool vacationRangeMode = false;
  DateTime? vacationRangeStart;

  bool showInfo = true;
  bool showStats = false;
  bool showHistory = false;

  bool isCalculatingTrip = false;
  double? calculatedKm;

  int currentTab = 0;
  int selectedMonthIndex = -1;

  @override
  void initState() {
    super.initState();
    loadData();
    loadTrips();
    loadVacations();
    loadUserInfo();
  }

  double selectedDayTotal() => kmForDay(selectedDate);

  double yearlyTotal() {
    final year = selectedDate.year;
    return entries
        .where((e) => e.date.year == year)
        .fold(0, (sum, e) => sum + e.km);
  }

  double monthlyTotal() {
    return entries
        .where((e) =>
            e.date.year == focusedDay.year && e.date.month == focusedDay.month)
        .fold(0, (sum, e) => sum + e.km);
  }

  double monthlyTotalFor(int month) {
    final year = selectedDate.year;
    return entries
        .where((e) => e.date.year == year && e.date.month == month)
        .fold(0, (sum, e) => sum + e.km);
  }

  double kmForDay(DateTime day) {
    return entries
        .where((e) => isSameDay(e.date, day))
        .fold(0, (sum, e) => sum + e.km);
  }

  bool isVacation(DateTime day) {
    return vacations.any((v) => isSameDay(v, day));
  }

  String formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String userName() => userNameController.text.trim().isEmpty
      ? 'Nom / Société'
      : userNameController.text.trim();

  String userAddress() => userAddressController.text.trim().isEmpty
      ? 'Adresse'
      : userAddressController.text.trim();

  String userCity() =>
      userCityController.text.trim().isEmpty ? 'Ville' : userCityController.text.trim();

  String taxOfficeName() => taxOfficeNameController.text.trim().isEmpty
      ? 'Cabinet comptable / Centre des impôts'
      : taxOfficeNameController.text.trim();

  String taxOfficeAddress() => taxOfficeAddressController.text.trim().isEmpty
      ? 'Adresse'
      : taxOfficeAddressController.text.trim();

  String vehicleText() {
    final vehicle = vehicleController.text.trim();
    final cv = vehiclePowerController.text.trim();

    if (vehicle.isEmpty && cv.isEmpty) return '...';
    if (vehicle.isNotEmpty && cv.isEmpty) return vehicle;
    if (vehicle.isEmpty && cv.isNotEmpty) return '$cv CV';
    return '$vehicle - $cv CV';
  }

  List<String> vacationPeriodsText() {
    if (vacations.isEmpty) {
      return ['........................................................................'];
    }

    final sorted = vacations.toList()..sort();
    final periods = <String>[];

    DateTime start = sorted.first;
    DateTime previous = sorted.first;

    for (final date in sorted.skip(1)) {
      final nextDay = previous.add(const Duration(days: 1));

      if (isSameDay(date, nextDay)) {
        previous = date;
      } else {
        if (isSameDay(start, previous)) {
          periods.add('- le ${formatDate(start)}');
        } else {
          periods.add('- du ${formatDate(start)} au ${formatDate(previous)}');
        }

        start = date;
        previous = date;
      }
    }

    if (isSameDay(start, previous)) {
      periods.add('- le ${formatDate(start)}');
    } else {
      periods.add('- du ${formatDate(start)} au ${formatDate(previous)}');
    }

    return periods;
  }

  void showSavedMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('✔️ Enregistré'),
        duration: const Duration(milliseconds: 700),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black87,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }

  void showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red.shade700,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }

  void replaceKmForSelectedDay() {
    final value = double.tryParse(kmController.text.replaceAll(',', '.'));
    if (value == null || value < 0) return;

    setState(() {
      entries.removeWhere((e) => isSameDay(e.date, selectedDate));

      if (value > 0) {
        entries.add(Entry(selectedDate, value));
      }

      kmController.clear();
    });

    saveData();
    showSavedMessage();
  }

  void addQuickKm(double value) {
    final newTotal = selectedDayTotal() + value;

    setState(() {
      entries.removeWhere((e) => isSameDay(e.date, selectedDate));
      entries.add(Entry(selectedDate, newTotal));
    });

    saveData();
    showSavedMessage();
  }

  void addTrip() {
    final name = tripNameController.text.trim();
    final km = double.tryParse(tripKmController.text.replaceAll(',', '.'));

    if (name.isEmpty || km == null) return;

    setState(() {
      trips.add(Trip(name, km));
      tripNameController.clear();
      tripKmController.clear();
    });

    saveTrips();
    showSavedMessage();
  }

  void createTripFromCalculated() {
    if (calculatedKm == null) return;

    final departure = departureController.text.trim();
    final arrival = arrivalController.text.trim();

    final name = departure.isNotEmpty && arrival.isNotEmpty
        ? '$departure → $arrival'
        : 'Trajet calculé';

    setState(() {
      trips.add(Trip(name, calculatedKm!));
    });

    saveTrips();
    showSavedMessage();
  }

  void deleteTrip(int index) {
    setState(() {
      trips.removeAt(index);
    });

    saveTrips();
  }

  void deleteEntry(DateTime date) {
    setState(() {
      entries.removeWhere((e) => isSameDay(e.date, date));
    });

    saveData();
  }

  void editEntry(DateTime date) {
    setState(() {
      selectedDate = date;
      focusedDay = date;
      kmController.text = kmForDay(date).toStringAsFixed(0);
      currentTab = 0;
    });
  }

  void toggleVacationDay(DateTime day) {
    setState(() {
      if (isVacation(day)) {
        vacations.removeWhere((v) => isSameDay(v, day));
      } else {
        vacations.add(day);
      }
    });

    saveVacations();
  }

  void handleVacationRange(DateTime day) {
    if (vacationRangeStart == null) {
      setState(() {
        vacationRangeStart = day;
      });
      return;
    }

    final start = vacationRangeStart!.isBefore(day) ? vacationRangeStart! : day;
    final end = vacationRangeStart!.isBefore(day) ? day : vacationRangeStart!;

    bool allAlreadyVacation = true;
    DateTime current = start;

    while (!current.isAfter(end)) {
      if (!isVacation(current)) {
        allAlreadyVacation = false;
        break;
      }
      current = current.add(const Duration(days: 1));
    }

    setState(() {
      current = start;

      while (!current.isAfter(end)) {
        if (allAlreadyVacation) {
          vacations.removeWhere((v) => isSameDay(v, current));
        } else if (!isVacation(current)) {
          vacations.add(current);
        }

        current = current.add(const Duration(days: 1));
      }

      vacationRangeStart = null;
      vacationRangeMode = false;
    });

    saveVacations();
  }

  void clearVacations() {
    setState(() {
      vacations.clear();
      vacationRangeStart = null;
      vacationRangeMode = false;
    });

    saveVacations();
  }

  Future<Map<String, double>?> geocodeAddress(String address) async {
    final url =
        'https://nominatim.openstreetmap.org/search?format=json&limit=1&q=${Uri.encodeComponent(address)}';

    final response = await html.HttpRequest.getString(url);
    final data = jsonDecode(response) as List;

    if (data.isEmpty) return null;

    return {
      'lat': double.parse(data.first['lat']),
      'lon': double.parse(data.first['lon']),
    };
  }

  Future<void> calculateTripDistance() async {
    final departure = departureController.text.trim();
    final arrival = arrivalController.text.trim();

    if (departure.isEmpty || arrival.isEmpty) {
      showErrorMessage('Renseigne le départ et l’arrivée.');
      return;
    }

    setState(() {
      isCalculatingTrip = true;
      calculatedKm = null;
    });

    try {
      final start = await geocodeAddress(departure);
      final end = await geocodeAddress(arrival);

      if (start == null || end == null) {
        showErrorMessage('Adresse introuvable. Essaie avec une adresse plus précise.');
        return;
      }

      final routeUrl =
          'https://router.project-osrm.org/route/v1/driving/${start['lon']},${start['lat']};${end['lon']},${end['lat']}?overview=false';

      final routeResponse = await html.HttpRequest.getString(routeUrl);
      final routeData = jsonDecode(routeResponse);

      final routes = routeData['routes'] as List;

      if (routes.isEmpty) {
        showErrorMessage('Trajet impossible à calculer.');
        return;
      }

      final meters = (routes.first['distance'] as num).toDouble();
      final km = meters / 1000;

      setState(() {
        calculatedKm = km;
        tripKmController.text = km.toStringAsFixed(0);
      });
    } catch (_) {
      showErrorMessage('Erreur pendant le calcul du trajet.');
    } finally {
      setState(() {
        isCalculatingTrip = false;
      });
    }
  }

  void exportCsv() {
    final sortedEntries = entries.toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final buffer = StringBuffer();
    buffer.writeln('Date;Kilometres');

    for (final e in sortedEntries) {
      buffer.writeln('${formatDate(e.date)};${e.km.toStringAsFixed(0)}');
    }

    buffer.writeln('');
    buffer.writeln(
      'Total annuel ${selectedDate.year};${yearlyTotal().toStringAsFixed(0)}',
    );

    final bytes = utf8.encode(buffer.toString());
    final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);

    html.AnchorElement(href: url)
      ..setAttribute('download', 'kilometres_${selectedDate.year}.csv')
      ..click();

    html.Url.revokeObjectUrl(url);
  }

  void exportBackup() {
    final data = {
      'entries': entries.map((e) => e.toJson()).toList(),
      'trips': trips.map((t) => t.toJson()).toList(),
      'vacations': vacations.map((v) => v.toIso8601String()).toList(),
      'user': {
        'name': userNameController.text,
        'address': userAddressController.text,
        'city': userCityController.text,
        'vehicle': vehicleController.text,
        'power': vehiclePowerController.text,
        'taxName': taxOfficeNameController.text,
        'taxAddress': taxOfficeAddressController.text,
      }
    };

    final jsonString = jsonEncode(data);
    final bytes = utf8.encode(jsonString);
    final blob = html.Blob([bytes], 'application/json');
    final url = html.Url.createObjectUrlFromBlob(blob);

    html.AnchorElement(href: url)
      ..setAttribute('download', 'sauvegarde_km.json')
      ..click();

    html.Url.revokeObjectUrl(url);
  }

  void importBackup() {
    final uploadInput = html.FileUploadInputElement();
    uploadInput.accept = '.json';
    uploadInput.click();

    uploadInput.onChange.listen((event) {
      final file = uploadInput.files?.first;
      if (file == null) return;

      final reader = html.FileReader();
      reader.readAsText(file);

      reader.onLoadEnd.listen((event) {
        final jsonData = jsonDecode(reader.result as String);

        setState(() {
          entries = (jsonData['entries'] as List)
              .map((e) => Entry.fromJson(e as Map<String, dynamic>))
              .toList();

          trips = (jsonData['trips'] as List)
              .map((t) => Trip.fromJson(t as Map<String, dynamic>))
              .toList();

          vacations = (jsonData['vacations'] as List)
              .map((v) => DateTime.parse(v as String))
              .toList();

          final user = jsonData['user'] ?? {};

          userNameController.text = user['name'] ?? '';
          userAddressController.text = user['address'] ?? '';
          userCityController.text = user['city'] ?? '';
          vehicleController.text = user['vehicle'] ?? '';
          vehiclePowerController.text = user['power'] ?? '';
          taxOfficeNameController.text = user['taxName'] ?? '';
          taxOfficeAddressController.text = user['taxAddress'] ?? '';
        });

        saveData();
        saveTrips();
        saveVacations();
        saveUserInfo();
        showSavedMessage();
      });
    });
  }

  Future<void> generatePdf() async {
    final pdf = pw.Document();
    final total = yearlyTotal();

    pdf.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(50),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                userName(),
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              pw.Text(userAddress()),
              pw.Text(userCity()),
              pw.SizedBox(height: 65),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      taxOfficeName(),
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(taxOfficeAddress()),
                  ],
                ),
              ),
              pw.SizedBox(height: 65),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Fait à ${userCity()},'),
                    pw.Text('Le ${formatDate(DateTime.now())}'),
                  ],
                ),
              ),
              pw.SizedBox(height: 55),
              pw.Text('Monsieur,'),
              pw.SizedBox(height: 28),
              pw.Text(
                'Je vous prie de bien vouloir noter les renseignements suivants :',
              ),
              pw.SizedBox(height: 38),
              pw.Text(
                '- nombre de kilomètres effectués sur l’année ${selectedDate.year} :',
              ),
              pw.SizedBox(height: 18),
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 40),
                child: pw.Text(
                  '${total.toStringAsFixed(0)} km',
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 40, top: 8),
                child: pw.Text('(véhicule utilisé : ${vehicleText()})'),
              ),
              pw.SizedBox(height: 32),
              pw.Text('- dates des congés :'),
              pw.SizedBox(height: 15),
              ...vacationPeriodsText().map(
                (line) => pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 40, bottom: 6),
                  child: pw.Text(line),
                ),
              ),
              pw.Spacer(),
              pw.Text(
                'Veuillez recevoir, Monsieur, l’expression de mes salutations distinguées.',
              ),
              pw.SizedBox(height: 42),
              pw.Text(
                userName(),
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
    );
  }

  void saveData() {
    final data = entries.map((e) => e.toJson()).toList();
    html.window.localStorage['entries'] = jsonEncode(data);
  }

  void loadData() {
    final data = html.window.localStorage['entries'];

    if (data != null) {
      final decoded = jsonDecode(data) as List;
      setState(() {
        entries = decoded
            .map((e) => Entry.fromJson(e as Map<String, dynamic>))
            .toList();
      });
    }
  }

  void saveTrips() {
    final data = trips.map((t) => t.toJson()).toList();
    html.window.localStorage['trips'] = jsonEncode(data);
  }

  void loadTrips() {
    final data = html.window.localStorage['trips'];

    if (data != null) {
      final decoded = jsonDecode(data) as List;
      setState(() {
        trips = decoded
            .map((t) => Trip.fromJson(t as Map<String, dynamic>))
            .toList();
      });
    }
  }

  void saveVacations() {
    final data = vacations.map((v) => v.toIso8601String()).toList();
    html.window.localStorage['vacations'] = jsonEncode(data);
  }

  void loadVacations() {
    final data = html.window.localStorage['vacations'];

    if (data != null) {
      final decoded = jsonDecode(data) as List;
      setState(() {
        vacations = decoded.map((v) => DateTime.parse(v as String)).toList();
      });
    }
  }

  void saveUserInfo() {
    html.window.localStorage['userName'] = userNameController.text;
    html.window.localStorage['userAddress'] = userAddressController.text;
    html.window.localStorage['userCity'] = userCityController.text;
    html.window.localStorage['vehicle'] = vehicleController.text;
    html.window.localStorage['vehiclePower'] = vehiclePowerController.text;
    html.window.localStorage['taxOfficeName'] = taxOfficeNameController.text;
    html.window.localStorage['taxOfficeAddress'] =
        taxOfficeAddressController.text;
  }

  void loadUserInfo() {
    userNameController.text = html.window.localStorage['userName'] ?? '';
    userAddressController.text = html.window.localStorage['userAddress'] ?? '';
    userCityController.text = html.window.localStorage['userCity'] ?? '';
    vehicleController.text = html.window.localStorage['vehicle'] ?? '';
    vehiclePowerController.text =
        html.window.localStorage['vehiclePower'] ?? '';
    taxOfficeNameController.text =
        html.window.localStorage['taxOfficeName'] ?? '';
    taxOfficeAddressController.text =
        html.window.localStorage['taxOfficeAddress'] ?? '';
  }

  Widget card(Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget sectionHeader(String title, bool opened, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
          ),
          Text(
            opened ? 'Masquer' : 'Afficher',
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget infoField(
    String label,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        onChanged: (_) => saveUserInfo(),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget gradientButton(String text, VoidCallback onTap) {
    return Container(
      width: double.infinity,
      height: 58,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF007AFF), Color(0xFF34C759)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
        ),
        onPressed: onTap,
        child: Text(text, style: const TextStyle(fontSize: 20)),
      ),
    );
  }

  Widget quickButton(String text, Color color, VoidCallback onTap) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: onTap,
      child: Text(text),
    );
  }

  Widget monthlyChart() {
    final values = List.generate(12, (index) => monthlyTotalFor(index + 1));
    final maxValue =
        values.fold<double>(0, (max, value) => value > max ? value : max);

    return SizedBox(
      height: 260,
      child: BarChart(
        BarChartData(
          barTouchData: BarTouchData(
            enabled: true,
            touchCallback: (event, response) {
              if (response != null && response.spot != null) {
                setState(() {
                  selectedMonthIndex = response.spot!.touchedBarGroupIndex;
                });
              }
            },
          ),
          maxY: maxValue == 0 ? 10 : maxValue + 10,
          gridData: const FlGridData(show: true),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 38,
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  const months = [
                    'J',
                    'F',
                    'M',
                    'A',
                    'M',
                    'J',
                    'J',
                    'A',
                    'S',
                    'O',
                    'N',
                    'D',
                  ];

                  final index = value.toInt();

                  if (index < 0 || index > 11) {
                    return const SizedBox.shrink();
                  }

                  return Text(
                    months[index],
                    style: const TextStyle(fontSize: 11),
                  );
                },
              ),
            ),
          ),
          barGroups: List.generate(12, (index) {
            final isSelected = index == selectedMonthIndex;

            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: values[index],
                  width: isSelected ? 20 : 14,
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget calendarDay(DateTime day, {bool selected = false}) {
    final km = kmForDay(day);
    final vacation = isVacation(day);
    final isRangeStart =
        vacationRangeStart != null && isSameDay(vacationRangeStart!, day);

    Color? background;
    Color textColor = Colors.black;

    if (vacation) {
      background = Colors.orange;
      textColor = Colors.white;
    }

    if (km > 0) {
      background = const Color(0xFF34C759);
      textColor = Colors.white;
    }

    if (isRangeStart) {
      background = Colors.deepOrange;
      textColor = Colors.white;
    }

    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
          border: selected ? Border.all(color: Colors.black, width: 2) : null,
        ),
        child: Center(
          child: km > 0
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${day.day}',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      km.toStringAsFixed(0),
                      style: const TextStyle(color: Colors.white, fontSize: 9),
                    ),
                  ],
                )
              : Text(
                  '${day.day}',
                  style: TextStyle(
                    color: textColor,
                    fontWeight:
                        background != null ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
        ),
      ),
    );
  }

  Widget homeScreen() {
    final sortedEntries = entries.toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF007AFF), Color(0xFF34C759)],
            ),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatDate(selectedDate),
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Mes kilomètres',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Total mois : ${monthlyTotal().toStringAsFixed(0)} km',
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ],
                ),
              ),
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.22),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.directions_car,
                    color: Colors.white, size: 36),
              ),
            ],
          ),
        ),

        const SizedBox(height: 26),

        card(
          Column(
            children: [
              TextField(
                controller: kmController,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: Colors.black,
                ),
                decoration: InputDecoration(
                  hintText: selectedDayTotal().toStringAsFixed(0),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 30),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
                onTap: () {
                  if (kmController.text.isEmpty && selectedDayTotal() > 0) {
                    kmController.text = selectedDayTotal().toStringAsFixed(0);
                  }
                },
                onSubmitted: (_) => replaceKmForSelectedDay(),
              ),
              const SizedBox(height: 12),
              gradientButton('Valider', replaceKmForSelectedDay),
              const SizedBox(height: 12),
              Text(
                'Touchez le compteur pour modifier le ${formatDate(selectedDate)}',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),

        card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Trajets favoris',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: tripNameController,
                      decoration: const InputDecoration(
                        labelText: 'Nom',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 110,
                    child: TextField(
                      controller: tripKmController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Km',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: addTrip,
                    icon: const Icon(Icons.add_circle, color: Color(0xFF007AFF)),
                    iconSize: 34,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Calculer un trajet',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: departureController,
                decoration: const InputDecoration(
                  labelText: 'Départ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: arrivalController,
                decoration: const InputDecoration(
                  labelText: 'Arrivée',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              gradientButton(
                isCalculatingTrip ? 'Calcul en cours...' : 'Calculer les km',
                isCalculatingTrip ? () {} : calculateTripDistance,
              ),
              if (calculatedKm != null) ...[
                const SizedBox(height: 14),
                Text(
                  'Distance estimée : ${calculatedKm!.toStringAsFixed(0)} km',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: quickButton(
                        'Ajouter aller',
                        const Color(0xFF007AFF),
                        () => addQuickKm(calculatedKm!),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: quickButton(
                        'Ajouter A/R',
                        const Color(0xFF34C759),
                        () => addQuickKm(calculatedKm! * 2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: createTripFromCalculated,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                  ),
                  child: const Text('Créer trajet favori'),
                ),
              ],
              const SizedBox(height: 18),
              ...trips.asMap().entries.map((item) {
                final index = item.key;
                final trip = item.value;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F7FB),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${trip.name}\n${trip.km.toStringAsFixed(0)} km',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      quickButton(
                        '+${trip.km.toStringAsFixed(0)}',
                        const Color(0xFF007AFF),
                        () => addQuickKm(trip.km),
                      ),
                      const SizedBox(width: 8),
                      quickButton(
                        '+${(trip.km * 2).toStringAsFixed(0)}',
                        const Color(0xFF34C759),
                        () => addQuickKm(trip.km * 2),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => deleteTrip(index),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),

        card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Calendrier',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  const Text(
                    'Mode vacances',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  Switch(
                    value: vacationMode,
                    activeColor: Colors.orange,
                    onChanged: (value) {
                      setState(() {
                        vacationMode = value;
                        vacationRangeMode = false;
                        vacationRangeStart = null;
                      });
                    },
                  ),
                ],
              ),
              if (vacationMode)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 8, bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    vacationRangeMode
                        ? vacationRangeStart == null
                            ? 'Sélection période : cliquez le premier jour.'
                            : 'Sélection période : cliquez le dernier jour.'
                        : 'Mode vacances : cliquez un jour pour cocher/décocher.',
                    style: const TextStyle(
                      color: Colors.deepOrange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              if (vacationMode)
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            vacationRangeMode = !vacationRangeMode;
                            vacationRangeStart = null;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: vacationRangeMode
                              ? Colors.orange
                              : Colors.orange.withOpacity(0.15),
                          foregroundColor:
                              vacationRangeMode ? Colors.white : Colors.black,
                        ),
                        child: Text(
                          vacationRangeMode
                              ? 'Annuler période'
                              : 'Sélection période',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: clearVacations,
                        child: const Text('Effacer vacances'),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              TableCalendar(
                locale: 'fr_FR',
                firstDay: DateTime(2020),
                lastDay: DateTime(2100),
                focusedDay: focusedDay,
                selectedDayPredicate: (day) => isSameDay(day, selectedDate),
                onDaySelected: (selected, focused) {
                  setState(() {
                    selectedDate = selected;
                    focusedDay = focused;
                  });

                  if (vacationMode) {
                    if (vacationRangeMode) {
                      handleVacationRange(selected);
                    } else {
                      toggleVacationDay(selected);
                    }
                  } else {
                    kmController.clear();
                  }
                },
                availableGestures: AvailableGestures.all,
                calendarFormat: CalendarFormat.month,
                startingDayOfWeek: StartingDayOfWeek.monday,
                rowHeight: 46,
                daysOfWeekHeight: 28,
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                calendarStyle: const CalendarStyle(
                  outsideDaysVisible: false,
                  selectedDecoration: BoxDecoration(
                    color: Color(0xFFEAF4FF),
                    shape: BoxShape.circle,
                    border: Border.fromBorderSide(
                      BorderSide(color: Colors.black, width: 2),
                    ),
                  ),
                  selectedTextStyle: TextStyle(
                    color: Color(0xFF007AFF),
                    fontWeight: FontWeight.bold,
                  ),
                  todayDecoration: BoxDecoration(
                    color: Color(0x332196F3),
                    shape: BoxShape.circle,
                  ),
                  todayTextStyle: TextStyle(
                    color: Color(0xFF007AFF),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                calendarBuilders: CalendarBuilders(
                  defaultBuilder: (context, day, focusedDay) {
                    return calendarDay(day);
                  },
                  selectedBuilder: (context, day, focusedDay) {
                    return calendarDay(day, selected: true);
                  },
                ),
              ),
            ],
          ),
        ),

        card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Historique',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (sortedEntries.isEmpty)
                const Text(
                  'Aucune saisie pour le moment.',
                  style: TextStyle(color: Colors.grey),
                ),
              ...sortedEntries.map((e) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(formatDate(e.date)),
                  subtitle: const Text('Cliquer pour modifier ce jour'),
                  onTap: () => editEntry(e.date),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${kmForDay(e.date).toStringAsFixed(0)} km'),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => editEntry(e.date),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => deleteEntry(e.date),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),

        const Center(
          child: Text(
            '© 2026 MB • Mes kilomètres',
            style: TextStyle(color: Colors.grey),
          ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget exportScreen() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Exports',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 30),
        gradientButton('Exporter PDF annuel', generatePdf),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: exportCsv,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 58),
          ),
          child: const Text('Exporter CSV'),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: exportBackup,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 58),
          ),
          child: const Text('Sauvegarder mes données'),
        ),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: importBackup,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 58),
          ),
          child: const Text('Importer une sauvegarde'),
        ),
      ],
    );
  }

  Widget settingsScreen() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              sectionHeader('Informations', showInfo, () {
                setState(() => showInfo = !showInfo);
              }),
              if (showInfo) ...[
                infoField('Nom / Société', userNameController),
                infoField('Adresse', userAddressController),
                infoField('Ville', userCityController),
                Row(
                  children: [
                    Expanded(
                      child: infoField('Véhicule', vehicleController),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 90,
                      child: infoField(
                        'CV',
                        vehiclePowerController,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Destinataire PDF',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                infoField(
                  'Cabinet comptable / Centre des impôts',
                  taxOfficeNameController,
                ),
                infoField(
                  'Adresse du cabinet / centre',
                  taxOfficeAddressController,
                ),
              ],
            ],
          ),
        ),
        card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              sectionHeader('Statistiques', showStats, () {
                setState(() => showStats = !showStats);
              }),
              if (showStats) ...[
                const SizedBox(height: 16),
                Text(
                  'Total année ${selectedDate.year} : ${yearlyTotal().toStringAsFixed(0)} km',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                monthlyChart(),
                if (selectedMonthIndex != -1) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Mois sélectionné : ${selectedMonthIndex + 1}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    'Total : ${monthlyTotalFor(selectedMonthIndex + 1).toStringAsFixed(0)} km',
                  ),
                ],
                const SizedBox(height: 8),
                Text('Total mois : ${monthlyTotal().toStringAsFixed(0)} km'),
              ],
            ],
          ),
        ),
        card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              sectionHeader('Historique', showHistory, () {
                setState(() => showHistory = !showHistory);
              }),
              if (showHistory) ...[
                const SizedBox(height: 16),
                if (entries.isEmpty)
                  const Text(
                    'Aucune saisie pour le moment.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ...entries.map(
                  (e) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(formatDate(e.date)),
                    trailing: Text('${e.km.toStringAsFixed(0)} km'),
                    onTap: () => editEntry(e.date),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [homeScreen(), exportScreen(), settingsScreen()];

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFF6F7FB),
        body: SafeArea(child: screens[currentTab]),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.all(18),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(34),
            child: BottomNavigationBar(
              currentIndex: currentTab,
              onTap: (index) => setState(() => currentTab = index),
              selectedItemColor: const Color(0xFF007AFF),
              unselectedItemColor: Colors.black,
              iconSize: 32,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.directions_car),
                  label: 'Accueil',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.description),
                  label: 'Exports',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings),
                  label: 'Réglages',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
