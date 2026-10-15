#pragma once

#include "ube/token.hpp"

#include <stdexcept>
#include <string>
#include <string_view>
#include <vector>

namespace ube {

class LexError : public std::runtime_error {
public:
    LexError(SourceLocation location, const std::string& message);
    SourceLocation location() const noexcept { return location_; }

private:
    SourceLocation location_;
};

class Lexer {
public:
    explicit Lexer(std::string_view source);
    std::vector<Token> scan();

private:
    bool at_end() const;
    char peek(std::size_t lookahead = 0) const;
    char advance();
    bool match(char expected);
    SourceLocation location() const;
    void add(TokenKind kind, SourceLocation start, std::size_t start_offset);
    void skip_horizontal_space_and_continuations();
    bool skip_comment();
    void scan_identifier();
    void scan_bracketed_identifier();
    void scan_number();
    void scan_string();
    bool scan_date();
    void scan_newline();

    std::string source_;
    std::size_t current_{};
    std::size_t line_{1};
    std::size_t column_{1};
    bool statement_start_{true};
    std::vector<Token> tokens_;
};

} // namespace ube
