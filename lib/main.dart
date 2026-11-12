import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BoardApp());
}

Future<void> connect() async {
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'local-emulator-only',
      appId: '1:123456789:android:1234567890abcdef',
      messagingSenderId: '123456789',
      projectId: 'demo-hw02-board',
    ),
  );
  const host = String.fromEnvironment(
    'FIREBASE_HOST',
    defaultValue: '10.0.2.2',
  );
  await FirebaseAuth.instance.useAuthEmulator(host, 9199);
  FirebaseFirestore.instance.useFirestoreEmulator(host, 8180);
}

class BoardApp extends StatefulWidget {
  const BoardApp({super.key});
  @override
  State<BoardApp> createState() => _BoardAppState();
}

class _BoardAppState extends State<BoardApp> {
  late final startup = connect();

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Message Board',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: const Color(0xff375b94)),
    home: FutureBuilder<void>(
      future: startup,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(
              child: Text(
                'Could not start Firebase. Reopen the app after checking setup.',
              ),
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.forum_outlined, size: 52),
                  SizedBox(height: 16),
                  Text('Message Board', style: TextStyle(fontSize: 26)),
                  SizedBox(height: 16),
                  CircularProgressIndicator(),
                ],
              ),
            ),
          );
        }
        return const AuthGate();
      },
    ),
  );
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final service = AuthService();
  late final auth = service.changes;
  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: auth,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final user = snapshot.data;
      if (user == null) return AccountForm(service: service);
      return ProfileGate(key: ValueKey(user.uid), service: service, user: user);
    },
  );
}

class ProfileGate extends StatefulWidget {
  const ProfileGate({super.key, required this.service, required this.user});
  final AuthService service;
  final User user;
  @override
  State<ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<ProfileGate> {
  late final profile = FirebaseFirestore.instance
      .doc('Users/${widget.user.uid}')
      .snapshots();
  @override
  Widget build(BuildContext context) =>
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: profile,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: widget.service.signOut,
                  child: const Text('Profile unavailable. Sign out'),
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (!snapshot.data!.exists) {
            return AccountForm(service: widget.service, user: widget.user);
          }
          return MessageBoard(user: widget.user, service: widget.service);
        },
      );
}

class AccountForm extends StatefulWidget {
  const AccountForm({super.key, required this.service, this.user});
  final AuthService service;
  final User? user;
  @override
  State<AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends State<AccountForm> {
  final form = GlobalKey<FormState>();
  final first = TextEditingController();
  final last = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  bool register = false;
  bool busy = false;
  String error = '';

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = '';
    });
    try {
      final user = widget.user;
      if (user != null) {
        await widget.service.createProfile(
          user,
          first.text.trim(),
          last.text.trim(),
        );
      } else if (register) {
        await widget.service.register(
          email.text.trim(),
          password.text,
          first.text.trim(),
          last.text.trim(),
        );
      } else {
        await widget.service.signIn(email.text.trim(), password.text);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Could not finish. Check your details and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String? requiredName(String? value) =>
      (value ?? '').trim().isEmpty ? 'Enter a name.' : null;

  @override
  void dispose() {
    first.dispose();
    last.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileOnly = widget.user != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Message Board')),
      body: SafeArea(
        child: Form(
          key: form,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                profileOnly
                    ? 'Finish your profile'
                    : register
                    ? 'Create an account'
                    : 'Sign in',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              if (profileOnly || register) ...[
                TextFormField(
                  controller: first,
                  validator: requiredName,
                  decoration: const InputDecoration(labelText: 'First name'),
                ),
                TextFormField(
                  controller: last,
                  validator: requiredName,
                  decoration: const InputDecoration(labelText: 'Last name'),
                ),
              ],
              if (!profileOnly) ...[
                TextFormField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) =>
                      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                          .hasMatch(value?.trim() ?? '')
                      ? null
                      : 'Enter a valid email.',
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                TextFormField(
                  controller: password,
                  obscureText: true,
                  validator: (value) => (value?.length ?? 0) < 6
                      ? 'Use at least six characters.'
                      : null,
                  decoration: const InputDecoration(labelText: 'Password'),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: busy ? null : submit,
                child: Text(
                  profileOnly
                      ? 'Save profile'
                      : register
                      ? 'Register'
                      : 'Sign in',
                ),
              ),
              if (!profileOnly)
                TextButton(
                  onPressed: busy
                      ? null
                      : () => setState(() {
                          register = !register;
                          error = '';
                        }),
                  child: Text(
                    register ? 'Back to sign in' : 'Create an account',
                  ),
                ),
              if (profileOnly)
                TextButton(
                  onPressed: busy ? null : widget.service.signOut,
                  child: const Text('Sign out'),
                ),
              if (error.isNotEmpty) Text(error),
            ],
          ),
        ),
      ),
    );
  }
}

