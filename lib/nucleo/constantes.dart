// lib/nucleo/constantes.dart
import 'package:flutter/material.dart';

/// 🎨 Colores principales
const Color kPrimaryColor = Color(0xFF6C5CE7); // Morado principal
const Color kSecondaryColor = Color(0xFFFFA726); // Naranja secundario
const Color kBackgroundColor = Color(0xFFF7F7F7); // Fondo general de pantallas

/// 📌 Colores para textos
const Color kTextPrimary = Color(0xFF2C2C2C); // Texto principal
const Color kTextSecondary = Color(0xFF6C6C6C); // Texto secundario (gris)
const Color kTextWhite = Colors.white; // Texto blanco

/// 🟩 Estados (éxito, error, advertencia, info)
const Color kSuccessColor = Color(0xFF4CAF50); // Verde éxito
const Color kErrorColor = Color(0xFFE53935); // Rojo error
const Color kWarningColor = Color(0xFFFFB300); // Amarillo advertencia
const Color kInfoColor = Color(0xFF2196F3); // Azul info

/// 🔲 Colores de tarjetas y bordes
const Color kCardBg = Color(0xFFFFFFFF); // Fondo de tarjetas (blanco)
const Color kCardBorder = Color(0xFFE0E0E0); // Borde gris claro
const double kCardRadius = 12.0; // Esquinas redondeadas

/// 🖼️ Sombra global para tarjetas
const List<BoxShadow> kCardShadow = [
  BoxShadow(
    color: Colors.black12,
    blurRadius: 6,
    offset: Offset(0, 2),
  ),
];

/// 🔘 Estilos de botones
const double kButtonRadius = 24.0; // Redondeado estándar
const EdgeInsets kButtonPadding = EdgeInsets.symmetric(
  horizontal: 20,
  vertical: 12,
);

/// 🅿️ Espaciados globales
const double kPadding = 16.0; // Padding estándar
const double kMargin = 16.0; // Margen estándar
