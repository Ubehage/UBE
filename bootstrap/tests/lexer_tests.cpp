#include "ube/lexer.hpp"
#include "ube/unicode.hpp"

#include <cstdlib>
#include <iostream>
#include <string>
#include <vector>

namespace {
using ube::TokenKind;

void fail(const std::string& message) {
    std::cerr << "FAIL: " << message << '\n';
    std::exit(1);
}

void expect_tokens(std::string_view source, const std::vector<TokenKind>& expected) {
    const auto tokens = ube::Lexer(source).scan();
    if (tokens.size() != expected.size()) fail("unexpected token count for: " + std::string(source));
    for (std::size_t i = 0; i < expected.size(); ++i) {
        if (tokens[i].kind != expected[i]) fail("unexpected token kind at index " + std::to_string(i));
    }
}

void expect_lexemes(std::string_view source, const std::vector<std::string>& expected) {
    const auto tokens = ube::Lexer(source).scan();
    if (tokens.size() != expected.size()) fail("unexpected token count");
    for (std::size_t i = 0; i < expected.size(); ++i) {
        if (tokens[i].lexeme != expected[i]) fail("unexpected lexeme at index " + std::to_string(i));
    }
}

void expect_error(std::string_view source, std::size_t line, std::size_t column,
                  std::string_view message) {
    try {
        static_cast<void>(ube::Lexer(source).scan());
    } catch (const ube::LexError& error) {
        if (error.location().line != line || error.location().column != column) {
            fail("unexpected error location for: " + std::string(source));
        }
        if (error.what() != message) fail("unexpected error message: " + std::string(error.what()));
        return;
    }
    fail("expected lexer error for: " + std::string(source));
}

void expect_location(std::string_view source, std::size_t token_index,
                     std::size_t offset, std::size_t line, std::size_t column) {
    const auto tokens = ube::Lexer(source).scan();
    if (token_index >= tokens.size()) fail("missing token for location check");
    const auto location = tokens[token_index].location;
    if (location.offset != offset || location.line != line || location.column != column) {
        fail("unexpected token location at index " + std::to_string(token_index));
    }
}

void expect_fold(std::string_view source, std::string_view expected) {
    const auto folded = ube::unicode::simple_case_fold(source);
    if (!folded || *folded != expected) fail("unexpected simple case fold");
}

void expect_controlled_result(std::string_view source) {
    try {
        static_cast<void>(ube::Lexer(source).scan());
    } catch (const ube::LexError&) {
        return;
    } catch (const std::exception& error) {
        fail("unexpected exception type for malformed input: " + std::string(error.what()));
    } catch (...) {
        fail("non-standard exception for malformed input");
    }
}
}

