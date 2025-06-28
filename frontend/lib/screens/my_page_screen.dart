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

class _MyPageScreenState extends State<MyPageScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  bool _audioEnabled = true;
  bool _isLoadingAudioSetting = true;
  bool _isProcessingWithdrawal = false;

  // Maisoku AI v1.0: 拡張好み設定関連
  UserPreferenceModel? _userPreferences;
  bool _isLoadingPreferences = true;
  bool _isSavingPreferences = false;
  UserPreferenceModel? _pendingPreferences; // 保存待ちの設定

  late final UserPreferenceService _userPreferenceService;
  late TabController _tabController;

  // Maisoku AI v1.0: 設定表示モード
  bool _isDetailedMode = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
          _pendingPreferences = preferences ??
              UserPreferenceModel(updatedAt: DateTime.now()); // 初期値として設定
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
      print('🔧 好み設定保存開始: ${widget.currentUser!.uid}');
      print('🔧 設定内容: ${_pendingPreferences!.toJson()}');

      final success = await _userPreferenceService.saveUserPreferences(
        widget.currentUser!.uid,
        _pendingPreferences!.copyWith(updatedAt: DateTime.now()),
      );

      if (success) {
        setState(() {
          _userPreferences = _pendingPreferences;
        });

        if (mounted) {
          print('✅ 好み設定保存成功');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('好み設定を保存しました'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          print('❌ 好み設定保存失敗');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('好み設定の保存に失敗しました'),
                ],
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ 好み設定保存エラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('保存エラー: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
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
            '・すべての好み設定が削除されます\n'
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
          content: const Text('詳細好み設定に変更があります。保存しますか？'),
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
          // 🆕 変更状態表示インジケーター
          if (_hasUnsavedChanges)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange[300]!),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit, color: Colors.orange[700], size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '未保存',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'detailed_mode') {
                setState(() {
                  _isDetailedMode = !_isDetailedMode;
                });
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'detailed_mode',
                child: Row(
                  children: [
                    Icon(
                      _isDetailedMode ? Icons.toggle_on : Icons.toggle_off,
                      color: _isDetailedMode
                          ? Colors.green[600]
                          : Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Text(_isDetailedMode ? '詳細設定 ON' : '詳細設定 OFF'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.green[700],
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: Colors.green[600],
          tabs: const [
            Tab(icon: Icon(Icons.person), text: 'プロフィール'),
            Tab(icon: Icon(Icons.tune), text: '好み設定'),
            Tab(icon: Icon(Icons.settings), text: '設定'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // プロフィールタブ
          _buildProfileTab(displayUser),

          // 🆕 好み設定タブ（保存ボタン付き）
          _buildPreferencesTabWithSaveButton(),

          // 設定タブ
          _buildSettingsTab(displayUser),
        ],
      ),
    );
  }

  // 🆕 保存ボタン付き好み設定タブ
  Widget _buildPreferencesTabWithSaveButton() {
    if (_isLoadingPreferences) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('好み設定を読み込んでいます...'),
          ],
        ),
      );
    }

    if (_pendingPreferences == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text('好み設定の読み込みに失敗しました'),
          ],
        ),
      );
    }

    return Column(
      children: [
        // メイン設定エリア
        Expanded(
          child: _isDetailedMode
              ? PreferenceSettingWidget(
                  initialPreferences: _pendingPreferences!,
                  onPreferencesChanged: _onPreferencesChanged,
                )
              : _buildBasicPreferencesDisplay(),
        ),

        // 🆕 固定保存エリア
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // 🆕 設定状態インジケーター
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _hasUnsavedChanges
                        ? Colors.orange[50]
                        : Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _hasUnsavedChanges
                          ? Colors.orange[200]!
                          : Colors.green[200]!,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _hasUnsavedChanges
                            ? Icons.edit_note
                            : Icons.check_circle_outline,
                        color: _hasUnsavedChanges
                            ? Colors.orange[600]
                            : Colors.green[600],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _hasUnsavedChanges
                              ? '設定に変更があります。保存ボタンを押して保存してください。'
                              : '設定は保存済みです。変更すると自動で検出されます。',
                          style: TextStyle(
                            fontSize: 13,
                            color: _hasUnsavedChanges
                                ? Colors.orange[700]
                                : Colors.green[700],
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // 🆕 保存ボタン（常時表示）
                SizedBox(
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
                        : const Icon(Icons.save, size: 20),
                    label: Text(
                      _isSavingPreferences
                          ? '保存中...'
                          : _hasUnsavedChanges
                              ? '好み設定を保存'
                              : '好み設定を保存', // 常に同じテキスト
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _hasUnsavedChanges
                          ? Colors.green[600]
                          : Colors.green[500],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: _hasUnsavedChanges ? 4 : 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileTab(User? displayUser) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Maisoku AI v1.0: プロフィール情報
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.green[400]!, Colors.green[600]!],
              ),
            ),
            child: Column(
              children: [
                if (displayUser?.photoURL != null &&
                    displayUser!.photoURL!.isNotEmpty)
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: NetworkImage(displayUser.photoURL!),
                    onBackgroundImageError: (exception, stackTrace) {
                      print('プロフィール画像読み込みエラー: $exception');
                    },
                  )
                else
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    child: Icon(
                      Icons.person,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  displayUser?.displayName ?? "ユーザー名なし",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  displayUser?.email ?? "取得できません",
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Maisoku AI v1.0: 好み設定保存機能修正版',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Maisoku AI v1.0: 設定概要
          if (_pendingPreferences != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildPreferencesOverviewCard(),
            ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab(User? displayUser) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 基本設定セクション
          _buildSettingsSection(
            title: '基本設定',
            children: [
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
                                    '音声設定を${newValue ? "有効" : "無効"}に変更しました',
                                  ),
                                ),
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
                                  content: Text('音声設定の更新に失敗しました。'),
                                ),
                              );
                            }
                          }
                        },
                  activeColor: Colors.green[600],
                ),
            ],
          ),

          const SizedBox(height: 24),

          // アカウント管理セクション
          _buildSettingsSection(
            title: 'アカウント管理',
            children: [
              // ログアウトボタン
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('ログアウト'),
                onTap: () async {
                  if (_hasUnsavedChanges) {
                    _showUnsavedChangesDialog();
                    return;
                  }

                  try {
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
              ),

              // 退会ボタン
              ListTile(
                leading: Icon(Icons.delete_forever, color: Colors.red[600]),
                title: Text(
                  '退会',
                  style: TextStyle(color: Colors.red[600]),
                ),
                onTap: _isProcessingWithdrawal
                    ? null
                    : _showWithdrawalConfirmDialog,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Maisoku AI v1.0: 注意事項
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '退会すると、すべての好み設定、アカウント情報が削除されます。この操作は取り消せません。',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange[800],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
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
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }

  Widget _buildPreferencesOverviewCard() {
    final completeness = _getPreferenceCompleteness();

    return Container(
      padding: const EdgeInsets.all(16),
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
          Row(
            children: [
              Icon(Icons.tune, color: Colors.green[600], size: 24),
              const SizedBox(width: 8),
              Text(
                'Maisoku AI v1.0 好み設定概要',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '設定完了度: ${(completeness * 100).round()}%',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: completeness,
            backgroundColor: Colors.green[200],
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green[600]!),
          ),
          const SizedBox(height: 16),
          Text(
            _getCompletenessMessage(completeness),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicPreferencesDisplay() {
    if (_pendingPreferences == null) {
      return const Center(child: Text('設定が読み込まれていません'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // モード切り替え説明
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[600], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Maisoku AI v1.0 好み設定モード',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '現在は基本設定モードです。右上のメニューから「詳細設定」をONにすると、'
                  'より詳細な好み設定（予算範囲、間取り、設備、働き方など）が設定できます。',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue[700],
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _isDetailedMode = true;
                      });
                    },
                    icon: const Icon(Icons.upgrade),
                    label: const Text('詳細設定モードに切り替え'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 基本設定の表示
          Container(
            padding: const EdgeInsets.all(16),
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
                Text(
                  '現在の基本設定',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 16),
                _buildPreferenceItem(
                  '👨‍👩‍👧‍👦 ライフスタイル',
                  _pendingPreferences!.lifestyleType.isEmpty
                      ? '未設定'
                      : AppConstants.LIFESTYLE_TYPES[
                              _pendingPreferences!.lifestyleType] ??
                          _pendingPreferences!.lifestyleType,
                ),
                _buildPreferenceItem(
                  '💰 予算優先度',
                  _pendingPreferences!.budgetPriority.isEmpty
                      ? '未設定'
                      : AppConstants.BUDGET_PRIORITIES[
                              _pendingPreferences!.budgetPriority] ??
                          _pendingPreferences!.budgetPriority,
                ),
                _buildPreferenceItem(
                  '🚇 交通重視',
                  _getTransportPreferences(),
                ),
                _buildPreferenceItem(
                  '🏪 施設重視',
                  _getFacilityPreferences(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferenceItem(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getTransportPreferences() {
    final prefs = <String>[];
    if (_pendingPreferences!.prioritizeStationAccess) prefs.add('駅近');
    if (_pendingPreferences!.prioritizeMultipleLines) prefs.add('複数路線');
    if (_pendingPreferences!.prioritizeCarAccess) prefs.add('車移動');
    return prefs.isEmpty ? '未設定' : prefs.join('・');
  }

  String _getFacilityPreferences() {
    final prefs = <String>[];
    if (_pendingPreferences!.prioritizeMedical) prefs.add('医療');
    if (_pendingPreferences!.prioritizeShopping) prefs.add('商業');
    if (_pendingPreferences!.prioritizeEducation) prefs.add('教育');
    if (_pendingPreferences!.prioritizeParks) prefs.add('公園');
    return prefs.isEmpty ? '未設定' : prefs.join('・');
  }

  double _getPreferenceCompleteness() {
    if (_pendingPreferences == null) return 0.0;

    int totalFields = 10; // 主要設定項目数
    int filledFields = 0;

    if (_pendingPreferences!.lifestyleType.isNotEmpty) filledFields++;
    if (_pendingPreferences!.budgetPriority.isNotEmpty) filledFields++;
    if (_pendingPreferences!.prioritizeStationAccess) filledFields++;
    if (_pendingPreferences!.prioritizeMultipleLines) filledFields++;
    if (_pendingPreferences!.prioritizeCarAccess) filledFields++;
    if (_pendingPreferences!.prioritizeMedical) filledFields++;
    if (_pendingPreferences!.prioritizeShopping) filledFields++;
    if (_pendingPreferences!.prioritizeEducation) filledFields++;
    if (_pendingPreferences!.prioritizeParks) filledFields++;

    // Maisoku AI v1.0: 詳細設定モードでは更に項目が増える想定
    if (_isDetailedMode) {
      totalFields = 15; // 詳細モードでは項目数を増加
    }

    return filledFields / totalFields;
  }

  String _getCompletenessMessage(double completeness) {
    if (completeness >= 0.8) {
      return 'Maisoku AI v1.0: 詳細な好み設定が完了しています。AI分析でより個人化された結果を提供できます。';
    } else if (completeness >= 0.5) {
      return 'Maisoku AI v1.0: 基本的な好み設定は完了していますが、詳細設定モードでより精度の高いAI分析が可能です。';
    } else {
      return 'Maisoku AI v1.0: 好み設定をより詳しく行うことで、あなたに最適化されたAI分析結果を提供できます。';
    }
  }
}
