#include "ube/unicode_letter_ranges.hpp"
#include "ube/unicode_case_folding.hpp"

#include <algorithm>
#include <cstdint>

extern "C" std::int32_t ube_unicode_is_letter(std::int32_t value) {
    if (value < 0 || value > 0x10FFFF) return 0;
    const auto code_point = static_cast<char32_t>(value);
    const auto found = std::lower_bound(
        ube::unicode::letter_ranges.begin(), ube::unicode::letter_ranges.end(), code_point,
        [](const ube::unicode::CodePointRange& range, char32_t candidate) {
            return range.last < candidate;
        });
    return found != ube::unicode::letter_ranges.end() && found->first <= code_point ? 1 : 0;
}

extern "C" std::int32_t ube_unicode_simple_fold_code_point(std::int32_t value) {
    if (value < 0 || value > 0x10FFFF) return value;
    const auto code_point = static_cast<char32_t>(value);
    const auto found = std::lower_bound(
        ube::unicode::simple_case_fold_mappings.begin(),
        ube::unicode::simple_case_fold_mappings.end(), code_point,
        [](const ube::unicode::CaseFoldMapping& mapping, char32_t candidate) {
            return mapping.source < candidate;
        });
    if (found == ube::unicode::simple_case_fold_mappings.end() || found->source != code_point) {
        return value;
    }
    return static_cast<std::int32_t>(found->target);
}
