#include "ube/codegen.hpp"
#include "ube/unicode.hpp"

#include <cstdint>
#include <sstream>
#include <unordered_map>

namespace ube {
namespace {

std::string canonical(std::string_view text) {
    const auto result = unicode::simple_case_fold(text);
    return result ? *result : std::string(text);
}

std::string llvm_type(ValueType type) {
    switch (type) {
    case ValueType::Boolean: return "i1";
    case ValueType::Integer: return "i16";
    case ValueType::Long: return "i32";
    case ValueType::LongLong: return "i64";
    case ValueType::Single: return "float";
    case ValueType::Double: return "double";
    case ValueType::String: return "ptr";
    case ValueType::Date: return "double";
    case ValueType::LongArray:
    case ValueType::StringArray:
    case ValueType::UserDefinedArray: return "ptr";
    case ValueType::UserDefined: break;
    case ValueType::Variant: break;
    }
    return {};
}

std::string zero_value(ValueType type) {
    if (type == ValueType::String || type == ValueType::LongArray || type == ValueType::StringArray ||
        type == ValueType::UserDefinedArray) return "null";
    if (type == ValueType::Single) return "0.000000e+00";
    if (type == ValueType::Double || type == ValueType::Date) return "0.000000e+00";
    return "0";
}

bool integer_type(ValueType type) {
    return type == ValueType::Boolean || type == ValueType::Integer ||
           type == ValueType::Long || type == ValueType::LongLong;
}

ValueType type_from_name(std::string_view name) {
    const auto folded = canonical(name);
    if (folded == "boolean") return ValueType::Boolean;
    if (folded == "integer") return ValueType::Integer;
    if (folded == "long") return ValueType::Long;
    if (folded == "longlong") return ValueType::LongLong;
    if (folded == "single") return ValueType::Single;
    if (folded == "double") return ValueType::Double;
    if (folded == "string") return ValueType::String;
    if (folded == "date") return ValueType::Date;
    return ValueType::Variant;
}

std::string llvm_name(std::string_view name) {
    std::ostringstream result;
    for (const unsigned char byte : canonical(name)) {
        if ((byte >= 'a' && byte <= 'z') || (byte >= '0' && byte <= '9') || byte == '_') {
            result << static_cast<char>(byte);
        } else {
            result << '_' << std::hex << static_cast<unsigned>(byte) << '_';
        }
    }
    return result.str();
}

std::string string_contents(std::string_view lexeme) {
    std::string result;
    for (std::size_t index = 1; index + 1 < lexeme.size(); ++index) {
        if (lexeme[index] == '"' && index + 1 < lexeme.size() - 1 && lexeme[index + 1] == '"') {
            result.push_back('"');
            ++index;
        } else {
            result.push_back(lexeme[index]);
        }
    }
    return result;
}

std::string escaped_bytes(std::string_view bytes) {
    std::ostringstream result;
    result << std::uppercase << std::hex;
    for (const unsigned char byte : bytes) {
        if (byte >= 0x20 && byte <= 0x7E && byte != '"' && byte != '\\') {
            result << static_cast<char>(byte);
        } else {
            result << '\\';
            if (byte < 0x10) result << '0';
            result << static_cast<unsigned>(byte);
        }
    }
    result << "\\00";
    return result.str();
}

std::int64_t integer_value(std::string lexeme, SourceLocation location) {
    while (!lexeme.empty()) {
        const char suffix = lexeme.back();
        if (suffix == '%' || suffix == '&' || suffix == '^' || suffix == 'S' || suffix == 's' ||
            suffix == 'I' || suffix == 'i' || suffix == 'L' || suffix == 'l' || suffix == 'U' || suffix == 'u') {
            lexeme.pop_back();
        } else {
            break;
        }
    }
    try {
        std::size_t consumed = 0;
        std::int64_t value = 0;
        if (lexeme.size() > 2 && lexeme[0] == '&' && (lexeme[1] == 'H' || lexeme[1] == 'h')) {
            value = static_cast<std::int64_t>(std::stoull(lexeme.substr(2), &consumed, 16));
            consumed += 2;
        } else if (lexeme.size() > 2 && lexeme[0] == '&' && (lexeme[1] == 'O' || lexeme[1] == 'o')) {
            value = static_cast<std::int64_t>(std::stoull(lexeme.substr(2), &consumed, 8));
            consumed += 2;
        } else {
            value = std::stoll(lexeme, &consumed, 10);
        }
        if (consumed != lexeme.size()) throw CodegenError(location, "invalid integer literal during lowering");
        return value;
    } catch (const CodegenError&) {
        throw;
    } catch (const std::exception&) {
        throw CodegenError(location, "integer literal is outside the bootstrap compiler range");
    }
}

struct GeneratedValue {
    std::string operand;
    ValueType type;
};

struct Local {
    std::string pointer;
    ValueType type;
    std::string user_type;
};

bool passed_by_reference(const ast::Parameter& parameter) {
    return parameter.passing_mode == ast::Parameter::PassingMode::ByRef ||
           parameter.passing_mode == ast::Parameter::PassingMode::DefaultByRef;
}

class Generator {
public:
    Generator(const ast::Module& module, const SemanticModel& semantics)
        : module_(module), semantics_(semantics) {}

