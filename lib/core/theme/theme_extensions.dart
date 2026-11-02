import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// Short accessors so widgets read tokens instead of hard-coding styles.
extension ThemeContext on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
}
