import CRayLib

extension KeyboardKey {
    var isPressed: Bool {
        IsKeyPressed(Int32(self.rawValue))
    }
    var isPressedRepeat: Bool {
        IsKeyPressedRepeat(Int32(self.rawValue))
    }
    var isDown: Bool {
        IsKeyDown(Int32(self.rawValue))
    }
    var isUp: Bool {
        IsKeyUp(Int32(self.rawValue))
    }
}