    std::string generate() {
        for (const auto& declaration : module_.types) {
            body_ << "%ube.type." << llvm_name(declaration.name) << " = type { ";
            for (std::size_t index = 0; index < declaration.fields.size(); ++index) {
                if (index != 0) body_ << ", ";
                body_ << llvm_type(type_from_name(declaration.fields[index].type_name));
            }
            body_ << " }\n";
        }
        if (!module_.types.empty()) body_ << "\n";
        body_ << "declare void @ube_print_i32(i32)\n"
              << "declare void @ube_print_i64(i64)\n"
              << "declare void @ube_print_f64(double)\n"
              << "declare void @ube_print_string(ptr)\n"
              << "declare void @ube_print_newline()\n"
              << "declare void @ube_invalid_for_step()\n"
              << "declare i32 @ube_checked_add_i32(i32, i32)\n"
              << "declare i32 @ube_checked_sub_i32(i32, i32)\n"
              << "declare i32 @ube_checked_mul_i32(i32, i32)\n"
              << "declare i32 @ube_checked_div_i32(i32, i32)\n"
              << "declare i32 @ube_checked_mod_i32(i32, i32)\n"
              << "declare i32 @ube_checked_neg_i32(i32)\n"
              << "declare ptr @ube_string_concat(ptr, ptr)\n"
              << "declare i32 @ube_string_compare(ptr, ptr)\n"
              << "declare i32 @ube_string_length(ptr)\n"
              << "declare i32 @ube_string_byte_at(ptr, i32)\n"
              << "declare ptr @ube_string_slice(ptr, i32, i32)\n"
              << "declare i32 @ube_string_index_of(ptr, ptr, i32)\n"
              << "declare ptr @ube_string_from_byte(i32)\n"
              << "declare ptr @ube_long_to_string(i32)\n"
              << "declare void @ube_runtime_set_args(i32, ptr)\n"
              << "declare i32 @ube_command_argument_count()\n"
              << "declare ptr @ube_command_argument(i32)\n"
              << "declare ptr @ube_read_all_text(ptr)\n"
              << "declare i32 @ube_write_all_text(ptr, ptr)\n"
              << "declare ptr @ube_string_array_join(ptr, i32)\n"
              << "declare i32 @ube_compiler_run_tool(ptr, ptr, i32)\n"
              << "declare i32 @ube_compiler_delete_file(ptr)\n"
              << "declare i32 @ube_compiler_monotonic_milliseconds()\n"
              << "declare i32 @ube_compiler_process_cpu_milliseconds()\n"
              << "declare i32 @ube_compiler_peak_working_set_kilobytes()\n"
              << "declare i32 @ube_compiler_validate_resource(ptr)\n"
              << "declare ptr @ube_compiler_resource_llvm_escape(ptr)\n"
              << "declare i32 @ube_compiler_validate_library_bundle(ptr, ptr, ptr, ptr)\n"
              << "declare i32 @ube_unicode_is_letter(i32)\n"
              << "declare i32 @ube_unicode_simple_fold_code_point(i32)\n\n";
        body_ << "declare ptr @ube_array_redim(ptr, i32, i32, i64, i1)\n"
              << "declare ptr @ube_array_element(ptr, i32)\n"
              << "declare void @ube_array_release(ptr)\n"
              << "declare i32 @ube_array_lbound(ptr)\n"
              << "declare i32 @ube_array_ubound(ptr)\n\n";
        for (const auto& procedure : module_.procedures) {
            procedures_.emplace(canonical(procedure.name), &procedure);
        }
        for (const auto& procedure : module_.procedures) generate_procedure(procedure);
        generate_entry_wrapper();
        return "; UBE stage-zero generated LLVM IR\n"
               "source_filename = \"ube-module\"\n"
               "target triple = \"x86_64-w64-windows-gnu\"\n\n" +
               globals_.str() + "\n" + body_.str();
    }

private:
    std::string next_register() { return "%v" + std::to_string(register_++); }

    const ast::TypeDeclaration* find_user_type(std::string_view name) const {
        for (const auto& declaration : module_.types) {
            if (canonical(declaration.name) == canonical(name)) return &declaration;
        }
        return nullptr;
    }

