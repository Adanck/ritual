# Ritual Context

Este archivo sirve como contexto vivo del proyecto. La idea es que puedas abrirlo desde otra PC, pegarlo en otro hilo y retomar el trabajo sin depender de la memoria del chat anterior.

Se recomienda mantener este documento actualizado cada vez que cierres una sesion importante o completes una feature relevante.

## 0. Progreso general

Progreso estimado actual del producto:

`97%`

Barra de avance:

`[-------------------] 97% completado`

Lectura practica:

- base y MVP serio: ya estan bastante solidos
- producto pulido y mas completo: todavia queda trabajo relevante
- falta aproximada: `3%`

Como actualizar este porcentaje:

- subelo cuando se cierre una capacidad grande de producto o una mejora estructural importante
- no lo subas por cambios cosmeticos pequenos o fixes aislados
- si se abre una linea nueva de producto grande, el porcentaje puede mantenerse estable aunque se haya trabajado mucho
- la meta no es precision matematica, sino orientacion honesta de por donde vamos

## 1. Vision del producto

`Ritual` es una app de planificacion diaria basada en bloques de tiempo. La intencion del producto no es solo listar tareas, sino ayudar al usuario a estructurar su dia de forma consciente, convertir acciones repetidas en rutina y mantener consistencia a traves de feedback visual y seguimiento.

La inspiracion nace de un sistema previo en Excel donde el usuario organizaba el dia por bloques horarios. La meta de la app es conservar esa claridad estructural, pero llevarla a una experiencia mucho mas visual, interactiva y persistente.

La idea general combina tres dimensiones:

- planificacion por bloques de tiempo
- seguimiento de habitos y cumplimiento diario
- una capa futura de gamificacion ligera y motivadora

Alcance actual deliberado:

- app local para uso personal en movil
- sin sincronizacion en la nube por ahora
- sin login ni autenticacion
- continuidad basada en almacenamiento local y respaldos manuales

El tono del producto debe sentirse sobrio, profesional, ordenado y agradable de usar. No se busca una experiencia infantil ni sobrecargada.

## 2. Direccion visual y experiencia

La linea visual actual gusta mucho y debe mantenerse como referencia base.

Caracteristicas de la direccion actual:

- tema oscuro como identidad principal
- acentos verdosos y azulados sobre fondos profundos
- sensacion sobria, moderna y profesional
- animaciones suaves, cortas y funcionales
- iconos Material usados con moderacion
- evitar efectos exagerados, rebotes excesivos o ruido visual

Decisiones UX importantes ya conversadas:

- el gesto principal debe servir para acciones frecuentes
- tocar un bloque debe completar o descompletar
- las acciones secundarias como editar o eliminar deben vivir en gestos o acciones auxiliares
- los checks deben animarse de forma sutil, no espectacular

## 3. Stack y arquitectura actual

Proyecto construido con Flutter.

Estructura general:

- `lib/main.dart`
- `lib/app/`
- `lib/core/`
- `lib/data/models/`
- `lib/data/services/`
- `lib/features/today/`
- `lib/shared/widgets/`

Persistencia:

- Hive como almacenamiento local

Enfoque actual:

- arquitectura simple tipo MVP temprano
- `TodayPage` mantiene la mayor parte del estado
- widgets reutilizables en `shared`
- modelos sencillos en `data/models`

Todavia no hay una capa mas avanzada de estado o repositorios complejos. El proyecto se ha mantenido intencionalmente simple para avanzar rapido.

## 4. Estado funcional actual

Al momento de escribir este archivo, esto ya existe y funciona:

### Base general

- app Flutter corriendo correctamente
- tema oscuro personalizado con identidad visual clara
- progreso animado del dia en la parte superior
- persistencia local de rutinas y bloques con Hive

### Rutinas

- carga de rutina por defecto en primera ejecucion
- selector de rutinas
- creacion de rutina nueva
- renombrado de rutina existente
- duplicado de rutinas
- eliminacion segura de rutinas
- una sola rutina activa a la vez
- vigencia configurable por rutina:
  - siempre
  - semana actual
  - mes actual
  - rango personalizado