class MessageBoard extends StatefulWidget {
  const MessageBoard({super.key, required this.user, required this.service});
  final User user;
  final AuthService service;
  @override
  State<MessageBoard> createState() => _MessageBoardState();
}

class _MessageBoardState extends State<MessageBoard> {
  final board = BoardService();
  final composer = TextEditingController();
  final preferences = SharedPreferencesAsync();
  late final messages = board.watch();
  DocumentReference<Map<String, dynamic>>? pending;
  String? pendingText;
  bool busy = false;
  bool compact = false;

  @override
  void initState() {
    super.initState();
    preferences.getBool('board.compact').then((value) {
      if (mounted) setState(() => compact = value ?? false);
    });
  }

  Future<void> post() async {
    final text = composer.text.trim();
    if (busy || text.isEmpty || text.length > 500) return;
    if (pendingText != text) pending = board.newMessage();
    pendingText = text;
    setState(() => busy = true);
    try {
      await board.post(pending!, widget.user.uid, text);
      composer.clear();
      pending = null;
      pendingText = null;
    } catch (_) {
      notice('Could not post. Retry when connected.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void notice(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> modify(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    bool edit,
  ) async {
    String text = doc.data()['text'] as String;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(edit ? 'Edit message' : 'Delete message?'),
        content: edit
            ? TextFormField(
                initialValue: text,
                maxLength: 500,
                onChanged: (value) => text = value.trim(),
              )
            : null,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(edit ? 'Save' : 'Delete'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    try {
      if (edit) {
        if (text.trim().isEmpty || text.length > 500) {
          notice('Enter a message of 1 to 500 characters.');
          return;
        }
        await board.edit(doc.id, text);
      } else {
        await board.delete(doc.id);
      }
    } catch (_) {
      notice('The change could not be saved.');
    }
  }

  @override
  void dispose() {
    composer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Message Board'),
      actions: [
        IconButton(
          tooltip: 'Toggle compact layout',
          icon: Icon(
            compact ? Icons.view_agenda_outlined : Icons.view_list_outlined,
          ),
          onPressed: () async {
            setState(() => compact = !compact);
            await preferences.setBool('board.compact', compact);
          },
        ),
        TextButton(
          onPressed: widget.service.signOut,
          child: const Text('Sign out'),
        ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: composer,
                  enabled: !busy,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Write a message',
                  ),
                ),
                FilledButton(
                  onPressed: busy ? null : post,
                  child: Text(busy ? 'Posting…' : 'Post message'),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: messages,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('The board could not be loaded.'),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text('No messages yet.'));
                }
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    final mine = data['authorUid'] == widget.user.uid;
                    return ListTile(
                      dense: compact,
                      title: Text(data['text'] as String),
                      subtitle: Text(mine ? 'Your message' : 'Board member'),
                      trailing: mine
                          ? PopupMenuButton<bool>(
                              onSelected: (edit) => modify(doc, edit),
                              itemBuilder: (context) => const [
                                PopupMenuItem(value: true, child: Text('Edit')),
                                PopupMenuItem(
                                  value: false,
                                  child: Text('Delete'),
                                ),
                              ],
                            )
                          : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
