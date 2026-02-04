import 'dart:ui';

class SelectionService {
  static final SelectionService _instance = SelectionService._internal();
  factory SelectionService() => _instance;
  SelectionService._internal();

  bool _isAllSelected = false;
  final List<VoidCallback> _listeners = [];

  bool get isAllSelected => _isAllSelected;

  void toggleAllSelection() {
    _isAllSelected = !_isAllSelected;
    _notifyListeners();
  }

  void setAllSelected(bool selected) {
    if (_isAllSelected != selected) {
      _isAllSelected = selected;
      _notifyListeners();
    }
  }

  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }
}