int main() {
    expect_tokens("Dim Value As Long\n", {TokenKind::Keyword, TokenKind::Identifier,
        TokenKind::Keyword, TokenKind::Keyword, TokenKind::Newline, TokenKind::EndOfFile});
    expect_tokens("42 1& &HFF 3.14 2E+3 7UL 1. .5 1# 2D 3!\n", {TokenKind::IntegerLiteral, TokenKind::IntegerLiteral,
        TokenKind::IntegerLiteral, TokenKind::RealLiteral, TokenKind::RealLiteral,
        TokenKind::IntegerLiteral, TokenKind::RealLiteral, TokenKind::RealLiteral,
        TokenKind::RealLiteral, TokenKind::RealLiteral, TokenKind::RealLiteral,
        TokenKind::Newline, TokenKind::EndOfFile});
    expect_tokens("&HFF& &O7UL\n", {TokenKind::IntegerLiteral, TokenKind::IntegerLiteral,
        TokenKind::Newline, TokenKind::EndOfFile});
    expect_tokens("\"a\"\"b\" #2026-10-13# [End]\n", {TokenKind::StringLiteral,
        TokenKind::DateLiteral, TokenKind::Identifier, TokenKind::Newline, TokenKind::EndOfFile});
    expect_tokens("#00:00# #23:59:59# #12:34:56.123456789# #2000-02-29 12:30#\n",
        {TokenKind::DateLiteral, TokenKind::DateLiteral, TokenKind::DateLiteral,
         TokenKind::DateLiteral, TokenKind::Newline, TokenKind::EndOfFile});
    expect_lexemes("x = 1 _\n  + 2 ' ignored\n", {"x", "=", "1", "+", "2", "\n", ""});
    expect_lexemes("Rem ignored\nx: Rem ignored\ny", {"\n", "x", ":", "\n", "y", "", ""});
    expect_lexemes("x _ ' continued\r\n\t+ y\r\n", {"x", "+", "y", "\r\n", ""});
    expect_lexemes("[a]]b] ' comment at EOF", {"[a]]b]", "", ""});
    const auto bom = std::string("\xEF\xBB\xBF") + "Dim x";
    expect_tokens(bom, {TokenKind::Keyword, TokenKind::Identifier, TokenKind::Newline, TokenKind::EndOfFile});
    expect_error("&O8", 1, 1, "expected digits after integer base prefix");
    expect_error("&O78", 1, 1, "invalid octal integer");
    expect_error("&HFG", 1, 1, "invalid hexadecimal integer");
    expect_error("x\ry", 1, 2, "carriage return must be followed by line feed");
    expect_error("x _\ry", 1, 3, "carriage return must be followed by line feed");
    expect_error("[]", 1, 1, "empty bracketed identifier");
    expect_error("\"unterminated", 1, 1, "unterminated string literal");
    expect_lexemes("Æble = \"blåbær\"\n", {"Æble", "=", "\"blåbær\"", "\n", ""});
    expect_tokens("Δelta Жук 東京 Deseret𐐀\n", {TokenKind::Identifier, TokenKind::Identifier,
        TokenKind::Identifier, TokenKind::Identifier, TokenKind::Newline, TokenKind::EndOfFile});
    expect_location("Æble x\n", 1, 6, 1, 6);
    expect_location("' blåbær\nÆble", 1, 11, 2, 1);
    expect_error(std::string("x ") + static_cast<char>(0x80), 1, 3, "invalid UTF-8 sequence");
    expect_error(std::string("x ") + static_cast<char>(0xC3), 1, 3, "invalid UTF-8 sequence");
    expect_error(std::string("x ") + "\xED\xA0\x80", 1, 3, "invalid UTF-8 sequence");
    expect_error(std::string("x ") + "\xF4\x90\x80\x80", 1, 3, "invalid UTF-8 sequence");
    expect_error("€uro", 1, 1, "unexpected byte 0xe2");
    expect_error("́accent", 1, 1, "unexpected byte 0xcc");
    expect_error("١number", 1, 1, "unexpected byte 0xd9");
    expect_error("á", 1, 2, "unexpected byte 0xcc");
    expect_error("#2025-02-29#", 1, 1, "invalid invariant date/time literal");
    expect_error("#2026-13-01#", 1, 1, "invalid invariant date/time literal");
    expect_error("#24:00#", 1, 1, "invalid invariant date/time literal");
    expect_error("#12:30:60#", 1, 1, "invalid invariant date/time literal");
    expect_error("#10/13/2026#", 1, 1, "invalid invariant date/time literal");
    expect_fold("DIM", "dim");
    expect_fold("Straße", "straße");
    expect_fold("Σςσ", "σσσ");
    expect_fold("Kelvin", "kelvin");
    expect_fold("𐐀", "𐐨");
    expect_fold("İ", "İ");
    if (ube::unicode::simple_case_fold(std::string(1, static_cast<char>(0x80)))) {
        fail("invalid UTF-8 unexpectedly case-folded");
    }
    for (unsigned first = 0; first <= 0xFF; ++first) {
        expect_controlled_result(std::string(1, static_cast<char>(first)));
        for (unsigned second = 0; second <= 0xFF; ++second) {
            std::string bytes;
            bytes.push_back(static_cast<char>(first));
            bytes.push_back(static_cast<char>(second));
            expect_controlled_result(bytes);
        }
    }
    std::cout << "lexer tests passed\n";
}
