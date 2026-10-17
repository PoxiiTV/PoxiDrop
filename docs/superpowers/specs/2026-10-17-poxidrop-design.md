# PoxiDrop · Diseño (v0.1.0 = fases 1 y 2)

Fecha: 2026-10-17 · Estado: aprobado por Alexis

## Qué es

Alternativa gratuita y open source a Dropover para macOS. Mientras arrastras algo (archivos, carpetas,
imágenes, texto, enlaces), **agitas el ratón** y aparece una **estantería** flotante donde soltarlo.
Lo que dejas ahí se queda guardado y luego lo arrastras a donde quieras. Ésta es la función principal
y la que más se pule.

- Interfaz: estética de Dropover (vidrio translúcido nativo de macOS, menús nativos con iconos SF).
- Icono y README: familia Poxi (P pixel-art con sombra escalonada, banner propio).
- Idioma: castellano.
- Plataforma: macOS 14+, Apple Silicon. App de barra de menú (sin icono en el Dock).
- Nombre: **PoxiDrop** (no se usa la marca «Dropover»; no se copian sus imágenes ni iconos).

## Alcance

**Entra en v0.1.0 (fases 1 y 2):**

1. Abrir la estantería: agitar mientras arrastras (sensibilidad ajustable), mantener una tecla
   modificadora elegida (⇧ ⌃ ⌥ ⌘) mientras arrastras, soltar en la muesca del MacBook, desde la
   barra de menú y con atajo global.
2. Estantería: vidrio translúcido, ✕ (cerrar) arriba a la izquierda, «…» (acciones) arriba a la derecha,
   miniaturas apiladas, píldora «N elementos ⌄» que abre el panel de detalle.
3. Panel de detalle: cuadrícula o lista, selección de elementos, tamaños, Vista rápida (espacio),
   doble clic para abrir, arrastrar todo o solo lo seleccionado.
4. Varias estanterías a la vez (la activa con borde azul), acoplar a un borde, estantería favorita fija,
   recientes, nombres automáticos («5 imágenes»), añadir desde el portapapeles.
5. Comportamiento: cerrar al sacar todo (opcional), copiar o mover al arrastrar fuera.
6. Acciones (menú «…» con buscador):
   - Archivo: abrir, mostrar en Finder, copiar, copiar ruta, copiar a…, mover a…, renombrar, comprimir (ZIP).
   - Compartir: AirDrop, Mensajes, Mail, menú Compartir de macOS.
   - Acciones directas: al arrastrar sobre la estantería aparecen casillas (AirDrop, Mensajes, Mail, ZIP)
     donde soltar.
   - Imagen: redimensionar, convertir formato (PNG, JPEG, HEIC, TIFF; WebP si el sistema lo admite),
     comprimir (calidad JPEG), quitar metadatos, unir (vertical u horizontal), extraer texto (OCR,
     castellano e inglés) y crear PDF.
   - Texto: convertir a texto plano.
   - Mis acciones: scripts del usuario que reciben las rutas de los elementos.
7. Ajustes con barra lateral de iconos de colores: Activación, Interacción, Acciones, Atajos, General
   (abrir al iniciar sesión, icono de la barra de menú), Acerca de.
8. Persistencia: las estanterías y su contenido sobreviven a cerrar la app y a reiniciar.

**Fuera (fases siguientes):** carpetas vigiladas, menú Servicios, extensión de Compartir, widgets,
acciones para Atajos (fase 3); subir a la nube y copiar enlace (fase 4).

## Arquitectura

Swift 6, SwiftUI para la interfaz y AppKit donde SwiftUI no llega (ventanas flotantes, arrastre
del sistema, Vista rápida, compartir). Paquete SwiftPM con dos módulos:

- `PoxiDropCore` (sin interfaz, testeable): detector de agitado, modelo y almacén de estanterías,
  importación de lo que se suelta, registro y ejecución de acciones.
- `PoxiDrop` (la app): barra de menú, vigía de arrastre, ventanas de estantería, panel de detalle,
  ajustes, atajos globales.

### Piezas

