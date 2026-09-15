import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class AppTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? icon;
  final bool sifreMi;
  final TextInputType? klavyeTipi;
  final String? hataMetni;
  final String? Function(String?)? dogrula;
  final TextInputAction? klavyeAksiyonu;
  final void Function(String)? gonderildiginde;
  final bool aktif;
  final int? maksUzunluk;

  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.icon,
    this.sifreMi = false,
    this.klavyeTipi,
    this.hataMetni,
    this.dogrula,
    this.klavyeAksiyonu,
    this.gonderildiginde,
    this.aktif = true,
    this.maksUzunluk,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _gizli = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: widget.controller,
          obscureText: widget.sifreMi && _gizli,
          keyboardType: widget.klavyeTipi,
          textInputAction: widget.klavyeAksiyonu,
          onFieldSubmitted: widget.gonderildiginde,
          enabled: widget.aktif,
          maxLength: widget.maksUzunluk,
          validator: widget.dogrula,
          decoration: InputDecoration(
            hintText: widget.hint,
            counterText: '',
            prefixIcon: widget.icon != null
                ? Icon(widget.icon, size: 20, color: AppColors.textTertiary)
                : null,
            suffixIcon: widget.sifreMi
                ? IconButton(
                    icon: Icon(
                      _gizli ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 20,
                      color: AppColors.textTertiary,
                    ),
                    onPressed: () => setState(() => _gizli = !_gizli),
                  )
                : null,
            errorText: widget.hataMetni,
          ),
        ),
      ],
    );
  }
}