    GeneratedValue generate_expression(const ast::Expression& expression) {
        const auto type_it = semantics_.expression_types.find(&expression);
        if (type_it == semantics_.expression_types.end()) {
            throw CodegenError(expression.location, "expression has no semantic type");
        }
        const auto type = type_it->second;
        switch (expression.kind) {
        case ast::ExpressionKind::Literal: {
            const auto& literal = static_cast<const ast::LiteralExpression&>(expression);
            if (literal.token.kind == TokenKind::IntegerLiteral) {
                return {std::to_string(integer_value(literal.token.lexeme, literal.location)), type};
            }
            if (literal.token.kind == TokenKind::RealLiteral) {
                std::string value = literal.token.lexeme;
                while (!value.empty() && (value.back() == '!' || value.back() == '#' ||
                       value.back() == '@' || value.back() == 'F' || value.back() == 'f' ||
                       value.back() == 'R' || value.back() == 'r' || value.back() == 'D' || value.back() == 'd')) {
                    value.pop_back();
                }
                return {value, type};
            }
            if (literal.token.kind == TokenKind::StringLiteral) {
                const auto value = string_contents(literal.token.lexeme);
                const auto index = string_index_++;
                const auto name = "@.ube.str." + std::to_string(index);
                globals_ << name << " = private unnamed_addr constant [" << value.size() + 1
                         << " x i8] c\"" << escaped_bytes(value) << "\"\n";
                const auto reg = next_register();
                body_ << "  " << reg << " = getelementptr inbounds [" << value.size() + 1
                      << " x i8], ptr " << name << ", i64 0, i64 0\n";
                return {reg, ValueType::String};
            }
            throw CodegenError(literal.location, "literal is not supported by the initial backend");
        }
        case ast::ExpressionKind::Name: {
            const auto& name = static_cast<const ast::NameExpression&>(expression);
            const auto key = canonical(name.name);
            if (key == "true") return {"1", ValueType::Boolean};
            if (key == "false") return {"0", ValueType::Boolean};
            const auto found = locals_.find(key);
            if (found == locals_.end()) throw CodegenError(name.location, "lowering could not find local: " + name.name);
            const auto reg = next_register();
            body_ << "  " << reg << " = load " << llvm_type(found->second.type) << ", ptr "
                  << found->second.pointer << "\n";
            return {reg, found->second.type};
        }
        case ast::ExpressionKind::Member: {
            const auto& member = static_cast<const ast::MemberExpression&>(expression);
            const auto resolution = semantics_.member_accesses.find(&member);
            if (resolution == semantics_.member_accesses.end()) {
                throw CodegenError(expression.location, "member access was not resolved");
            }
            std::string base_pointer;
            if (member.base->kind == ast::ExpressionKind::Name) {
                const auto& name = static_cast<const ast::NameExpression&>(*member.base);
                const auto base_local = locals_.find(canonical(name.name));
                if (base_local == locals_.end()) throw CodegenError(member.location, "member base was not lowered");
                base_pointer = base_local->second.pointer;
            } else if (member.base->kind == ast::ExpressionKind::Call) {
                const auto& indexed = static_cast<const ast::CallExpression&>(*member.base);
                const auto base_local = locals_.find(canonical(indexed.callee));
                if (base_local == locals_.end() || base_local->second.type != ValueType::UserDefinedArray) {
                    throw CodegenError(member.location, "indexed member base is not a record array");
                }
                const auto index = generate_expression(*indexed.arguments.front());
                const auto handle = next_register();
                base_pointer = next_register();
                body_ << "  " << handle << " = load ptr, ptr " << base_local->second.pointer << "\n"
                      << "  " << base_pointer << " = call ptr @ube_array_element(ptr " << handle
                      << ", i32 " << index.operand << ")\n";
            } else {
                throw CodegenError(member.location, "member base is not addressable");
            }
            const auto address = next_register();
            const auto value = next_register();
            const auto record_type = "%ube.type." + llvm_name(resolution->second.owner->name);
            body_ << "  " << address << " = getelementptr inbounds " << record_type
                  << ", ptr " << base_pointer << ", i32 0, i32 "
                  << resolution->second.field_index << "\n"
                  << "  " << value << " = load " << llvm_type(resolution->second.type)
                  << ", ptr " << address << "\n";
            return {value, resolution->second.type};
        }
        case ast::ExpressionKind::Unary: {
            const auto& unary = static_cast<const ast::UnaryExpression&>(expression);
            auto operand = generate_expression(*unary.operand);
            if (unary.op == "+") return operand;
            if (!integer_type(operand.type)) {
                throw CodegenError(unary.location, "floating-point unary lowering is not implemented");
            }
            const auto reg = next_register();
            if (unary.op == "-") {
                if (operand.type == ValueType::Long) {
                    body_ << "  " << reg << " = call i32 @ube_checked_neg_i32(i32 "
                          << operand.operand << ")\n";
                } else {
                    body_ << "  " << reg << " = sub " << llvm_type(operand.type) << " 0, " << operand.operand << "\n";
                }
            } else if (unary.op == "not") {
                body_ << "  " << reg << " = xor " << llvm_type(operand.type) << ' ' << operand.operand << ", -1\n";
            } else {
                throw CodegenError(unary.location, "unsupported unary operator");
            }
            return {reg, operand.type};
        }
        case ast::ExpressionKind::Binary: {
            const auto& binary = static_cast<const ast::BinaryExpression&>(expression);
            auto left = generate_expression(*binary.left);
            auto right = generate_expression(*binary.right);
            if (left.type != right.type) throw CodegenError(binary.location, "numeric widening is not lowered yet");
            if (binary.op == "&") {
                if (left.type != ValueType::String) {
                    throw CodegenError(binary.location, "string concatenation requires String operands");
                }
                const auto reg = next_register();
                body_ << "  " << reg << " = call ptr @ube_string_concat(ptr " << left.operand
                      << ", ptr " << right.operand << ")\n";
                return {reg, ValueType::String};
            }
            if (left.type == ValueType::String &&
                (binary.op == "=" || binary.op == "<>" || binary.op == "<" ||
                 binary.op == "<=" || binary.op == ">" || binary.op == ">=")) {
                const auto comparison = next_register();
                const auto result = next_register();
                std::string predicate;
                if (binary.op == "=") predicate = "eq";
                else if (binary.op == "<>") predicate = "ne";
                else if (binary.op == "<") predicate = "slt";
                else if (binary.op == "<=") predicate = "sle";
                else if (binary.op == ">") predicate = "sgt";
                else predicate = "sge";
                body_ << "  " << comparison << " = call i32 @ube_string_compare(ptr "
                      << left.operand << ", ptr " << right.operand << ")\n"
                      << "  " << result << " = icmp " << predicate << " i32 "
                      << comparison << ", 0\n";
                return {result, ValueType::Boolean};
            }
            if (!integer_type(left.type)) {
                throw CodegenError(binary.location, "floating-point arithmetic lowering is not implemented");
            }
            if (left.type == ValueType::Long &&
                (binary.op == "+" || binary.op == "-" || binary.op == "*" ||
                 binary.op == "\\" || binary.op == "mod")) {
                std::string helper;
                if (binary.op == "+") helper = "add";
                else if (binary.op == "-") helper = "sub";
                else if (binary.op == "*") helper = "mul";
                else if (binary.op == "\\") helper = "div";
                else helper = "mod";
                const auto reg = next_register();
                body_ << "  " << reg << " = call i32 @ube_checked_" << helper
                      << "_i32(i32 " << left.operand << ", i32 " << right.operand << ")\n";
                return {reg, ValueType::Long};
            }
            std::string instruction;
            if (binary.op == "=" || binary.op == "<>" || binary.op == "<" ||
                binary.op == "<=" || binary.op == ">" || binary.op == ">=") {
                std::string predicate;
                if (binary.op == "=") predicate = "eq";
                else if (binary.op == "<>") predicate = "ne";
                else if (binary.op == "<") predicate = "slt";
                else if (binary.op == "<=") predicate = "sle";
                else if (binary.op == ">") predicate = "sgt";
                else predicate = "sge";
                const auto reg = next_register();
                body_ << "  " << reg << " = icmp " << predicate << ' ' << llvm_type(left.type)
                      << ' ' << left.operand << ", " << right.operand << "\n";
                return {reg, ValueType::Boolean};
            }
            if (binary.op == "+") instruction = "add";
            else if (binary.op == "-") instruction = "sub";
            else if (binary.op == "*") instruction = "mul";
            else if (binary.op == "\\") instruction = "sdiv";
            else if (binary.op == "mod") instruction = "srem";
            else if (binary.op == "and") instruction = "and";
            else if (binary.op == "or") instruction = "or";
            else if (binary.op == "xor") instruction = "xor";
            else throw CodegenError(binary.location, "operator is not supported by the initial backend: " + binary.op);
            const auto reg = next_register();
            body_ << "  " << reg << " = " << instruction << ' ' << llvm_type(type) << ' '
                  << left.operand << ", " << right.operand << "\n";
            return {reg, type};
        }
        case ast::ExpressionKind::Call: {
            const auto& call = static_cast<const ast::CallExpression&>(expression);
            const auto call_name = canonical(call.callee);
            if (call_name == "lbound" || call_name == "ubound") {
                const auto array_value = generate_expression(*call.arguments.front());
                const auto result = next_register();
                body_ << "  " << result << " = call i32 @ube_array_" << call_name
                      << "(ptr " << array_value.operand << ")\n";
                return {result, ValueType::Long};
            }
            const auto array = semantics_.array_accesses.find(&call);
            if (array != semantics_.array_accesses.end()) {
                const auto local = locals_.find(canonical(call.callee));
                if (local == locals_.end()) throw CodegenError(call.location, "lowering could not find array: " + call.callee);
                const auto index = generate_expression(*call.arguments.front());
                if (index.type != ValueType::Long) throw CodegenError(call.location, "array index conversion is not implemented");
                const auto handle = next_register();
                const auto address = next_register();
                const auto value = next_register();
                const auto element = array->second == ValueType::StringArray ? ValueType::String : ValueType::Long;
                body_ << "  " << handle << " = load ptr, ptr " << local->second.pointer << "\n"
                      << "  " << address << " = call ptr @ube_array_element(ptr " << handle
                      << ", i32 " << index.operand << ")\n"
                      << "  " << value << " = load " << llvm_type(element) << ", ptr " << address << "\n";
                return {value, element};
            }
            return generate_call(call, true);
        }
        }
        throw CodegenError(expression.location, "unknown expression kind");
    }

