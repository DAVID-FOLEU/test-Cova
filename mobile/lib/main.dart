import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// const String _apiBaseUrl = String.fromEnvironment(
//   'BACKEND_URL',
//   defaultValue: 'http://10.0.2.2:8080/api',
// );

import 'package:flutter/foundation.dart';

// Injection de la variable d'environnement si elle existe
const String _envUrl = String.fromEnvironment('BACKEND_URL');

// Fallback dynamique selon la plateforme
String get apiBaseUrl {
  if (_envUrl.isNotEmpty) {
    return _envUrl;
  }
  if (kIsWeb) {
    return 'http://localhost:8080/api'; // Pour Chrome / Web
  }
  if (defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:8080/api'; // Pour l'émulateur Android
  }
  return 'http://localhost:8080/api'; // iOS / Desktop / Autre
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Manager Cova',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF020817),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF818CF8),
          secondary: Color(0xFF818CF8),
          surface: Color(0xFF0F172A),
          onSurface: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF0F172A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF334155)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF334155)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF818CF8)),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F172A),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: const CovaHome(),
    );
  }
}

class CovaHome extends StatefulWidget {
  const CovaHome({super.key});

  @override
  State<CovaHome> createState() => _CovaHomeState();
}

class _CovaHomeState extends State<CovaHome> {
  CovaUserSession? session;
  bool loadingSession = false;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final savedSession = await CovaUserSession.load();
    if (!mounted) return;
    setState(() {
      session = savedSession;
      loadingSession = false;
    });
  }

  void _onLoggedIn(CovaUserSession newSession) {
    setState(() {
      session = newSession;
    });
    newSession.save();
  }

  void _onLogout() {
    CovaUserSession.clear();
    setState(() {
      session = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loadingSession) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF818CF8)),
        ),
      );
    }

    if (session == null) {
      return AuthScreen(onLoggedIn: _onLoggedIn);
    }

    return TaskManagerScreen(session: session!, onLogout: _onLogout);
  }
}

class CovaUserSession {
  final int userId;
  final String email;
  final String token;

  const CovaUserSession({
    required this.userId,
    required this.email,
    required this.token,
  });