- sugerencia automatica de la mejor rutina para hoy cuando aplica
- administracion de rutinas por periodo y estado temporal
- avisos cuando una rutina esta por empezar, terminar o quedar fuera del rango sugerido

### Bloques

- modelo `DayBlock` con:
  - inicio
  - fin
  - titulo
  - descripcion opcional
  - tipo
  - estado completado/no completado
- creacion de bloques
- edicion de bloques
- eliminacion de bloques
- reordenamiento de bloques
- seleccion de hora con picker nativo de Flutter
- validacion basica para que la hora final sea mayor que la inicial
- validacion de traslapes con confirmacion explicita del usuario
- alcance de cambios:
  - solo hoy
  - toda la rutina
- propiedad `countsTowardProgress`
- propiedad `receivesPushNotification`

### Interacciones

- tap en el bloque para completar o descompletar
- swipe a la derecha para editar
- swipe a la izquierda para eliminar
- icono de completado con animacion suave
- handle visual para reordenar bloques

### Historial, calendario y eventos

- historial diario separado de la plantilla de rutina
- reset diario automatico basado en registros por fecha
- streaks o rachas
- estadisticas basicas
- calendario mensual con navegacion por meses
- detalle por fecha con:
  - registro real
  - vista previa futura
  - estado vacio explicativo
- bloques o eventos puntuales por fecha
- edicion y eliminacion de eventos puntuales desde el detalle del calendario

### Notificaciones

- base de notificaciones locales en dispositivo
- diagnostico visible en la pantalla principal
- prueba manual de notificacion
- reagendado de recordatorios desde la UI
- comparacion exacta entre agenda esperada y agenda real del dispositivo
- vista `Ver agenda` para inspeccionar recordatorios esperados
- intento silencioso de auto-reparacion cuando la agenda queda desalineada
- soporte web limitado: conserva la preferencia, pero no agenda notificaciones locales

### Respaldo y continuidad

- exportacion de biblioteca de rutinas en CSV compatible con Excel
- importacion de biblioteca de rutinas pegando CSV desde Excel
- backup completo en JSON versionado con:
  - rutinas
  - historial diario
  - eventos puntuales
  - ajustes
- la continuidad actual del producto se apoya en estos respaldos manuales, no en servidor

## 5. Decisiones de producto ya tomadas

Estas decisiones ya se conversaron y conviene mantenerlas consistentes:

1. Todos los bloques pueden marcarse como completados.

Antes solo algunos tipos eran marcables. Se decidio que es mejor permitir completar cualquier bloque, porque en el uso real del producto tiene sentido marcar tambien trabajo, almuerzo, curso, descanso, etc.

2. El tipo de bloque no debe definir por si solo si se puede completar.

En el futuro, si hace falta distinguir entre bloques informativos y bloques medibles, seria mejor introducir una propiedad explicita como `countsTowardProgress` o `isTrackable`.

Tambien se decidio seguir la misma filosofia para notificaciones: cuando llegue esa etapa, cada bloque deberia poder definir explicitamente si quiere recibir recordatorio push, en lugar de inferirlo automaticamente por su tipo.

3. La vigencia de una rutina debe servir principalmente como sugerencia y organizacion, no como bloqueo duro.

El usuario puede seguir viendo o usando otras rutinas aunque no sean la recomendada para hoy.

4. Una sola rutina activa sigue siendo el comportamiento base de la app por ahora.

Sin embargo, queda anotada como idea futura la posibilidad de permitir varias rutinas en un mismo dia, por ejemplo una rutina de manana y otra de tarde, si eso aporta flexibilidad real sin complicar demasiado el producto.

5. La UX prioriza rapidez para el uso cotidiano.

Por eso:
- tap = completar
- swipe = editar/eliminar
- arrastre = reordenar

6. La linea visual actual debe mantenerse.

No se planea abrir variaciones de tema por ahora. Eso puede hablarse mucho mas adelante.

