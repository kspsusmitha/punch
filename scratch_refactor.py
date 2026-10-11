import os

base_dir = r"c:\Users\USER\Desktop\Flutter\punch\demo1\lib"
main_file = os.path.join(base_dir, "main.dart")

with open(main_file, "r", encoding="utf-8") as f:
    lines = f.readlines()

# Line numbers (1-indexed, so we subtract 1 for 0-indexed list)
task_handler_lines = lines[13:78]
main_lines = lines[78:101]
splash_screen_lines = lines[101:246]
home_screen_lines = lines[246:2248]
custom_painters_lines = lines[2248:2487]
calendar_activity_page_lines = lines[2487:2769]
edit_profile_screen_lines = lines[2769:]

imports = """import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:math' as math;
import 'dart:isolate';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:flutter_svg/flutter_svg.dart';
"""

def write_file(subpath, content_lines, extra_imports=""):
    path = os.path.join(base_dir, subpath)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(imports)
        f.write(extra_imports)
        f.write("\n")
        f.writelines(content_lines)

# Write files
write_file(r"services\task_handler.dart", task_handler_lines)
write_file(r"screens\splash_screen.dart", splash_screen_lines, "import 'home_screen.dart';\n")
write_file(r"screens\home_screen.dart", home_screen_lines, "import 'package:punchhh/services/task_handler.dart';\nimport 'package:punchhh/widgets/custom_painters.dart';\nimport 'package:punchhh/screens/calendar_activity_page.dart';\nimport 'package:punchhh/screens/edit_profile_screen.dart';\n")
write_file(r"widgets\custom_painters.dart", custom_painters_lines)
write_file(r"screens\calendar_activity_page.dart", calendar_activity_page_lines)
write_file(r"screens\edit_profile_screen.dart", edit_profile_screen_lines, "import 'package:punchhh/screens/home_screen.dart';\n")

# Re-write main.dart
main_new_content = imports + """
import 'package:punchhh/screens/splash_screen.dart';
import 'package:punchhh/services/task_handler.dart';

""" + "".join(main_lines)

with open(main_file, "w", encoding="utf-8") as f:
    f.write(main_new_content)

print("Refactor complete.")
