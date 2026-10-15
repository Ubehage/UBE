#pragma once

#include "ube/semantic.hpp"

#include <stdexcept>
#include <string>

namespace ube {

class CodegenError : public std::runtime_error {
public:
    CodegenError(SourceLocation location, const std::string& message);
    SourceLocation location() const noexcept { return location_; }

private:
    SourceLocation location_;
};

std::string generate_llvm_ir(const ast::Module& module, const SemanticModel& semantics);

} // namespace ube
