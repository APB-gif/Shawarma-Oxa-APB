// lib/nucleo/tema.dart
import 'package:flutter/material.dart';
import 'package:shawarma_pos_nuevo/nucleo/constantes.dart';

ThemeData appTheme = ThemeData(
  primaryColor: const Color.fromARGB(0, 0, 0, 0),
  scaffoldBackgroundColor: const Color.fromARGB(206, 255, 255, 255),

  // Esquema de colores moderno
  colorScheme: ColorScheme.fromSwatch().copyWith(
    secondary: kSecondaryColor,
    primary: const Color.fromARGB(255, 9, 72, 114),
  ),

  appBarTheme: const AppBarTheme(
    backgroundColor: Color.fromARGB(255, 9, 72, 114),
    foregroundColor: Color.fromARGB(255, 255, 255, 255), // color de texto/iconos en el AppBar
    titleTextStyle: TextStyle(
      fontSize: 30,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    ),
  ),

  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: Color.fromARGB(255, 9, 72, 114), fontSize: 16),
    bodyMedium: TextStyle(color: Color.fromARGB(255, 9, 72, 114), fontSize: 14),
  ),

  // Botones modernos
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: kPrimaryColor,
      foregroundColor: Colors.white,
      textStyle: const TextStyle(fontWeight: FontWeight.bold),
    ),
  ),

  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: kPrimaryColor,
    ),
  ),
);
