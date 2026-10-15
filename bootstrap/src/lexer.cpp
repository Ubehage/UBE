#include "ube/lexer.hpp"
#include "ube/unicode.hpp"
#include "ube/unicode_letter_ranges.hpp"

#include <algorithm>
#include <cctype>
#include <sstream>
#include <unordered_set>

namespace ube {
namespace {

bool ascii_alpha(char c) {
    const auto u = static_cast<unsigned char>(c);
    return std::isalpha(u) != 0 || c == '_';
}

struct DecodedCodePoint {
    char32_t value;
    std::size_t length;
};

DecodedCodePoint decode_utf8(std::string_view source, std::size_t offset) {
    if (offset >= source.size()) return {};
    const auto first = static_cast<unsigned char>(source[offset]);
    if (first < 0x80) return {first, 1};

    std::size_t length = 0;
    char32_t code_point = 0;
    if (first >= 0xC2 && first <= 0xDF) {
        length = 2;
        code_point = first & 0x1F;
    } else if (first >= 0xE0 && first <= 0xEF) {
        length = 3;
        code_point = first & 0x0F;
    } else if (first >= 0xF0 && first <= 0xF4) {
        length = 4;
        code_point = first & 0x07;
    } else {
        return {};
    }
    if (offset + length > source.size()) return {};

    for (std::size_t index = 1; index < length; ++index) {
        const auto continuation = static_cast<unsigned char>(source[offset + index]);
        if ((continuation & 0xC0) != 0x80) return {};
        code_point = (code_point << 6) | (continuation & 0x3F);
    }

    if ((length == 3 && code_point < 0x800) ||
        (length == 4 && code_point < 0x10000) ||
        (code_point >= 0xD800 && code_point <= 0xDFFF) || code_point > 0x10FFFF) {
        return {};
    }
    return {code_point, length};
}

bool unicode_letter(char32_t code_point) {
    const auto found = std::upper_bound(
        unicode::letter_ranges.begin(), unicode::letter_ranges.end(), code_point,
        [](char32_t value, const unicode::CodePointRange& range) { return value < range.first; });
    if (found == unicode::letter_ranges.begin()) return false;
    return code_point <= std::prev(found)->last;
}

bool identifier_start(std::string_view source, std::size_t offset) {
    const auto decoded = decode_utf8(source, offset);
    if (decoded.length == 0) return false;
    if (decoded.value < 0x80) return ascii_alpha(static_cast<char>(decoded.value));
    return unicode_letter(decoded.value);
}

bool identifier_part(std::string_view source, std::size_t offset) {
    const auto decoded = decode_utf8(source, offset);
    return identifier_start(source, offset) ||
           (decoded.value >= U'0' && decoded.value <= U'9');
}

const std::unordered_set<std::string>& keywords() {
    static const std::unordered_set<std::string> values = {
        "access", "addressof", "alias", "and", "any", "append", "as",
        "asm", "attribute", "base", "begin", "binary", "boolean", "byte", "bytecode",
        "byref", "byval", "call", "case", "class", "close", "compare", "const",
        "chdir", "chdrive", "currency", "database", "date", "decimal", "declare", "default", "dim", "do", "double",
        "each", "else", "elseif", "empty", "end", "enum", "eqv", "erase", "error",
        "event", "exit", "explicit", "false", "filecopy", "for", "forceinline", "form", "friend",
        "function", "get", "global", "gosub", "goto", "if", "imp", "implements",
        "in", "inline", "input", "integer", "intrinsic", "intptr", "is", "let",
        "kill", "len", "lib", "like", "line", "load", "lock", "long", "longlong", "loop", "lset",
        "mid", "mkdir", "mod", "module", "name", "new", "next", "not", "nothing", "null", "object", "off",
        "on", "open", "option", "optional", "or", "output", "page", "paramarray", "preserve",
        "print", "private", "property", "public", "put", "raiseevent", "random", "read",
        "redim", "reference", "rem", "resume", "return", "rmdir", "rset", "savepicture", "seek", "select", "set",
        "shared", "single", "spc", "static", "step", "stop", "string", "sub", "tab", "text", "then", "to",
        "true", "type", "uintptr", "unload", "until", "usercontrol", "variable", "variant", "version",
        "wend", "while", "with", "write", "xor"
    };
    return values;
}

bool is_hex(char c) {
    return std::isxdigit(static_cast<unsigned char>(c)) != 0;
}

bool is_oct(char c) { return c >= '0' && c <= '7'; }

bool parse_decimal_field(std::string_view text, std::size_t offset,
                         std::size_t length, unsigned& value) {
    if (offset + length > text.size()) return false;
    value = 0;
    for (std::size_t index = offset; index < offset + length; ++index) {
        const auto c = static_cast<unsigned char>(text[index]);
        if (c < '0' || c > '9') return false;
        value = value * 10 + (c - '0');
    }
    return true;
}

bool leap_year(unsigned year) {
    return year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);
}

bool valid_date_text(std::string_view text) {
    if (text.size() != 10 || text[4] != '-' || text[7] != '-') return false;
    unsigned year = 0;
    unsigned month = 0;
    unsigned day = 0;
    if (!parse_decimal_field(text, 0, 4, year) ||
        !parse_decimal_field(text, 5, 2, month) ||
        !parse_decimal_field(text, 8, 2, day) || year == 0 || month == 0 || month > 12) {
        return false;
    }
    constexpr unsigned days_per_month[] = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};
    unsigned maximum = days_per_month[month - 1];
    if (month == 2 && leap_year(year)) maximum = 29;
    return day != 0 && day <= maximum;
}