    void generate_procedure(const ast::Procedure& procedure) {
        if (procedure.intrinsic) return;
        locals_.clear();
        loop_exits_.clear();
        register_ = 0;
        terminated_ = false;
        const auto returns_value = procedure.kind == ast::ProcedureKind::Function;
        const auto return_type = returns_value ? type_from_name(procedure.return_type) : ValueType::Variant;
        if (returns_value && return_type != ValueType::Long) {
            throw CodegenError(procedure.location, "the initial backend supports only Long function results");
        }
        body_ << "define " << (returns_value ? llvm_type(return_type) : "void") << " @ube."
              << llvm_name(procedure.name) << '(';
        for (std::size_t index = 0; index < procedure.parameters.size(); ++index) {
            if (index != 0) body_ << ", ";
            auto type = type_from_name(procedure.parameters[index].type_name);
            if (type == ValueType::Variant && find_user_type(procedure.parameters[index].type_name) != nullptr) {
                type = ValueType::UserDefined;
            }
            if (procedure.parameters[index].dynamic_array) {
                if (type == ValueType::Long) type = ValueType::LongArray;
                else if (type == ValueType::String) type = ValueType::StringArray;
                else if (type == ValueType::UserDefined) type = ValueType::UserDefinedArray;
            }
            if (procedure.parameters[index].passing_mode == ast::Parameter::PassingMode::ParamArray) {
                throw CodegenError(procedure.parameters[index].location,
                                   "ParamArray lowering is not implemented");
            }
            if (type == ValueType::UserDefined && !passed_by_reference(procedure.parameters[index])) {
                throw CodegenError(procedure.parameters[index].location,
                                   "bootstrap user-defined type parameters must be ByRef");
            }
            if ((type == ValueType::LongArray || type == ValueType::StringArray ||
                 type == ValueType::UserDefinedArray) && !passed_by_reference(procedure.parameters[index])) {
                throw CodegenError(procedure.parameters[index].location,
                                   "bootstrap dynamic array parameters must be ByRef");
            }
            if (type == ValueType::Variant || (type != ValueType::UserDefined && llvm_type(type).empty())) {
                throw CodegenError(procedure.parameters[index].location,
                                   "Variant parameters are not lowered yet");
            }
            body_ << (passed_by_reference(procedure.parameters[index]) ? "ptr" : llvm_type(type))
                  << " %arg." << llvm_name(procedure.parameters[index].name);
        }
        body_ << ") {\nentry:\n";

        if (returns_value) {
            body_ << "  %result = alloca " << llvm_type(return_type) << "\n"
                  << "  store " << llvm_type(return_type) << ' ' << zero_value(return_type)
                  << ", ptr %result\n";
            locals_.emplace(canonical(procedure.name), Local{"%result", return_type, {}});
        }
        for (const auto& parameter : procedure.parameters) {
            auto type = type_from_name(parameter.type_name);
            std::string user_type;
            if (type == ValueType::Variant) {
                if (const auto* declaration = find_user_type(parameter.type_name)) {
                    type = ValueType::UserDefined;
                    user_type = declaration->name;
                }
            }
            if (parameter.dynamic_array) {
                if (type == ValueType::Long) type = ValueType::LongArray;
                else if (type == ValueType::String) type = ValueType::StringArray;
                else if (type == ValueType::UserDefined) type = ValueType::UserDefinedArray;
            }
            if (passed_by_reference(parameter)) {
                locals_.emplace(canonical(parameter.name),
                                Local{"%arg." + llvm_name(parameter.name), type, user_type});
            } else {
                const auto pointer = "%param." + llvm_name(parameter.name);
                body_ << "  " << pointer << " = alloca " << llvm_type(type) << "\n"
                      << "  store " << llvm_type(type) << " %arg." << llvm_name(parameter.name)
                      << ", ptr " << pointer << "\n";
                locals_.emplace(canonical(parameter.name), Local{pointer, type, {}});
            }
        }
        allocate_locals(procedure.statements);
        generate_statements(procedure.statements);
        if (!terminated_) body_ << "  br label %ube.exit\n";
        body_ << "ube.exit:\n";
        if (returns_value) {
            const auto reg = next_register();
            body_ << "  " << reg << " = load " << llvm_type(return_type) << ", ptr %result\n"
                  << "  ret " << llvm_type(return_type) << ' ' << reg << "\n";
        } else {
            body_ << "  ret void\n";
        }
        body_ << "}\n\n";
    }