| Pieza | Módulo | Responsabilidad |
|---|---|---|
| `ShakeDetector` | Core | Recibe puntos (x, y, tiempo) y decide si hubo agitado: N cambios de dirección horizontal, cada tramo con un desplazamiento mínimo, todo dentro de una ventana de tiempo. Parámetros según la sensibilidad. Lógica pura. |
| `DragWatcher` | App | Monitores globales de `leftMouseDragged` y `leftMouseUp`. Sabe que hay un arrastre con contenido cuando cambia el `changeCount` del portapapeles de arrastre. Pasa los puntos al `ShakeDetector`, lee `NSEvent.modifierFlags` para la tecla y comprueba si el cursor entra en la zona de la muesca. Pide abrir una estantería en la posición del cursor. |
| `Shelf`, `ShelfItem` | Core | Modelo. Un elemento es un archivo o carpeta (con *bookmark* para seguir encontrándolo si se mueve) o contenido guardado como archivo propio (texto, imagen, enlace `.webloc`). |
| `ShelfStore` | Core | Lista de estanterías, favorita y recientes. Guarda en JSON en `~/Library/Application Support/PoxiDrop/` y el contenido propio en `…/PoxiDrop/Items/<id>/`. Limpia los archivos de estanterías borradas. |
| `DropImporter` | Core | Convierte lo soltado (URLs de archivo, promesas de archivo de Fotos o Mail, imágenes, texto, URLs web) en `ShelfItem`. |
| `ShelfPanel` | App | `NSPanel` flotante que no activa la app, presente en todos los escritorios y sobre pantallas completas, con fondo `NSVisualEffectView` y esquinas redondeadas. Destino de arrastre (entrada) y origen de arrastre con varios archivos (salida). Muestra `ShelfView` (SwiftUI). |
| `DetailView` | App | Panel de detalle (cuadrícula o lista, selección, Vista rápida, arrastre parcial). |
| `Action` + `ActionRegistry` | Core | Protocolo: id, título, símbolo SF, grupo, `admite(elementos)`, `ejecutar(elementos) async throws -> [URL]`. Los resultados se añaden a la estantería. Las acciones que necesitan la interfaz (compartir, elegir carpeta) se implementan en la app. |
| `HotKeys` | App | Atajos globales con `RegisterEventHotKey` (no requiere Accesibilidad). |
| `Settings` | App | `UserDefaults`; ventana de ajustes con barra lateral. |

### Flujo principal

1. El usuario empieza a arrastrar. `DragWatcher` detecta el cambio del portapapeles de arrastre.
2. Mientras arrastra: agitado, tecla o muesca → `ShelfStore` crea una estantería y `ShelfPanel` se
   muestra junto al cursor.
3. Suelta dentro → `DropImporter` crea los elementos → se guardan.
4. Más tarde arrastra desde la estantería → el sistema recibe las URLs (copiar o mover según ajuste)
   → si «cerrar al sacar todo» está activo y no queda nada, se cierra y pasa a recientes.

## Errores

- Acciones que fallan: aviso dentro de la estantería con el motivo en castellano. Nunca se borran
  los originales al fallar.
- Elemento cuyo archivo ya no existe: se muestra atenuado con «No encontrado» y se puede quitar.
- Si macOS pidiera algún permiso (Accesibilidad, carpetas), se explica en la app antes de pedirlo.

## Pruebas

- Tests automáticos (`swift test`) de `PoxiDropCore`: detector de agitado con trayectorias simuladas
  (agitado claro, movimiento normal, agitado lento, poco recorrido), guardado y carga de estanterías,
  importación, y cada acción sobre archivos de prueba (ZIP, redimensionar, convertir, comprimir,
  quitar metadatos, unir, OCR, PDF, texto plano, script).
- Interfaz revisada con capturas generadas por código (estantería, detalle, menú, ajustes).
- El tacto real (agitado, arrastre entre apps) lo prueba Alexis; la sensibilidad se ajusta con sus
  pruebas.

## Entrega

Repo privado `PoxiiTV/PoxiDrop`, README y banner de la familia Poxi, icono pixel-art, `.dmg` y
release `v0.1.0` (pre-release, beta).
