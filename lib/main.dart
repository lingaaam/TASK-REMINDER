import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class Task {
  final String id;
  final String title;
  final String description;
  final DateTime scheduledTime;

  Task({required this.id, required this.title, required this.description, required this.scheduledTime});

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'description': description,
    'scheduledTime': scheduledTime.toIso8601String(),
  };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
    id: json['id'], title: json['title'],
    description: json['description'] ?? '',
    scheduledTime: DateTime.parse(json['scheduledTime']),
  );
}

class NativeAlarm {
  static const _ch = MethodChannel('com.example.task_reminder/alarm');
  static Future<void> schedule(Task t) => _ch.invokeMethod('scheduleAlarm', {
    'taskId': t.id.hashCode.abs(),
    'taskTitle': t.title,
    'timeMillis': t.scheduledTime.millisecondsSinceEpoch,
  });
  static Future<void> cancel(String id) => _ch.invokeMethod('cancelAlarm', {
    'taskId': id.hashCode.abs(),
  });
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Task Reminder',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5)),
      useMaterial3: true,
    ),
    home: const HomeScreen(),
  );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeState();
}

class _HomeState extends State<HomeScreen> {
  List<Task> tasks = [];

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList('tasks') ?? [];
    setState(() {
      tasks = list.map((e) => Task.fromJson(jsonDecode(e))).toList()
        ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    });
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList('tasks', tasks.map((t) => jsonEncode(t.toJson())).toList());
  }

  Future<void> _add(Task t) async {
    setState(() {
      tasks.add(t);
      tasks.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    });
    await _save();
    await NativeAlarm.schedule(t);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🔔 "${t.title}" reminder set!'),
        backgroundColor: const Color(0xFF4F46E5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _delete(Task t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Task?'),
        content: Text('"${t.title}" delete செய்யட்டுமா?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await NativeAlarm.cancel(t.id);
      setState(() => tasks.remove(t));
      await _save();
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final upcoming = tasks.where((t) => t.scheduledTime.isAfter(now)).toList();
    final past = tasks.where((t) => t.scheduledTime.isBefore(now)).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF0F0FF),
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: 130, pinned: true,
          backgroundColor: const Color(0xFF4F46E5),
          flexibleSpace: FlexibleSpaceBar(
            title: const Text('Task Reminder',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
              ),
              child: const Align(
                alignment: Alignment(0.85, 0.0),
                child: Text('⏰', style: TextStyle(fontSize: 64)),
              ),
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(children: [
              _Chip(label: 'Upcoming', count: upcoming.length, color: const Color(0xFF4F46E5)),
              const SizedBox(width: 10),
              _Chip(label: 'Past', count: past.length, color: Colors.green),
            ]),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: const Row(children: [
                Text('🔊', style: TextStyle(fontSize: 18)),
                SizedBox(width: 8),
                Expanded(child: Text(
                  'குறிப்பிட்ட நேரத்தில் ஒலி எழுப்பி task heading இரண்டு முறை சொல்லும்!',
                  style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w500),
                )),
              ]),
            ),
          ),
        ),

        if (tasks.isEmpty) SliverFillRemaining(
          child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('📭', style: TextStyle(fontSize: 70)),
            const SizedBox(height: 16),
            const Text('No tasks yet!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
            const SizedBox(height: 8),
            Text('Tap + to add a reminder', style: TextStyle(color: Colors.grey[500])),
          ])),
        ),

        if (upcoming.isNotEmpty) ...[
          const SliverToBoxAdapter(child: Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text('⏰  Upcoming',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
          )),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(delegate: SliverChildBuilderDelegate(
              (_, i) => TaskCard(task: upcoming[i], onDelete: () => _delete(upcoming[i])),
              childCount: upcoming.length,
            )),
          ),
        ],

        if (past.isNotEmpty) ...[
          const SliverToBoxAdapter(child: Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text('✅  Past',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey)),
          )),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(delegate: SliverChildBuilderDelegate(
              (_, i) => TaskCard(task: past[i], onDelete: () => _delete(past[i]), isPast: true),
              childCount: past.length,
            )),
          ),
        ],

        const SliverToBoxAdapter(child: SizedBox(height: 90)),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final t = await Navigator.push<Task>(context, MaterialPageRoute(builder: (_) => const AddScreen()));
          if (t != null) _add(t);
        },
        backgroundColor: const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_alarm),
        label: const Text('Add Task', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label; final int count; final Color color;
  const _Chip({required this.label, required this.count, required this.color});
  @override
  Widget build(BuildContext ctx) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text('$count', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(color: color, fontSize: 13)),
    ]),
  );
}

