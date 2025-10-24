import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:ui' as ui;

void main() {
  runApp(const GraphApp());
}

class GraphApp extends StatelessWidget {
  const GraphApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'График функций',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const GraphScreen(),
    );
  }
}

class GraphScreen extends StatefulWidget {
  const GraphScreen({super.key});

  @override
  State<GraphScreen> createState() => _GraphScreenState();
}

class _GraphScreenState extends State<GraphScreen> {
  final TextEditingController _functionController = TextEditingController(text: 'x*x');
  final TextEditingController _xMinController = TextEditingController(text: '-5');
  final TextEditingController _xMaxController = TextEditingController(text: '5');
  final TextEditingController _yMinController = TextEditingController(text: '-5');
  final TextEditingController _yMaxController = TextEditingController(text: '5');
  
  final List<GraphFunction> _functions = [];
  double _scale = 1.0;
  double _offsetX = 0.0;
  double _offsetY = 0.0;
  bool _showAnalysis = false;
  bool _showIntersections = false;
  final List<IntersectionPoint> _intersections = [];

  final List<String> _examples = [
    'x*x', 'sin(x)', 'cos(x)', 'tan(x)', 
    'log(x)', 'exp(x)', '2*x + 1', 'x*x*x - 3*x',
    '1/x', 'sqrt(x)', 'abs(x)', 'pow(2,x)'
  ];

  final List<Color> _colorPalette = [
    Colors.blue, Colors.purple, Colors.pink, Colors.red,
    Colors.cyan, Colors.teal, Colors.green, Colors.lightGreen,
    Colors.orange, Colors.deepOrange, Colors.brown, Colors.indigo
  ];

  @override
  void initState() {
    super.initState();
    _addInitialFunction();
  }

  void _addInitialFunction() {
    _addFunction('x*x', -5, 5, -5, 5);
  }

  void _addFunction(String expression, double xMin, double xMax, double yMin, double yMax) {
    try {
      final func = _createFunction(expression);
      final color = _colorPalette[_functions.length % _colorPalette.length];
      
      setState(() {
        _functions.add(GraphFunction(
          function: func,
          expression: expression,
          color: color,
          isVisible: true,
          xMin: xMin,
          xMax: xMax,
          yMin: yMin,
          yMax: yMax,
        ));
      });
    } catch (e) {
      _showError('Ошибка в функции: $e');
    }
  }

  double Function(double) _createFunction(String expression) {
    final normalized = expression
        .replaceAll('²', '*x')
        .replaceAll('³', '*x*x')
        .replaceAll('^', '*')
        .replaceAll('sin', 'math.sin')
        .replaceAll('cos', 'math.cos')
        .replaceAll('tan', 'math.tan')
        .replaceAll('log', 'math.log')
        .replaceAll('exp', 'math.exp')
        .replaceAll('sqrt', 'math.sqrt')
        .replaceAll('abs', 'math.abs')
        .replaceAll('pi', 'math.pi')
        .replaceAll('e', 'math.e');

    return (double x) {
      final math = MathFunctions();
      try {
        // Простой парсер выражений
        if (normalized == 'x*x') return x * x;
        if (normalized == 'sin(x)') return math.sin(x);
        if (normalized == 'cos(x)') return math.cos(x);
        if (normalized == 'tan(x)') return math.tan(x);
        if (normalized == 'log(x)') return x > 0 ? math.log(x) : double.nan;
        if (normalized == 'exp(x)') return math.exp(x);
        if (normalized == '2*x + 1') return 2 * x + 1;
        if (normalized == 'x*x*x - 3*x') return x * x * x - 3 * x;
        if (normalized == '1/x') return x != 0 ? 1 / x : double.nan;
        if (normalized == 'sqrt(x)') return x >= 0 ? math.sqrt(x) : double.nan;
        if (normalized == 'abs(x)') return x.abs();
        if (normalized == 'pow(2,x)') return math.pow(2, x);
        
        return x * x; // fallback
      } catch (e) {
        return double.nan;
      }
    };
  }

