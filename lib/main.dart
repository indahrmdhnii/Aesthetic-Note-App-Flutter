import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

// App Constants
class AppConstants {
  static const String appName = 'NoteFlow';
  static const String dbName = 'noteflow.db';
}

// Model untuk Note
class Note {
  final int? id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  Note({
    this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'],
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']),
    );
  }

  Note copyWith({
    int? id,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// Database Helper
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String dbPath = path.join(await getDatabasesPath(), AppConstants.dbName);
    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE notes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
  }

  Future<int> insertNote(Note note) async {
    final db = await database;
    return await db.insert('notes', note.toMap());
  }

  Future<List<Note>> getNotes() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'notes',
      orderBy: 'updated_at DESC',
    );
    return List.generate(maps.length, (i) => Note.fromMap(maps[i]));
  }

  Future<List<Note>> searchNotes(String query) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'notes',
      where: 'title LIKE ? OR content LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'updated_at DESC',
    );
    return List.generate(maps.length, (i) => Note.fromMap(maps[i]));
  }

  Future<int> updateNote(Note note) async {
    final db = await database;
    return await db.update(
      'notes',
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  Future<int> deleteNote(int id) async {
    final db = await database;
    return await db.delete(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

// State Management dengan Inherited Widget
class NotesState extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Note> _notes = [];
  List<Note> _filteredNotes = [];
  bool _isLoading = false;
  String _searchQuery = '';

  List<Note> get notes => _filteredNotes;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;

  Future<void> loadNotes() async {
    _isLoading = true;
    notifyListeners();

    try {
      _notes = await _dbHelper.getNotes();
      _filteredNotes = _notes;
    } catch (e) {
      print('Error loading notes: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addNote(String title, String content) async {
    final now = DateTime.now();
    final note = Note(
      title: title,
      content: content,
      createdAt: now,
      updatedAt: now,
    );

    try {
      await _dbHelper.insertNote(note);
      await loadNotes();
    } catch (e) {
      print('Error adding note: $e');
    }
  }

  Future<void> updateNote(int id, String title, String content) async {
    final existingNote = _notes.firstWhere((note) => note.id == id);
    final updatedNote = existingNote.copyWith(
      title: title,
      content: content,
      updatedAt: DateTime.now(),
    );

    try {
      await _dbHelper.updateNote(updatedNote);
      await loadNotes();
    } catch (e) {
      print('Error updating note: $e');
    }
  }

  Future<void> deleteNote(int id) async {
    try {
      await _dbHelper.deleteNote(id);
      await loadNotes();
    } catch (e) {
      print('Error deleting note: $e');
    }
  }

  void searchNotes(String query) {
    _searchQuery = query;
    if (query.isEmpty) {
      _filteredNotes = _notes;
    } else {
      _filteredNotes = _notes
          .where((note) =>
              note.title.toLowerCase().contains(query.toLowerCase()) ||
              note.content.toLowerCase().contains(query.toLowerCase()))
          .toList();
    }
    notifyListeners();
  }

  void clearSearch() {
    _searchQuery = '';
    _filteredNotes = _notes;
    notifyListeners();
  }
}

class NotesInheritedWidget extends InheritedNotifier<NotesState> {
  const NotesInheritedWidget({
    Key? key,
    required NotesState notesState,
    required Widget child,
  }) : super(key: key, notifier: notesState, child: child);

  static NotesState? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<NotesInheritedWidget>()
        ?.notifier;
  }
}

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return NotesInheritedWidget(
      notesState: NotesState(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: AppConstants.appName,
        theme: ThemeData(
          primarySwatch: Colors.brown,
          textTheme: GoogleFonts.poppinsTextTheme(),
          appBarTheme: const AppBarTheme(
            elevation: 0,
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
          ),
        ),
        home: const NotesHomePage(),
      ),
    );
  }
}

class NotesHomePage extends StatefulWidget {
  const NotesHomePage({Key? key}) : super(key: key);

  @override
  State<NotesHomePage> createState() => _NotesHomePageState();
}

class _NotesHomePageState extends State<NotesHomePage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotesInheritedWidget.of(context)?.loadNotes();
    });
  }

  @override
  Widget build(BuildContext context) {
    final notesState = NotesInheritedWidget.of(context)!;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF8B4513), // Saddle Brown
              Color(0xFFA0522D), // Sienna
              Color(0xFFCD853F), // Peru
              Color(0xFFD2B48C), // Tan
            ],
          ),
        ),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 140,
              floating: false,
              pinned: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  'Catatan Saya',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    shadows: [
                      Shadow(
                        offset: Offset(1, 1),
                        blurRadius: 3,
                        color: Colors.black26,
                      ),
                    ],
                  ),
                ),
                titlePadding: EdgeInsets.only(left: 20, bottom: 16),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF6F4E37), // Coffee
                        Color(0xFF8B4513), // Saddle Brown
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.9),
                        Colors.brown[50]!.withOpacity(0.9),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        spreadRadius: 2,
                        blurRadius: 15,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: notesState.searchNotes,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.brown[800],
                    ),
                    decoration: InputDecoration(
                      hintText: 'Cari catatan...',
                      hintStyle: GoogleFonts.poppins(
                        color: Colors.brown[400],
                      ),
                      prefixIcon: Icon(Icons.search, color: Colors.brown[700]),
                      suffixIcon: notesState.searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, color: Colors.brown[600]),
                              onPressed: () {
                                _searchController.clear();
                                notesState.clearSearch();
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            notesState.isLoading
                ? SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        strokeWidth: 3,
                      ),
                    ),
                  )
                : notesState.notes.isEmpty
                    ? SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(50),
                                ),
                                child: Icon(
                                  Icons.note_add_outlined,
                                  size: 60,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 20),
                              Text(
                                notesState.searchQuery.isEmpty
                                    ? 'Belum ada catatan'
                                    : 'Tidak ada catatan yang cocok',
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                notesState.searchQuery.isEmpty
                                    ? 'Tap tombol + untuk membuat catatan pertama'
                                    : 'Coba kata kunci yang berbeda',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : SliverPadding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final note = notesState.notes[index];
                              return Padding(
                                padding: EdgeInsets.only(bottom: 15),
                                child: NoteCard(note: note),
                              );
                            },
                            childCount: notesState.notes.length,
                          ),
                        ),
                      ),
            SliverToBoxAdapter(
              child: SizedBox(height: 100), // Space for FAB
            ),
          ],
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              Color(0xFF6F4E37), // Coffee
              Color(0xFF8B4513), // Saddle Brown
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              spreadRadius: 2,
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddEditNotePage(),
              ),
            );
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: Icon(Icons.add, color: Colors.white, size: 24),
          label: Text(
            'Buat Catatan',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}