bool valid_time_text(std::string_view text) {
    if (text.size() < 5 || text[2] != ':') return false;
    unsigned hour = 0;
    unsigned minute = 0;
    if (!parse_decimal_field(text, 0, 2, hour) ||
        !parse_decimal_field(text, 3, 2, minute) || hour > 23 || minute > 59) {
        return false;
    }
    if (text.size() == 5) return true;
    if (text.size() < 8 || text[5] != ':') return false;
    unsigned second = 0;
    if (!parse_decimal_field(text, 6, 2, second) || second > 59) return false;
    if (text.size() == 8) return true;
    if (text[8] != '.' || text.size() == 9 || text.size() > 18) return false;
    for (std::size_t index = 9; index < text.size(); ++index) {
        if (text[index] < '0' || text[index] > '9') return false;
    }
    return true;
}

bool valid_date_time_text(std::string_view text) {
    if (valid_date_text(text) || valid_time_text(text)) return true;
    return text.size() > 11 && (text[10] == 'T' || text[10] == ' ') &&
           valid_date_text(text.substr(0, 10)) && valid_time_text(text.substr(11));
}

} // namespace

LexError::LexError(SourceLocation location, const std::string& message)
    : std::runtime_error(message), location_(location) {}

Lexer::Lexer(std::string_view source) : source_(source) {
    if (source_.size() >= 3 && static_cast<unsigned char>(source_[0]) == 0xEF &&
        static_cast<unsigned char>(source_[1]) == 0xBB &&
        static_cast<unsigned char>(source_[2]) == 0xBF) {
        current_ = 3;
        column_ = 1;
    }
}

bool Lexer::at_end() const { return current_ >= source_.size(); }

char Lexer::peek(std::size_t lookahead) const {
    const auto index = current_ + lookahead;
    return index < source_.size() ? source_[index] : '\0';
}

char Lexer::advance() {
    const char c = source_[current_];
    const auto decoded = decode_utf8(source_, current_);
    if (decoded.length == 0) throw LexError(location(), "invalid UTF-8 sequence");
    current_ += decoded.length;
    ++column_;
    return c;
}

bool Lexer::match(char expected) {
    if (peek() != expected) return false;
    advance();
    return true;
}

SourceLocation Lexer::location() const { return {current_, line_, column_}; }

void Lexer::add(TokenKind kind, SourceLocation start, std::size_t start_offset) {
    tokens_.push_back({kind, source_.substr(start_offset, current_ - start_offset), start});
}

