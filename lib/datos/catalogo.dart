// lib/datos/catalogo.dart

import 'modelos/categoria.dart';
import 'modelos/producto.dart';

class Catalogo {
  static final List<Categoria> categories = [
    // =======================================================================
    // CORREGIDO: Se añade el parámetro 'iconAssetPath' a cada categoría
    // ¡Asegúrate de que el ID ('pollo') y la ruta ('assets/icons/1.svg') sean correctos!
    // =======================================================================
    const Categoria(id: 'pollo', nombre: 'Shawarma de Pollo', tipo: ''),
    const Categoria(id: 'carne', nombre: 'Shawarma de Carne', tipo: ''),
    const Categoria(id: 'mixto', nombre: 'Shawarma Mixto', tipo: ''),
    const Categoria(id: 'oxa', nombre: 'Shawarma OXA', tipo: ''),
    const Categoria(id: 'veg', nombre: 'Shawarma Vegetariano', tipo: ''),
    const Categoria(id: 'adds', nombre: 'Adicionales', tipo: ''),
    const Categoria(id: 'soda', nombre: 'Gaseosas', tipo: ''),
    const Categoria(id: 'tea', nombre: 'Infusiones', tipo: ''),
  ];

  static final Map<String, List<Producto>> productsByCategory = {
    'pollo': [
      const Producto(
          id: 'p-jr',
          nombre: 'Junior',
          precio: 8.90,
          categoriaId: 'pollo',
          categoriaNombre: 'Shawarma de Pollo'),
      const Producto(
          id: 'p-rg',
          nombre: 'Regular',
          precio: 13.90,
          categoriaId: 'pollo',
          categoriaNombre: 'Shawarma de Pollo'),
      const Producto(
          id: 'p-ex',
          nombre: 'Extra',
          precio: 16.90,
          categoriaId: 'pollo',
          categoriaNombre: 'Shawarma de Pollo'),
    ],
    'carne': [
      const Producto(
          id: 'c-jr',
          nombre: 'Junior',
          precio: 10.90,
          categoriaId: 'carne',
          categoriaNombre: 'Shawarma de Carne'),
      const Producto(
          id: 'c-rg',
          nombre: 'Regular',
          precio: 15.90,
          categoriaId: 'carne',
          categoriaNombre: 'Shawarma de Carne'),
      const Producto(
          id: 'c-ex',
          nombre: 'Extra',
          precio: 18.90,
          categoriaId: 'carne',
          categoriaNombre: 'Shawarma de Carne'),
    ],
    'mixto': [
      const Producto(
          id: 'm-jr',
          nombre: 'Junior',
          precio: 9.90,
          categoriaId: 'mixto',
          categoriaNombre: 'Shawarma Mixto'),
      const Producto(
          id: 'm-rg',
          nombre: 'Regular',
          precio: 14.90,
          categoriaId: 'mixto',
          categoriaNombre: 'Shawarma Mixto'),
      const Producto(
          id: 'm-ex',
          nombre: 'Extra',
          precio: 17.90,
          categoriaId: 'mixto',
          categoriaNombre: 'Shawarma Mixto'),
    ],
    'oxa': [
      const Producto(
          id: 'o-uni',
          nombre: 'OXA Especial',
          precio: 24.90,
          categoriaId: 'oxa',
          categoriaNombre: 'Shawarma OXA'),
    ],
    'veg': [
      const Producto(
          id: 'v-jr',
          nombre: 'Junior',
          precio: 8.90,
          categoriaId: 'veg',
          categoriaNombre: 'Shawarma Vegetariano'),
      const Producto(
          id: 'v-rg',
          nombre: 'Regular',
          precio: 13.90,
          categoriaId: 'veg',
          categoriaNombre: 'Shawarma Vegetariano'),
      const Producto(
          id: 'v-ex',
          nombre: 'Extra',
          precio: 16.90,
          categoriaId: 'veg',
          categoriaNombre: 'Shawarma Vegetariano'),
    ],
    'adds': [
      const Producto(
          id: 'a-chorizo',
          nombre: 'Chorizo',
          precio: 5.00,
          categoriaId: 'adds',
          categoriaNombre: 'Adicionales'),
      const Producto(
          id: 'a-cabanossi',
          nombre: 'Cabanossi',
          precio: 3.00,
          categoriaId: 'adds',
          categoriaNombre: 'Adicionales'),
      const Producto(
          id: 'a-tocino',
          nombre: 'Tocino',
          precio: 4.00,
          categoriaId: 'adds',
          categoriaNombre: 'Adicionales'),
    ],
    'soda': [
      const Producto(
          id: 'g-coca',
          nombre: 'Coca 600ml',
          precio: 4.00,
          categoriaId: 'soda',
          categoriaNombre: 'Gaseosas'),
      const Producto(
          id: 'g-inka',
          nombre: 'Inka 600ml',
          precio: 4.00,
          categoriaId: 'soda',
          categoriaNombre: 'Gaseosas'),
      const Producto(
          id: 'p-coca',
          nombre: 'Coca 192ml',
          precio: 1.50,
          categoriaId: 'soda',
          categoriaNombre: 'Gaseosas'),
      const Producto(
          id: 'p-inka',
          nombre: 'Inka 192ml',
          precio: 1.50,
          categoriaId: 'soda',
          categoriaNombre: 'Gaseosas'),
      const Producto(
          id: 'p-fanta',
          nombre: 'Fanta 192ml',
          precio: 2.50,
          categoriaId: 'soda',
          categoriaNombre: 'Gaseosas'),
    ],
    'tea': [
      const Producto(
          id: 't-agua',
          nombre: 'Agua',
          precio: 1.50,
          categoriaId: 'tea',
          categoriaNombre: 'Infusiones'),
      const Producto(
          id: 't-manz',
          nombre: 'Manzanilla',
          precio: 2.00,
          categoriaId: 'tea',
          categoriaNombre: 'Infusiones'),
      const Producto(
          id: 't-tepuro',
          nombre: 'Té puro',
          precio: 2.00,
          categoriaId: 'tea',
          categoriaNombre: 'Infusiones'),
      const Producto(
          id: 't-aniz',
          nombre: 'Aníz',
          precio: 2.00,
          categoriaId: 'tea',
          categoriaNombre: 'Infusiones'),
      const Producto(
          id: 't-caf',
          nombre: 'Café',
          precio: 3.00,
          categoriaId: 'tea',
          categoriaNombre: 'Infusiones'),
    ],
  };
}
