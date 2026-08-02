import 'package:flutter/widgets.dart';

String localizedText(BuildContext context, String chinese, String english) {
  return Localizations.localeOf(context).languageCode == 'en'
      ? english
      : chinese;
}