void Lexer::scan_newline() {
    const auto start = location();
    const auto offset = current_;
    if (match('\r')) {
        if (!match('\n')) throw LexError(start, "carriage return must be followed by line feed");
    } else {
        advance();
    }
    add(TokenKind::Newline, start, offset);
    ++line_;
    column_ = 1;
    statement_start_ = true;
}

bool Lexer::skip_comment() {
    if (peek() == '\'') {
        while (!at_end() && peek() != '\r' && peek() != '\n') advance();
        return true;
    }
    const auto rem = current_ + 3 <= source_.size()
        ? unicode::simple_case_fold(std::string_view(source_).substr(current_, 3))
        : std::nullopt;
    if (statement_start_ && rem && *rem == "rem" &&
        (peek(3) == ' ' || peek(3) == '\t' || peek(3) == '\r' || peek(3) == '\n' || peek(3) == '\0')) {
        while (!at_end() && peek() != '\r' && peek() != '\n') advance();
        return true;
    }
    return false;
}

void Lexer::skip_horizontal_space_and_continuations() {
    for (;;) {
        bool saw_space = false;
        while (peek() == ' ' || peek() == '\t') { saw_space = true; advance(); }
        if (!saw_space || peek() != '_') return;

        std::size_t look = 1;
        while (peek(look) == ' ' || peek(look) == '\t') ++look;
        if (peek(look) == '\'') {
            while (peek(look) != '\0' && peek(look) != '\r' && peek(look) != '\n') ++look;
        }
        if (peek(look) != '\r' && peek(look) != '\n') return;
        if (peek(look) == '\r' && peek(look + 1) != '\n') {
            throw LexError(location(), "carriage return must be followed by line feed");
        }

        const auto newline_offset = current_ + look;
        while (current_ < newline_offset) advance();
        if (match('\r')) match('\n'); else advance();
        ++line_;
        column_ = 1;
    }
}

void Lexer::scan_identifier() {
    const auto start = location();
    const auto offset = current_;
    while (identifier_part(source_, current_)) advance();
    const auto folded = unicode::simple_case_fold(
        std::string_view(source_).substr(offset, current_ - offset));
    add(folded && keywords().count(*folded) ? TokenKind::Keyword : TokenKind::Identifier,
        start, offset);
    statement_start_ = false;
}

void Lexer::scan_bracketed_identifier() {
    const auto start = location();
    const auto offset = current_;
    advance();
    bool has_content = false;
    while (!at_end() && peek() != '\r' && peek() != '\n') {
        if (peek() == ']') {
            advance();
            if (match(']')) { has_content = true; continue; }
            if (!has_content) throw LexError(start, "empty bracketed identifier");
            add(TokenKind::Identifier, start, offset);
            statement_start_ = false;
            return;
        }
        has_content = true;
        advance();
    }
    throw LexError(start, "unterminated bracketed identifier");
}

void Lexer::scan_number() {
    const auto start = location();
    const auto offset = current_;
    bool real = false;
    bool based = false;
    bool hexadecimal = false;
    if (peek() == '&' && (peek(1) == 'H' || peek(1) == 'h' || peek(1) == 'O' || peek(1) == 'o')) {
        based = true;
        hexadecimal = peek(1) == 'H' || peek(1) == 'h';
        advance(); advance();
        const auto digits = current_;
        while (hexadecimal ? is_hex(peek()) : is_oct(peek())) advance();
        if (current_ == digits) throw LexError(start, "expected digits after integer base prefix");
    } else {
        while (std::isdigit(static_cast<unsigned char>(peek()))) advance();
        if (peek() == '.') {
            real = true; advance();
            while (std::isdigit(static_cast<unsigned char>(peek()))) advance();
        }
        if (peek() == 'e' || peek() == 'E') {
            real = true; advance();
            if (peek() == '+' || peek() == '-') advance();
            if (!std::isdigit(static_cast<unsigned char>(peek()))) throw LexError(start, "expected exponent digits");
            while (std::isdigit(static_cast<unsigned char>(peek()))) advance();
        }
    }
    if (!based && (peek() == '!' || peek() == '#' || peek() == '@' ||
                   peek() == 'F' || peek() == 'f' || peek() == 'R' ||
                   peek() == 'r' || peek() == 'D' || peek() == 'd')) {
        real = true;
        advance();
    } else if (!real) {
        if (peek() == '%' || peek() == '&' || peek() == '^') {
            advance();
        } else {
            const auto suffix = unicode::simple_case_fold(
                std::string_view(source_).substr(current_, 2));
            if (suffix && (*suffix == "us" || *suffix == "ui" || *suffix == "ul")) {
                advance(); advance();
            } else if (peek() == 'S' || peek() == 's' || peek() == 'I' || peek() == 'i' ||
                       peek() == 'L' || peek() == 'l') {
                advance();
            }
        }
    }
    if (based && std::isalnum(static_cast<unsigned char>(peek())) != 0) {
        throw LexError(start, hexadecimal ? "invalid hexadecimal integer" : "invalid octal integer");
    }
    add(real ? TokenKind::RealLiteral : TokenKind::IntegerLiteral, start, offset);
    statement_start_ = false;
}

