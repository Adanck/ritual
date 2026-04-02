# Ritual Roadmap

Este documento convierte la vision del producto en una secuencia concreta de trabajo. La idea es completar tareas pequenas, validar visualmente o con pruebas, y hacer un commit limpio despues de cada item o subitem.

## Como usar este roadmap

- Usa `docs/ritual_roadmap.csv` como tablero de seguimiento en Excel.
- Cambia la columna `Estado` a valores como `Hecho`, `En progreso`, `Pendiente` o `Bloqueado`.
- Si una tarea es muy grande, dividela en subtareas antes de implementarla.
- Intenta hacer un commit por cambio coherente y pequeno.

## Fase 1 - Base solida

### RIT-001 Separar BlockType del widget

Ya esta completado. El objetivo era evitar que la capa de datos dependiera de un widget visual. Esto mejora la arquitectura y facilita reutilizar el modelo en otras pantallas o servicios.

### RIT-002 Renombrar share a shared

Ya esta completado. El objetivo era alinear la estructura real del proyecto con la arquitectura deseada y con una convencion mas clara para componentes reutilizables.

### RIT-003 Definir estructura estable del proyecto

Esta tarea busca documentar y ordenar el proyecto para que escale sin confusion.

Resultado esperado:
- `app/` para configuracion global, tema y navegacion.
- `core/` para utilidades, constantes, errores y helpers compartidos.
- `data/` para modelos, servicios, repositorios y persistencia.
- `features/` para cada modulo funcional.
- `shared/` para widgets reutilizables y piezas visuales comunes.

Commit sugerido:
`refactor: organize project structure`

### RIT-004 Mejorar modelo de tiempo

Hoy `DayBlock` usa `String` para `start` y `end`. Eso sirve para avanzar rapido, pero a mediano plazo limita validaciones y ordenamiento.

Objetivos:
- Representar mejor la hora.
- Evitar bloques invalidos.
- Preparar el proyecto para edicion de horarios, validaciones y calculos.

Opciones futuras:
- usar una clase propia para tiempo del dia
- usar `TimeOfDay` en la capa de UI y una representacion serializable en data
- guardar minutos desde medianoche

Commit sugerido:
`refactor: improve day block time model`

### RIT-005 Agregar tests basicos

La base ideal minima es:
- tests para modelos
- tests para persistencia
- tests de widgets clave

Objetivo:
- detectar regresiones antes de seguir agregando features
- validar que guardar y cargar rutinas siga funcionando

Commit sugerido:
`test: add model and storage coverage`

## Fase 2 - Rutinas

### RIT-006 Implementar selector de rutinas

Es el siguiente paso recomendado. Debe permitir cambiar entre rutinas y persistir cual queda activa.

Resultado esperado:
- el usuario ve la rutina activa
- puede abrir un selector
- puede elegir otra rutina
- la pantalla se actualiza
- el cambio se guarda

Commit sugerido:
`feat: add routine selector`

### RIT-007 Crear una rutina nueva

Empezar simple es buena idea: un dialog para nombre y una rutina vacia o con plantilla inicial.

Commit sugerido:
`feat: add create routine flow`

### RIT-008 Editar nombre de rutina

Debe permitir renombrar sin perder bloques ni estado.

Commit sugerido:
`feat: allow renaming routines`

### RIT-009 Marcar una rutina como activa

Esto normalmente quedara incluido junto al selector, pero conviene tratarlo como responsabilidad clara:
- solo una rutina activa a la vez
- persistencia correcta

Commit sugerido:
`feat: support active routine switching`

### RIT-010 Eliminar una rutina

Debe contemplar reglas seguras:
- no dejar al usuario sin rutina
- confirmar antes de borrar

Commit sugerido:
`feat: allow deleting routines`

## Fase 3 - Bloques

### RIT-011 Crear bloque nuevo

Formulario minimo recomendado:
- hora de inicio
- hora de fin
- titulo
- tipo de bloque

Commit sugerido:
`feat: add day block creation`

### RIT-012 Editar bloque

El usuario debe poder modificar datos sin borrar y volver a crear.

Commit sugerido:
`feat: add day block editing`

### RIT-013 Eliminar bloque

Idealmente con confirmacion o accion segura.

Commit sugerido:
`feat: allow deleting day blocks`

### RIT-014 Reordenar bloques

Esto mejora mucho la experiencia de configuracion de la rutina.

Commit sugerido:
`feat: support block reordering`

### RIT-015 Validar horarios

Esta tarea evita errores de consistencia.

Validaciones utiles:
- hora final mayor que hora inicial
- no traslapes invalidos si decides impedirlos
- no permitir datos vacios

Commit sugerido:
`feat: validate day block time ranges`

### RIT-016 Mejorar visual de tipos de bloque

Objetivo:
- que cada tipo se identifique rapido
- mantener claridad y limpieza visual

Commit sugerido:
`feat: improve block type visuals`

## Fase 4 - Experiencia diaria

### RIT-017 Mejorar barra de progreso

Ya hay una buena base, pero luego se puede enriquecer con:
- porcentaje
- mensaje motivador
- hitos visuales