    void allocate_locals(const std::vector<std::unique_ptr<ast::Statement>>& statements) {
        for (const auto& statement : statements) {
            if (statement->kind == ast::StatementKind::VariableDeclaration) {
                const auto& declaration = static_cast<const ast::VariableDeclaration&>(*statement);
                auto type = type_from_name(declaration.type_name);
                std::string user_type;
                if (type == ValueType::Variant) {
                    for (const auto& candidate : module_.types) {
                        if (canonical(candidate.name) == canonical(declaration.type_name)) {
                            type = ValueType::UserDefined;
                            user_type = candidate.name;
                            break;
                        }
                    }
                }
                if (declaration.dynamic_array) {
                    if (type == ValueType::Long) type = ValueType::LongArray;
                    else if (type == ValueType::String) type = ValueType::StringArray;
                    else if (type == ValueType::UserDefined) type = ValueType::UserDefinedArray;
                    else throw CodegenError(declaration.location,
                                            "dynamic array element type is not lowered");
                }
                const auto pointer = "%local." + llvm_name(declaration.name);
                if (type == ValueType::Variant || (type != ValueType::UserDefined && llvm_type(type).empty())) {
                    throw CodegenError(declaration.location, "Variant lowering is not implemented");
                }
                const auto storage_type = type == ValueType::UserDefined
                    ? "%ube.type." + llvm_name(user_type) : llvm_type(type);
                body_ << "  " << pointer << " = alloca " << storage_type << "\n";
                locals_.emplace(canonical(declaration.name), Local{pointer, type, user_type});
            } else if (statement->kind == ast::StatementKind::If) {
                const auto& conditional = static_cast<const ast::IfStatement&>(*statement);
                allocate_locals(conditional.then_statements);
                allocate_locals(conditional.else_statements);
            } else if (statement->kind == ast::StatementKind::While) {
                allocate_locals(static_cast<const ast::WhileStatement&>(*statement).statements);
            } else if (statement->kind == ast::StatementKind::For) {
                allocate_locals(static_cast<const ast::ForStatement&>(*statement).statements);
            }
        }
    }

    void generate_statements(const std::vector<std::unique_ptr<ast::Statement>>& statements) {
        for (const auto& statement : statements) {
            if (terminated_) throw CodegenError(statement->location, "statement is unreachable after Exit");
            generate_statement(*statement);
        }
    }

