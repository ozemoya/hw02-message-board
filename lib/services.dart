import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  Stream<User?> get changes => _auth.authStateChanges();

  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> register(
    String email,
    String password,
    String first,
    String last,
  ) async {
    final result = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    try {
      await createProfile(result.user!, first, last);
    } catch (_) {
      await _auth.signOut();
      rethrow;
    }
  }

  Future<void> createProfile(User user, String first, String last) async {
    await _db.collection('Users').doc(user.uid).set({
      'uid': user.uid,
      'firstName': first,
      'lastName': last,
      'role': 'member',
      'registrationDateTime': FieldValue.serverTimestamp(),
    });
  }

  Future<void> signOut() => _auth.signOut();
}

class BoardService {
  final _messages = FirebaseFirestore.instance.collection('Messages');

  Stream<QuerySnapshot<Map<String, dynamic>>> watch() =>
      _messages.orderBy('createdAt', descending: true).snapshots();

  DocumentReference<Map<String, dynamic>> newMessage() => _messages.doc();

  Future<void> post(
    DocumentReference<Map<String, dynamic>> ref,
    String uid,
    String text,
  ) => FirebaseFirestore.instance.runTransaction((transaction) async {
    if ((await transaction.get(ref)).exists) return;
    transaction.set(ref, {
      'authorUid': uid,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  });

  Future<void> edit(String id, String text) => _messages.doc(id).update({
    'text': text,
    'updatedAt': FieldValue.serverTimestamp(),
  });

  Future<void> delete(String id) => _messages.doc(id).delete();
}
