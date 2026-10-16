package content

import "core:encoding/json"
import "core:strconv"
import "core:unicode/utf8"
import "core:math"

Strict :: struct { tokenizer: json.Tokenizer, token: json.Token, count: int, error: string }
advance :: proc(s: ^Strict) {
    if s.error != "" { return }
    t, e := json.get_token(&s.tokenizer)
    s.token = t
    s.count += 1
    if s.count > MAX_TOKENS { s.error = "token_limit" }
    else if e != nil && !(e == .EOF && t.kind == .EOF) { s.error = "invalid_json" }
    else if t.kind == .String && !strict_string(t.text) { s.error = "invalid_string" }
    else if t.kind == .Integer || t.kind == .Float {
        if !strict_number(t.text) { s.error = "invalid_number"; return }
        if t.kind == .Integer {
            // The installed strconv parser can wrap overflowing signed values
            // while returning ok. Check decimal bounds before conversion.
            digits:=t.text; bound:="9223372036854775807"
            if digits[0]=='-' { digits=digits[1:]; bound="9223372036854775808" }
            if len(digits)>len(bound) || len(digits)==len(bound) && digits>bound { s.error="number_range"; return }
            _, ok := strconv.parse_i64(t.text)
            if !ok { s.error = "number_range" }
        } else {
            f, ok := strconv.parse_f64(t.text)
            if !ok || math.is_inf(f) || math.is_nan(f) { s.error = "number_range" }
        }
    }
}
strict_number :: proc(t: string) -> bool {
    i := 0
    if len(t) == 0 { return false }
    if t[i] == '-' { i += 1 }
    if i >= len(t) { return false }
    if t[i] == '0' { i += 1 }
    else {
        if t[i] < '1' || t[i] > '9' { return false }
        for i < len(t) && t[i] >= '0' && t[i] <= '9' { i += 1 }
    }
    if i < len(t) && t[i] == '.' {
        i += 1; start := i
        for i < len(t) && t[i] >= '0' && t[i] <= '9' { i += 1 }
        if i == start { return false }
    }
    if i < len(t) && (t[i] == 'e' || t[i] == 'E') {
        i += 1
        if i < len(t) && (t[i] == '+' || t[i] == '-') { i += 1 }
        start := i
        for i < len(t) && t[i] >= '0' && t[i] <= '9' { i += 1 }
        if i == start { return false }
    }
    return i == len(t)
}
hex4 :: proc(t: string) -> (u32, bool) {
    if len(t) < 4 { return 0, false }
    n: u32
    for c in t[:4] {
        n *= 16
        switch c { case '0'..='9': n += u32(c-'0'); case 'a'..='f': n += u32(c-'a'+10); case 'A'..='F': n += u32(c-'A'+10); case: return 0, false }
    }
    return n, true
}
strict_string :: proc(t: string) -> bool {
    if len(t) < 2 || t[0] != '"' || t[len(t)-1] != '"' { return false }
    for i := 1; i < len(t)-1; i += 1 {
        c := t[i]
        if c < 32 || c == '"' { return false }
        if c != '\\' { continue }
        i += 1
        if i >= len(t)-1 { return false }
        switch t[i] {
        case '"', '\\', '/', 'b', 'f', 'n', 'r', 't':
        case 'u':
            n, ok := hex4(t[i+1:len(t)-1]); if !ok { return false }; i += 4
            if n >= 0xd800 && n <= 0xdbff {
                if i+6 >= len(t) || t[i+1:i+3] != "\\u" { return false }
                low, valid := hex4(t[i+3:len(t)-1])
                if !valid || low < 0xdc00 || low > 0xdfff { return false }; i += 6
            } else if n >= 0xdc00 && n <= 0xdfff { return false }
        case: return false
        }
    }
    return true
}
strict_value :: proc(s: ^Strict, depth: int) {
    if s.error != "" { return }
    if depth > MAX_DEPTH { s.error = "depth_limit"; return }
    #partial switch s.token.kind {
    case .Open_Brace, .Open_Bracket:
        object := s.token.kind == .Open_Brace
        end := json.Token_Kind.Close_Bracket
        if object { end = .Close_Brace }
        advance(s)
        if s.token.kind == end { advance(s); return }
        for s.error == "" {
            if object {
                if s.token.kind != .String { s.error = "expected_key"; return }
                // Installed DOM parsing silently drops empty object keys.
                // No v1 content/protocol object allows an empty field or ID.
                if s.token.text == `""` { s.error = "unknown_field"; return }
                advance(s)
                if s.token.kind != .Colon { s.error = "expected_colon"; return }
                advance(s)
            }
            strict_value(s, depth+1)
            if s.error != "" { return }
            if s.token.kind == end { advance(s); return }
            if s.token.kind != .Comma { s.error = "expected_delimiter"; return }
            advance(s)
            if s.token.kind == end { s.error = "trailing_comma"; return }
        }
    case .String, .Integer, .Float, .True, .False, .Null: advance(s)
    case: s.error = "expected_value"
    }
}
// Strict adapter over the installed tokenizer, followed by duplicate-key-aware
// DOM parsing. The adapter also closes installed tokenizer gaps (NUL/whitespace,
// number conversion overflow, exponent grammar, escapes and surrogate pairing).
parse_strict :: proc(bytes: []u8, file: string) -> (json.Value, Diagnostic, bool) {
    if len(bytes) > MAX_DOCUMENT_BYTES { return {}, diagnostic("size_limit", file, "", "Document exceeds 256 KiB"), false }
    if !utf8.valid_string(string(bytes)) { return {}, diagnostic("invalid_utf8", file, "", "Input must be valid UTF-8"), false }
    quoted, escaped := false, false
    for b in bytes {
        if !quoted && (b == 0 || b == 11 || b == 12) { return {}, diagnostic("invalid_json", file, "", "Invalid JSON whitespace or NUL"), false }
        if escaped { escaped = false; continue }
        if quoted && b == '\\' { escaped = true; continue }
        if b == '"' { quoted = !quoted }
    }
    if len(bytes) >= 3 && bytes[0] == 0xef && bytes[1] == 0xbb && bytes[2] == 0xbf { return {}, diagnostic("invalid_json", file, "", "BOM is not accepted"), false }
    s := Strict{tokenizer=json.make_tokenizer(string(bytes), .JSON, true)}
    advance(&s); strict_value(&s, 0)
    if s.error == "" && s.token.kind != .EOF { s.error = "trailing_input" }
    if s.error != "" {
        d := diagnostic(s.error, file, "", "Strict JSON rejected input")
        d.line = s.token.line; d.column = s.token.column+1
        return {}, d, false
    }
    v, e := json.parse(bytes, .JSON, true)
    if e != nil { return {}, diagnostic("invalid_json", file, "", "JSON DOM rejected input (including duplicate keys)"), false }
    return v, {}, true
}
