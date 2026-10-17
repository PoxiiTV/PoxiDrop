import Foundation

/// Estado local de una vista. En el SDK 27, `@State` es una macro cuyo plugin solo viene con Xcode;
/// con un `ObservableObject` y `@StateObject` la app compila también solo con las Command Line Tools.
@MainActor
final class ViewState<Value>: ObservableObject {
    @Published var value: Value
    init(_ value: Value) { self.value = value }
}
