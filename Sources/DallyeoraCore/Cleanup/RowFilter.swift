import Foundation

/// 정리하기 창의 검색. 줄의 제목·설명·프로세스 이름 중 하나에 검색어가 들어 있으면 맞다.
public enum RowFilter {
    public static func matches(query: String, in fields: [String]) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).precomposedStringWithCanonicalMapping
        guard !needle.isEmpty else { return true }
        return fields.contains {
            $0.precomposedStringWithCanonicalMapping.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }
}
