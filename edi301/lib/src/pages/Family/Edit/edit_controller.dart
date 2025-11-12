import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class EditController {
  BuildContext? context;

  Future? init(BuildContext context) {
    this.context = context;
    return null;
  }

  // void goToDetailsPage() {
  //   Navigator.pushNamed(context!, 'edit');
  // }
}
