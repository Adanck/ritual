# Ritual Context

Este archivo sirve como contexto vivo del proyecto. La idea es que puedas abrirlo desde otra PC, pegarlo en otro hilo y retomar el trabajo sin depender de la memoria del chat anterior.

Se recomienda mantener este documento actualizado cada vez que cierres una sesion importante o completes una feature relevante.

## 1. Vision del producto

`Ritual` es una app de planificacion diaria basada en bloques de tiempo. La intencion del producto no es solo listar tareas, sino ayudar al usuario a estructurar su dia de forma consciente, convertir acciones repetidas en rutina y mantener consistencia a traves de feedback visual y seguimiento.

La inspiracion nace de un sistema previo en Excel donde el usuario organizaba el dia por bloques horarios. La meta de la app es conservar esa claridad estructural, pero llevarla a una experiencia mucho mas visual, interactiva y persistente.

La idea general combina tres dimensiones:

- planificacion por bloques de tiempo
- seguimiento de habitos y cumplimiento diario
- una capa futura de gamificacion ligera y motivadora

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
- una sola rutina activa a la vez

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

### Interacciones

- tap en el bloque para completar o descompletar
- swipe a la derecha para editar
- swipe a la izquierda para eliminar
- icono de completado con animacion suave
- handle visual para reordenar bloques

## 5. Decisiones de producto ya tomadas

Estas decisiones ya se conversaron y conviene mantenerlas consistentes:

1. Todos los bloques pueden marcarse como completados.

Antes solo algunos tipos eran marcables. Se decidio que es mejor permitir completar cualquier bloque, porque en el uso real del producto tiene sentido marcar tambien trabajo, almuerzo, curso, descanso, etc.

2. El tipo de bloque no debe definir por si solo si se puede completar.

En el futuro, si hace falta distinguir entre bloques informativos y bloques medibles, seria mejor introducir una propiedad explicita como `countsTowardProgress` o `isTrackable`.

3. La UX prioriza rapidez para el uso cotidiano.

Por eso:
- tap = completar
- swipe = editar/eliminar
- arrastre = reordenar

4. La linea visual actual debe mantenerse.

No se planea abrir variaciones de tema por ahora. Eso puede hablarse mucho mas adelante.

## 6. Lo que falta por hacer

Lo mas importante que sigue pendiente, en terminos practicos, es esto:

### Prioridad alta

- revisar y reforzar la validacion de horas
- agregar tests basicos de modelos, persistencia y widgets clave
- evaluar si el progreso debe contar todos los bloques o solo algunos
- mejorar el modelo de tiempo para que no dependa siempre de `String`

### Prioridad media

- eliminar rutinas
- crear una pantalla o flujo mas comodo para administrar rutinas
- mejorar el estado vacio y mensajes de ayuda
- mejorar la estructura interna del proyecto para que escale mejor

### Prioridad futura

- historial por fecha
- streaks o rachas
- estadisticas
- gamificacion
- importacion/exportacion con Excel
- sincronizacion en la nube
- autenticacion
- mejor soporte web y escritorio

## 7. Proximos pasos recomendados

Si otra persona o un futuro hilo retoma el proyecto, el orden recomendado es:

1. fortalecer validacion de horas
2. agregar tests basicos
3. decidir si todos los bloques cuentan igual para progreso
4. permitir eliminar rutinas de forma segura
5. mejorar el modelo de tiempo
6. empezar historial diario y streaks

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
- Este archivo esta pensado para ser editado manualmente y tambien para que Codex lo actualice en futuras sesiones.