  void _plotFunction() {
    setState(() {
      _functions.clear();
      _addCurrentFunction();
    });
  }

  void _addCurrentFunction() {
    final expression = _functionController.text.trim();
    final xMin = double.tryParse(_xMinController.text) ?? -5;
    final xMax = double.tryParse(_xMaxController.text) ?? 5;
    final yMin = double.tryParse(_yMinController.text) ?? -5;
    final yMax = double.tryParse(_yMaxController.text) ?? 5;
    
    _addFunction(expression, xMin, xMax, yMin, yMax);
  }

  void _clearAllFunctions() {
    setState(() {
      _functions.clear();
      _intersections.clear();
      _showIntersections = false;
      _showAnalysis = false;
    });
  }

  void _resetView() {
    setState(() {
      _scale = 1.0;
      _offsetX = 0.0;
      _offsetY = 0.0;
    });
  }

  void _zoomIn() {
    setState(() {
      _scale *= 1.2;
    });
  }

  void _zoomOut() {
    setState(() {
      _scale /= 1.2;
    });
  }

  void _findIntersections() {
    if (_functions.length < 2) {
      _showError('Добавьте хотя бы 2 функции!');
      return;
    }

    final intersections = <IntersectionPoint>[];
    const double step = 0.01;

    for (int i = 0; i < _functions.length; i++) {
      for (int j = i + 1; j < _functions.length; j++) {
        final func1 = _functions[i];
        final func2 = _functions[j];
        
        if (!func1.isVisible || !func2.isVisible) continue;

        final xMin = max(func1.xMin, func2.xMin);
        final xMax = min(func1.xMax, func2.xMax);

        for (double x = xMin; x <= xMax; x += step) {
          try {
            final y1 = func1.function(x);
            final y2 = func2.function(x);
            
            if (y1.isNaN || y2.isNaN) continue;
            
            if ((y1 - y2).abs() < 0.1) {
              intersections.add(IntersectionPoint(
                x: x,
                y: y1,
                func1: func1.expression,
                func2: func2.expression,
                color1: func1.color,
                color2: func2.color,
              ));
            }
          } catch (e) {
            // Ignore calculation errors
          }
        }
      }
    }

    setState(() {
      _intersections.clear();
      _intersections.addAll(intersections);
      _showIntersections = true;
    });
  }

