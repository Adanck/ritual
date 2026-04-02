/// Clasifica semanticamente los bloques del sistema.
///
/// Los tipos ayudan a dar contexto visual y de uso. `event` representa un
/// bloque puntual ligado a una fecha concreta, como una reunion o una cita.
enum BlockType {
  habit,
  commitment,
  visual,
  reminder,
  event,
}
