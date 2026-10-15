#include "ube/codegen.hpp"
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

std::string compile_to_ir(std::string_view source) {
    const auto module = ube::Parser(ube::Lexer(source).scan()).parse_module();
    const auto semantics = ube::SemanticAnalyzer().analyze(module);
    return ube::generate_llvm_ir(module, semantics);
}

void require_fragment(const std::string& text, std::string_view fragment) {
    if (text.find(fragment) == std::string::npos) fail("missing IR fragment: " + std::string(fragment));
}

void expect_codegen_error(std::string_view source, std::string_view message) {
    try {
        static_cast<void>(compile_to_ir(source));
    } catch (const ube::CodegenError& error) {
        if (error.what() != message) fail("unexpected codegen error: " + std::string(error.what()));
        return;
    }
    fail("expected codegen error");
}

} // namespace

int main() {
    const auto ir = compile_to_ir(
        "Function Main() As Long\n"
        "Dim answer As Long = 40\n"
        "answer = answer + 2\n"
        "Print \"UBE\", answer\n"
        "Main = 7\n"
        "End Function\n");
    require_fragment(ir, "define i32 @ube.main()");
    require_fragment(ir, "%local.answer = alloca i32");
    require_fragment(ir, "call i32 @ube_checked_add_i32");
    require_fragment(ir, "call void @ube_print_string(ptr");
    require_fragment(ir, "call void @ube_print_i32(i32");
    require_fragment(ir, "br label %ube.exit\nube.exit:");
    require_fragment(ir, "%exit.code = call i32 @ube.main()");
    require_fragment(ir, "ret i32 %exit.code");

    const auto sub_ir = compile_to_ir("Sub Main()\nPrint \"ok\"\nEnd Sub\n");
    require_fragment(sub_ir, "define void @ube.main()");
    require_fragment(sub_ir, "call void @ube.main()");
    require_fragment(sub_ir, "ret i32 0");

    const auto control_ir = compile_to_ir(
        "Sub Main()\nDim x As Long = 0\nWhile x < 2\n"
        "If x = 0 Then\nPrint x\nElse\nPrint \"one\"\nEnd If\n"
        "x = x + 1\nWend\nEnd Sub\n");
    require_fragment(control_ir, "icmp slt i32");
    require_fragment(control_ir, "ube.while.condition.");
    require_fragment(control_ir, "ube.if.then.");

    const auto for_ir = compile_to_ir(
        "Sub Main()\nDim i As Long\nFor i = 3 To 1 Step -1\n"
        "If i = 2 Then\nExit For\nEnd If\nPrint i\nNext i\nEnd Sub\n");
    require_fragment(for_ir, "ube.for.condition.");
    require_fragment(for_ir, "select i1");
    require_fragment(for_ir, "ube.for.increment.");

    const auto call_ir = compile_to_ir(
        "Function Add(ByVal a As Long, ByVal b As Long) As Long\nAdd = a + b\nEnd Function\n"
        "Sub Show(ByVal value As Long)\nPrint value\nEnd Sub\n"
        "Sub Main()\nDim result As Long = Add(20, 22)\nCall Show(result)\nEnd Sub\n");
    require_fragment(call_ir, "define i32 @ube.add(i32 %arg.a, i32 %arg.b)");
    require_fragment(call_ir, "call i32 @ube.add(i32 20, i32 22)");
    require_fragment(call_ir, "call void @ube.show(i32");

    const auto byref_ir = compile_to_ir(
        "Sub Increment(ByRef value As Long)\nvalue = value + 1\nEnd Sub\n"
        "Sub IncrementBoth(ByRef leftValue As Long, ByRef rightValue As Long)\n"
        "leftValue = leftValue + 1\nrightValue = rightValue + 1\nEnd Sub\n"
        "Sub Rename(value As String)\nvalue = \"updated\"\nEnd Sub\n"
        "Sub Main()\nDim number As Long = 41\nDim message As String = \"old\"\n"
        "Call Increment(number)\nCall IncrementBoth(number, number)\n"
        "Call Rename(message)\nPrint number\nPrint message\nEnd Sub\n");
    require_fragment(byref_ir, "define void @ube.increment(ptr %arg.value)");
    require_fragment(byref_ir, "call void @ube.increment(ptr %local.number)");
    require_fragment(byref_ir,
                     "call void @ube.incrementboth(ptr %local.number, ptr %local.number)");
    require_fragment(byref_ir, "define void @ube.rename(ptr %arg.value)");
    require_fragment(byref_ir, "call void @ube.rename(ptr %local.message)");

    const auto array_ir = compile_to_ir(
        "Sub Main()\nDim values() As Long\nReDim values(2)\n"
        "values(0) = 40\nvalues(1) = 2\nPrint values(0) + values(1)\nEnd Sub\n");
    require_fragment(array_ir, "call ptr @ube_array_redim");
    require_fragment(array_ir, "call ptr @ube_array_element");

    const auto type_ir = compile_to_ir(
        "Type Token\nKind As Long\nLexeme As String\nEnd Type\n"
        "Sub Initialize(ByRef value As Token)\nvalue.Kind = 7\nEnd Sub\n"
        "Sub Grow(ByRef values() As Token)\nReDim Preserve values(2)\n"
        "values(2).Kind = 10\nEnd Sub\n"
        "Sub Main()\nDim current As Token\nCall Initialize(current)\n"
        "current.Lexeme = \"identifier\"\nPrint current.Kind\n"
        "Dim tokens() As Token\nReDim tokens(1)\ntokens(0).Kind = 9\n"
        "Call Grow(tokens)\nPrint tokens(0).Kind\nEnd Sub\n");
    require_fragment(type_ir, "%ube.type.token = type { i32, ptr }");
    require_fragment(type_ir, "%local.current = alloca %ube.type.token");
    require_fragment(type_ir, "getelementptr inbounds %ube.type.token");
    require_fragment(type_ir, "define void @ube.initialize(ptr %arg.value)");
    require_fragment(type_ir, "call void @ube.initialize(ptr %local.current)");
    require_fragment(type_ir, "define void @ube.grow(ptr %arg.values)");
    require_fragment(type_ir, "call void @ube.grow(ptr %local.tokens)");
    require_fragment(type_ir, "ptrtoint (ptr getelementptr (%ube.type.token, ptr null, i32 1) to i64)");

    const auto string_ir = compile_to_ir(
        "Sub Main()\nDim greeting As String = \"Hello\" & \" world\"\n"
        "If greeting = \"Hello world\" Then\nPrint greeting\nEnd If\nEnd Sub\n");
    require_fragment(string_ir, "call ptr @ube_string_concat");
    require_fragment(string_ir, "call i32 @ube_string_compare");

    const auto intrinsic_ir = compile_to_ir(
        "Intrinsic Function StringLength(ByVal Value As String) As Long\nEnd Function\n"
        "Intrinsic Function StringSlice(ByVal Value As String, ByVal Start As Long, ByVal Length As Long) As String\nEnd Function\n"
        "Intrinsic Function StringArrayJoin(ByRef Values() As String, ByVal Count As Long) As String\nEnd Function\n"
        "Intrinsic Function UnicodeIsLetter(ByVal CodePoint As Long) As Long\nEnd Function\n"
        "Intrinsic Function UnicodeSimpleFoldCodePoint(ByVal CodePoint As Long) As Long\nEnd Function\n"
        "Sub Join(ByRef Values() As String)\nPrint StringArrayJoin(Values, 1)\nEnd Sub\n"
        "Sub Main()\nPrint StringLength(\"abc\")\nPrint StringSlice(\"abc\", 1, 2)\n"
        "Print UnicodeIsLetter(65)\nPrint UnicodeSimpleFoldCodePoint(65)\nEnd Sub\n");
    require_fragment(intrinsic_ir, "call i32 @ube_string_length");
    require_fragment(intrinsic_ir, "call ptr @ube_string_slice");
    require_fragment(intrinsic_ir, "call ptr @ube_string_array_join");
    require_fragment(intrinsic_ir, "call i32 @ube_unicode_is_letter");
    require_fragment(intrinsic_ir, "call i32 @ube_unicode_simple_fold_code_point");
    require_fragment(intrinsic_ir, "call void @ube_runtime_set_args(i32 %argc, ptr %argv)");

    expect_codegen_error("Function Main() As Long\nMain = 2 ^ 3\nEnd Function\n",
                         "operator is not supported by the initial backend: ^");
    expect_codegen_error("Function Main() As Long\nExit Function\nMain = 1\nEnd Function\n",
                         "statement is unreachable after Exit");
    std::cout << "codegen tests passed\n";
}
