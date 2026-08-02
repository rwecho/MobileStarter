import 'command_runner.dart';

final class CommandArguments {
  CommandArguments(List<String> values) : _values = values;

  final List<String> _values;

  String positional({required int index, required String label}) {
    final positionals = _values
        .where((value) => !value.startsWith('--'))
        .toList();
    if (positionals.length <= index) {
      throw MobileUiUsageException('missing $label');
    }
    return positionals[index];
  }

  String option(String name, {String? fallback}) {
    final index = _values.indexOf('--$name');
    if (index == -1) {
      if (fallback != null) return fallback;
      throw MobileUiUsageException('missing --$name');
    }
    if (index + 1 >= _values.length || _values[index + 1].startsWith('--')) {
      throw MobileUiUsageException('missing value for --$name');
    }
    return _values[index + 1];
  }
}