  factory CovaUserSession.fromJson(Map<String, dynamic> json) {
    return CovaUserSession(
      userId: (json['userId'] as num?)?.toInt() ?? 0,
      email: (json['email'] ?? '').toString(),
      token: (json['token'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'email': email,
    'token': token,
  };

  static Future<CovaUserSession?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedData = prefs.getString('cova_user');
    if (savedData == null || savedData.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(savedData) as Map<String, dynamic>;
      return CovaUserSession.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cova_user', jsonEncode(toJson()));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cova_user');
  }
}

class AuthScreen extends StatefulWidget {
  final void Function(CovaUserSession) onLoggedIn;

  const AuthScreen({super.key, required this.onLoggedIn});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isRegister = false;
  bool showPassword = false;
  bool authLoading = false;
  String authError = '';

  final TextEditingController nomController = TextEditingController();
  final TextEditingController prenomController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  Future<void> _handleAuthSubmit() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty ||
        password.isEmpty ||
        (isRegister &&
            (nomController.text.trim().isEmpty ||
                prenomController.text.trim().isEmpty))) {
      setState(
        () => authError = 'Veuillez remplir tous les champs obligatoires.',
      );
      return;
    }

    setState(() {
      authError = '';
      authLoading = true;
    });

    try {
      final endpoint = isRegister ? '/auth/register' : '/auth/login';
      final payload = isRegister
          ? {
              'nom': nomController.text.trim(),
              'prenom': prenomController.text.trim(),
              'email': email,
              'password': password,
            }
          : {'email': email, 'password': password};

      final response = await http.post(
        Uri.parse('$apiBaseUrl$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode >= 400) {
        throw Exception(_parseApiError(response.body));
      }

      if (isRegister) {
        if (!mounted) return;
        setState(() {
          isRegister = false;
          authError = '';
        });
        nomController.clear();
        prenomController.clear();
        passwordController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Inscription réussie ! Vous pouvez maintenant vous connecter.',
            ),
          ),
        );
        return;
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final session = CovaUserSession.fromJson(decoded);
      widget.onLoggedIn(session);
    } catch (error) {
      setState(() {
        authError = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => authLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF1E293B)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isRegister ? 'Inscription Cova' : 'Connexion Cova',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFA5B4FC),
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                if (authError.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7F1D1D),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFEF4444)),
                    ),
                    child: Text(
                      authError,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                if (isRegister)
                  Column(
                    children: [
                      TextField(
                        controller: nomController,
                        decoration: const InputDecoration(hintText: 'Nom'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: prenomController,
                        decoration: const InputDecoration(hintText: 'Prénom'),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(hintText: 'Email'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: !showPassword,
                  decoration: InputDecoration(
                    hintText: 'Mot de passe',
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => showPassword = !showPassword),
                      icon: Icon(
                        showPassword ? Icons.visibility_off : Icons.visibility,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: authLoading ? null : _handleAuthSubmit,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: authLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(isRegister ? "S'inscrire" : 'Se connecter'),
                ),
                const SizedBox(height: 18),
                TextButton(
                  onPressed: () {
                    setState(() {
                      isRegister = !isRegister;
                      authError = '';
                    });
                  },
                  child: Text(
                    isRegister
                        ? 'Déjà un compte ? Se connecter'
                        : "Pas de compte ? S'inscrire",
                    style: const TextStyle(color: Color(0xFFCBD5E1)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TaskManagerScreen extends StatefulWidget {
  final CovaUserSession session;
  final VoidCallback onLogout;

  const TaskManagerScreen({
    super.key,
    required this.session,
    required this.onLogout,
  });

  @override
  State<TaskManagerScreen> createState() => _TaskManagerScreenState();
}

class _TaskManagerScreenState extends State<TaskManagerScreen> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController editTitleController = TextEditingController();
  final TextEditingController editDescriptionController =
      TextEditingController();

  List<CovaTask> tasks = [];
  String filterStatus = 'ALL';
  CovaTask? editingTask;
  bool isCreating = false;
  bool isUpdating = false;
  bool isLoadingTasks = false;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => isLoadingTasks = true);

    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/tasks?userId=${widget.session.userId}'),
        headers: {'Authorization': 'Bearer ${widget.session.token}'},
      );

      if (response.statusCode >= 400) {
        throw Exception(_parseApiError(response.body));
      }

      final decoded = jsonDecode(response.body) as List<dynamic>;
      final loadedTasks = decoded
          .map((item) => CovaTask.fromJson(item as Map<String, dynamic>))
          .toList();
      if (mounted) {
        setState(() => tasks = loadedTasks);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoadingTasks = false);
      }
    }
  }

  Future<void> _refreshTasks() async {
    await _loadTasks();
  }

  Future<void> _createTask() async {
    final title = titleController.text.trim();
    if (title.isEmpty) return;

    setState(() => isCreating = true);

    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/tasks?userId=${widget.session.userId}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.session.token}',
        },
        body: jsonEncode({
          'title': title,
          'description': descriptionController.text.trim(),
          'status': 'PENDING',
        }),
      );

      if (response.statusCode >= 400) {
        throw Exception(_parseApiError(response.body));
      }

      titleController.clear();
      descriptionController.clear();
      await _refreshTasks();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isCreating = false);
      }
    }
  }

  Future<void> _updateTask() async {
    final task = editingTask;
    if (task == null) return;

    final updatedTitle = editTitleController.text.trim();
    if (updatedTitle.isEmpty) return;

    setState(() => isUpdating = true);

    try {
      final response = await http.put(
        Uri.parse(
          '$apiBaseUrl/tasks/${task.id}?userId=${widget.session.userId}',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.session.token}',
        },
        body: jsonEncode({
          'id': task.id,
          'title': updatedTitle,
          'description': editDescriptionController.text.trim(),
          'status': task.status,
        }),
      );

      if (response.statusCode >= 400) {
        throw Exception(_parseApiError(response.body));
      }

      setState(() => editingTask = null);
      await _refreshTasks();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isUpdating = false);
      }
    }
  }

  Future<void> _toggleStatus(CovaTask task, String nextStatus) async {
    try {
      final response = await http.put(
        Uri.parse(
          '$apiBaseUrl/tasks/${task.id}?userId=${widget.session.userId}',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.session.token}',
        },
        body: jsonEncode({
          'id': task.id,
          'title': task.title,
          'description': task.description,
          'status': nextStatus,
        }),
      );

      if (response.statusCode >= 400) {
        throw Exception(_parseApiError(response.body));
      }

      await _refreshTasks();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    }
  }

  Future<void> _deleteTask(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$apiBaseUrl/tasks/$id?userId=${widget.session.userId}'),
        headers: {'Authorization': 'Bearer ${widget.session.token}'},
      );

      if (response.statusCode >= 400) {
        throw Exception(_parseApiError(response.body));
      }

      await _refreshTasks();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    }
  }

  List<CovaTask> get filteredTasks {
    if (filterStatus == 'ALL') {
      return tasks;
    }
    return tasks.where((task) => task.status == filterStatus).toList();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      {'key': 'ALL', 'label': 'Toutes'},
      {'key': 'PENDING', 'label': 'En attente'},
      {'key': 'IN_PROGRESS', 'label': 'En cours'},
      {'key': 'COMPLETED', 'label': 'Terminées'},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF020817),
      appBar: AppBar(
        title: const Text('Task Manager Cova'),
        actions: [
          IconButton(
            onPressed: widget.onLogout,
            tooltip: 'Déconnexion',
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF1E293B)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Task Manager Cova',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFA5B4FC),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.session.email,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFCBD5E1),
                          ),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: widget.onLogout,
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('Déconnexion'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFFCA5A5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF1E293B)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nouvelle tâche',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        hintText: 'Titre de la tâche',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        hintText: 'Description (optionnelle)',
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: isCreating ? null : _createTask,
                      icon: isCreating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.add),
                      label: const Text('Ajouter la tâche'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (editingTask != null)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFF818CF8)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Modifier la tâche',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFA5B4FC),
                            ),
                          ),
                          IconButton(
                            onPressed: () => setState(() => editingTask = null),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: editTitleController,
                        decoration: const InputDecoration(hintText: 'Titre'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: editDescriptionController,
                        decoration: const InputDecoration(
                          hintText: 'Description',
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => setState(() => editingTask = null),
                            child: const Text('Annuler'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: isUpdating ? null : _updateTask,
                            child: isUpdating
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Enregistrer'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: tabs.map((tab) {
                    final key = tab['key'] as String;
                    final isSelected = filterStatus == key;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(tab['label'] as String),
                        selected: isSelected,
                        onSelected: (_) => setState(() => filterStatus = key),
                        selectedColor: const Color(0xFF4F46E5),
                        backgroundColor: const Color(0xFF0F172A),
                        labelStyle: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFFCBD5E1),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              if (isLoadingTasks)
                const Padding(
                  padding: EdgeInsets.all(18),
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF818CF8)),
                  ),
                )
              else if (filteredTasks.isEmpty)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFF1E293B)),
                  ),
                  child: const Center(
                    child: Text(
                      'Aucune tâche ne correspond à ce filtre.',
                      style: TextStyle(color: Color(0xFF94A3B8)),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredTasks.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final task = filteredTasks[index];
                    final statusColor = switch (task.status) {
                      'COMPLETED' => const Color(0xFF10B981),
                      'IN_PROGRESS' => const Color(0xFF60A5FA),
                      _ => const Color(0xFFFBBF24),
                    };

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: task.status == 'COMPLETED'
                              ? const Color(0xFF10B981).withValues(alpha: 0.3)
                              : const Color(0xFF1E293B),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Icon(
                              task.status == 'COMPLETED'
                                  ? Icons.check_circle
                                  : task.status == 'IN_PROGRESS'
                                  ? Icons.play_circle_fill
                                  : Icons.circle_outlined,
                              color: statusColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  task.title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: task.status == 'COMPLETED'
                                        ? Colors.grey
                                        : Colors.white,
                                    decoration: task.status == 'COMPLETED'
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                                if (task.description != null &&
                                    task.description!.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    task.description!,
                                    style: const TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: statusColor.withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: Text(
                                    task.status == 'COMPLETED'
                                        ? 'Terminée'
                                        : task.status == 'IN_PROGRESS'
                                        ? 'En cours'
                                        : 'En attente',
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            alignment: WrapAlignment.end,
                            children: [
                              if (task.status != 'PENDING')
                                TextButton(
                                  onPressed: () =>
                                      _toggleStatus(task, 'PENDING'),
                                  child: const Text('Attente'),
                                ),
                              if (task.status != 'IN_PROGRESS')
                                TextButton(
                                  onPressed: () =>
                                      _toggleStatus(task, 'IN_PROGRESS'),
                                  child: const Text('En cours'),
                                ),
                              if (task.status != 'COMPLETED')
                                TextButton(
                                  onPressed: () =>
                                      _toggleStatus(task, 'COMPLETED'),
                                  child: const Text('Terminer'),
                                ),
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    editingTask = task;
                                    editTitleController.text = task.title;
                                    editDescriptionController.text =
                                        task.description ?? '';
                                  });
                                },
                                icon: const Icon(Icons.edit, size: 18),
                              ),
                              IconButton(
                                onPressed: () => _deleteTask(task.id!),
                                icon: const Icon(Icons.delete, size: 18),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class CovaTask {
  final int? id;
  final String title;
  final String? description;
  final String status;

  const CovaTask({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
  });

  factory CovaTask.fromJson(Map<String, dynamic> json) {
    return CovaTask(
      id: json['id'] as int?,
      title: (json['title'] ?? '').toString(),
      description: json['description'] as String?,
      status: (json['status'] ?? 'PENDING').toString(),
    );
  }
}

String _parseApiError(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is String) return decoded;
    if (decoded is Map<String, dynamic>) {
      return decoded['message']?.toString() ??
          decoded['error']?.toString() ??
          'Erreur serveur.';
    }
  } catch (_) {
    // ignore decode errors and return raw body
  }

  return body.isEmpty ? 'Erreur serveur' : body;
}
