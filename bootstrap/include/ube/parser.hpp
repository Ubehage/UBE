#pragma once

#include "ube/ast.hpp"

#include <stdexcept>
#include <vector>

namespace ube {

class ParseError : public std::runtime_error {
public:
    ParseError(SourceLocation location, const std::string& message);
    SourceLocation location() const noexcept { return location_; }

private:
    SourceLocation location_;
};

class Parser {
public:
    explicit Parser(std::vector<Token> tokens);
    ast::Module parse_module();

private:
    const Token& current() const;
    const Token& previous() const;
    bool at_end() const;
    const Token& advance();
    bool check(TokenKind kind) const;
    bool check_text(std::string_view text) const;
    bool match_text(std::string_view text);
    const Token& consume_text(std::string_view text, const std::string& message);
    const Token& consume_identifier(const std::string& message);
    void consume_line_end();
    void skip_newlines();

    ast::Procedure parse_procedure();
    ast::TypeDeclaration parse_type_declaration();
    ast::Parameter parse_parameter();
    std::string parse_type_name();
    std::unique_ptr<ast::Statement> parse_statement();
    std::unique_ptr<ast::Statement> parse_variable_declaration();
    std::unique_ptr<ast::Statement> parse_print_statement();
    std::unique_ptr<ast::Statement> parse_assignment_statement();
    std::unique_ptr<ast::Statement> parse_redim_statement();
    std::unique_ptr<ast::Statement> parse_if_statement();
    std::unique_ptr<ast::Statement> parse_while_statement();
    std::unique_ptr<ast::Statement> parse_for_statement();
    std::unique_ptr<ast::Statement> parse_call_statement();
    std::vector<std::unique_ptr<ast::Statement>> parse_statement_block(
        std::string_view first_terminator, std::string_view second_terminator = {});
    std::unique_ptr<ast::Expression> parse_expression(int minimum_precedence = 1);
    std::unique_ptr<ast::Expression> parse_unary();
    std::unique_ptr<ast::Expression> parse_primary();
    std::unique_ptr<ast::CallExpression> finish_call(const Token& name);
    int binary_precedence() const;
    bool right_associative() const;

    std::vector<Token> tokens_;
    std::size_t current_{};
};

} // namespace ube
