#include "ube/lexer.hpp"
#include "ube/parser.hpp"
#include "ube/semantic.hpp"

#include <cstdlib>
#include <iostream>
#include <string>

namespace {

void fail(const std::string& message) {
    std::cerr << "FAIL: " << message << '\n';
    std::exit(1);
}

ube::SemanticModel analyze(std::string_view source, ube::ast::Module& module) {
    module = ube::Parser(ube::Lexer(source).scan()).parse_module();
    return ube::SemanticAnalyzer().analyze(module);
}

void expect_semantic_error(std::string_view source, std::string_view message) {
    try {
        ube::ast::Module module;
        static_cast<void>(analyze(source, module));
    } catch (const ube::SemanticError& error) {
        if (error.what() != message) fail("unexpected semantic error: " + std::string(error.what()));
        return;
    }
    fail("expected semantic error");
}

} // namespace

int main() {
    ube::ast::Module module;
    auto model = analyze(
        "Function Main() As Long\n"
        "Dim total As Long = 40\n"
        "total = total + 2\n"
        "Print \"answer\", total\n"
        "Main = 0\n"
        "End Function\n", module);
    if (model.entry_point != &module.procedures.front()) fail("Main was not selected as entry point");
    if (model.expression_types.empty()) fail("expressions were not typed");

    static_cast<void>(analyze("Sub Main()\nPrint \"ok\"\nEnd Sub\n", module));
    static_cast<void>(analyze(
        "Sub Main()\nDim x As Long = 0\nWhile x < 2\n"
        "If x = 0 Then\nPrint x\nElse\nPrint \"done\"\nEnd If\n"
        "x = x + 1\nWend\nEnd Sub\n", module));
    static_cast<void>(analyze(
        "Sub Main()\nDim i As Long\nFor i = 1 To 3\n"
        "If i = 2 Then\nExit For\nEnd If\nNext i\nEnd Sub\n", module));
    static_cast<void>(analyze(
        "Function Add(ByVal a As Long, ByVal b As Long) As Long\nAdd = a + b\nEnd Function\n"
        "Sub Show(ByVal value As Long)\nPrint value\nEnd Sub\n"
        "Sub Main()\nDim result As Long = Add(20, 22)\nCall Show(result)\nEnd Sub\n", module));
    static_cast<void>(analyze(
        "Intrinsic Function StringLength(ByVal Value As String) As Long\nEnd Function\n"
        "Sub Main()\nPrint StringLength(\"abc\")\nEnd Sub\n", module));
    static_cast<void>(analyze(
        "Intrinsic Function StringArrayJoin(ByRef Values() As String, ByVal Count As Long) As String\n"
        "End Function\nSub Main()\nDim Parts() As String\nReDim Parts(0)\n"
        "Parts(0) = \"ok\"\nPrint StringArrayJoin(Parts, 1)\nEnd Sub\n", module));
    static_cast<void>(analyze(
        "Intrinsic Function UnicodeIsLetter(ByVal CodePoint As Long) As Long\nEnd Function\n"
        "Sub Main()\nPrint UnicodeIsLetter(65)\nEnd Sub\n", module));
    static_cast<void>(analyze(
        "Intrinsic Function UnicodeSimpleFoldCodePoint(ByVal CodePoint As Long) As Long\nEnd Function\n"
        "Sub Main()\nPrint UnicodeSimpleFoldCodePoint(65)\nEnd Sub\n", module));
    static_cast<void>(analyze(
        "Sub Main()\nDim values() As Long\nReDim values(1 To 3)\n"
        "values(1) = 7\nPrint values(1)\nReDim Preserve values(1 To 4)\nEnd Sub\n", module));
    static_cast<void>(analyze(
        "Type Token\nKind As Long\nLexeme As String\nEnd Type\n"
        "Sub Initialize(ByRef value As Token)\nvalue.Kind = 1\nEnd Sub\n"
        "Sub Main()\nDim current As Token\nCall Initialize(current)\n"
        "current.Lexeme = \"name\"\nPrint current.Kind\n"
        "Dim tokens() As Token\nReDim tokens(2)\ntokens(0).Kind = 3\n"
        "Print tokens(0).Kind\nEnd Sub\n", module));
    static_cast<void>(analyze(
        "Sub Increment(ByRef value As Long)\nvalue = value + 1\nEnd Sub\n"
        "Sub Rename(value As String)\nvalue = \"updated\"\nEnd Sub\n"
        "Sub Main()\nDim number As Long = 1\nDim message As String = \"old\"\n"
        "Call Increment(number)\nCall Rename(message)\nEnd Sub\n", module));
    expect_semantic_error("Sub Work()\nEnd Sub\n",
                          "executable requires Sub Main() or Function Main() As Long");
    expect_semantic_error("Function Main() As Integer\nMain = 0\nEnd Function\n",
                          "Function Main must return Long");
    expect_semantic_error("Sub Main(value As Long)\nEnd Sub\n", "Main must not have parameters");
    expect_semantic_error("Sub Main()\nmissing = 1\nEnd Sub\n",
                          "assignment target is not declared: missing");
    expect_semantic_error("Sub Main()\nDim x As Long\nDim X As Long\nEnd Sub\n",
                          "duplicate local name: X");
    expect_semantic_error("Sub Main()\nDim x As Long\nx = \"text\"\nEnd Sub\n",
                          "assigned value has an incompatible type");
    expect_semantic_error("Sub Main()\nExit Function\nEnd Sub\n",
                          "Exit does not match the enclosing procedure");
    expect_semantic_error("Sub Main()\nExit For\nEnd Sub\n",
                          "Exit does not match an enclosing construct");
    expect_semantic_error("Sub Main()\nIf 1 Then\nEnd If\nEnd Sub\n",
                          "If condition must be Boolean");
    expect_semantic_error("Sub Main()\nCall Missing()\nEnd Sub\n",
                          "procedure is not declared: Missing");
    expect_semantic_error(
        "Function Add(ByVal value As Long) As Long\nAdd = value\nEnd Function\n"
        "Sub Main()\nPrint Add()\nEnd Sub\n",
        "argument count does not match procedure: Add");
    expect_semantic_error(
        "Intrinsic Function Mystery() As Long\nEnd Function\nSub Main()\nEnd Sub\n",
        "intrinsic is not implemented by stage zero: Mystery");
    expect_semantic_error(
        "Intrinsic Function StringArrayJoin(ByVal Values() As String, ByVal Count As Long) As String\n"
        "End Function\nSub Main()\nEnd Sub\n",
        "intrinsic declaration has the wrong signature: StringArrayJoin");
    expect_semantic_error(
        "Sub Change(ByRef value As Long)\nEnd Sub\nSub Main()\nCall Change(1)\nEnd Sub\n",
        "ByRef argument must be an addressable variable");
    expect_semantic_error(
        "Sub Change(ByRef value As Long)\nEnd Sub\n"
        "Sub Main()\nDim value As Integer\nCall Change(value)\nEnd Sub\n",
        "ByRef argument type must exactly match the parameter");
    expect_semantic_error("Sub Main()\nDim value As Long\nReDim value(3)\nEnd Sub\n",
                          "ReDim target is not a declared dynamic array: value");
    expect_semantic_error(
        "Type Token\nKind As Long\nEnd Type\nSub Main()\nDim item As Token\nPrint item.Missing\nEnd Sub\n",
        "type Token has no member Missing");
    expect_semantic_error(
        "Type Token\nKind As Long\nkind As String\nEnd Type\nSub Main()\nEnd Sub\n",
        "duplicate field in type Token: kind");
    expect_semantic_error(
        "Type LeftType\nValue As Long\nEnd Type\nType RightType\nValue As Long\nEnd Type\n"
        "Sub Change(ByRef value As LeftType)\nEnd Sub\n"
        "Sub Main()\nDim value As RightType\nCall Change(value)\nEnd Sub\n",
        "user-defined type argument must exactly match the parameter");
    std::cout << "semantic tests passed\n";
}
