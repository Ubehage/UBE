#include "ube/parser.hpp"
#include "ube/unicode.hpp"

#include <utility>

namespace ube {
namespace {

std::string folded(std::string_view text) {
    const auto value = unicode::simple_case_fold(text);
    return value ? *value : std::string(text);
}

bool is_literal(TokenKind kind) {
    return kind == TokenKind::IntegerLiteral || kind == TokenKind::RealLiteral ||
           kind == TokenKind::StringLiteral || kind == TokenKind::DateLiteral;
}

} // namespace

ParseError::ParseError(SourceLocation location, const std::string& message)
    : std::runtime_error(message), location_(location) {}

Parser::Parser(std::vector<Token> tokens) : tokens_(std::move(tokens)) {
    if (tokens_.empty() || tokens_.back().kind != TokenKind::EndOfFile) {
        throw ParseError({}, "parser requires an EOF-terminated token stream");
    }
}

const Token& Parser::current() const { return tokens_[current_]; }
const Token& Parser::previous() const { return tokens_[current_ - 1]; }
bool Parser::at_end() const { return current().kind == TokenKind::EndOfFile; }

const Token& Parser::advance() {
    if (!at_end()) ++current_;
    return previous();
}

bool Parser::check(TokenKind kind) const { return current().kind == kind; }

bool Parser::check_text(std::string_view text) const {
    const auto value = unicode::simple_case_fold(current().lexeme);
    return value && *value == text;
}

bool Parser::match_text(std::string_view text) {
    if (!check_text(text)) return false;
    advance();
    return true;
}

const Token& Parser::consume_text(std::string_view text, const std::string& message) {
    if (!check_text(text)) throw ParseError(current().location, message);
    return advance();
}

const Token& Parser::consume_identifier(const std::string& message) {
    if (!check(TokenKind::Identifier)) throw ParseError(current().location, message);
    return advance();
}

void Parser::consume_line_end() {
    if (!check(TokenKind::Newline)) throw ParseError(current().location, "expected end of line");
    advance();
}

void Parser::skip_newlines() {
    while (check(TokenKind::Newline)) advance();
}

ast::Module Parser::parse_module() {
    ast::Module module;
    skip_newlines();
    while (!at_end()) {
        if (check_text("type")) module.types.push_back(parse_type_declaration());
        else module.procedures.push_back(parse_procedure());
        skip_newlines();
    }
    return module;
}

ast::TypeDeclaration Parser::parse_type_declaration() {
    ast::TypeDeclaration declaration;
    declaration.location = advance().location;
    declaration.name = consume_identifier("expected type name").lexeme;
    consume_line_end();
    while (!at_end() && !check_text("end")) {
        if (check(TokenKind::Newline)) {
            advance();
            continue;
        }
        const auto& name = consume_identifier("expected type field name");
        ast::TypeField field{name.lexeme, {}, name.location};
        if (match_text("(")) {
            consume_text(")", "dynamic type field requires empty parentheses");
            field.dynamic_array = true;
        }
        consume_text("as", "type field requires an explicit As type");
        field.type_name = parse_type_name();
        consume_line_end();
        declaration.fields.push_back(std::move(field));
    }
    consume_text("end", "expected End Type");
    consume_text("type", "expected Type after End");
    consume_line_end();
    return declaration;
}

ast::Procedure Parser::parse_procedure() {
    while (check_text("public") || check_text("private") || check_text("friend") ||
           check_text("global") || check_text("static") || check_text("inline") ||
           check_text("forceinline")) {
        advance();
    }

    ast::Procedure procedure;
    procedure.intrinsic = match_text("intrinsic");
    if (match_text("sub")) {
        procedure.kind = ast::ProcedureKind::Sub;
    } else if (match_text("function")) {
        procedure.kind = ast::ProcedureKind::Function;
    } else {
        throw ParseError(current().location, "expected Sub or Function declaration");
    }
    procedure.location = previous().location;
    procedure.name = consume_identifier("expected procedure name").lexeme;

    if (match_text("(")) {
        if (!check_text(")")) {
            do {
                procedure.parameters.push_back(parse_parameter());
            } while (match_text(","));
        }
        consume_text(")", "expected ')' after parameters");
    }
    if (match_text("as")) procedure.return_type = parse_type_name();
    consume_line_end();

    if (procedure.intrinsic) {
        consume_text("end", "expected intrinsic procedure terminator");
        consume_text(procedure.kind == ast::ProcedureKind::Sub ? "sub" : "function",
                     "intrinsic procedure terminator does not match its declaration");
        consume_line_end();
        return procedure;
    }

    while (!at_end() && !(check_text("end") && current_ + 1 < tokens_.size() &&
                           (folded(tokens_[current_ + 1].lexeme) == "sub" ||
                            folded(tokens_[current_ + 1].lexeme) == "function"))) {
        if (check(TokenKind::Newline)) {
            advance();
            continue;
        }
        procedure.statements.push_back(parse_statement());
        consume_line_end();
    }
    consume_text("end", "expected procedure terminator");
    consume_text(procedure.kind == ast::ProcedureKind::Sub ? "sub" : "function",
                 "procedure terminator does not match its declaration");
    consume_line_end();
    return procedure;
}

ast::Parameter Parser::parse_parameter() {
    if (check_text("optional")) advance();
    auto passing_mode = ast::Parameter::PassingMode::DefaultByRef;
    if (match_text("byval")) passing_mode = ast::Parameter::PassingMode::ByVal;
    else if (match_text("byref")) passing_mode = ast::Parameter::PassingMode::ByRef;
    else if (match_text("paramarray")) passing_mode = ast::Parameter::PassingMode::ParamArray;
    const auto& name = consume_identifier("expected parameter name");
    ast::Parameter parameter{name.lexeme, {}, name.location, passing_mode};
    if (match_text("(")) {
        consume_text(")", "dynamic array parameter requires empty parentheses");
        parameter.dynamic_array = true;
    }
    if (match_text("as")) parameter.type_name = parse_type_name();
    return parameter;
}

std::string Parser::parse_type_name() {
    if (current().kind != TokenKind::Keyword && current().kind != TokenKind::Identifier) {
        throw ParseError(current().location, "expected type name");
    }
    return advance().lexeme;
}

std::unique_ptr<ast::Statement> Parser::parse_statement() {
    if (check_text("dim") || check_text("static")) return parse_variable_declaration();
    if (check_text("print")) return parse_print_statement();
    if (check_text("if")) return parse_if_statement();
    if (check_text("while")) return parse_while_statement();
    if (check_text("for")) return parse_for_statement();
    if (check_text("call")) return parse_call_statement();
    if (check_text("redim")) return parse_redim_statement();
    if (check_text("exit")) {
        const auto location = advance().location;
        if (check(TokenKind::Newline)) throw ParseError(current().location, "expected construct after Exit");
        return std::make_unique<ast::ExitStatement>(folded(advance().lexeme), location);
    }
    return parse_assignment_statement();
}

std::unique_ptr<ast::Statement> Parser::parse_call_statement() {
    const auto location = advance().location;
    const auto name = consume_identifier("expected procedure name after Call");
    return std::make_unique<ast::CallStatement>(finish_call(name), location);
}

std::vector<std::unique_ptr<ast::Statement>> Parser::parse_statement_block(
    std::string_view first_terminator, std::string_view second_terminator) {
    std::vector<std::unique_ptr<ast::Statement>> statements;
    while (!at_end() && !check_text(first_terminator) &&
           (second_terminator.empty() || !check_text(second_terminator))) {
        if (check(TokenKind::Newline)) {
            advance();
            continue;
        }
        statements.push_back(parse_statement());
        consume_line_end();
    }
    if (at_end()) throw ParseError(current().location, "unterminated statement block");
    return statements;
}

std::unique_ptr<ast::Statement> Parser::parse_if_statement() {
    const auto location = advance().location;
    auto condition = parse_expression();
    consume_text("then", "expected Then after If condition");
    if (!check(TokenKind::Newline)) {
        throw ParseError(current().location, "single-line If is not implemented in the bootstrap parser yet");
    }
    consume_line_end();
    auto statement = std::make_unique<ast::IfStatement>(std::move(condition), location);
    statement->then_statements = parse_statement_block("else", "end");
    if (match_text("else")) {
        consume_line_end();
        statement->else_statements = parse_statement_block("end");
    }
    consume_text("end", "expected End If");
    consume_text("if", "expected If after End");
    return statement;
}

std::unique_ptr<ast::Statement> Parser::parse_while_statement() {
    const auto location = advance().location;
    auto condition = parse_expression();
    consume_line_end();
    auto statement = std::make_unique<ast::WhileStatement>(std::move(condition), location);
    statement->statements = parse_statement_block("wend");
    consume_text("wend", "expected Wend");
    return statement;
}

std::unique_ptr<ast::Statement> Parser::parse_for_statement() {
    const auto location = advance().location;
    const auto variable = consume_identifier("expected control variable after For").lexeme;
    consume_text("=", "expected '=' after For control variable");
    auto start = parse_expression();
    consume_text("to", "expected To in For statement");
    auto finish = parse_expression();
    std::unique_ptr<ast::Expression> step;
    if (match_text("step")) step = parse_expression();
    consume_line_end();
    auto statement = std::make_unique<ast::ForStatement>(
        variable, std::move(start), std::move(finish), std::move(step), location);
    statement->statements = parse_statement_block("next");
    consume_text("next", "expected Next");
    if (check(TokenKind::Identifier)) {
        const auto closing = advance();
        if (folded(closing.lexeme) != folded(variable)) {
            throw ParseError(closing.location, "Next variable does not match For variable");
        }
    }
    return statement;
}

std::unique_ptr<ast::Statement> Parser::parse_variable_declaration() {
    const auto location = advance().location;
    const auto name = consume_identifier("expected variable name").lexeme;
    bool dynamic_array = false;
    if (match_text("(")) {
        consume_text(")", "dynamic array declaration requires empty parentheses");
        dynamic_array = true;
    }
    std::string type_name;
    if (match_text("as")) type_name = parse_type_name();
    std::unique_ptr<ast::Expression> initializer;
    if (match_text("=")) initializer = parse_expression();
    return std::make_unique<ast::VariableDeclaration>(name, type_name, std::move(initializer), location,
                                                       dynamic_array);
}

std::unique_ptr<ast::Statement> Parser::parse_print_statement() {
    const auto location = advance().location;
    auto statement = std::make_unique<ast::PrintStatement>(location);
    if (!check(TokenKind::Newline)) {
        do {
            statement->values.push_back(parse_expression());
        } while (match_text(",") || match_text(";"));
    }
    return statement;
}

std::unique_ptr<ast::Statement> Parser::parse_assignment_statement() {
    match_text("let");
    const auto& name = consume_identifier("expected assignment target");
    std::unique_ptr<ast::Expression> index;
    if (match_text("(")) {
        index = parse_expression();
        consume_text(")", "expected ')' after array index");
    }
    std::string member;
    if (match_text(".")) member = consume_identifier("expected member name after '.'").lexeme;
    consume_text("=", "expected '=' in assignment");
    auto statement = std::make_unique<ast::AssignmentStatement>(name.lexeme, parse_expression(), name.location);
    statement->target_member = std::move(member);
    statement->target_index = std::move(index);
    return statement;
}

std::unique_ptr<ast::Statement> Parser::parse_redim_statement() {
    const auto location = advance().location;
    const bool preserve = match_text("preserve");
    const auto name = consume_identifier("expected array name after ReDim").lexeme;
    consume_text("(", "expected '(' after array name");
    auto first = parse_expression();
    std::unique_ptr<ast::Expression> lower;
    std::unique_ptr<ast::Expression> upper;
    if (match_text("to")) {
        lower = std::move(first);
        upper = parse_expression();
    } else {
        upper = std::move(first);
    }
    consume_text(")", "expected ')' after array bounds");
    return std::make_unique<ast::ReDimStatement>(name, std::move(lower), std::move(upper), preserve,
                                                 location);
}

std::unique_ptr<ast::Expression> Parser::parse_expression(int minimum_precedence) {
    auto left = parse_unary();
    while (binary_precedence() >= minimum_precedence) {
        const auto precedence = binary_precedence();
        const bool is_right_associative = right_associative();
        const auto location = current().location;
        const auto op = folded(advance().lexeme);
        const auto next_precedence = is_right_associative ? precedence : precedence + 1;
        auto right = parse_expression(next_precedence);
        left = std::make_unique<ast::BinaryExpression>(
            std::move(left), op, std::move(right), location);
    }
    return left;
}

std::unique_ptr<ast::Expression> Parser::parse_unary() {
    if (check_text("+") || check_text("-") || check_text("not")) {
        const auto location = current().location;
        const auto op = folded(advance().lexeme);
        return std::make_unique<ast::UnaryExpression>(op, parse_expression(12), location);
    }
    return parse_primary();
}

std::unique_ptr<ast::Expression> Parser::parse_primary() {
    if (is_literal(current().kind)) return std::make_unique<ast::LiteralExpression>(advance());
    if (check(TokenKind::Identifier)) {
        const auto token = advance();
        std::unique_ptr<ast::Expression> expression;
        if (check_text("(")) expression = finish_call(token);
        else expression = std::make_unique<ast::NameExpression>(token.lexeme, token.location);
        while (match_text(".")) {
            const auto member = consume_identifier("expected member name after '.'");
            expression = std::make_unique<ast::MemberExpression>(std::move(expression), member.lexeme,
                                                                  token.location);
        }
        return expression;
    }
    if (check_text("true") || check_text("false") || check_text("nothing") ||
        check_text("null") || check_text("empty")) {
        const auto token = advance();
        return std::make_unique<ast::NameExpression>(token.lexeme, token.location);
    }
    if (match_text("(")) {
        auto expression = parse_expression();
        consume_text(")", "expected ')' after expression");
        return expression;
    }
    throw ParseError(current().location, "expected expression");
}

std::unique_ptr<ast::CallExpression> Parser::finish_call(const Token& name) {
    auto call = std::make_unique<ast::CallExpression>(name.lexeme, name.location);
    consume_text("(", "expected '(' after procedure name");
    if (!check_text(")")) {
        do {
            call->arguments.push_back(parse_expression());
        } while (match_text(","));
    }
    consume_text(")", "expected ')' after arguments");
    return call;
}

int Parser::binary_precedence() const {
    if (check_text("imp")) return 1;
    if (check_text("eqv")) return 2;
    if (check_text("xor")) return 3;
    if (check_text("or")) return 4;
    if (check_text("and")) return 5;
    if (check_text("=") || check_text("<>") || check_text("<=") || check_text(">=") ||
        check_text("<") || check_text(">") || check_text("like") || check_text("is")) return 6;
    if (check_text("&")) return 7;
    if (check_text("+") || check_text("-")) return 8;
    if (check_text("*") || check_text("/")) return 9;
    if (check_text("\\")) return 10;
    if (check_text("mod")) return 11;
    if (check_text("^")) return 13;
    return 0;
}

bool Parser::right_associative() const { return check_text("^"); }

} // namespace ube
