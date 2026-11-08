import Carbon

public final class CarbonInputSourceService: InputSourceServicing {
    public init() {}

    public func availableInputSources() -> [InputSourceInfo] {
        keyboardSources().compactMap { source in
            guard let id = stringProperty(source, kTISPropertyInputSourceID),
                  let name = stringProperty(source, kTISPropertyLocalizedName) else {
                return nil
            }
            return InputSourceInfo(id: id, name: name)
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    public func currentInputSourceID() -> String? {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            return nil
        }
        return stringProperty(source, kTISPropertyInputSourceID)
    }

    public func selectInputSource(id: String) -> Bool {
        guard let source = keyboardSources().first(where: {
            stringProperty($0, kTISPropertyInputSourceID) == id
        }) else {
            return false
        }
        return TISSelectInputSource(source) == noErr
    }

    private func keyboardSources() -> [TISInputSource] {
        guard let sources = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] else {
            return []
        }
        return sources.filter { source in
            guard stringProperty(source, kTISPropertyInputSourceCategory) == kTISCategoryKeyboardInputSource as String,
                  let pointer = TISGetInputSourceProperty(source, kTISPropertyInputSourceIsSelectCapable) else {
                return false
            }
            return CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(pointer).takeUnretainedValue())
        }
    }

    private func stringProperty(_ source: TISInputSource, _ key: CFString) -> String? {
        guard let pointer = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<CFString>.fromOpaque(pointer).takeUnretainedValue() as String
    }
}