class TaskCard extends StatelessWidget {
  final Task task; final VoidCallback onDelete; final bool isPast;
  const TaskCard({super.key, required this.task, required this.onDelete, this.isPast = false});

  @override
  Widget build(BuildContext ctx) {
    final fmt = DateFormat('dd MMM yyyy  •  hh:mm a');
    final diff = task.scheduledTime.difference(DateTime.now());
    String cd = '';
    if (!isPast) {
      if (diff.inDays > 0) cd = '${diff.inDays}d ${diff.inHours % 24}h left';
      else if (diff.inHours > 0) cd = '${diff.inHours}h ${diff.inMinutes % 60}m left';
      else if (diff.inMinutes > 0) cd = '${diff.inMinutes}m left';
      else cd = 'Due now!';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isPast ? Colors.white.withOpacity(0.5) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isPast ? Colors.grey.withOpacity(0.2) : const Color(0xFF4F46E5).withOpacity(0.2)),
        boxShadow: isPast ? [] : [BoxShadow(color: const Color(0xFF4F46E5).withOpacity(0.07), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              color: isPast ? Colors.grey.withOpacity(0.1) : const Color(0xFF4F46E5).withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(isPast ? Icons.check_circle_outline : Icons.campaign,
              color: isPast ? Colors.grey : const Color(0xFF4F46E5), size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // TITLE (Heading)
            Text(task.title, style: TextStyle(
              fontWeight: FontWeight.w800, fontSize: 16,
              color: isPast ? Colors.grey : Colors.black87,
              decoration: isPast ? TextDecoration.lineThrough : null,
            )),
            // DESCRIPTION
            if (task.description.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(task.description, style: TextStyle(
                fontSize: 13, color: isPast ? Colors.grey[400] : Colors.black54,
              )),
            ],
            const SizedBox(height: 5),
            // TIME
            Row(children: [
              Icon(Icons.access_time, size: 13, color: isPast ? Colors.grey[400] : const Color(0xFF6366F1)),
              const SizedBox(width: 4),
              Text(fmt.format(task.scheduledTime), style: TextStyle(
                fontSize: 12, color: isPast ? Colors.grey[400] : const Color(0xFF6366F1),
              )),
            ]),
            if (!isPast && cd.isNotEmpty) ...[
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: cd == 'Due now!' ? Colors.orange.withOpacity(0.15) : const Color(0xFF4F46E5).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(cd, style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: cd == 'Due now!' ? Colors.orange : const Color(0xFF4F46E5),
                )),
              ),
            ],
          ])),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
            onPressed: onDelete,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
          ),
        ]),
      ),
    );
  }
}

class AddScreen extends StatefulWidget {
  const AddScreen({super.key});
  @override State<AddScreen> createState() => _AddState();
}

class _AddState extends State<AddScreen> {
  final titleCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  DateTime? selDate;
  TimeOfDay? selTime;
  final _uuid = const Uuid();

