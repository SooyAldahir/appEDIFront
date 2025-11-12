import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class HomeController {
  BuildContext? context;

  Future? init(BuildContext context) {
    this.context = context;
    return null;
  }

  // void goToEditPage() {
  //   Navigator.pushNamed(context!, 'edit');
  // }
}
