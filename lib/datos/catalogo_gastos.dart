// lib/datos/catalogo_gastos.dart
import 'modelos/categoria.dart';
import 'modelos/producto.dart';

class CatalogoGastos {
  static final List<Categoria> categories = [
    const Categoria(id: 'carnes_embutidos', nombre: 'Carnes y Embutidos', tipo: 'gasto'),
    const Categoria(id: 'silvino', nombre: 'Silvino (Proveedor)', tipo: 'gasto'),
    const Categoria(id: 'feria_mercado', nombre: 'Feria o Mercado', tipo: 'gasto'),
    const Categoria(id: 'condimentos', nombre: 'Condimentos', tipo: 'gasto'),
    const Categoria(id: 'el_brillante', nombre: 'El Brillante (Limpieza)', tipo: 'gasto'),
    const Categoria(id: 'giulianno', nombre: 'Giulianno (Limpieza)', tipo: 'gasto'),
    const Categoria(id: 'gisela', nombre: 'Gisela (Proveedor)', tipo: 'gasto'),
    const Categoria(id: 'personal', nombre: 'Personal', tipo: 'gasto'),
    const Categoria(id: 'otros', nombre: 'Otros Gastos', tipo: 'gasto'),
  ];

  static final Map<String, List<Producto>> productsByCategory = {
    'carnes_embutidos': [
      const Producto(id: 'gas-carne', nombre: 'Carne', precio: 0.0, tipo: 'gasto', categoriaId: 'carnes_embutidos', categoriaNombre: 'Carnes y Embutidos'),
      const Producto(id: 'gas-pollo', nombre: 'Pollo', precio: 0.0, tipo: 'gasto', categoriaId: 'carnes_embutidos', categoriaNombre: 'Carnes y Embutidos'),
      const Producto(id: 'gas-chorizo', nombre: 'Chorizo', precio: 0.0, tipo: 'gasto', categoriaId: 'carnes_embutidos', categoriaNombre: 'Carnes y Embutidos'),
      const Producto(id: 'gas-cabanossi', nombre: 'Cabanossi', precio: 0.0, tipo: 'gasto', categoriaId: 'carnes_embutidos', categoriaNombre: 'Carnes y Embutidos'),
      const Producto(id: 'gas-tocino', nombre: 'Tocino', precio: 0.0, tipo: 'gasto', categoriaId: 'carnes_embutidos', categoriaNombre: 'Carnes y Embutidos'),
      const Producto(id: 'gas-champinones', nombre: 'Champiñones', precio: 0.0, tipo: 'gasto', categoriaId: 'carnes_embutidos', categoriaNombre: 'Carnes y Embutidos'),
    ],
    'silvino': [
      const Producto(id: 'gas-huevos', nombre: 'Huevos', precio: 0.0, tipo: 'gasto', categoriaId: 'silvino', categoriaNombre: 'Silvino (Proveedor)'),
      const Producto(id: 'gas-galleta', nombre: 'Galleta', precio: 0.0, tipo: 'gasto', categoriaId: 'silvino', categoriaNombre: 'Silvino (Proveedor)'),
      const Producto(id: 'gas-ajo-silvino', nombre: 'Ajo', precio: 0.0, tipo: 'gasto', categoriaId: 'silvino', categoriaNombre: 'Silvino (Proveedor)'),
      const Producto(id: 'gas-aceite-silvino', nombre: 'Aceite', precio: 0.0, tipo: 'gasto', categoriaId: 'silvino', categoriaNombre: 'Silvino (Proveedor)'),
      const Producto(id: 'gas-vinagre-silvino', nombre: 'Vinagre', precio: 0.0, tipo: 'gasto', categoriaId: 'silvino', categoriaNombre: 'Silvino (Proveedor)'),
      const Producto(id: 'gas-manzanilla', nombre: 'Manzanilla', precio: 0.0, tipo: 'gasto', categoriaId: 'silvino', categoriaNombre: 'Silvino (Proveedor)'),
      const Producto(id: 'gas-aniz', nombre: 'Aniz', precio: 0.0, tipo: 'gasto', categoriaId: 'silvino', categoriaNombre: 'Silvino (Proveedor)'),
      const Producto(id: 'gas-te', nombre: 'Te Puro', precio: 0.0, tipo: 'gasto', categoriaId: 'silvino', categoriaNombre: 'Silvino (Proveedor)'),
      const Producto(id: 'gas-sal-silvino', nombre: 'Sal', precio: 0.0, tipo: 'gasto', categoriaId: 'silvino', categoriaNombre: 'Silvino (Proveedor)'),
      const Producto(id: 'gas-papas-hilo-silvino', nombre: 'Papas al Hilo', precio: 0.0, tipo: 'gasto', categoriaId: 'silvino', categoriaNombre: 'Silvino (Proveedor)'),
      const Producto(id: 'gas-servilleta-silvino', nombre: 'Servilleta', precio: 0.0, tipo: 'gasto', categoriaId: 'silvino', categoriaNombre: 'Silvino (Proveedor)'),
      const Producto(id: 'gas-papel-envolver', nombre: 'Papel de Envolver', precio: 0.0, tipo: 'gasto', categoriaId: 'silvino', categoriaNombre: 'Silvino (Proveedor)'),
      const Producto(id: 'gas-bolsas-aza', nombre: 'Bolsas con Aza', precio: 0.0, tipo: 'gasto', categoriaId: 'silvino', categoriaNombre: 'Silvino (Proveedor)'),
      const Producto(id: 'gas-bolsas-peq', nombre: 'Bolsas Trans. Shaw (Pequeño)', precio: 0.0, tipo: 'gasto', categoriaId: 'silvino', categoriaNombre: 'Silvino (Proveedor)'),
      const Producto(id: 'gas-bolsas-gra', nombre: 'Bolsas Trans. Shaw (Grande)', precio: 0.0, tipo: 'gasto', categoriaId: 'silvino', categoriaNombre: 'Silvino (Proveedor)'),
      const Producto(id: 'gas-azucar', nombre: 'Azucar', precio: 0.0, tipo: 'gasto', categoriaId: 'silvino', categoriaNombre: 'Silvino (Proveedor)'),
    ],
    'feria_mercado': [
      const Producto(id: 'gas-tomate', nombre: 'Tomate', precio: 0.0, tipo: 'gasto', categoriaId: 'feria_mercado', categoriaNombre: 'Feria o Mercado'),
      const Producto(id: 'gas-cebolla', nombre: 'Cebolla', precio: 0.0, tipo: 'gasto', categoriaId: 'feria_mercado', categoriaNombre: 'Feria o Mercado'),
      const Producto(id: 'gas-lechuga', nombre: 'Lechuga', precio: 0.0, tipo: 'gasto', categoriaId: 'feria_mercado', categoriaNombre: 'Feria o Mercado'),
      const Producto(id: 'gas-pepino', nombre: 'Pepino', precio: 0.0, tipo: 'gasto', categoriaId: 'feria_mercado', categoriaNombre: 'Feria o Mercado'),
      const Producto(id: 'gas-limon', nombre: 'Limon', precio: 0.0, tipo: 'gasto', categoriaId: 'feria_mercado', categoriaNombre: 'Feria o Mercado'),
      const Producto(id: 'gas-hierva-buena', nombre: 'Hierva Buena', precio: 0.0, tipo: 'gasto', categoriaId: 'feria_mercado', categoriaNombre: 'Feria o Mercado'),
      const Producto(id: 'gas-perejil', nombre: 'Perejil', precio: 0.0, tipo: 'gasto', categoriaId: 'feria_mercado', categoriaNombre: 'Feria o Mercado'),
      const Producto(id: 'gas-culantro', nombre: 'Culantro', precio: 0.0, tipo: 'gasto', categoriaId: 'feria_mercado', categoriaNombre: 'Feria o Mercado'),
      const Producto(id: 'gas-sal-feria', nombre: 'Sal', precio: 0.0, tipo: 'gasto', categoriaId: 'feria_mercado', categoriaNombre: 'Feria o Mercado'),
      const Producto(id: 'gas-papas-hilo-feria', nombre: 'Papas al Hilo', precio: 0.0, tipo: 'gasto', categoriaId: 'feria_mercado', categoriaNombre: 'Feria o Mercado'),
    ],
    'condimentos': [
      const Producto(id: 'gas-paprika', nombre: 'Paprika', precio: 0.0, tipo: 'gasto', categoriaId: 'condimentos', categoriaNombre: 'Condimentos'),
      const Producto(id: 'gas-comino', nombre: 'Comino', precio: 0.0, tipo: 'gasto', categoriaId: 'condimentos', categoriaNombre: 'Condimentos'),
      const Producto(id: 'gas-pimienta', nombre: 'Pimienta', precio: 0.0, tipo: 'gasto', categoriaId: 'condimentos', categoriaNombre: 'Condimentos'),
      const Producto(id: 'gas-romero', nombre: 'Romero', precio: 0.0, tipo: 'gasto', categoriaId: 'condimentos', categoriaNombre: 'Condimentos'),
    ],
    'el_brillante': [
      const Producto(id: 'gas-guantes', nombre: 'Guantes', precio: 0.0, tipo: 'gasto', categoriaId: 'el_brillante', categoriaNombre: 'El Brillante (Limpieza)'),
      const Producto(id: 'gas-poet-brillante', nombre: 'Poet', precio: 0.0, tipo: 'gasto', categoriaId: 'el_brillante', categoriaNombre: 'El Brillante (Limpieza)'),
      const Producto(id: 'gas-ayudin-brillante', nombre: 'Ayudin Lesly', precio: 0.0, tipo: 'gasto', categoriaId: 'el_brillante', categoriaNombre: 'El Brillante (Limpieza)'),
      const Producto(id: 'gas-jabon-liq-brillante', nombre: 'Jabon Liquido', precio: 0.0, tipo: 'gasto', categoriaId: 'el_brillante', categoriaNombre: 'El Brillante (Limpieza)'),
    ],
    'giulianno': [
      const Producto(id: 'gas-servilletas-giulianno', nombre: 'Servilletas', precio: 0.0, tipo: 'gasto', categoriaId: 'giulianno', categoriaNombre: 'Giulianno (Limpieza)'),
      const Producto(id: 'gas-papel-paracas', nombre: 'Papel Paracas', precio: 0.0, tipo: 'gasto', categoriaId: 'giulianno', categoriaNombre: 'Giulianno (Limpieza)'),
      const Producto(id: 'gas-ayudin-giulianno', nombre: 'Ayudin Leslys', precio: 0.0, tipo: 'gasto', categoriaId: 'giulianno', categoriaNombre: 'Giulianno (Limpieza)'),
      const Producto(id: 'gas-jabon-liq-giulianno', nombre: 'Jabon Liquido', precio: 0.0, tipo: 'gasto', categoriaId: 'giulianno', categoriaNombre: 'Giulianno (Limpieza)'),
      const Producto(id: 'gas-poett-giulianno', nombre: 'Poett', precio: 0.0, tipo: 'gasto', categoriaId: 'giulianno', categoriaNombre: 'Giulianno (Limpieza)'),
    ],
    'gisela': [
      const Producto(id: 'gas-cafe', nombre: 'Café', precio: 0.0, tipo: 'gasto', categoriaId: 'gisela', categoriaNombre: 'Gisela (Proveedor)'),
      const Producto(id: 'gas-aceite-gisela', nombre: 'Aceite', precio: 0.0, tipo: 'gasto', categoriaId: 'gisela', categoriaNombre: 'Gisela (Proveedor)'),
      const Producto(id: 'gas-vinagre-gisela', nombre: 'Vinagre', precio: 0.0, tipo: 'gasto', categoriaId: 'gisela', categoriaNombre: 'Gisela (Proveedor)'),
      const Producto(id: 'gas-ajo-gisela', nombre: 'Ajo', precio: 0.0, tipo: 'gasto', categoriaId: 'gisela', categoriaNombre: 'Gisela (Proveedor)'),
      const Producto(id: 'gas-sal-gisela', nombre: 'Sal', precio: 0.0, tipo: 'gasto', categoriaId: 'gisela', categoriaNombre: 'Gisela (Proveedor)'),
      const Producto(id: 'gas-papas-hilo-gisela', nombre: 'Papas al Hilo', precio: 0.0, tipo: 'gasto', categoriaId: 'gisela', categoriaNombre: 'Gisela (Proveedor)'),
    ],
    'personal': [
      const Producto(id: 'gas-ayudante-local', nombre: 'Ayudante Local', precio: 0.0, tipo: 'gasto', categoriaId: 'personal', categoriaNombre: 'Personal'),
      const Producto(id: 'gas-ayudante-verduras', nombre: 'Ayudante Verduras', precio: 0.0, tipo: 'gasto', categoriaId: 'personal', categoriaNombre: 'Personal'),
    ],
    'otros': [
      const Producto(id: 'gas-pan-arabe', nombre: 'Pan Arabe', precio: 0.0, tipo: 'gasto', categoriaId: 'otros', categoriaNombre: 'Otros Gastos'),
      const Producto(id: 'gas-gas', nombre: 'Gas', precio: 0.0, tipo: 'gasto', categoriaId: 'otros', categoriaNombre: 'Otros Gastos'),
      const Producto(id: 'gas-gaseosa-600', nombre: 'Gaseosa 600ml', precio: 0.0, tipo: 'gasto', categoriaId: 'otros', categoriaNombre: 'Otros Gastos'),
      const Producto(id: 'gas-gaseosa-192', nombre: 'Gaseosa 192ml', precio: 0.0, tipo: 'gasto', categoriaId: 'otros', categoriaNombre: 'Otros Gastos'),
      const Producto(id: 'gas-agua-botella', nombre: 'Agua', precio: 0.0, tipo: 'gasto', categoriaId: 'otros', categoriaNombre: 'Otros Gastos'),
      const Producto(id: 'gas-agua-potable', nombre: 'Agua Potable', precio: 0.0, tipo: 'gasto', categoriaId: 'otros', categoriaNombre: 'Otros Gastos'),
      const Producto(id: 'gas-luz-electrica', nombre: 'Luz eléctrica', precio: 0.0, tipo: 'gasto', categoriaId: 'otros', categoriaNombre: 'Otros Gastos'),
    ],
  };
}