import CRayLib

extension KeyboardKey {
    var isPressed: Bool {
        return IsKeyPressed(Int32(self.rawValue))
    }
}
