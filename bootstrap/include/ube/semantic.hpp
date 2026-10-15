#pragma once

#include "ube/ast.hpp"

#include <stdexcept>
#include <unordered_map>

namespace ube {

enum class ValueType { Boolean, Integer, Long, LongLong, Single, Double, String, Date,
                       LongArray, StringArray, UserDefined, UserDefinedArray, Variant };

struct ResolvedMember {
    const ast::TypeDeclaration* owner{};
    const ast::TypeField* field{};
    std::size_t field_index{};
    ValueType type{ValueType::Variant};
};

class SemanticError : public std::runtime_error {
public:
    SemanticError(SourceLocation location, const std::string& message);
    SourceLocation location() const noexcept { return location_; }

private:
    SourceLocation location_;
};

struct SemanticModel {
    const ast::Procedure* entry_point{};
    std::unordered_map<const ast::Expression*, ValueType> expression_types;
    std::unordered_map<const ast::Expression*, const ast::TypeDeclaration*> user_types;
    std::unordered_map<const ast::CallExpression*, ValueType> array_accesses;
    std::unordered_map<const ast::MemberExpression*, ResolvedMember> member_accesses;
    std::unordered_map<const ast::AssignmentStatement*, ResolvedMember> member_assignments;
};

class SemanticAnalyzer {
public:
    SemanticModel analyze(const ast::Module& module);
};

} // namespace ube