## 6. Lo que falta por hacer

Lo mas importante que sigue pendiente, en terminos practicos, es esto:

### Prioridad alta

- seguir estabilizando las notificaciones reales en Android y dispositivo
- validar en Android real la nueva comparacion exacta y el auto-healing de la agenda
- pulir mas la experiencia de eventos puntuales por fecha
- seguir fortaleciendo la gestion de rutinas por periodo
- seguir enriqueciendo estadisticas y lectura historica del sistema
- reforzar tests en flujos mas completos de calendario, eventos y cambio de rutina
- llevar el respaldo actual a una experiencia mas directa con archivos si hace falta

### Prioridad media

- mejorar la estructura interna del proyecto para que escale mejor
- refinar mas la experiencia del calendario
- mejorar la administracion de rutinas por periodo
- decidir si en el futuro se soportaran varias rutinas en un mismo dia

### Prioridad futura

- gamificacion
- importacion/exportacion directa con archivos Excel reales
- mejor soporte web y escritorio

Fuera de alcance por ahora:

- sincronizacion en la nube
- autenticacion

## 7. Proximos pasos recomendados

Si otra persona o un futuro hilo retoma el proyecto, el orden recomendado es:

1. validar en Android real el nuevo flujo de notificaciones con agenda exacta, auto-reparacion y diagnostico
2. seguir enriqueciendo eventos puntuales por fecha
3. reforzar tests de flujos completos en agenda, backup y notificaciones
4. mejorar la estructura interna del proyecto para que `TodayPage` no concentre tanta logica
5. decidir si el siguiente salto de continuidad sera archivo Excel real o una UX mas directa para CSV/backup

## 8. Estado del roadmap

Existe un roadmap mas estructurado en:

- `docs/ritual_roadmap.csv`
- `docs/ritual_roadmap.md`

Este archivo no reemplaza al roadmap. Lo complementa.

- `ritual_roadmap.csv` sirve como tablero y checklist
- `ritual_roadmap.md` sirve como explicacion por fases
- `ritual_context.md` sirve como resumen narrativo y contexto de continuidad

## 9. Como actualizar este archivo

Se recomienda actualizar estas secciones cuando avances:

- `Estado funcional actual`
- `Decisiones de producto ya tomadas`
- `Lo que falta por hacer`
- `Proximos pasos recomendados`

Si haces una feature importante, puedes agregar una subseccion como:

### Ultimos cambios

- fecha
- feature implementada
- decision UX tomada
- commit asociado

## 10. Prompt sugerido para retomar en otro hilo

Si quieres abrir otro hilo en otra PC, puedes pegar algo como esto:

> Estoy trabajando en una app Flutter llamada Ritual. Revisa `docs/ritual_context.md`, `docs/ritual_roadmap.md` y `docs/ritual_roadmap.csv` para tomar contexto. Quiero continuar desde el estado actual del proyecto sin perder la linea visual oscura, sobria y con animaciones suaves que ya definimos.

## 11. Notas abiertas

- La app tiene una buena base visual inicial y conviene no desordenarla con demasiadas acciones o iconos.
- El proyecto sigue en una fase donde la velocidad de iteracion importa mucho, pero ya empieza a valer la pena cuidar mejor la arquitectura.
- Cuando se implemente notificaciones, la intencion es que cada bloque tenga una propiedad explicita tipo `receivesPushNotification` o similar, comparable a `countsTowardProgress`.
- Este archivo esta pensado para ser editado manualmente y tambien para que Codex lo actualice en futuras sesiones.

## 12. Ultimos cambios importantes

### Historial y estadisticas

La app ya no depende solo de la plantilla de la rutina para representar el dia actual.
Ahora existe una separacion clara entre:

- la rutina como plantilla editable
- el registro diario como lo que realmente ocurrio en una fecha concreta

Esto permitio implementar:

- reset diario automatico
- historial por fecha
- rachas
- estadisticas basicas

### Navegacion de dias anteriores

