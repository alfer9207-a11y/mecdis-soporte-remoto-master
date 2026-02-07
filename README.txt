Fix Flutter 3.24 build errors:
- Revert common.dart to use DialogTheme and TabBarTheme (not DialogThemeData/TabBarThemeData).
Apply by replacing flutter/lib/common.dart with the one in this ZIP.