    void generate_statement(const ast::Statement& statement) {
        switch (statement.kind) {
        case ast::StatementKind::VariableDeclaration: {
            const auto& declaration = static_cast<const ast::VariableDeclaration&>(statement);
            const auto& local = locals_.at(canonical(declaration.name));
            if (local.type == ValueType::UserDefined) {
                if (declaration.initializer) {
                    throw CodegenError(declaration.location,
                                       "user-defined type initializers are not implemented");
                }
                body_ << "  store %ube.type." << llvm_name(local.user_type)
                      << " zeroinitializer, ptr " << local.pointer << "\n";
                break;
            }
            if (declaration.initializer) {
                const auto value = generate_expression(*declaration.initializer);
                if (value.type != local.type) {
                    throw CodegenError(declaration.location, "numeric conversion lowering is not implemented");
                }
                body_ << "  store " << llvm_type(local.type) << ' ' << value.operand
                      << ", ptr " << local.pointer << "\n";
            } else {
                body_ << "  store " << llvm_type(local.type) << ' ' << zero_value(local.type)
                      << ", ptr " << local.pointer << "\n";
            }
            break;
        }
        case ast::StatementKind::Assignment: {
            const auto& assignment = static_cast<const ast::AssignmentStatement&>(statement);
            const auto& local = locals_.at(canonical(assignment.target));
            const auto value = generate_expression(*assignment.value);
            auto target_type = local.type;
            std::string target_pointer = local.pointer;
            if (!assignment.target_member.empty()) {
                const auto resolution = semantics_.member_assignments.find(&assignment);
                if (resolution == semantics_.member_assignments.end()) {
                    throw CodegenError(assignment.location, "member assignment was not resolved");
                }
                target_type = resolution->second.type;
                std::string base_pointer = local.pointer;
                if (assignment.target_index) {
                    const auto index = generate_expression(*assignment.target_index);
                    if (index.type != ValueType::Long) throw CodegenError(assignment.location, "array index conversion is not implemented");
                    const auto handle = next_register();
                    base_pointer = next_register();
                    body_ << "  " << handle << " = load ptr, ptr " << local.pointer << "\n"
                          << "  " << base_pointer << " = call ptr @ube_array_element(ptr " << handle
                          << ", i32 " << index.operand << ")\n";
                }
                target_pointer = next_register();
                body_ << "  " << target_pointer << " = getelementptr inbounds %ube.type."
                      << llvm_name(resolution->second.owner->name) << ", ptr " << base_pointer
                      << ", i32 0, i32 " << resolution->second.field_index << "\n";
            } else if (assignment.target_index) {
                const auto index = generate_expression(*assignment.target_index);
                if (index.type != ValueType::Long) throw CodegenError(assignment.location, "array index conversion is not implemented");
                const auto handle = next_register();
                target_pointer = next_register();
                target_type = local.type == ValueType::StringArray ? ValueType::String : ValueType::Long;
                body_ << "  " << handle << " = load ptr, ptr " << local.pointer << "\n"
                      << "  " << target_pointer << " = call ptr @ube_array_element(ptr " << handle
                      << ", i32 " << index.operand << ")\n";
            }
            if (value.type != target_type) {
                throw CodegenError(assignment.location, "numeric conversion lowering is not implemented");
            }
            body_ << "  store " << llvm_type(target_type) << ' ' << value.operand
                  << ", ptr " << target_pointer << "\n";
            break;
        }
        case ast::StatementKind::ReDim: {
            const auto& redim = static_cast<const ast::ReDimStatement&>(statement);
            const auto& local = locals_.at(canonical(redim.name));
            const auto lower = redim.lower_bound ? generate_expression(*redim.lower_bound)
                                                  : GeneratedValue{"0", ValueType::Long};
            const auto upper = generate_expression(*redim.upper_bound);
            if (lower.type != ValueType::Long || upper.type != ValueType::Long) {
                throw CodegenError(redim.location, "array bound conversion is not implemented");
            }
            const auto old_handle = next_register();
            const auto new_handle = next_register();
            std::string element_size = local.type == ValueType::StringArray ? "8" : "4";
            if (local.type == ValueType::UserDefinedArray) {
                element_size = "ptrtoint (ptr getelementptr (%ube.type." + llvm_name(local.user_type) +
                               ", ptr null, i32 1) to i64)";
            }
            body_ << "  " << old_handle << " = load ptr, ptr " << local.pointer << "\n"
                  << "  " << new_handle << " = call ptr @ube_array_redim(ptr " << old_handle
                  << ", i32 " << lower.operand << ", i32 " << upper.operand << ", i64 "
                  << element_size << ", i1 " << (redim.preserve ? 1 : 0) << ")\n"
                  << "  store ptr " << new_handle << ", ptr " << local.pointer << "\n";
            break;
        }
        case ast::StatementKind::Print: {
            const auto& print = static_cast<const ast::PrintStatement&>(statement);
            for (const auto& expression : print.values) {
                const auto value = generate_expression(*expression);
                if (value.type == ValueType::String) {
                    body_ << "  call void @ube_print_string(ptr " << value.operand << ")\n";
                } else if (value.type == ValueType::LongLong) {
                    body_ << "  call void @ube_print_i64(i64 " << value.operand << ")\n";
                } else if (value.type == ValueType::Double) {
                    body_ << "  call void @ube_print_f64(double " << value.operand << ")\n";
                } else if (value.type == ValueType::Long) {
                    body_ << "  call void @ube_print_i32(i32 " << value.operand << ")\n";
                } else if (value.type == ValueType::Integer || value.type == ValueType::Boolean) {
                    const auto widened = next_register();
                    body_ << "  " << widened << " = "
                          << (value.type == ValueType::Boolean ? "zext" : "sext") << ' '
                          << llvm_type(value.type) << ' ' << value.operand << " to i32\n"
                          << "  call void @ube_print_i32(i32 " << widened << ")\n";
                } else {
                    throw CodegenError(expression->location, "value type cannot be printed by the initial backend");
                }
            }
            body_ << "  call void @ube_print_newline()\n";
            break;
        }
        case ast::StatementKind::Exit: {
            const auto& exit = static_cast<const ast::ExitStatement&>(statement);
            std::string target = "ube.exit";
            if (exit.construct == "for" || exit.construct == "while") {
                for (auto iterator = loop_exits_.rbegin(); iterator != loop_exits_.rend(); ++iterator) {
                    if (iterator->first == exit.construct) { target = iterator->second; break; }
                }
            }
            body_ << "  br label %" << target << "\n";
            terminated_ = true;
            break;
        }
        case ast::StatementKind::If: {
            const auto& conditional = static_cast<const ast::IfStatement&>(statement);
            const auto condition = generate_expression(*conditional.condition);
            const auto label = label_++;
            const auto then_label = "ube.if.then." + std::to_string(label);
            const auto else_label = "ube.if.else." + std::to_string(label);
            const auto end_label = "ube.if.end." + std::to_string(label);
            body_ << "  br i1 " << condition.operand << ", label %" << then_label
                  << ", label %" << else_label << "\n" << then_label << ":\n";
            terminated_ = false;
            generate_statements(conditional.then_statements);
            const bool then_terminated = terminated_;
            if (!then_terminated) body_ << "  br label %" << end_label << "\n";
            body_ << else_label << ":\n";
            terminated_ = false;
            generate_statements(conditional.else_statements);
            const bool else_terminated = terminated_;
            if (!else_terminated) body_ << "  br label %" << end_label << "\n";
            terminated_ = then_terminated && else_terminated;
            if (!terminated_) body_ << end_label << ":\n";
            break;
        }
        case ast::StatementKind::While: {
            const auto& loop = static_cast<const ast::WhileStatement&>(statement);
            const auto label = label_++;
            const auto condition_label = "ube.while.condition." + std::to_string(label);
            const auto body_label = "ube.while.body." + std::to_string(label);
            const auto end_label = "ube.while.end." + std::to_string(label);
            body_ << "  br label %" << condition_label << "\n" << condition_label << ":\n";
            const auto condition = generate_expression(*loop.condition);
            body_ << "  br i1 " << condition.operand << ", label %" << body_label
                  << ", label %" << end_label << "\n" << body_label << ":\n";
            terminated_ = false;
            loop_exits_.push_back({"while", end_label});
            generate_statements(loop.statements);
            loop_exits_.pop_back();
            if (!terminated_) body_ << "  br label %" << condition_label << "\n";
            body_ << end_label << ":\n";
            terminated_ = false;
            break;
        }
        case ast::StatementKind::For: {
            const auto& loop = static_cast<const ast::ForStatement&>(statement);
            const auto& control = locals_.at(canonical(loop.variable));
            const auto first = generate_expression(*loop.start);
            const auto finish = generate_expression(*loop.finish);
            const auto step = loop.step ? generate_expression(*loop.step)
                                        : GeneratedValue{"1", ValueType::Long};
            const auto label = label_++;
            const auto end_storage = "%for.end." + std::to_string(label);
            const auto step_storage = "%for.step." + std::to_string(label);
            const auto condition_label = "ube.for.condition." + std::to_string(label);
            const auto body_label = "ube.for.body." + std::to_string(label);
            const auto increment_label = "ube.for.increment." + std::to_string(label);
            const auto end_label = "ube.for.end." + std::to_string(label);
            const auto step_error_label = "ube.for.step.error." + std::to_string(label);
            const auto step_is_zero = next_register();
            body_ << "  " << end_storage << " = alloca i32\n"
                  << "  " << step_storage << " = alloca i32\n"
                  << "  store i32 " << first.operand << ", ptr " << control.pointer << "\n"
                  << "  store i32 " << finish.operand << ", ptr " << end_storage << "\n"
                  << "  store i32 " << step.operand << ", ptr " << step_storage << "\n"
                  << "  " << step_is_zero << " = icmp eq i32 " << step.operand << ", 0\n"
                  << "  br i1 " << step_is_zero << ", label %" << step_error_label
                  << ", label %" << condition_label << "\n"
                  << step_error_label << ":\n  call void @ube_invalid_for_step()\n  unreachable\n"
                  << condition_label << ":\n";
            const auto current = next_register();
            const auto final_value = next_register();
            const auto step_value = next_register();
            const auto ascending = next_register();
            const auto ascending_condition = next_register();
            const auto descending_condition = next_register();
            const auto condition = next_register();
            body_ << "  " << current << " = load i32, ptr " << control.pointer << "\n"
                  << "  " << final_value << " = load i32, ptr " << end_storage << "\n"
                  << "  " << step_value << " = load i32, ptr " << step_storage << "\n"
                  << "  " << ascending << " = icmp sge i32 " << step_value << ", 0\n"
                  << "  " << ascending_condition << " = icmp sle i32 " << current << ", " << final_value << "\n"
                  << "  " << descending_condition << " = icmp sge i32 " << current << ", " << final_value << "\n"
                  << "  " << condition << " = select i1 " << ascending << ", i1 "
                  << ascending_condition << ", i1 " << descending_condition << "\n"
                  << "  br i1 " << condition << ", label %" << body_label << ", label %" << end_label
                  << "\n" << body_label << ":\n";
            terminated_ = false;
            loop_exits_.push_back({"for", end_label});
            generate_statements(loop.statements);
            loop_exits_.pop_back();
            if (!terminated_) body_ << "  br label %" << increment_label << "\n";
            body_ << increment_label << ":\n";
            const auto increment_current = next_register();
            const auto increment_step = next_register();
            const auto next_value = next_register();
            body_ << "  " << increment_current << " = load i32, ptr " << control.pointer << "\n"
                  << "  " << increment_step << " = load i32, ptr " << step_storage << "\n"
                  << "  " << next_value << " = call i32 @ube_checked_add_i32(i32 "
                  << increment_current << ", i32 " << increment_step << ")\n"
                  << "  store i32 " << next_value << ", ptr " << control.pointer << "\n"
                  << "  br label %" << condition_label << "\n" << end_label << ":\n";
            terminated_ = false;
            break;
        }
        case ast::StatementKind::Call: {
            const auto& call = *static_cast<const ast::CallStatement&>(statement).call;
            static_cast<void>(generate_call(call, false));
            break;
        }
        }
    }

