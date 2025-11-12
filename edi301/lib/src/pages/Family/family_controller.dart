import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class FamilyController {
  BuildContext? context;

  Future? init(BuildContext context) {
    this.context = context;
    return null;
  }

  void goToEditPage(BuildContext context) {
    Navigator.pushNamed(context, 'edit');
  }
}