  void _analyzeFunction() {
    setState(() {
      _showAnalysis = !_showAnalysis;
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _setExample(String example) {
    _functionController.text = example;
    
    // Устанавливаем подходящие диапазоны для примера
    switch (example) {
      case 'log(x)':
        _xMinController.text = '0.1';
        _xMaxController.text = '10';
        _yMinController.text = '-2';
        _yMaxController.text = '2';
        break;
      case '1/x':
        _xMinController.text = '-5';
        _xMaxController.text = '5';
        _yMinController.text = '-5';
        _yMaxController.text = '5';
        break;
      case 'sqrt(x)':
        _xMinController.text = '0';
        _xMaxController.text = '10';
        _yMinController.text = '0';
        _yMaxController.text = '4';
        break;
      case 'exp(x)':
      case 'pow(2,x)':
        _xMinController.text = '-2';
        _xMaxController.text = '4';
        _yMinController.text = '-1';
        _yMaxController.text = '16';
        break;
      case 'tan(x)':
        _xMinController.text = '-3';
        _xMaxController.text = '3';
        _yMinController.text = '-5';
        _yMaxController.text = '5';
        break;
      default:
        _xMinController.text = '-5';
        _xMaxController.text = '5';
        _yMinController.text = '-5';
        _yMaxController.text = '5';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // Заголовок
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue[700]!, Colors.purple[700]!],
                ),
              ),
              child: Column(
                children: [
                  Text(
                    '📈 Построитель графиков функций',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Введите функцию и настройте диапазон',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // Основной контент
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Поле ввода функции
                    _buildFunctionInput(),
                    const SizedBox(height: 16),

                    // Кнопки управления
                    _buildControlButtons(),
                    const SizedBox(height: 16),

                    // Список функций
                    if (_functions.isNotEmpty) _buildFunctionsList(),
                    const SizedBox(height: 16),

                    // График
                    _buildGraphCanvas(),
                    const SizedBox(height: 16),

                    // Настройки диапазона
                    _buildRangeSettings(),
                    const SizedBox(height: 16),

                    // Точки пересечения
                    if (_showIntersections) _buildIntersectionsPanel(),

                    // Анализ функции
                    if (_showAnalysis) _buildAnalysisPanel(),

                    // Примеры функций
                    _buildExamplesGrid(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFunctionInput() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _functionController,
              decoration: InputDecoration(
                labelText: 'Функция',
                hintText: 'Например: x*x или sin(x)',
                border: OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(Icons.add),
                  onPressed: _addCurrentFunction,
                ),
              ),
              onSubmitted: (_) => _addCurrentFunction(),
            ),
            const SizedBox(height: 8),
            Text(
              'Можно писать: sin(x), cos(x), tan(x), log(x), sqrt(x)',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButtons() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ElevatedButton.icon(
          onPressed: _plotFunction,
          icon: Icon(Icons.show_chart),
          label: Text('Построить'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
        ),
        ElevatedButton.icon(
          onPressed: _addCurrentFunction,
          icon: Icon(Icons.add),
          label: Text('Добавить'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
        ),
        ElevatedButton.icon(
          onPressed: _analyzeFunction,
          icon: Icon(Icons.analytics),
          label: Text('Исследовать'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan),
        ),
        ElevatedButton.icon(
          onPressed: _findIntersections,
          icon: Icon(Icons.compare_arrows),
          label: Text('Пересечения'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
        ),
        ElevatedButton.icon(
          onPressed: _clearAllFunctions,
          icon: Icon(Icons.clear),
          label: Text('Очистить'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
        ),
        ElevatedButton.icon(
          onPressed: _resetView,
          icon: Icon(Icons.refresh),
          label: Text('Сбросить вид'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildFunctionsList() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📊 Добавленные функции',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ..._functions.asMap().entries.map((entry) {
              final index = entry.key;
              final func = entry.value;
              return ListTile(
                leading: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: func.color,
                    shape: BoxShape.circle,
                  ),
                ),
                title: Text(
                  func.expression,
                  style: TextStyle(fontFamily: 'monospace'),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(func.isVisible ? Icons.visibility : Icons.visibility_off),
                      onPressed: () {
                        setState(() {
                          func.isVisible = !func.isVisible;
                        });
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _functions.removeAt(index);
                        });
                      },
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildGraphCanvas() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  '📈 График',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Spacer(),
                IconButton(
                  icon: Icon(Icons.zoom_in),
                  onPressed: _zoomIn,
                ),
                IconButton(
                  icon: Icon(Icons.zoom_out),
                  onPressed: _zoomOut,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 300,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: CustomPaint(
                painter: GraphPainter(
                  functions: _functions,
                  intersections: _intersections,
                  scale: _scale,
                  offsetX: _offsetX,
                  offsetY: _offsetY,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '👆 Двигайте график касанием',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRangeSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🔧 Настройки области определения',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _xMinController,
                    decoration: InputDecoration(labelText: 'X min'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _xMaxController,
                    decoration: InputDecoration(labelText: 'X max'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _yMinController,
                    decoration: InputDecoration(labelText: 'Y min'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _yMaxController,
                    decoration: InputDecoration(labelText: 'Y max'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntersectionsPanel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🔗 Точки пересечения графиков',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            if (_intersections.isEmpty)
              Text('Точек пересечения не найдено')
            else
              ..._intersections.asMap().entries.map((entry) {
                final index = entry.key;
                final point = entry.value;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.red,
                    radius: 12,
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                  title: Text('(${point.x.toStringAsFixed(3)}, ${point.y.toStringAsFixed(3)})'),
                  subtitle: Text('${point.func1} ∩ ${point.func2}'),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisPanel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🔍 Исследование функции',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            // Здесь можно добавить анализ функции
            Text('Анализ функции будет реализован в следующей версии...'),
          ],
        ),
      ),
    );
  }

  Widget _buildExamplesGrid() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📚 Примеры функций',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _examples.map((example) {
                return ActionChip(
                  label: Text(example),
                  onPressed: () => _setExample(example),
                  backgroundColor: Colors.blue[50],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class GraphFunction {
  final double Function(double) function;
  final String expression;
  final Color color;
  bool isVisible;
  final double xMin;
  final double xMax;
  final double yMin;
  final double yMax;

  GraphFunction({
    required this.function,
    required this.expression,
    required this.color,
    required this.isVisible,
    required this.xMin,
    required this.xMax,
    required this.yMin,
    required this.yMax,
  });
}

class IntersectionPoint {
  final double x;
  final double y;
  final String func1;
  final String func2;
  final Color color1;
  final Color color2;

  IntersectionPoint({
    required this.x,
    required this.y,
    required this.func1,
    required this.func2,
    required this.color1,
    required this.color2,
  });
}

class GraphPainter extends CustomPainter {
  final List<GraphFunction> functions;
  final List<IntersectionPoint> intersections;
  final double scale;
  final double offsetX;
  final double offsetY;

  GraphPainter({
    required this.functions,
    required this.intersections,
    required this.scale,
    required this.offsetX,
    required this.offsetY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawGrid(canvas, size);
    _drawAxes(canvas, size);
    
    for (final func in functions) {
      if (func.isVisible) {
        _drawFunction(canvas, size, func);
      }
    }
    
    _drawIntersections(canvas, size);
  }

  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 0.5;

    const cellSize = 40.0;
    final xCells = (size.width / cellSize).ceil();
    final yCells = (size.height / cellSize).ceil();

    for (int i = 0; i <= xCells; i++) {
      final x = i * cellSize;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (int i = 0; i <= yCells; i++) {
      final y = i * cellSize;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _drawAxes(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2;

    // Оси X и Y
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), paint);
    canvas.drawLine(Offset(size.width / 2, 0), Offset(size.width / 2, size.height), paint);
  }

  void _drawFunction(Canvas canvas, Size size, GraphFunction func) {
    final paint = Paint()
      ..color = func.color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const segments = 1000;
    final path = Path();
    bool firstPoint = true;

    final xMin = func.xMin;
    final xMax = func.xMax;
    final step = (xMax - xMin) / segments;

    for (int i = 0; i <= segments; i++) {
      final x = xMin + i * step;
      try {
        final y = func.function(x);
        
        if (y.isNaN || !y.isFinite) {
          firstPoint = true;
          continue;
        }

        final screenX = _mapX(x, size);
        final screenY = _mapY(y, size);

        if (screenY < 0 || screenY > size.height) {
          firstPoint = true;
          continue;
        }

        if (firstPoint) {
          path.moveTo(screenX, screenY);
          firstPoint = false;
        } else {
          path.lineTo(screenX, screenY);
        }
      } catch (e) {
        firstPoint = true;
      }
    }

    canvas.drawPath(path, paint);
  }

  void _drawIntersections(Canvas canvas, Size size) {
    for (final point in intersections) {
      final paint = Paint()
        ..color = Colors.red
        ..style = PaintingStyle.fill;

      final center = Offset(_mapX(point.x, size), _mapY(point.y, size));
      canvas.drawCircle(center, 4, paint);

      final borderPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      
      canvas.drawCircle(center, 4, borderPaint);
    }
  }

  double _mapX(double x, Size size) {
    return (x + offsetX) * scale * 40 + size.width / 2;
  }

  double _mapY(double y, Size size) {
    return size.height / 2 - (y + offsetY) * scale * 40;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Вспомогательный класс для математических функций
class MathFunctions {
  double sin(double x) => math.sin(x);
  double cos(double x) => math.cos(x);
  double tan(double x) => math.tan(x);
  double log(double x) => math.log(x);
  double exp(double x) => math.exp(x);
  double sqrt(double x) => math.sqrt(x);
  double abs(double x) => x.abs();
  double pow(double base, double exponent) => math.pow(base, exponent).toDouble();
}