Desde la pantalla principal ya existe una entrada al historial de la rutina activa.
El usuario puede:

- abrir dias anteriores
- ver el estado de cumplimiento de cada dia
- entrar al detalle de un dia pasado
- revisar que bloques tuvo ese dia y cuales se completaron

### Vigencia de rutinas

Las rutinas ahora tienen una configuracion explicita de vigencia.
Por el momento soportan:

- siempre
- semana actual
- mes actual
- rango personalizado

Decision de producto:

- una rutina puede seguir editandose aunque no este vigente hoy
- la vigencia sirve principalmente como aviso o sugerencia, no como bloqueo duro
- si la rutina no esta vigente hoy, la pantalla lo comunica, pero el usuario aun puede decidir usarla

### Rutina sugerida y administracion

La app ya puede sugerir automaticamente la mejor rutina para hoy cuando hay varias opciones vigentes.
Tambien existe una vista de administracion que agrupa rutinas por periodo y estado temporal para que sea mas facil mantenerlas.

Ademas, esa vista ya muestra una lectura mas rica por rutina:

- racha actual
- rendimiento de 7 dias
- progreso historico
- estado de vigencia
- pista breve de uso o preparacion

### Calendario y bloques puntuales

El calendario mensual ya no es solo una lista de registros. Ahora permite:

- navegar por meses
- ver dias con actividad real
- ver dias futuros planificados
- abrir el detalle de una fecha
- agregar, editar y eliminar eventos puntuales por fecha

Los eventos puntuales se tratan como algo separado de la rutina base, para no contaminar el historial ni la plantilla.

### Notificaciones del dispositivo

Ya existe una base real para notificaciones locales:

- propiedad `receivesPushNotification` por bloque
- servicio de notificaciones
- reagendado desde la UI
- prueba manual de notificacion
- diagnostico de permisos y cantidad de recordatorios programados

Todavia conviene seguir probandolo en Android real para asegurar que el comportamiento sea consistente.

### Estadisticas dedicadas

Ya existe una pantalla especifica de estadisticas separada de la home.

Permite:

- ver una vision general del sistema
- revisar cumplimiento global
- comparar rutinas por racha, 7 dias, 30 dias y progreso historico
- filtrar rutinas por contexto temporal

### Idea futura anotada

Se deja registrada una idea de evolucion posible:

- permitir varias rutinas en un mismo dia

Ejemplo de uso:

- una rutina de manana
- otra de tarde
- desactivar o reemplazar solo una parte del dia

Por ahora esto no forma parte del comportamiento base. Se mantiene como exploracion futura porque implicaria revisar con cuidado el modelo del dia, el calendario y la logica de sugerencias.

### Siguiente conversacion recomendada

Si otro hilo retoma el proyecto despues de este punto, el siguiente paso natural puede ser uno de estos:

1. validar en Android real la agenda exacta de notificaciones y su auto-reparacion
2. seguir mejorando los eventos puntuales por fecha
3. reforzar tests de flujos completos
4. llevar el respaldo a una experiencia de archivo mas directa si hace falta

## 13. Cambios recientes pendientes de validar

En la sesion actual se reforzo especialmente:

- diagnostico y prueba manual de notificaciones locales
- reagendado de recordatorios desde la UI
- flujo rapido para agregar:
  - bloque de rutina
  - evento puntual
- mejor separacion visual entre rutina base y eventos puntuales en el detalle de fecha
- exportacion/importacion de biblioteca en CSV compatible con Excel
- backup completo de la app en JSON versionado
- comparacion exacta de notificaciones esperadas vs pendientes en dispositivo
- vista `Ver agenda` para inspeccionar recordatorios esperados
- segundo intento silencioso de resincronizacion cuando la agenda sigue desalineada

La intencion de producto en este punto es:

- la vigencia debe avisar, no bloquear
- cada bloque decide si quiere push o no
- los eventos puntuales de calendario no deben reescribir la rutina base
- una sola rutina activa sigue siendo el comportamiento base, aunque existe la idea futura de permitir varias en un mismo dia
