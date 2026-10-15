#pragma once

#include <cstddef>
#include <string>
#include <string_view>

namespace ube {

struct SourceLocation {
    std::size_t offset{};
    std::size_t line{1};
    std::size_t column{1};
};

enum class TokenKind {
    Identifier,
    Keyword,
    IntegerLiteral,
    RealLiteral,
    StringLiteral,
    DateLiteral,
    Operator,
    Punctuation,
    Newline,
    EndOfFile,
};

struct Token {
    TokenKind kind;
    std::string lexeme;
    SourceLocation location;
};

constexpr std::string_view token_kind_name(TokenKind kind) {
    switch (kind) {
    case TokenKind::Identifier: return "identifier";
    case TokenKind::Keyword: return "keyword";
    case TokenKind::IntegerLiteral: return "integer";
    case TokenKind::RealLiteral: return "real";
    case TokenKind::StringLiteral: return "string";
    case TokenKind::DateLiteral: return "date";
    case TokenKind::Operator: return "operator";
    case TokenKind::Punctuation: return "punctuation";
    case TokenKind::Newline: return "newline";
    case TokenKind::EndOfFile: return "eof";
    }
    return "unknown";
}

} // namespace ube