    GeneratedValue generate_call(const ast::CallExpression& call, bool require_result) {
        const auto found = procedures_.find(canonical(call.callee));
        if (found == procedures_.end()) throw CodegenError(call.location, "lowering could not find procedure: " + call.callee);
        const auto& procedure = *found->second;
        if (require_result && procedure.kind != ast::ProcedureKind::Function) {
            throw CodegenError(call.location, "Sub call has no expression result");
        }
        struct GeneratedArgument {
            std::string operand;
            ValueType type;
            bool by_reference;
        };
        std::vector<GeneratedArgument> arguments;
        arguments.reserve(call.arguments.size());
        for (std::size_t index = 0; index < call.arguments.size(); ++index) {
            const auto& parameter = procedure.parameters[index];
            auto expected = type_from_name(procedure.parameters[index].type_name);
            if (expected == ValueType::Variant && find_user_type(procedure.parameters[index].type_name) != nullptr) {
                expected = ValueType::UserDefined;
            }
            if (procedure.parameters[index].dynamic_array) {
                if (expected == ValueType::Long) expected = ValueType::LongArray;
                else if (expected == ValueType::String) expected = ValueType::StringArray;
                else if (expected == ValueType::UserDefined) expected = ValueType::UserDefinedArray;
            }
            if (passed_by_reference(parameter)) {
                if (call.arguments[index]->kind != ast::ExpressionKind::Name) {
                    throw CodegenError(call.arguments[index]->location,
                                       "ByRef argument is not addressable during lowering");
                }
                const auto& name = static_cast<const ast::NameExpression&>(*call.arguments[index]);
                const auto found_local = locals_.find(canonical(name.name));
                if (found_local == locals_.end()) {
                    throw CodegenError(name.location,
                                       "lowering could not find ByRef argument: " + name.name);
                }
                if (found_local->second.type != expected) {
                    throw CodegenError(name.location,
                                       "ByRef argument type changed after semantic analysis");
                }
                arguments.push_back({found_local->second.pointer, expected, true});
                continue;
            }
            auto argument = generate_expression(*call.arguments[index]);
            if (argument.type != expected) {
                throw CodegenError(call.arguments[index]->location,
                                   "argument conversion lowering is not implemented");
            }
            arguments.push_back({std::move(argument.operand), argument.type, false});
        }
        const auto returns_value = procedure.kind == ast::ProcedureKind::Function;
        const auto return_type = returns_value ? type_from_name(procedure.return_type) : ValueType::Variant;
        std::string result;
        if (returns_value && require_result) {
            result = next_register();
            body_ << "  " << result << " = ";
        } else {
            body_ << "  ";
        }
        body_ << "call " << (returns_value ? llvm_type(return_type) : "void") << ' '
              << (procedure.intrinsic ? intrinsic_symbol(procedure) : "@ube." + llvm_name(procedure.name))
              << '(';
        for (std::size_t index = 0; index < arguments.size(); ++index) {
            if (index != 0) body_ << ", ";
            body_ << (arguments[index].by_reference ? "ptr" : llvm_type(arguments[index].type))
                  << ' ' << arguments[index].operand;
        }
        body_ << ")\n";
        return {result, return_type};
    }

