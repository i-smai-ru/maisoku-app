// lib/screens/widgets/address_input_widget.dart

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/address_model.dart';
import '../../services/address_service.dart';
import '../../utils/address_validator.dart';

/// Maisoku AI v1.0: 住所入力ウィジェット
///
/// エリア分析画面で使用する住所入力UI
/// - GPS取得・手動入力・Google Places候補選択対応
/// - リアルタイムバリデーション・候補表示
/// - Cloud Run API対応・段階的認証システム対応
class AddressInputWidget extends StatefulWidget {
  /// 住所選択時のコールバック
  final Function(AddressModel) onAddressSelected;

  /// 住所サービス（GPS・Google Places・住所正規化）
  final AddressService addressService;

  /// 初期表示する住所（オプション）
  final String? initialAddress;

  /// 入力フィールドのヒントテキスト
  final String? hintText;

  /// GPS取得を有効にするか
  final bool enableGPS;

  const AddressInputWidget({
    Key? key,
    required this.onAddressSelected,
    required this.addressService,
    this.initialAddress,
    this.hintText,
    this.enableGPS = true,
  }) : super(key: key);

  @override
  State<AddressInputWidget> createState() => _AddressInputWidgetState();
}

class _AddressInputWidgetState extends State<AddressInputWidget> {
  // コントローラー・フォーカス
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  // Google Places候補 - AddressSuggestion型を使用
  List<AddressSuggestion> _suggestions = [];
  bool _isLoadingSuggestions = false;
  bool _showSuggestions = false;

  // GPS関連
  bool _isGettingLocation = false;

