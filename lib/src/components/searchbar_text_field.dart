import 'package:flutter/material.dart';

class SearchbarTextField extends StatefulWidget {
  final TextEditingController? controller;

  final FocusNode focus;

  final String? hintText;

  final EdgeInsetsGeometry contentPadding;

  const SearchbarTextField(
      {super.key,
      this.controller,
      required this.focus,
      this.hintText,
      required this.contentPadding});

  @override
  State<SearchbarTextField> createState() => _SearchbarTextFieldState();
}

class _SearchbarTextFieldState extends State<SearchbarTextField> {
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focus,
        decoration: InputDecoration(
          hintText: widget.hintText,
          border: InputBorder.none,
          errorBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          isDense: true,
          contentPadding: widget.contentPadding,
        ),
      ),
    );
  }
}
