#include "ube/semantic.hpp"
#include "ube/unicode.hpp"

#include <initializer_list>
#include <unordered_map>
#include <unordered_set>

namespace ube {
namespace {

using ProcedureTable = std::unordered_map<std::string, const ast::Procedure*>;
using TypeTable = std::unordered_map<std::string, const ast::TypeDeclaration*>;
using RecordNames = std::unordered_map<std::string, std::string>;

std::string canonical(std::string_view text) {
    const auto folded = unicode::simple_case_fold(text);
    return folded ? *folded : std::string(text);
}

ValueType declared_type(std::string_view name, SourceLocation location,
                        const TypeTable* types = nullptr) {
    const auto type = canonical(name);
    if (type.empty() || type == "variant") return ValueType::Variant;
    if (type == "boolean") return ValueType::Boolean;
    if (type == "integer") return ValueType::Integer;
    if (type == "long") return ValueType::Long;
    if (type == "longlong") return ValueType::LongLong;
    if (type == "single") return ValueType::Single;
    if (type == "double") return ValueType::Double;
    if (type == "string") return ValueType::String;
    if (type == "date") return ValueType::Date;
    if (types != nullptr && types->count(type) != 0) return ValueType::UserDefined;
    throw SemanticError(location, "unsupported type in bootstrap profile: " + std::string(name));
}

void require_intrinsic_signature(const ast::Procedure& procedure, ValueType result,
                                 std::initializer_list<ValueType> parameters) {
    if (procedure.kind != ast::ProcedureKind::Function ||
        declared_type(procedure.return_type, procedure.location) != result ||
        procedure.parameters.size() != parameters.size()) {
        throw SemanticError(procedure.location,
                            "intrinsic declaration has the wrong signature: " + procedure.name);
    }
    std::size_t index = 0;
    for (const auto expected : parameters) {
        const auto& parameter = procedure.parameters[index++];
        if (parameter.passing_mode != ast::Parameter::PassingMode::ByVal ||
            declared_type(parameter.type_name, parameter.location) != expected) {
            throw SemanticError(parameter.location,
                                "intrinsic declaration has the wrong signature: " + procedure.name);
        }
    }
}

void validate_intrinsic(const ast::Procedure& procedure) {
    const auto name = canonical(procedure.name);
    if (name == "stringlength") {
        require_intrinsic_signature(procedure, ValueType::Long, {ValueType::String});
    } else if (name == "stringbyteat") {
        require_intrinsic_signature(procedure, ValueType::Long,
                                    {ValueType::String, ValueType::Long});
    } else if (name == "stringslice") {
        require_intrinsic_signature(procedure, ValueType::String,
                                    {ValueType::String, ValueType::Long, ValueType::Long});
    } else if (name == "stringindexof") {
        require_intrinsic_signature(procedure, ValueType::Long,
                                    {ValueType::String, ValueType::String, ValueType::Long});
    } else if (name == "stringfrombyte") {
        require_intrinsic_signature(procedure, ValueType::String, {ValueType::Long});
    } else if (name == "longtostring") {
        require_intrinsic_signature(procedure, ValueType::String, {ValueType::Long});
    } else if (name == "commandargumentcount") {
        require_intrinsic_signature(procedure, ValueType::Long, {});
    } else if (name == "commandargument") {
        require_intrinsic_signature(procedure, ValueType::String, {ValueType::Long});
    } else if (name == "readalltext") {
        require_intrinsic_signature(procedure, ValueType::String, {ValueType::String});
    } else if (name == "writealltext") {
        require_intrinsic_signature(procedure, ValueType::Long,
                                    {ValueType::String, ValueType::String});
    } else if (name == "stringarrayjoin") {
        if (procedure.kind != ast::ProcedureKind::Function ||
            declared_type(procedure.return_type, procedure.location) != ValueType::String ||
            procedure.parameters.size() != 2) {
            throw SemanticError(procedure.location,
                                "intrinsic declaration has the wrong signature: " + procedure.name);
        }
        const auto& values = procedure.parameters[0];
        const auto& count = procedure.parameters[1];
        if (!values.dynamic_array ||
            (values.passing_mode != ast::Parameter::PassingMode::ByRef &&
             values.passing_mode != ast::Parameter::PassingMode::DefaultByRef) ||
            declared_type(values.type_name, values.location) != ValueType::String ||
            count.dynamic_array || count.passing_mode != ast::Parameter::PassingMode::ByVal ||
            declared_type(count.type_name, count.location) != ValueType::Long) {
            throw SemanticError(procedure.location,
                                "intrinsic declaration has the wrong signature: " + procedure.name);
        }
    } else if (name == "unicodeisletter") {
        require_intrinsic_signature(procedure, ValueType::Long, {ValueType::Long});
    } else if (name == "unicodesimplefoldcodepoint") {
        require_intrinsic_signature(procedure, ValueType::Long, {ValueType::Long});
    } else {
        throw SemanticError(procedure.location,
                            "intrinsic is not implemented by stage zero: " + procedure.name);
    }
}

bool numeric(ValueType type) {
    return type == ValueType::Integer || type == ValueType::Long || type == ValueType::LongLong ||
           type == ValueType::Single || type == ValueType::Double;
}

bool array_type(ValueType type) {
    return type == ValueType::LongArray || type == ValueType::StringArray ||
           type == ValueType::UserDefinedArray;
}

ValueType array_element(ValueType type) {
    if (type == ValueType::UserDefinedArray) return ValueType::UserDefined;
    return type == ValueType::StringArray ? ValueType::String : ValueType::Long;
}

ValueType dynamic_array_type(ValueType element, SourceLocation location) {
    if (element == ValueType::Long) return ValueType::LongArray;
    if (element == ValueType::String) return ValueType::StringArray;
    if (element == ValueType::UserDefined) return ValueType::UserDefinedArray;
    throw SemanticError(location, "bootstrap dynamic arrays currently require Long or String elements");
}

bool assignable(ValueType target, ValueType source) {
    return target == ValueType::Variant || source == ValueType::Variant || target == source ||
           (numeric(target) && numeric(source));
}

bool passed_by_reference(const ast::Parameter& parameter) {
    return parameter.passing_mode == ast::Parameter::PassingMode::ByRef ||
           parameter.passing_mode == ast::Parameter::PassingMode::DefaultByRef;
}

void validate_argument(const ast::Expression& expression, ValueType argument,
                       const ast::Parameter& parameter, ValueType expected) {
    if (!passed_by_reference(parameter)) {
        if (!assignable(expected, argument)) {
            throw SemanticError(expression.location, "argument type is not assignable to parameter");
        }
        return;
    }
    if (expression.kind != ast::ExpressionKind::Name) {
        throw SemanticError(expression.location, "ByRef argument must be an addressable variable");
    }
    const auto& name = static_cast<const ast::NameExpression&>(expression);
    const auto key = canonical(name.name);
    if (key == "true" || key == "false") {
        throw SemanticError(expression.location, "ByRef argument must be an addressable variable");
    }
    if (expected != argument) {
        throw SemanticError(expression.location, "ByRef argument type must exactly match the parameter");
    }
}

void validate_user_type_argument(const ast::Expression& expression,
                                 const ast::Parameter& parameter,
                                 const RecordNames& record_names) {
    if (expression.kind != ast::ExpressionKind::Name) {
        throw SemanticError(expression.location,
                            "user-defined type argument must be a named variable");
    }
    const auto& name = static_cast<const ast::NameExpression&>(expression);
    const auto actual = record_names.find(canonical(name.name));
    if (actual == record_names.end() || actual->second != canonical(parameter.type_name)) {
        throw SemanticError(expression.location,
                            "user-defined type argument must exactly match the parameter");
    }
    if (!passed_by_reference(parameter)) {
        throw SemanticError(parameter.location,
                            "bootstrap user-defined type parameters must be ByRef");
    }
}

ValueType numeric_result(ValueType left, ValueType right) {
    if (left == ValueType::Double || right == ValueType::Double) return ValueType::Double;
    if (left == ValueType::Single || right == ValueType::Single) return ValueType::Single;
    if (left == ValueType::LongLong || right == ValueType::LongLong) return ValueType::LongLong;
    if (left == ValueType::Long || right == ValueType::Long) return ValueType::Long;
    return ValueType::Integer;
}

ValueType analyze_expression(const ast::Expression& expression,
                             const std::unordered_map<std::string, ValueType>& variables,
                             const ProcedureTable& procedures,
                             SemanticModel& model, const TypeTable& types,
                             const RecordNames& record_names) {
    ValueType result = ValueType::Variant;
    switch (expression.kind) {
    case ast::ExpressionKind::Literal: {
        const auto& literal = static_cast<const ast::LiteralExpression&>(expression);
        switch (literal.token.kind) {
        case TokenKind::IntegerLiteral: result = ValueType::Long; break;
        case TokenKind::RealLiteral: result = ValueType::Double; break;
        case TokenKind::StringLiteral: result = ValueType::String; break;
        case TokenKind::DateLiteral: result = ValueType::Date; break;
        default: result = ValueType::Variant; break;
        }
        break;
    }
    case ast::ExpressionKind::Name: {
        const auto& name = static_cast<const ast::NameExpression&>(expression);
        const auto key = canonical(name.name);
        if (key == "true" || key == "false") {
            result = ValueType::Boolean;
        } else {
            const auto found = variables.find(key);
            if (found == variables.end()) {
                throw SemanticError(name.location, "name is not declared: " + name.name);
            }
            result = found->second;
            if (result == ValueType::UserDefined || result == ValueType::UserDefinedArray) {
                const auto record = record_names.find(key);
                if (record != record_names.end()) model.user_types.emplace(&expression, types.at(record->second));
            }
        }
        break;
    }
    case ast::ExpressionKind::Member: {
        const auto& member = static_cast<const ast::MemberExpression&>(expression);
        const auto base_type = analyze_expression(*member.base, variables, procedures, model, types, record_names);
        const auto base_record = model.user_types.find(member.base.get());
        if (base_type != ValueType::UserDefined || base_record == model.user_types.end()) {
            throw SemanticError(member.location, "member base is not a user-defined type");
        }
        const auto owner = base_record->second;
        const ast::TypeField* resolved = nullptr;
        std::size_t field_index = 0;
        for (std::size_t index = 0; index < owner->fields.size(); ++index) {
            if (canonical(owner->fields[index].name) == canonical(member.member)) {
                resolved = &owner->fields[index];
                field_index = index;
                break;
            }
        }
        if (resolved == nullptr) throw SemanticError(member.location, "type " + owner->name + " has no member " + member.member);
        result = declared_type(resolved->type_name, resolved->location, &types);
        if (resolved->dynamic_array) result = dynamic_array_type(result, resolved->location);
        model.member_accesses.emplace(&member, ResolvedMember{owner, resolved, field_index, result});
        break;
    }
    case ast::ExpressionKind::Unary: {
        const auto& unary = static_cast<const ast::UnaryExpression&>(expression);
        const auto operand = analyze_expression(*unary.operand, variables, procedures, model, types, record_names);
        if (unary.op == "not") {
            if (operand != ValueType::Boolean && !numeric(operand)) {
                throw SemanticError(unary.location, "Not requires a Boolean or integer operand");
            }
            result = operand;
        } else {
            if (!numeric(operand)) throw SemanticError(unary.location, "numeric unary operator requires a number");
            result = operand;
        }
        break;
    }
    case ast::ExpressionKind::Binary: {
        const auto& binary = static_cast<const ast::BinaryExpression&>(expression);
        const auto left = analyze_expression(*binary.left, variables, procedures, model, types, record_names);
        const auto right = analyze_expression(*binary.right, variables, procedures, model, types, record_names);
        if (binary.op == "&") {
            if (left != ValueType::String || right != ValueType::String) {
                throw SemanticError(binary.location,
                                    "bootstrap string concatenation requires two String operands");
            }
            result = ValueType::String;
        } else if (binary.op == "=" || binary.op == "<>" || binary.op == "<" ||
                   binary.op == "<=" || binary.op == ">" || binary.op == ">=" ||
                   binary.op == "like" || binary.op == "is") {
            if (left != right) {
                throw SemanticError(binary.location, "comparison operands must have matching types");
            }
            result = ValueType::Boolean;
        } else if (binary.op == "and" || binary.op == "or" || binary.op == "xor" ||
                   binary.op == "eqv" || binary.op == "imp") {
            if ((left != ValueType::Boolean && !numeric(left)) ||
                (right != ValueType::Boolean && !numeric(right))) {
                throw SemanticError(binary.location, "logical operator requires Boolean or integer operands");
            }
            result = left == ValueType::Boolean && right == ValueType::Boolean
                ? ValueType::Boolean : numeric_result(left, right);
        } else {
            if (!numeric(left) || !numeric(right)) {
                throw SemanticError(binary.location, "arithmetic operator requires numeric operands");
            }
            result = numeric_result(left, right);
        }
        break;
    }
    case ast::ExpressionKind::Call: {
        const auto& call = static_cast<const ast::CallExpression&>(expression);
        const auto call_name = canonical(call.callee);
        if (call_name == "lbound" || call_name == "ubound") {
            if (call.arguments.size() != 1) {
                throw SemanticError(call.location, call.callee + " requires exactly one array argument");
            }
            const auto argument = analyze_expression(*call.arguments.front(), variables, procedures, model, types, record_names);
            if (!array_type(argument)) {
                throw SemanticError(call.arguments.front()->location, call.callee + " requires a dynamic array");
            }
            result = ValueType::Long;
            break;
        }
        const auto variable = variables.find(canonical(call.callee));
        if (variable != variables.end() && array_type(variable->second)) {
            if (call.arguments.size() != 1) {
                throw SemanticError(call.location, "array access requires exactly one index");
            }
            const auto index_type = analyze_expression(*call.arguments.front(), variables, procedures, model, types, record_names);
            if (!numeric(index_type)) throw SemanticError(call.arguments.front()->location, "array index must be numeric");
            result = array_element(variable->second);
            model.array_accesses.emplace(&call, variable->second);
            if (result == ValueType::UserDefined) {
                const auto record = record_names.find(canonical(call.callee));
                if (record != record_names.end()) model.user_types.emplace(&expression, types.at(record->second));
            }
            break;
        }
        const auto found = procedures.find(canonical(call.callee));
        if (found == procedures.end()) throw SemanticError(call.location, "procedure is not declared: " + call.callee);
        const auto& procedure = *found->second;
        if (procedure.kind != ast::ProcedureKind::Function) {
            throw SemanticError(call.location, "Sub cannot be used as an expression: " + call.callee);
        }
        if (call.arguments.size() != procedure.parameters.size()) {
            throw SemanticError(call.location, "argument count does not match procedure: " + call.callee);
        }
        for (std::size_t index = 0; index < call.arguments.size(); ++index) {
            const auto argument = analyze_expression(*call.arguments[index], variables, procedures, model, types, record_names);
            auto parameter = declared_type(procedure.parameters[index].type_name,
                                           procedure.parameters[index].location, &types);
            if (procedure.parameters[index].dynamic_array) {
                parameter = dynamic_array_type(parameter, procedure.parameters[index].location);
            }
            validate_argument(*call.arguments[index], argument, procedure.parameters[index], parameter);
            if (parameter == ValueType::UserDefined || parameter == ValueType::UserDefinedArray) {
                validate_user_type_argument(*call.arguments[index], procedure.parameters[index], record_names);
            }
        }
        result = declared_type(procedure.return_type, procedure.location, &types);
        break;
    }
    }
    model.expression_types.emplace(&expression, result);
    return result;
}

void collect_declarations(const std::vector<std::unique_ptr<ast::Statement>>& statements,
                          std::unordered_map<std::string, ValueType>& variables,
                          RecordNames& record_names, const TypeTable& types) {
    for (const auto& statement : statements) {
        if (statement->kind == ast::StatementKind::VariableDeclaration) {
            const auto& declaration = static_cast<const ast::VariableDeclaration&>(*statement);
            const auto key = canonical(declaration.name);
            if (variables.count(key) != 0) {
                throw SemanticError(declaration.location, "duplicate local name: " + declaration.name);
            }
            auto type = declared_type(declaration.type_name, declaration.location, &types);
            if (declaration.dynamic_array) type = dynamic_array_type(type, declaration.location);
            variables.emplace(key, type);
            if (type == ValueType::UserDefined || type == ValueType::UserDefinedArray) {
                record_names.emplace(key, canonical(declaration.type_name));
            }
        } else if (statement->kind == ast::StatementKind::If) {
            const auto& conditional = static_cast<const ast::IfStatement&>(*statement);
            collect_declarations(conditional.then_statements, variables, record_names, types);
            collect_declarations(conditional.else_statements, variables, record_names, types);
        } else if (statement->kind == ast::StatementKind::While) {
            const auto& loop = static_cast<const ast::WhileStatement&>(*statement);
            collect_declarations(loop.statements, variables, record_names, types);
        } else if (statement->kind == ast::StatementKind::For) {
            collect_declarations(static_cast<const ast::ForStatement&>(*statement).statements,
                                 variables, record_names, types);
        }
    }
}

void analyze_statements(const std::vector<std::unique_ptr<ast::Statement>>& statements,
                        const std::unordered_map<std::string, ValueType>& variables,
                        const ProcedureTable& procedures, ast::ProcedureKind procedure_kind,
                        SemanticModel& model, const TypeTable& types,
                        const RecordNames& record_names, std::size_t for_depth = 0,
                        std::size_t while_depth = 0) {
    for (const auto& statement : statements) {
        switch (statement->kind) {
        case ast::StatementKind::VariableDeclaration: {
            const auto& declaration = static_cast<const ast::VariableDeclaration&>(*statement);
            if (declaration.initializer) {
                const auto source = analyze_expression(*declaration.initializer, variables, procedures, model, types, record_names);
                const auto target = variables.at(canonical(declaration.name));
                if (!assignable(target, source)) throw SemanticError(declaration.location, "initializer type is not assignable");
            }
            break;
        }
        case ast::StatementKind::Assignment: {
            const auto& assignment = static_cast<const ast::AssignmentStatement&>(*statement);
            const auto target = variables.find(canonical(assignment.target));
            if (target == variables.end()) throw SemanticError(assignment.location, "assignment target is not declared: " + assignment.target);
            auto target_type = target->second;
            if (!assignment.target_member.empty()) {
                const auto record_name = record_names.find(canonical(assignment.target));
                if (assignment.target_index) {
                    if (target_type != ValueType::UserDefinedArray) {
                        throw SemanticError(assignment.location, "indexed member assignment target is not a record array");
                    }
                    if (!numeric(analyze_expression(*assignment.target_index, variables, procedures,
                                                    model, types, record_names))) {
                        throw SemanticError(assignment.target_index->location, "array index must be numeric");
                    }
                } else if (target_type != ValueType::UserDefined) {
                    throw SemanticError(assignment.location, "member assignment target is not a user-defined type");
                }
                if (record_name == record_names.end()) {
                    throw SemanticError(assignment.location, "member assignment target is not a user-defined type");
                }
                const auto owner = types.at(record_name->second);
                const ast::TypeField* field = nullptr;
                std::size_t field_index = 0;
                for (std::size_t index = 0; index < owner->fields.size(); ++index) {
                    if (canonical(owner->fields[index].name) == canonical(assignment.target_member)) {
                        field = &owner->fields[index]; field_index = index; break;
                    }
                }
                if (field == nullptr) throw SemanticError(assignment.location, "type " + owner->name + " has no member " + assignment.target_member);
                target_type = declared_type(field->type_name, field->location, &types);
                if (field->dynamic_array) target_type = dynamic_array_type(target_type, field->location);
                model.member_assignments.emplace(&assignment,
                    ResolvedMember{owner, field, field_index, target_type});
            } else if (assignment.target_index) {
                if (!array_type(target_type)) throw SemanticError(assignment.location, "indexed assignment target is not an array");
                if (!numeric(analyze_expression(*assignment.target_index, variables, procedures, model, types, record_names))) {
                    throw SemanticError(assignment.target_index->location, "array index must be numeric");
                }
                target_type = array_element(target_type);
            } else if (array_type(target_type)) {
                throw SemanticError(assignment.location, "array assignment requires an index");
            }
            const auto source_type = analyze_expression(*assignment.value, variables, procedures, model, types, record_names);
            if (!assignable(target_type, source_type)) throw SemanticError(assignment.location, "assigned value has an incompatible type");
            break;
        }
        case ast::StatementKind::ReDim: {
            const auto& redim = static_cast<const ast::ReDimStatement&>(*statement);
            const auto found = variables.find(canonical(redim.name));
            if (found == variables.end() || !array_type(found->second)) {
                throw SemanticError(redim.location, "ReDim target is not a declared dynamic array: " + redim.name);
            }
            if (redim.lower_bound && !numeric(analyze_expression(*redim.lower_bound, variables, procedures, model, types, record_names))) {
                throw SemanticError(redim.lower_bound->location, "array lower bound must be numeric");
            }
            if (!numeric(analyze_expression(*redim.upper_bound, variables, procedures, model, types, record_names))) {
                throw SemanticError(redim.upper_bound->location, "array upper bound must be numeric");
            }
            break;
        }
        case ast::StatementKind::Print: {
            const auto& print = static_cast<const ast::PrintStatement&>(*statement);
            for (const auto& value : print.values) {
                static_cast<void>(analyze_expression(*value, variables, procedures, model, types, record_names));
            }
            break;
        }
        case ast::StatementKind::Exit: {
            const auto& exit = static_cast<const ast::ExitStatement&>(*statement);
            const auto expected = procedure_kind == ast::ProcedureKind::Sub ? "sub" : "function";
            if ((exit.construct == "sub" || exit.construct == "function") && exit.construct != expected) {
                throw SemanticError(exit.location, "Exit does not match the enclosing procedure");
            }
            if (exit.construct != expected && !(exit.construct == "for" && for_depth != 0) &&
                !(exit.construct == "while" && while_depth != 0)) {
                throw SemanticError(exit.location, "Exit does not match an enclosing construct");
            }
            break;
        }
        case ast::StatementKind::If: {
            const auto& conditional = static_cast<const ast::IfStatement&>(*statement);
            if (analyze_expression(*conditional.condition, variables, procedures, model, types, record_names) != ValueType::Boolean) {
                throw SemanticError(conditional.location, "If condition must be Boolean");
            }
            analyze_statements(conditional.then_statements, variables, procedures, procedure_kind, model, types, record_names, for_depth, while_depth);
            analyze_statements(conditional.else_statements, variables, procedures, procedure_kind, model, types, record_names, for_depth, while_depth);
            break;
        }
        case ast::StatementKind::While: {
            const auto& loop = static_cast<const ast::WhileStatement&>(*statement);
            if (analyze_expression(*loop.condition, variables, procedures, model, types, record_names) != ValueType::Boolean) {
                throw SemanticError(loop.location, "While condition must be Boolean");
            }
            analyze_statements(loop.statements, variables, procedures, procedure_kind, model, types, record_names, for_depth, while_depth + 1);
            break;
        }
        case ast::StatementKind::For: {
            const auto& loop = static_cast<const ast::ForStatement&>(*statement);
            const auto variable = variables.find(canonical(loop.variable));
            if (variable == variables.end() || variable->second != ValueType::Long) {
                throw SemanticError(loop.location, "For control variable must be a declared Long");
            }
            if (analyze_expression(*loop.start, variables, procedures, model, types, record_names) != ValueType::Long ||
                analyze_expression(*loop.finish, variables, procedures, model, types, record_names) != ValueType::Long ||
                (loop.step && analyze_expression(*loop.step, variables, procedures, model, types, record_names) != ValueType::Long)) {
                throw SemanticError(loop.location, "For bounds and Step must be Long");
            }
            analyze_statements(loop.statements, variables, procedures, procedure_kind, model, types,
                               record_names, for_depth + 1, while_depth);
            break;
        }
        case ast::StatementKind::Call: {
            const auto& call_statement = static_cast<const ast::CallStatement&>(*statement);
            const auto& call = *call_statement.call;
            const auto found = procedures.find(canonical(call.callee));
            if (found == procedures.end()) throw SemanticError(call.location, "procedure is not declared: " + call.callee);
            const auto& procedure = *found->second;
            if (call.arguments.size() != procedure.parameters.size()) {
                throw SemanticError(call.location, "argument count does not match procedure: " + call.callee);
            }
            for (std::size_t index = 0; index < call.arguments.size(); ++index) {
                const auto argument = analyze_expression(*call.arguments[index], variables, procedures, model, types, record_names);
                auto parameter = declared_type(procedure.parameters[index].type_name,
                                               procedure.parameters[index].location, &types);
                if (procedure.parameters[index].dynamic_array) {
                    parameter = dynamic_array_type(parameter, procedure.parameters[index].location);
                }
                validate_argument(*call.arguments[index], argument, procedure.parameters[index], parameter);
                if (parameter == ValueType::UserDefined || parameter == ValueType::UserDefinedArray) {
                    validate_user_type_argument(*call.arguments[index], procedure.parameters[index], record_names);
                }
            }
            break;
        }
        }
    }
}

void analyze_procedure(const ast::Procedure& procedure, const ProcedureTable& procedures,
                       SemanticModel& model, const TypeTable& types) {
    if (procedure.intrinsic) {
        return;
    }
    std::unordered_map<std::string, ValueType> variables;
    RecordNames record_names;
    for (const auto& parameter : procedure.parameters) {
        const auto key = canonical(parameter.name);
        if (variables.count(key) != 0) throw SemanticError(parameter.location, "duplicate parameter: " + parameter.name);
        auto type = declared_type(parameter.type_name, parameter.location, &types);
        if (parameter.dynamic_array) type = dynamic_array_type(type, parameter.location);
        variables.emplace(key, type);
        if (type == ValueType::UserDefined || type == ValueType::UserDefinedArray) {
            record_names.emplace(key, canonical(parameter.type_name));
        }
    }
    if (procedure.kind == ast::ProcedureKind::Function) {
        variables.emplace(canonical(procedure.name), declared_type(procedure.return_type, procedure.location, &types));
    }
    collect_declarations(procedure.statements, variables, record_names, types);
    analyze_statements(procedure.statements, variables, procedures, procedure.kind, model, types, record_names);
}

} // namespace

SemanticError::SemanticError(SourceLocation location, const std::string& message)
    : std::runtime_error(message), location_(location) {}

SemanticModel SemanticAnalyzer::analyze(const ast::Module& module) {
    SemanticModel model;
    TypeTable types;
    for (const auto& declaration : module.types) {
        const auto key = canonical(declaration.name);
        if (!types.emplace(key, &declaration).second) {
            throw SemanticError(declaration.location, "duplicate type: " + declaration.name);
        }
        std::unordered_set<std::string> fields;
        for (const auto& field : declaration.fields) {
            if (!fields.insert(canonical(field.name)).second) {
                throw SemanticError(field.location, "duplicate field in type " + declaration.name + ": " + field.name);
            }
        }
    }
    for (const auto& declaration : module.types) {
        for (const auto& field : declaration.fields) {
            const auto type = declared_type(field.type_name, field.location, &types);
            if (type == ValueType::UserDefined || field.dynamic_array) {
                throw SemanticError(field.location,
                    "bootstrap type fields currently require scalar Long or String values");
            }
            if (type != ValueType::Long && type != ValueType::String) {
                throw SemanticError(field.location,
                    "bootstrap type fields currently require Long or String");
            }
        }
    }
    std::unordered_set<std::string> procedure_names;
    ProcedureTable procedures;
    for (const auto& procedure : module.procedures) {
        const auto key = canonical(procedure.name);
        if (!procedure_names.insert(key).second) {
            throw SemanticError(procedure.location, "duplicate procedure: " + procedure.name);
        }
        procedures.emplace(key, &procedure);
        if (procedure.intrinsic) validate_intrinsic(procedure);
        if (key == "main") {
            if (procedure.intrinsic) throw SemanticError(procedure.location, "Main cannot be Intrinsic");
            if (model.entry_point != nullptr) throw SemanticError(procedure.location, "executable has more than one Main procedure");
            if (!procedure.parameters.empty()) throw SemanticError(procedure.location, "Main must not have parameters");
            if (procedure.kind == ast::ProcedureKind::Function && canonical(procedure.return_type) != "long") {
                throw SemanticError(procedure.location, "Function Main must return Long");
            }
            model.entry_point = &procedure;
        }
    }
    for (const auto& procedure : module.procedures) analyze_procedure(procedure, procedures, model, types);
    if (model.entry_point == nullptr) throw SemanticError({}, "executable requires Sub Main() or Function Main() As Long");
    return model;
}

} // namespace ube