class NoteCard extends StatelessWidget {
  final Note note;

  const NoteCard({Key? key, required this.note}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final notesState = NotesInheritedWidget.of(context)!;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Colors.brown[50]!,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddEditNotePage(note: note),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        note.title,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.brown[800],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.brown[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, color: Colors.brown[600]),
                        itemBuilder: (BuildContext context) => [
                          PopupMenuItem<String>(
                            child: Row(
                              children: [
                                Icon(Icons.edit,
                                    color: Colors.brown[700], size: 20),
                                SizedBox(width: 8),
                                Text('Edit', style: GoogleFonts.poppins()),
                              ],
                            ),
                            value: 'edit',
                          ),
                          PopupMenuItem<String>(
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Colors.red, size: 20),
                                SizedBox(width: 8),
                                Text('Hapus', style: GoogleFonts.poppins()),
                              ],
                            ),
                            value: 'delete',
                          ),
                        ],
                        onSelected: (String value) {
                          if (value == 'edit') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    AddEditNotePage(note: note),
                              ),
                            );
                          } else if (value == 'delete') {
                            _showDeleteDialog(context, notesState);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Text(
                  note.content,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.brown[600],
                    height: 1.5,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.brown[200]!,
                        Colors.brown[100]!,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    DateFormat('dd MMM yyyy, HH:mm').format(note.updatedAt),
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.brown[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, NotesState notesState) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.white,
          title: Text(
            'Hapus Catatan',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: Colors.brown[800],
            ),
          ),
          content: Text(
            'Apakah Anda yakin ingin menghapus catatan ini?',
            style: GoogleFonts.poppins(
              color: Colors.brown[600],
            ),
          ),
          actions: [
            TextButton(
              child: Text(
                'Batal',
                style: GoogleFonts.poppins(
                  color: Colors.brown[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red[400]!, Colors.red[600]!],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextButton(
                child: Text(
                  'Hapus',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: () {
                  notesState.deleteNote(note.id!);
                  Navigator.of(context).pop();
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class AddEditNotePage extends StatefulWidget {
  final Note? note;

  const AddEditNotePage({Key? key, this.note}) : super(key: key);

  @override
  State<AddEditNotePage> createState() => _AddEditNotePageState();
}

class _AddEditNotePageState extends State<AddEditNotePage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final FocusNode _titleFocus = FocusNode();
  final FocusNode _contentFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.note != null) {
      _titleController.text = widget.note!.title;
      _contentController.text = widget.note!.content;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _titleFocus.dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notesState = NotesInheritedWidget.of(context)!;
    final isEditing = widget.note != null;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF8B4513), // Saddle Brown
              Color(0xFFA0522D), // Sienna
              Color(0xFFCD853F), // Peru
              Color(0xFFD2B48C), // Tan
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom AppBar
              Container(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          isEditing ? 'Edit Catatan' : 'Buat Catatan',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.3),
                            Colors.white.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextButton(
                        onPressed: _saveNote,
                        child: Text(
                          'Simpan',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: Container(
                  margin: EdgeInsets.all(16),
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white,
                        Colors.brown[50]!,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        spreadRadius: 2,
                        blurRadius: 20,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _titleController,
                        focusNode: _titleFocus,
                        decoration: InputDecoration(
                          hintText: 'Judul catatan...',
                          hintStyle: GoogleFonts.poppins(
                            color: Colors.brown[300],
                            fontSize: 24,
                          ),
                          border: InputBorder.none,
                        ),
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.brown[800],
                        ),
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => _contentFocus.requestFocus(),
                      ),
                      Container(
                        height: 1,
                        margin: EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.brown[200]!,
                              Colors.brown[100]!,
                              Colors.brown[200]!,
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _contentController,
                          focusNode: _contentFocus,
                          decoration: InputDecoration(
                            hintText: 'Tulis catatan Anda di sini...',
                            hintStyle: GoogleFonts.poppins(
                              color: Colors.brown[300],
                              fontSize: 16,
                            ),
                            border: InputBorder.none,
                          ),
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.brown[700],
                            height: 1.6,
                          ),
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _saveNote() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Judul catatan tidak boleh kosong',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: Colors.red[400],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          margin: EdgeInsets.all(16),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final notesState = NotesInheritedWidget.of(context)!;

    if (widget.note != null) {
      await notesState.updateNote(widget.note!.id!, title, content);
    } else {
      await notesState.addNote(title, content);
    }

    Navigator.pop(context);
  }
}
