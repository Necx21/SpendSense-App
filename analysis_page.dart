import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/transaction_provider.dart';

class AnalysisPage extends StatefulWidget {
  const AnalysisPage({super.key});

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  late DateTimeRange _selectedRange;
  bool _isIncomeAnalysis = false;
  bool _showGraphChart = false;
  int _touchedPieIndex = -1;

  @override
  void initState() {
    super.initState();
    _setInitialMonth();
  }

  void _setInitialMonth() {
    final now = DateTime.now();
    _selectedRange = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month + 1, 0),
    );
  }

  void _changeMonth(int offset) {
    setState(() {
      final newStart = DateTime(
        _selectedRange.start.year,
        _selectedRange.start.month + offset,
        1,
      );
      _selectedRange = DateTimeRange(
        start: newStart,
        end: DateTime(newStart.year, newStart.month + 1, 0),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TransactionProvider>(context);
    final dataMap = provider.getCategoryDataFiltered(
      isIncome: _isIncomeAnalysis,
      range: _selectedRange,
    );

    final totalSpent = dataMap.values.fold<double>(0, (sum, val) => sum + val);
    final sortedList = dataMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildHeaderControl(),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _quickFilterBtn('This Month'),
                  const SizedBox(width: 10),
                  _quickFilterBtn('This Year'),
                  const SizedBox(width: 10),
                  _datePickerBtn(),
                ],
              ),
              const SizedBox(height: 25),
              if (dataMap.isEmpty)
                _buildEmptyState()
              else ...[
                _buildChartCard(dataMap, totalSpent, provider),
                const SizedBox(height: 30),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Spending Breakdown',
                    selectionColor: Theme.of(context).textTheme.bodyLarge?.color,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                _buildCategoryProgressList(sortedList, totalSpent, provider),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderControl() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => _changeMonth(-1),
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
              ),
              Text(
                DateFormat('MMMM yyyy').format(_selectedRange.start),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF748D74),
                ),
              ),
              IconButton(
                onPressed: () => _changeMonth(1),
                icon: const Icon(Icons.arrow_forward_ios, size: 18),
              ),
            ],
          ),
          const Divider(height: 1),
          Row(
            children: [
              _toggleTab('Expenses', !_isIncomeAnalysis),
              _toggleTab('Income', _isIncomeAnalysis),
            ],
          )
        ],
      ),
    );
  }

  Widget _toggleTab(String title, bool active) {
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _isIncomeAnalysis = (title == 'Income')),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active ? const Color(0xFF748D74) : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
                color: active ? const Color(0xFF748D74) : Colors.grey,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChartCard(
    Map<String, double> data,
    double total,
    TransactionProvider provider,
  ) {
    return Container(
      height: 320,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 12, 0),
            child: Row(
              children: [
                Text(
                  _showGraphChart ? 'Graph Chart' : 'Pie Chart',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Switch.adaptive(
                  value: _showGraphChart,
                  onChanged: (value) => setState(() => _showGraphChart = value),
                ),
              ],
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _showGraphChart
                  ? _buildWeeklyLineChart(provider)
                  : _buildPieChart(data, total, provider),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart(
    Map<String, double> data,
    double total,
    TransactionProvider provider,
  ) {
    final sorted = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final legendItems = sorted.take(4).toList();

    return Column(
      key: const ValueKey('pie_chart'),
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 62,
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {
                      if (!event.isInterestedForInteractions ||
                          response == null ||
                          response.touchedSection == null) {
                        setState(() => _touchedPieIndex = -1);
                        return;
                      }
                      setState(
                        () => _touchedPieIndex =
                            response.touchedSection!.touchedSectionIndex,
                      );
                    },
                  ),
                  sections: List.generate(sorted.length, (i) {
                    final e = sorted[i];
                    final isTouched = i == _touchedPieIndex;
                    final percentage = total == 0 ? 0.0 : (e.value / total) * 100;
                    return PieChartSectionData(
                      color: provider.getColor(i),
                      value: e.value,
                      title: percentage >= 8 ? "${percentage.toStringAsFixed(0)}%" : '',
                      titleStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      radius: isTouched ? 58 : 50,
                    );
                  }),
                ),
                duration: const Duration(milliseconds: 500),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isIncomeAnalysis ? "Income" : "Expense",
                      style: TextStyle(color: Colors.grey[600], fontSize: 11),
                    ),
                    Text(
                      "${provider.currencySymbol}${total.toStringAsFixed(0)}",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2D312D),
                      ),
                    ),
                    Text(
                      DateFormat('MMM yyyy').format(_selectedRange.start),
                      style: TextStyle(color: Colors.grey[500], fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(legendItems.length, (i) {
              final item = legendItems[i];
              final pct = total == 0 ? 0.0 : (item.value / total) * 100;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: provider.getColor(i),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "${item.key} ${pct.toStringAsFixed(0)}%",
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  List<MapEntry<DateTime, double>> _weeklyTrendPoints(
    TransactionProvider provider,
  ) {
    final now = DateTime.now();
    final endRaw = _selectedRange.end.isAfter(now) ? now : _selectedRange.end;
    final end = DateTime(endRaw.year, endRaw.month, endRaw.day);
    final start = end.subtract(const Duration(days: 6));

    final byDay = <DateTime, double>{
      for (int i = 0; i < 7; i++)
        DateTime(start.year, start.month, start.day + i): 0.0,
    };

    for (final tx in provider.transactions) {
      if (tx.isIncome != _isIncomeAnalysis) continue;
      final day = DateTime(tx.date.year, tx.date.month, tx.date.day);
      if (day.isBefore(start) || day.isAfter(end)) continue;
      byDay[day] = (byDay[day] ?? 0) + tx.amount;
    }

    final points = byDay.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return points;
  }

  Widget _buildWeeklyLineChart(TransactionProvider provider) {
    final points = _weeklyTrendPoints(provider);
    final total = points.fold<double>(0.0, (sum, p) => sum + p.value);
    final avg = total / points.length;
    final peak = points.reduce((a, b) => a.value >= b.value ? a : b);
    final maxVal = points.fold<double>(
      0.0,
      (max, e) => e.value > max ? e.value : max,
    );
    final maxY = maxVal <= 0 ? 10.0 : maxVal * 1.2;
    final interval = maxY / 4;
    const lineColor = Color(0xFF748D74);

    return Padding(
      key: const ValueKey('line_chart'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                _trendChip("Total", "${provider.currencySymbol}${total.toStringAsFixed(0)}"),
                const SizedBox(width: 8),
                _trendChip("Avg/day", "${provider.currencySymbol}${avg.toStringAsFixed(0)}"),
                const SizedBox(width: 8),
                _trendChip(
                  "Peak",
                  "${DateFormat('E').format(peak.key)} ${provider.currencySymbol}${peak.value.toStringAsFixed(0)}",
                ),
              ],
            ),
          ),
          Expanded(
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: 6,
                minY: 0,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: interval,
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => Colors.black87,
                    getTooltipItems: (spots) => spots.map((s) {
                      final idx = s.x.toInt();
                      final date = points[idx].key;
                      return LineTooltipItem(
                        "${DateFormat('EEE, dd MMM').format(date)}\n${provider.currencySymbol}${s.y.toStringAsFixed(0)}",
                        const TextStyle(color: Colors.white, fontSize: 11),
                      );
                    }).toList(),
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 52,
                      interval: interval,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          "${provider.currencySymbol}${value.toStringAsFixed(0)}",
                          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final rounded = value.round();
                        if ((value - rounded).abs() > 0.001) {
                          return const SizedBox.shrink();
                        }
                        if (rounded < 0 || rounded >= points.length) {
                          return const SizedBox.shrink();
                        }
                        final date = points[rounded].key;
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            DateFormat('E').format(date),
                            style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(
                      points.length,
                      (i) => FlSpot(i.toDouble(), points[i].value),
                    ),
                    isCurved: false,
                    color: lineColor,
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                        radius: 3.5,
                        color: lineColor,
                        strokeWidth: 1.5,
                        strokeColor: Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: lineColor.withOpacity(0.12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _trendChip(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryProgressList(
    List<MapEntry<String, double>> list,
    double total,
    TransactionProvider provider,
  ) {
    return Column(
      children: list.map((entry) {
        final index = list.indexOf(entry);
        final percentage = total == 0
            ? 0.0
            : (entry.value / total).clamp(0.0, 1.0).toDouble();
        final color = provider.getColor(index);

        return Container(
          margin: const EdgeInsets.only(bottom: 15),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border.all(color: Colors.black.withOpacity(0.05)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    entry.key,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  Text(
                    "${provider.currencySymbol}${entry.value.toStringAsFixed(0)}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: percentage,
                  backgroundColor: color.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 8,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _quickFilterBtn(String title) {
    return ActionChip(
      label: Text(title, style: const TextStyle(fontSize: 12)),
      onPressed: () {
        final now = DateTime.now();
        setState(() {
          if (title == 'This Month') {
            _selectedRange = DateTimeRange(
              start: DateTime(now.year, now.month, 1),
              end: now,
            );
          }
          if (title == 'This Year') {
            _selectedRange = DateTimeRange(
              start: DateTime(now.year, 1, 1),
              end: now,
            );
          }
        });
      },
    );
  }

  Widget _datePickerBtn() {
    return IconButton(
      icon: const Icon(Icons.date_range, color: Color(0xFF748D74)),
      onPressed: () async {
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2023),
          lastDate: DateTime.now(),
        );
        if (picked != null) {
          setState(() => _selectedRange = picked);
        }
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 100),
          Icon(Icons.receipt_long, size: 80, color: Colors.grey[300]),
          const Text('No transactions yet!', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
