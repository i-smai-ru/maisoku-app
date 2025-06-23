import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // 現在のユーザー
  User? get currentUser => _auth.currentUser;

  // 認証状態の変更を監視
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // 🔐 Google サインイン
  Future<UserCredential?> signInWithGoogle() async {
    try {
      print('🔐 Google サインイン開始...');

      // Google サインインフローを起動
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        print('❌ Google サインインがキャンセルされました');
        return null;
      }

      print('✅ Google アカウント選択完了: ${googleUser.email}');

      // Google 認証情報を取得
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Firebase 認証情報を作成
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Firebase にサインイン
      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      print('✅ Firebase サインイン完了: ${userCredential.user?.uid}');
      print('📧 ユーザーメール: ${userCredential.user?.email}');

      return userCredential;
    } catch (e) {
      print('❌ Google サインインエラー: $e');
      return null;
    }
  }

  // 🔓 サインアウト
  Future<void> signOut() async {
    try {
      print('🔐 サインアウト開始...');

      await _googleSignIn.signOut();
      await _auth.signOut();

      print('✅ サインアウト完了');
    } catch (e) {
      print('❌ サインアウトエラー: $e');
    }
  }

  // 🎯 IDトークン取得
  Future<String?> getIdToken() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final token = await user.getIdToken();
        print('✅ IDトークン取得成功');
        return token;
      } catch (e) {
        print('❌ IDトークン取得エラー: $e');
        return null;
      }
    }
    print('⚠️ ユーザー未ログイン - IDトークンなし');
    return null;
  }
}