  DateTime? get dt => selDate == null || selTime == null ? null
      : DateTime(selDate!.year, selDate!.month, selDate!.day, selTime!.hour, selTime!.minute);

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context, initialDate: DateTime.now(),
      firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF4F46E5))),
        child: child!,
      ),
    );
    if (d != null) setState(() => selDate = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context, initialTime: TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF4F46E5))),
        child: child!,
      ),
    );
    if (t != null) setState(() => selTime = t);
  }

  void _save() {
    final title = titleCtrl.text.trim();
    final desc = descCtrl.text.trim();
    if (title.isEmpty) { _snack('Task Heading உள்ளிடவும்!', Colors.red); return; }
    if (dt == null) { _snack('தேதி & நேரம் தேர்ந்தெடுக்கவும்!', Colors.red); return; }
    if (dt!.isBefore(DateTime.now())) { _snack('எதிர்கால நேரம் தேர்ந்தெடுக்கவும்!', Colors.orange); return; }
    Navigator.pop(context, Task(id: _uuid.v4(), title: title, description: desc, scheduledTime: dt!));
  }

  void _snack(String m, Color c) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(m), backgroundColor: c, behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
  );

  @override void dispose() { titleCtrl.dispose(); descCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('EEEE, dd MMM yyyy');
    final tf = DateFormat('hh:mm a');

    return Scaffold(
      backgroundColor: const Color(0xFFF0F0FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white,
        title: const Text('New Reminder', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.08), borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.green.withOpacity(0.25)),
            ),
            child: const Row(children: [
              Text('🔊', style: TextStyle(fontSize: 22)),
              SizedBox(width: 10),
              Expanded(child: Text(
                'நேரம் வந்ததும் Task Heading மட்டும்\nஇரண்டு முறை தானாகவே சொல்லும்!',
                style: TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.w600),
              )),
            ]),
          ),

          const SizedBox(height: 20),

          // HEADING
          const _Lbl(t: '📌  Task Heading (சொல்லப்படும்)'),
          const SizedBox(height: 8),
          _Card(child: TextField(
            controller: titleCtrl,
            decoration: const InputDecoration(
              hintText: 'உதாரணம்: மருந்து சாப்பிட வேண்டும்',
              border: InputBorder.none, contentPadding: EdgeInsets.all(16),
            ),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          )),

          const SizedBox(height: 16),

          // DESCRIPTION
          const _Lbl(t: '📝  Task Description (விவரம்)'),
          const SizedBox(height: 8),
          _Card(child: TextField(
            controller: descCtrl,
            maxLines: 3, minLines: 1,
            decoration: const InputDecoration(
              hintText: 'உதாரணம்: காலை மாத்திரை 2 எண்ணிக்கை சாப்பிட வேண்டும் (optional)',
              border: InputBorder.none, contentPadding: EdgeInsets.all(16),
            ),
            style: const TextStyle(fontSize: 14),
          )),

          const SizedBox(height: 16),

          // DATE
          const _Lbl(t: '📅  தேதி'),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickDate,
            child: _Card(child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                const Icon(Icons.calendar_today, color: Color(0xFF4F46E5), size: 22),
                const SizedBox(width: 12),
                Text(
                  selDate == null ? 'தேதி தேர்ந்தெடுக்கவும்' : df.format(selDate!),
                  style: TextStyle(fontSize: 15,
                    color: selDate == null ? Colors.grey : Colors.black87,
                    fontWeight: selDate == null ? FontWeight.normal : FontWeight.w600),
                ),
                const Spacer(),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ]),
            )),
          ),

          const SizedBox(height: 14),

          // TIME
          const _Lbl(t: '⏰  நேரம்'),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickTime,
            child: _Card(child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                const Icon(Icons.access_time, color: Color(0xFF4F46E5), size: 22),
                const SizedBox(width: 12),
                Text(
                  selTime == null ? 'நேரம் தேர்ந்தெடுக்கவும்'
                    : tf.format(DateTime(2000, 1, 1, selTime!.hour, selTime!.minute)),
                  style: TextStyle(fontSize: 15,
                    color: selTime == null ? Colors.grey : Colors.black87,
                    fontWeight: selTime == null ? FontWeight.normal : FontWeight.w600),
                ),
                const Spacer(),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ]),
            )),
          ),

          const SizedBox(height: 30),

          SizedBox(height: 54, child: ElevatedButton.icon(
            onPressed: _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 4,
            ),
            icon: const Icon(Icons.alarm_add),
            label: const Text('Reminder சேமிக்கவும்',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          )),
        ]),
      ),
    );
  }
}

class _Lbl extends StatelessWidget {
  final String t; const _Lbl({required this.t});
  @override Widget build(BuildContext ctx) => Text(t,
    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF374151)));
}

class _Card extends StatelessWidget {
  final Widget child; const _Card({required this.child});
  @override Widget build(BuildContext ctx) => Container(
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.15)),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: child,
  );
}