    void generate_entry_wrapper() {
        if (semantics_.entry_point == nullptr) throw CodegenError({}, "missing validated entry point");
        body_ << "define i32 @main(i32 %argc, ptr %argv) {\nentry:\n"
              << "  call void @ube_runtime_set_args(i32 %argc, ptr %argv)\n";
        if (semantics_.entry_point->kind == ast::ProcedureKind::Function) {
            body_ << "  %exit.code = call i32 @ube." << llvm_name(semantics_.entry_point->name)
                  << "()\n  ret i32 %exit.code\n";
        } else {
            body_ << "  call void @ube." << llvm_name(semantics_.entry_point->name)
                  << "()\n  ret i32 0\n";
        }
        body_ << "}\n";
    }

    std::string intrinsic_symbol(const ast::Procedure& procedure) const {
        const auto name = canonical(procedure.name);
        if (name == "stringlength") return "@ube_string_length";
        if (name == "stringbyteat") return "@ube_string_byte_at";
        if (name == "stringslice") return "@ube_string_slice";
        if (name == "stringindexof") return "@ube_string_index_of";
        if (name == "stringfrombyte") return "@ube_string_from_byte";
        if (name == "longtostring") return "@ube_long_to_string";
        if (name == "commandargumentcount") return "@ube_command_argument_count";
        if (name == "commandargument") return "@ube_command_argument";
        if (name == "readalltext") return "@ube_read_all_text";
        if (name == "writealltext") return "@ube_write_all_text";
        if (name == "stringarrayjoin") return "@ube_string_array_join";
        if (name == "compilerruntool") return "@ube_compiler_run_tool";
        if (name == "compilerdeletefile") return "@ube_compiler_delete_file";
        if (name == "compilermonotonicmilliseconds") return "@ube_compiler_monotonic_milliseconds";
        if (name == "compilerprocesscpumilliseconds") return "@ube_compiler_process_cpu_milliseconds";
        if (name == "compilerpeakworkingsetkilobytes") return "@ube_compiler_peak_working_set_kilobytes";
        if (name == "compilervalidateresource") return "@ube_compiler_validate_resource";
        if (name == "compilerresourcellvmescape") return "@ube_compiler_resource_llvm_escape";
        if (name == "compilervalidatelibrarybundle") return "@ube_compiler_validate_library_bundle";
        if (name == "unicodeisletter") return "@ube_unicode_is_letter";
        if (name == "unicodesimplefoldcodepoint") return "@ube_unicode_simple_fold_code_point";
        throw CodegenError(procedure.location, "intrinsic has no backend implementation: " + procedure.name);
    }

    const ast::Module& module_;
    const SemanticModel& semantics_;
    std::ostringstream globals_;
    std::ostringstream body_;
    std::unordered_map<std::string, Local> locals_;
    std::unordered_map<std::string, const ast::Procedure*> procedures_;
    std::size_t register_{};
    std::size_t string_index_{};
    std::size_t label_{};
    bool terminated_{};
    std::vector<std::pair<std::string, std::string>> loop_exits_;
};

} // namespace

CodegenError::CodegenError(SourceLocation location, const std::string& message)
    : std::runtime_error(message), location_(location) {}

std::string generate_llvm_ir(const ast::Module& module, const SemanticModel& semantics) {
    return Generator(module, semantics).generate();
}

} // namespace ube
