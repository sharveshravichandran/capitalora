import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart'; // created by `flutterfire configure`

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const WealthApp());
}

class WealthApp extends StatelessWidget {
  const WealthApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'My Wealth',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
        darkTheme: ThemeData(
            colorSchemeSeed: Colors.teal,
            brightness: Brightness.dark,
            useMaterial3: true),
        home: const AuthGate(),
      );
}

/// Shows login when signed out, otherwise routes by role.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final user = snap.data;
        if (user == null) return const LoginPage();
        return RoleRouter(user: user);
      },
    );
  }
}

/// Holds the Firestore stream once, so it is not re-created on every rebuild.
class RoleRouter extends StatefulWidget {
  final User user;
  const RoleRouter({super.key, required this.user});
  @override
  State<RoleRouter> createState() => _RoleRouterState();
}

class _RoleRouterState extends State<RoleRouter> {
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _stream =
      FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .snapshots();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, doc) {
        if (doc.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final role = doc.data?.data()?['role'];
        return role == 'admin' ? const AdminPage() : HomePage(user: widget.user);
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _register = false, _busy = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = FirebaseAuth.instance;
      final email = _email.text.trim();
      final cred = _register
          ? await auth.createUserWithEmailAndPassword(
              email: email, password: _pass.text)
          : await auth.signInWithEmailAndPassword(
              email: email, password: _pass.text);
      await _recordLogin(cred.user!);
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? e.code);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Saves email + last login + login count. Role is only set on first create.
  Future<void> _recordLogin(User u) async {
    final ref = FirebaseFirestore.instance.collection('users').doc(u.uid);
    final snap = await ref.get();
    if (snap.exists) {
      await ref.update({
        'email': u.email,
        'lastLogin': FieldValue.serverTimestamp(),
        'loginCount': FieldValue.increment(1),
      });
    } else {
      await ref.set({
        'email': u.email,
        'role': 'user',
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
        'loginCount': 1,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(24),
              children: [
                Text('My Wealth',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 4),
                Text(_register ? 'Create your account' : 'Sign in'),
                const SizedBox(height: 20),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                      labelText: 'Email', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _pass,
                  obscureText: true,
                  onSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                      labelText: 'Password (6+ characters)',
                      border: OutlineInputBorder()),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Text(_busy
                      ? 'Please wait…'
                      : _register
                          ? 'Create account'
                          : 'Sign in'),
                ),
                TextButton(
                  onPressed: () => setState(() => _register = !_register),
                  child: Text(_register
                      ? 'Have an account? Sign in'
                      : 'New here? Create account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Regular user screen. Put your assets / salary / savings screens here.
class HomePage extends StatelessWidget {
  final User user;
  const HomePage({super.key, required this.user});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('My Wealth'), actions: [
          IconButton(
              onPressed: FirebaseAuth.instance.signOut,
              icon: const Icon(Icons.logout))
        ]),
        body: Center(child: Text('Welcome, ${user.email}')),
      );
}

/// Admin screen: only lists who has logged in (email, last login, count).
class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  static final Stream<QuerySnapshot<Map<String, dynamic>>> _usersStream =
      FirebaseFirestore.instance
          .collection('users')
          .orderBy('lastLogin', descending: true)
          .snapshots();

  String _fmt(Timestamp? t) {
    if (t == null) return '-';
    final d = t.toDate().toLocal();
    String p(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${p(d.month)}-${p(d.day)} ${p(d.hour)}:${p(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin: logged-in users'), actions: [
        IconButton(
            onPressed: FirebaseAuth.instance.signOut,
            icon: const Icon(Icons.logout))
      ]),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _usersStream,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!.docs;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('${docs.length} users',
                      style: Theme.of(context).textTheme.titleMedium)),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final u = docs[i].data();
                  return ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(u['email'] ?? '-'),
                    subtitle: Text(
                        'Last login: ${_fmt(u['lastLogin'] as Timestamp?)}  ·  Logins: ${u['loginCount'] ?? 0}'),
                    trailing: u['role'] == 'admin'
                        ? const Chip(label: Text('admin'))
                        : null,
                  );
                },
              ),
            ),
          ]);
        },
      ),
    );
  }
}