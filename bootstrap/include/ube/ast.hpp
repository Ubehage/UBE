#pragma once

#include "ube/token.hpp"

#include <memory>
#include <string>
#include <vector>

namespace ube::ast {

enum class ExpressionKind { Literal, Name, Member, Unary, Binary, Call };

struct Expression {
    explicit Expression(ExpressionKind expression_kind, SourceLocation source_location)
        : kind(expression_kind), location(source_location) {}
    virtual ~Expression() = default;

    ExpressionKind kind;
    SourceLocation location;
};

struct LiteralExpression final : Expression {
    LiteralExpression(Token literal_token)
        : Expression(ExpressionKind::Literal, literal_token.location), token(std::move(literal_token)) {}
    Token token;
};

struct NameExpression final : Expression {
    NameExpression(std::string name_text, SourceLocation source_location)
        : Expression(ExpressionKind::Name, source_location), name(std::move(name_text)) {}
    std::string name;
};

struct MemberExpression final : Expression {
    MemberExpression(std::unique_ptr<Expression> base_expression, std::string member_name,
                     SourceLocation source_location)
        : Expression(ExpressionKind::Member, source_location), base(std::move(base_expression)),
          member(std::move(member_name)) {}
    std::unique_ptr<Expression> base;
    std::string member;
};

struct UnaryExpression final : Expression {
    UnaryExpression(std::string operator_text, std::unique_ptr<Expression> operand_expression,
                    SourceLocation source_location)
        : Expression(ExpressionKind::Unary, source_location), op(std::move(operator_text)),
          operand(std::move(operand_expression)) {}
    std::string op;
    std::unique_ptr<Expression> operand;
};

struct BinaryExpression final : Expression {
    BinaryExpression(std::unique_ptr<Expression> left_expression, std::string operator_text,
                     std::unique_ptr<Expression> right_expression, SourceLocation source_location)
        : Expression(ExpressionKind::Binary, source_location), left(std::move(left_expression)),
          op(std::move(operator_text)), right(std::move(right_expression)) {}
    std::unique_ptr<Expression> left;
    std::string op;
    std::unique_ptr<Expression> right;
};

struct CallExpression final : Expression {
    CallExpression(std::string callee_name, SourceLocation source_location)
        : Expression(ExpressionKind::Call, source_location), callee(std::move(callee_name)) {}
    std::string callee;
    std::vector<std::unique_ptr<Expression>> arguments;
};

enum class StatementKind { VariableDeclaration, Assignment, ReDim, Print, Exit, If, While, For, Call };

struct Statement {
    explicit Statement(StatementKind statement_kind, SourceLocation source_location)
        : kind(statement_kind), location(source_location) {}
    virtual ~Statement() = default;

    StatementKind kind;
    SourceLocation location;
};

struct VariableDeclaration final : Statement {
    VariableDeclaration(std::string variable_name, std::string declared_type,
                        std::unique_ptr<Expression> initial_value, SourceLocation source_location,
                        bool is_dynamic_array = false)
        : Statement(StatementKind::VariableDeclaration, source_location),
          name(std::move(variable_name)), type_name(std::move(declared_type)),
          initializer(std::move(initial_value)), dynamic_array(is_dynamic_array) {}
    std::string name;
    std::string type_name;
    std::unique_ptr<Expression> initializer;
    bool dynamic_array{};
};

struct AssignmentStatement final : Statement {
    AssignmentStatement(std::string target_name, std::unique_ptr<Expression> assigned_value,
                        SourceLocation source_location)
        : Statement(StatementKind::Assignment, source_location), target(std::move(target_name)),
          value(std::move(assigned_value)) {}
    std::string target;
    std::string target_member;
    std::unique_ptr<Expression> target_index;
    std::unique_ptr<Expression> value;
};

struct ReDimStatement final : Statement {
    ReDimStatement(std::string variable_name, std::unique_ptr<Expression> lower,
                   std::unique_ptr<Expression> upper, bool keep_values,
                   SourceLocation source_location)
        : Statement(StatementKind::ReDim, source_location), name(std::move(variable_name)),
          lower_bound(std::move(lower)), upper_bound(std::move(upper)), preserve(keep_values) {}
    std::string name;
    std::unique_ptr<Expression> lower_bound;
    std::unique_ptr<Expression> upper_bound;
    bool preserve{};
};

struct PrintStatement final : Statement {
    explicit PrintStatement(SourceLocation source_location)
        : Statement(StatementKind::Print, source_location) {}
    std::vector<std::unique_ptr<Expression>> values;
};

struct ExitStatement final : Statement {
    ExitStatement(std::string exited_construct, SourceLocation source_location)
        : Statement(StatementKind::Exit, source_location), construct(std::move(exited_construct)) {}
    std::string construct;
};

struct IfStatement final : Statement {
    IfStatement(std::unique_ptr<Expression> condition_expression, SourceLocation source_location)
        : Statement(StatementKind::If, source_location), condition(std::move(condition_expression)) {}
    std::unique_ptr<Expression> condition;
    std::vector<std::unique_ptr<Statement>> then_statements;
    std::vector<std::unique_ptr<Statement>> else_statements;
};

struct WhileStatement final : Statement {
    WhileStatement(std::unique_ptr<Expression> condition_expression, SourceLocation source_location)
        : Statement(StatementKind::While, source_location), condition(std::move(condition_expression)) {}
    std::unique_ptr<Expression> condition;
    std::vector<std::unique_ptr<Statement>> statements;
};

struct ForStatement final : Statement {
    ForStatement(std::string variable_name, std::unique_ptr<Expression> first,
                 std::unique_ptr<Expression> last, std::unique_ptr<Expression> increment,
                 SourceLocation source_location)
        : Statement(StatementKind::For, source_location), variable(std::move(variable_name)),
          start(std::move(first)), finish(std::move(last)), step(std::move(increment)) {}
    std::string variable;
    std::unique_ptr<Expression> start;
    std::unique_ptr<Expression> finish;
    std::unique_ptr<Expression> step;
    std::vector<std::unique_ptr<Statement>> statements;
};

struct CallStatement final : Statement {
    CallStatement(std::unique_ptr<CallExpression> call_expression, SourceLocation source_location)
        : Statement(StatementKind::Call, source_location), call(std::move(call_expression)) {}
    std::unique_ptr<CallExpression> call;
};

enum class ProcedureKind { Sub, Function };

struct Parameter {
    enum class PassingMode { DefaultByRef, ByVal, ByRef, ParamArray };
    std::string name;
    std::string type_name;
    SourceLocation location;
    PassingMode passing_mode{PassingMode::DefaultByRef};
    bool dynamic_array{};
};

struct Procedure {
    ProcedureKind kind{ProcedureKind::Sub};
    bool intrinsic{};
    std::string name;
    std::string return_type;
    SourceLocation location;
    std::vector<Parameter> parameters;
    std::vector<std::unique_ptr<Statement>> statements;
};

struct TypeField {
    std::string name;
    std::string type_name;
    SourceLocation location;
    bool dynamic_array{};
};

struct TypeDeclaration {
    std::string name;
    SourceLocation location;
    std::vector<TypeField> fields;
};

struct Module {
    std::vector<TypeDeclaration> types;
    std::vector<Procedure> procedures;
};

} // namespace ube::ast
