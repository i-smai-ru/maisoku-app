// lib/screens/my_page_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/user_preference_service.dart';
import '../services/audio_service.dart';
import '../models/user_preference_model.dart';
import 'widgets/preference_setting_widget.dart';
import '../utils/constants.dart';

class MyPageScreen extends StatefulWidget {
  final FirestoreService firestoreService;
  final User? currentUser;
  final AudioService audioService;

  const MyPageScreen({
    Key? key,
    required this.firestoreService,
    this.currentUser,
    required this.audioService,
  }) : super(key: key);

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  final AuthService _authService = AuthService();
  bool _audioEnabled = true;
  bool _isLoadingAudioSetting = true;
  bool _isProcessingWithdrawal = false;

  // 🆕 好み設定関連
  UserPreferenceModel? _userPreferences;
  bool _isLoadingPreferences = true;
  bool _isSavingPreferences = false;
  UserPreferenceModel? _pendingPreferences; // 保存待ちの設定

  late final UserPreferenceService _userPreferenceService;

  @override
  void initState() {
    super.initState();
    _userPreferenceService =
        UserPreferenceService(firestoreService: widget.firestoreService);

    if (widget.currentUser != null) {
      _loadAudioSetting();
      _loadUserPreferences();
    } else {
      _isLoadingAudioSetting = false;
      _isLoadingPreferences = false;
    }
  }

  Future<void> _loadAudioSetting() async {
    if (widget.currentUser == null) {
      if (mounted) setState(() => _isLoadingAudioSetting = false);
      return;
    }
    try {
      _audioEnabled = await widget.firestoreService
          .getUserAudioSetting(widget.currentUser!.uid);
    } catch (e) {
      print('音声設定読み込みエラー: $e');
    }
    if (mounted) {
      setState(() {
        _isLoadingAudioSetting = false;
      });
    }
  }

  Future<void> _loadUserPreferences() async {
    if (widget.currentUser == null) {
      if (mounted) setState(() => _isLoadingPreferences = false);
      return;
    }

    try {
      final preferences = await _userPreferenceService
          .getUserPreferences(widget.currentUser!.uid);

      if (mounted) {
        setState(() {
          _userPreferences = preferences;
          _pendingPreferences = preferences; // 初期値として設定
          _isLoadingPreferences = false;
        });
      }
    } catch (e) {
      print('好み設定読み込みエラー: $e');
      if (mounted) {
        setState(() {
          _userPreferences = UserPreferenceModel(updatedAt: DateTime.now());
          _pendingPreferences = _userPreferences;
          _isLoadingPreferences = false;
        });
      }
    }
  }