void Lexer::scan_string() {
    const auto start = location();
    const auto offset = current_;
    advance();
    while (!at_end() && peek() != '\r' && peek() != '\n') {
        if (peek() == '"') {
            advance();
            if (match('"')) continue;
            add(TokenKind::StringLiteral, start, offset);
            statement_start_ = false;
            return;
        }
        advance();
    }
    throw LexError(start, "unterminated string literal");
}

bool Lexer::scan_date() {
    const auto close = source_.find('#', current_ + 1);
    const auto newline = source_.find_first_of("\r\n", current_ + 1);
    if (close == std::string::npos || (newline != std::string::npos && newline < close) || close == current_ + 1) return false;
    const auto start = location();
    const auto offset = current_;
    const auto contents = std::string_view(source_).substr(current_ + 1, close - current_ - 1);
    if (!valid_date_time_text(contents)) {
        throw LexError(start, "invalid invariant date/time literal");
    }
    while (current_ <= close) advance();
    add(TokenKind::DateLiteral, start, offset);
    statement_start_ = false;
    return true;
}

std::vector<Token> Lexer::scan() {
    while (!at_end()) {
        skip_horizontal_space_and_continuations();
        if (at_end()) break;
        if (skip_comment()) continue;
        const char c = peek();
        if (c == '\r' || c == '\n') { scan_newline(); continue; }
        if (identifier_start(source_, current_)) { scan_identifier(); continue; }
        if (c == '[') { scan_bracketed_identifier(); continue; }
        if (std::isdigit(static_cast<unsigned char>(c)) ||
            (c == '.' && std::isdigit(static_cast<unsigned char>(peek(1)))) ||
            (c == '&' && (peek(1) == 'H' || peek(1) == 'h' || peek(1) == 'O' || peek(1) == 'o'))) {
            scan_number(); continue;
        }
        if (c == '"') { scan_string(); continue; }
        if (c == '#' && scan_date()) continue;

        const auto start = location();
        const auto offset = current_;
        advance();
        if ((c == '<' && (peek() == '=' || peek() == '>')) || (c == '>' && peek() == '=')) advance();
        const bool punctuation = c == '(' || c == ')' || c == ',' || c == '.' || c == ':' ||
                                 c == ';' || c == '#';
        const bool op = c == '+' || c == '-' || c == '*' || c == '/' || c == '\\' || c == '^' ||
                        c == '=' || c == '<' || c == '>' || c == '&' || c == '!' || c == '@' || c == '$' || c == '%';
        if (!punctuation && !op) {
            std::ostringstream message;
            message << "unexpected byte 0x" << std::hex << static_cast<int>(static_cast<unsigned char>(c));
            throw LexError(start, message.str());
        }
        add(punctuation ? TokenKind::Punctuation : TokenKind::Operator, start, offset);
        statement_start_ = c == ':';
    }

    if (tokens_.empty() || tokens_.back().kind != TokenKind::Newline) {
        tokens_.push_back({TokenKind::Newline, "", location()});
    }
    tokens_.push_back({TokenKind::EndOfFile, "", location()});
    return tokens_;
}

} // namespace ube
