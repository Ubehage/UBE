#pragma once

#include <optional>
#include <string>
#include <string_view>

namespace ube::unicode {

// Returns the locale-independent Unicode simple case fold of valid UTF-8.
// Invalid UTF-8 returns std::nullopt and never produces a partial result.
std::optional<std::string> simple_case_fold(std::string_view text);

} // namespace ube::unicode