  Future<void> _saveUserPreferences() async {
    if (widget.currentUser == null || _pendingPreferences == null) return;

    setState(() {
      _isSavingPreferences = true;
    });

    try {
      final success = await _userPreferenceService.saveUserPreferences(
        widget.currentUser!.uid,
        _pendingPreferences!.copyWith(updatedAt: DateTime.now()),
      );

      if (success) {
        setState(() {
          _userPreferences = _pendingPreferences;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('好み設定を保存しました'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('好み設定の保存に失敗しました'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('好み設定保存エラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存エラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSavingPreferences = false;
        });
      }
    }
  }

  void _onPreferencesChanged(UserPreferenceModel newPreferences) {
    setState(() {
      _pendingPreferences = newPreferences;
    });
  }

  bool get _hasUnsavedChanges {
    if (_userPreferences == null || _pendingPreferences == null) return false;
    return _userPreferences!.toJson().toString() !=
        _pendingPreferences!.toJson().toString();
  }

  Future<void> _withdrawAccount() async {
    if (widget.currentUser == null) return;

    setState(() {
      _isProcessingWithdrawal = true;
    });

    try {
      await widget.firestoreService.withdrawUser(widget.currentUser!.uid);

      // signOut()はFuture<void>なので、戻り値をboolとして扱わない
      await _authService.signOut();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('退会処理が完了しました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('退会処理エラー: $e');
      if (mounted) {
        setState(() {
          _isProcessingWithdrawal = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('退会処理でエラーが発生しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showWithdrawalConfirmDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('退会確認'),
          content: const Text(
            'アカウントを削除しますか？\n\n'
            '・すべての分析履歴が削除されます\n'
            '・好み設定も削除されます\n'
            '・この操作は取り消せません\n'
            '・削除処理は完了まで時間がかかる場合があります',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _withdrawAccount();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('退会する'),
            ),
          ],
        );
      },
    );
  }

  void _showUnsavedChangesDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('未保存の変更があります'),
          content: const Text('好み設定に変更があります。保存しますか？'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _pendingPreferences = _userPreferences;
                });
              },
              child: const Text('破棄'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _saveUserPreferences();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.green),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? displayUser = widget.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('マイページ'),
        actions: [
          if (_hasUnsavedChanges)
            IconButton(
              icon: Icon(Icons.save, color: Colors.green[600]),
              onPressed: _isSavingPreferences ? null : _saveUserPreferences,
              tooltip: '好み設定を保存',
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // プロフィール情報
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.green[50],
              child: Column(
                children: [
                  if (displayUser?.photoURL != null &&
                      displayUser!.photoURL!.isNotEmpty)
                    CircleAvatar(
                      radius: 40,
                      backgroundImage: NetworkImage(displayUser.photoURL!),
                      onBackgroundImageError: (exception, stackTrace) {
                        print('プロフィール画像読み込みエラー: $exception');
                      },
                    ),
                  if (displayUser?.photoURL != null &&
                      displayUser!.photoURL!.isNotEmpty)
                    const SizedBox(height: 16),
                  Text(
                    displayUser?.displayName ?? "取得できません",
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    displayUser?.email ?? "取得できません",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 基本設定セクション
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        '基本設定',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                    const Divider(height: 1),

                    // 音声設定
                    if (_isLoadingAudioSetting)
                      const ListTile(
                        leading: Icon(Icons.volume_up),
                        title: Text('音声機能'),
                        trailing: CircularProgressIndicator(),
                      )
                    else
                      SwitchListTile(
                        secondary: const Icon(Icons.volume_up),
                        title: const Text('音声機能'),
                        subtitle: const Text('分析結果の音声読み上げ'),
                        value: _audioEnabled,
                        onChanged: (displayUser == null)
                            ? null
                            : (bool newValue) async {
                                setState(() {
                                  _audioEnabled = newValue;
                                });
                                try {
                                  await widget.firestoreService
                                      .updateUserAudioSetting(
                                    displayUser!.uid,
                                    newValue,
                                  );
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(
                                              '音声設定を${newValue ? "有効" : "無効"}に変更しました')),
                                    );
                                  }
                                } catch (e) {
                                  print('音声設定更新エラー: $e');
                                  if (mounted) {
                                    setState(() {
                                      _audioEnabled = !newValue;
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text('音声設定の更新に失敗しました。')),
                                    );
                                  }
                                }
                              },
                        activeColor: Colors.green[600],
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 好み設定セクション
            if (_isLoadingPreferences)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('好み設定を読み込んでいます...'),
                    ],
                  ),
                ),
              )
            else if (_pendingPreferences != null)
              PreferenceSettingWidget(
                initialPreferences: _pendingPreferences!,
                onPreferencesChanged: _onPreferencesChanged,
              ),

            const SizedBox(height: 24),

            // 保存ボタン（変更がある場合のみ表示）
            if (_hasUnsavedChanges)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed:
                        _isSavingPreferences ? null : _saveUserPreferences,
                    icon: _isSavingPreferences
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(_isSavingPreferences ? '保存中...' : '好み設定を保存'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 32),

            // アカウント管理セクション
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // ログアウトボタン
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        if (_hasUnsavedChanges) {
                          _showUnsavedChangesDialog();
                          return;
                        }

                        try {
                          // signOut()はFuture<void>なので、戻り値をboolとして扱わない
                          await _authService.signOut();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('ログアウトしました'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                          print('ログアウト処理完了');
                        } catch (e) {
                          print('ログアウトエラー: $e');
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('ログアウトエラー: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.logout),
                      label: const Text('ログアウト'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 退会ボタン
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isProcessingWithdrawal
                          ? null
                          : _showWithdrawalConfirmDialog,
                      icon: _isProcessingWithdrawal
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.delete_forever),
                      label: Text(_isProcessingWithdrawal ? '退会処理中...' : '退会'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[50],
                        foregroundColor: Colors.red[700],
                        side: BorderSide(color: Colors.red[300]!),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 注意事項
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.orange[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '退会すると、すべての分析履歴、好み設定、アカウント情報が削除されます。この操作は取り消せません。',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