  // エラー・UI状態
  String _errorMessage = '';
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialAddress ?? '');
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// テキスト変更時の処理
  void _onTextChanged() {
    final String input = _controller.text;

    // リアルタイムバリデーション
    setState(() {
      _errorMessage = AddressValidator.getValidationErrorMessage(input);
    });

    // Google Places候補取得
    if (input.length >= 2 && _errorMessage.isEmpty) {
      _getSuggestions(input);
    } else {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
    }
  }

  /// フォーカス変更時の処理
  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      // フォーカスを失った場合は候補を非表示
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          setState(() {
            _showSuggestions = false;
          });
        }
      });
    }
  }

  /// Google Places候補取得
  Future<void> _getSuggestions(String input) async {
    setState(() {
      _isLoadingSuggestions = true;
    });

    try {
      final suggestions =
          await widget.addressService.getAddressSuggestions(input);

      if (mounted && _controller.text == input) {
        setState(() {
          _suggestions = suggestions;
          _showSuggestions = suggestions.isNotEmpty;
          _isLoadingSuggestions = false;
        });
      }
    } catch (e) {
      print('❌ 住所候補取得エラー: $e');
      if (mounted) {
        setState(() {
          _isLoadingSuggestions = false;
          _errorMessage = '住所候補の取得に失敗しました';
        });
      }
    }
  }

  /// GPS現在地取得
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
      _errorMessage = '';
    });

    try {
      final Position? position =
          await widget.addressService.getCurrentLocation();

      if (position != null) {
        final AddressModel? address = await widget.addressService
            .getAddressFromCoordinates(position.latitude, position.longitude);

        if (address != null) {
          setState(() {
            _controller.text = address.normalizedAddress;
            _showSuggestions = false;
          });
          widget.onAddressSelected(address);
        } else {
          setState(() {
            _errorMessage = '現在地の住所取得に失敗しました';
          });
        }
      } else {
        setState(() {
          _errorMessage = 'GPS位置の取得に失敗しました。設定から位置情報を有効にしてください。';
        });
      }
    } catch (e) {
      print('❌ GPS取得エラー: $e');
      setState(() {
        _errorMessage =
            'GPS取得中にエラーが発生しました: ${_getGPSErrorMessage(e.toString())}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isGettingLocation = false;
        });
      }
    }
  }

  /// GPSエラーメッセージを分かりやすく変換
  String _getGPSErrorMessage(String error) {
    if (error.contains('permission')) {
      return '位置情報の許可が必要です';
    } else if (error.contains('service')) {
      return '位置情報サービスが無効です';
    } else if (error.contains('timeout')) {
      return 'GPS取得がタイムアウトしました';
    }
    return 'GPS取得に失敗しました';
  }

  /// Google Places候補選択
  Future<void> _selectSuggestion(AddressSuggestion suggestion) async {
    // AddressSuggestion の description プロパティを使用
    final String description = suggestion.description;

    setState(() {
      _controller.text = description;
      _showSuggestions = false;
      _isProcessing = true;
      _errorMessage = '';
    });

    try {
      // normalizeAddress を使用して住所を処理
      final AddressModel? address =
          await widget.addressService.normalizeAddress(description);

      if (address != null) {
        widget.onAddressSelected(address);
      } else {
        setState(() {
          _errorMessage = '住所の詳細取得に失敗しました';
        });
      }
    } catch (e) {
      print('❌ 住所選択エラー: $e');
      setState(() {
        _errorMessage = '住所選択中にエラーが発生しました';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  /// 手動入力住所の処理
  Future<void> _processManualInput() async {
    final String input = _controller.text.trim();

    if (input.isEmpty) {
      setState(() {
        _errorMessage = '住所を入力してください';
      });
      return;
    }

    final validationError = AddressValidator.getValidationErrorMessage(input);
    if (validationError.isNotEmpty) {
      setState(() {
        _errorMessage = validationError;
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = '';
    });

    try {
      final AddressModel? address =
          await widget.addressService.normalizeAddress(input);

      if (address != null) {
        widget.onAddressSelected(address);
      } else {
        setState(() {
          _errorMessage = '住所の解析に失敗しました。より具体的な住所を入力してください。';
        });
      }
    } catch (e) {
      print('❌ 住所処理エラー: $e');
      setState(() {
        _errorMessage = '住所処理中にエラーが発生しました';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // タイトル
          Row(
            children: [
              Icon(Icons.location_on, color: Colors.green[600], size: 24),
              const SizedBox(width: 8),
              Text(
                '分析するエリアを教えてください',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[800],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // GPS取得ボタン（有効な場合のみ表示）
          if (widget.enableGPS) ...[
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isGettingLocation ? null : _getCurrentLocation,
                icon: _isGettingLocation
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.my_location),
                label: Text(_isGettingLocation ? 'GPS取得中...' : '現在地から取得'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 区切り線
            Row(
              children: [
                Expanded(child: Divider(color: Colors.grey[300])),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'または',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                Expanded(child: Divider(color: Colors.grey[300])),
              ],
            ),

            const SizedBox(height: 16),
          ],

          // 住所入力フィールド
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _controller,
                focusNode: _focusNode,
                decoration: InputDecoration(
                  hintText: widget.hintText ?? '住所・駅名を入力（例：渋谷駅、東京都新宿区）',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _isProcessing
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : _controller.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _controller.clear();
                                setState(() {
                                  _suggestions = [];
                                  _showSuggestions = false;
                                  _errorMessage = '';
                                });
                              },
                            )
                          : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  errorText: _errorMessage.isNotEmpty ? _errorMessage : null,
                ),
                onSubmitted: (_) => _processManualInput(),
                textInputAction: TextInputAction.search,
              ),

              const SizedBox(height: 8),

              // 入力案内
              Text(
                '💡 住所・駅名・ランドマーク名を入力できます',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 分析実行ボタン
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: (_isProcessing || _controller.text.trim().isEmpty)
                  ? null
                  : _processManualInput,
              icon: _isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.analytics),
              label: Text(_isProcessing ? '解析中...' : 'エリア分析を開始'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),

          // Google Places候補表示
          if (_showSuggestions) ...[
            const SizedBox(height: 16),
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 候補ヘッダー
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.location_city,
                            color: Colors.grey[600], size: 16),
                        const SizedBox(width: 8),
                        Text(
                          '住所候補',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[700],
                          ),
                        ),
                        if (_isLoadingSuggestions) ...[
                          const SizedBox(width: 8),
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // 候補リスト
                  Flexible(
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: _suggestions.length,
                      itemBuilder: (context, index) {
                        final suggestion = _suggestions[index];

                        return ListTile(
                          dense: true,
                          leading: Icon(
                            Icons.location_on,
                            color: Colors.green[600],
                            size: 20,
                          ),
                          title: Text(
                            suggestion.description,
                            style: const TextStyle(fontSize: 14),
                          ),
                          onTap: () => _selectSuggestion(suggestion),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