Commit sugerido:
`feat: enhance daily progress feedback`

### RIT-018 Agregar resumen del dia

Ejemplos:
- total de bloques
- completados
- pendientes
- habitos cumplidos

Commit sugerido:
`feat: add daily summary card`

### RIT-019 Feedback al completar habitos

Puede incluir:
- cambio visual mas claro
- animacion breve
- mensaje pequeno

Commit sugerido:
`feat: add completion feedback`

### RIT-020 Estado vacio

Muy importante para rutinas nuevas o borradas.

Commit sugerido:
`feat: add empty state for routines`

### RIT-021 Reinicio diario

Esta tarea separa el concepto de plantilla de rutina del progreso diario.

Objetivo:
- que los checks no queden eternamente marcados
- que cada dia empiece limpio segun la logica del producto

Commit sugerido:
`feat: reset habits by day`

## Fase 5 - Historial

### RIT-022 Guardar historial por fecha

Esta es una de las tareas mas importantes de producto, porque transforma la app de una rutina estatica a un sistema de seguimiento real.

Commit sugerido:
`feat: add daily history storage`

### RIT-023 Mostrar estado del dia

Debe permitir responder preguntas como:
- hoy complete mi rutina
- ayer cumpli 3 de 5 bloques

Commit sugerido:
`feat: show daily completion status`

### RIT-024 Streaks

Sirve para gamificacion y consistencia.

Commit sugerido:
`feat: add streak tracking`

### RIT-025 Estadisticas basicas

Ejemplos:
- porcentaje de cumplimiento
- dias activos
- habitos mas constantes

Commit sugerido:
`feat: add routine statistics`

### RIT-026 Preparar base de gamificacion

Antes de meter puntos y logros, conviene definir:
- que se recompensa
- cuando se gana
- como se muestra

Commit sugerido:
`refactor: prepare gamification model`

### RIT-026A Configurar notificaciones por bloque

La idea es que cada bloque pueda decidir explicitamente si participa o no en recordatorios push, igual que hoy ya puede decidir si cuenta o no para el progreso.

Objetivo:
- no inferir notificaciones solo por tipo de bloque
- permitir bloques informativos sin push
- permitir bloques importantes con push
- dejar abierta la puerta a horarios o estrategias de recordatorio futuras

Posible propiedad:
- `receivesPushNotification`

Commit sugerido:
`feat: support block-level push notification preference`

## Fase 6 - Producto completo

### RIT-027 Pantalla de ajustes

Opciones posibles:
- preferencias visuales
- reinicio diario
- notificaciones futuras

Commit sugerido:
`feat: add settings page`

### RIT-028 Exportar a Excel

Importante por el origen del producto.

Commit sugerido:
`feat: export routines to excel`

### RIT-029 Importar desde Excel

Permite migrar desde el sistema actual sin reescribir todo a mano.

Commit sugerido:
`feat: import routines from excel`

### RIT-030 Sincronizacion en la nube

Pensada para:
- backup
- varios dispositivos
- futura cuenta de usuario

Commit sugerido:
`feat: add cloud sync`

### RIT-031 Autenticacion

Solo tiene sentido cuando exista una necesidad real de cuentas y sincronizacion.

Commit sugerido:
`feat: add user authentication`

### RIT-032 Mejor soporte web y escritorio

Objetivo:
- adaptar layout
- mejorar navegacion por mouse y teclado
- pulir experiencia segun plataforma

Commit sugerido:
`feat: improve web and desktop support`

## Orden recomendado inmediato

El siguiente orden es el que recomiendo para no abrir demasiados frentes a la vez:

1. RIT-006 Implementar selector de rutinas
2. RIT-007 Crear rutina nueva
3. RIT-011 Crear bloque nuevo
4. RIT-012 Editar bloque existente
5. RIT-015 Validar horarios
6. RIT-020 Agregar estado vacio
7. RIT-005 Agregar tests basicos
8. RIT-026A Configurar notificaciones por bloque

## Convencion sugerida para estados

Puedes usar estos valores dentro del Excel:

- `Pendiente`
- `En progreso`
- `Hecho`
- `Bloqueado`
- `Descartado`

## Convencion sugerida para commits

- `feat:` para comportamiento nuevo visible al usuario
- `fix:` para corregir errores
- `refactor:` para reorganizar codigo sin cambiar comportamiento
- `test:` para pruebas
- `docs:` para documentacion
- `style:` para cambios visuales menores o de formato

## Actualizacion reciente

Ya quedaron implementadas estas capacidades del roadmap:

- selector, creacion, edicion y eliminacion segura de rutinas
- creacion, edicion, eliminacion y reordenamiento de bloques
- validacion de horarios y tests basicos
- historial diario con reset automatico
- rachas y estadisticas basicas
- vista de dias anteriores y detalle de un dia historico
- vigencia de rutinas con modos `siempre`, `semana actual`, `mes actual` y `rango personalizado`

Siguiente bloque recomendado:

1. avisos de vigencia para rutinas que estan por empezar o terminar
2. seleccion automatica de la rutina que aplica hoy cuando haya varias vigentes
3. preferencia por bloque para recibir notificaciones push
