#include "ube/lexer.hpp"
#include "ube/parser.hpp"

#include <cstdlib>
#include <iostream>
#include <string>

namespace {

void fail(const std::string& message) {
    std::cerr << "FAIL: " << message << '\n';
    std::exit(1);
}

ube::ast::Module parse(std::string_view source) {
    return ube::Parser(ube::Lexer(source).scan()).parse_module();
}

void expect_parse_error(std::string_view source, std::size_t line, std::string_view message) {
    try {
        static_cast<void>(parse(source));
    } catch (const ube::ParseError& error) {
        if (error.location().line != line) fail("unexpected parse-error line");
        if (error.what() != message) fail("unexpected parse-error message: " + std::string(error.what()));
        return;
    }
    fail("expected parse error");
}

} // namespace

int main() {
    auto module = parse(
        "Public Function Main() As Long\n"
        "Dim result As Long = 3\n"
        "result = -2 ^ 2 + result * 4\n"
        "Print \"result\"; result\n"
        "Main = 0\n"
        "Exit Function\n"
        "End Function\n");
    if (module.procedures.size() != 1) fail("expected one procedure");
    const auto& main = module.procedures.front();
    if (main.kind != ube::ast::ProcedureKind::Function || main.name != "Main" ||
        main.return_type != "Long" || !main.parameters.empty()) {
        fail("unexpected Main declaration");
    }
    if (main.statements.size() != 5) fail("unexpected Main statement count");
    if (main.statements[0]->kind != ube::ast::StatementKind::VariableDeclaration ||
        main.statements[1]->kind != ube::ast::StatementKind::Assignment ||
        main.statements[2]->kind != ube::ast::StatementKind::Print ||
        main.statements[4]->kind != ube::ast::StatementKind::Exit) {
        fail("unexpected statement kinds");
    }

    const auto* assignment = dynamic_cast<const ube::ast::AssignmentStatement*>(main.statements[1].get());
    const auto* addition = assignment
        ? dynamic_cast<const ube::ast::BinaryExpression*>(assignment->value.get()) : nullptr;
    const auto* negation = addition
        ? dynamic_cast<const ube::ast::UnaryExpression*>(addition->left.get()) : nullptr;
    const auto* power = negation
        ? dynamic_cast<const ube::ast::BinaryExpression*>(negation->operand.get()) : nullptr;
    if (!addition || addition->op != "+" || !negation || negation->op != "-" ||
        !power || power->op != "^") {
        fail("expression precedence tree is incorrect");
    }

    auto sub = parse("Sub Work(ByVal value As Long)\nPrint value\nEnd Sub\n");
    if (sub.procedures.front().parameters.size() != 1 ||
        sub.procedures.front().parameters.front().type_name != "Long") {
        fail("parameter was not parsed");
    }

    auto control = parse(
        "Sub Main()\n"
        "Dim x As Long = 0\n"
        "While x < 3\n"
        "If x = 1 Then\n"
        "Print \"one\"\n"
        "Else\n"
        "Print x\n"
        "End If\n"
        "x = x + 1\n"
        "Wend\n"
        "End Sub\n");
    if (control.procedures.front().statements.size() != 2 ||
        control.procedures.front().statements[1]->kind != ube::ast::StatementKind::While) {
        fail("block control flow was not parsed");
    }
    auto for_loop = parse(
        "Sub Main()\nDim index As Long\nFor index = 3 To 1 Step -1\n"
        "Print index\nNext index\nEnd Sub\n");
    if (for_loop.procedures.front().statements[1]->kind != ube::ast::StatementKind::For) {
        fail("For loop was not parsed");
    }

    auto calls = parse(
        "Function Add(ByVal a As Long, ByVal b As Long) As Long\nAdd = a + b\nEnd Function\n"
        "Sub Show(ByVal value As Long)\nPrint value\nEnd Sub\n"
        "Sub Main()\nDim result As Long = Add(20, 22)\nCall Show(result)\nEnd Sub\n");
    if (calls.procedures.size() != 3 ||
        calls.procedures[2].statements[1]->kind != ube::ast::StatementKind::Call) {
        fail("procedure calls were not parsed");
    }

    auto intrinsic = parse(
        "Intrinsic Function StringLength(ByVal Value As String) As Long\nEnd Function\n"
        "Sub Main()\nPrint StringLength(\"abc\")\nEnd Sub\n");
    if (!intrinsic.procedures.front().intrinsic ||
        !intrinsic.procedures.front().statements.empty()) {
        fail("intrinsic declaration was not parsed");
    }

    auto record = parse(
        "Type Token\nKind As Long\nLexeme As String\nOffsets() As Long\nEnd Type\n"
        "Sub Main()\nEnd Sub\n");
    if (record.types.size() != 1 || record.types.front().name != "Token" ||
        record.types.front().fields.size() != 3 || !record.types.front().fields[2].dynamic_array) {
        fail("user-defined type was not parsed");
    }
    auto members = parse(
        "Type Token\nKind As Long\nEnd Type\nSub Main()\n"
        "Dim item As Token\nitem.Kind = 3\nPrint item.Kind\nEnd Sub\n");
    const auto& member_statements = members.procedures.front().statements;
    const auto* member_assignment = dynamic_cast<const ube::ast::AssignmentStatement*>(
        member_statements[1].get());
    const auto* member_print = dynamic_cast<const ube::ast::PrintStatement*>(
        member_statements[2].get());
    if (!member_assignment || member_assignment->target_member != "Kind" || !member_print ||
        member_print->values.front()->kind != ube::ast::ExpressionKind::Member) {
        fail("user-defined type member access was not parsed");
    }
    auto array_parameter = parse(
        "Type Token\nKind As Long\nEnd Type\n"
        "Sub Grow(ByRef values() As Token)\nEnd Sub\nSub Main()\nEnd Sub\n");
    if (!array_parameter.procedures.front().parameters.front().dynamic_array) {
        fail("dynamic array parameter was not parsed");
    }

    expect_parse_error("Function Main() As Long\nEnd Sub\n", 2,
                       "procedure terminator does not match its declaration");
    expect_parse_error("Sub Main()\nDim\nEnd Sub\n", 2, "expected variable name");
    expect_parse_error("Sub Main()\nDim i As Long\nFor i = 1 To 2\nNext j\nEnd Sub\n",
                       4, "Next variable does not match For variable");
    if (!parse("").procedures.empty()) fail("empty module should have no procedures");
    std::cout << "parser tests passed\n";
}
