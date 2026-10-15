#include "ube/unicode.hpp"
#include "ube/unicode_case_folding.hpp"

#include <algorithm>

namespace ube::unicode {
namespace {

struct DecodedCodePoint {
    char32_t value;
    std::size_t length;
};

DecodedCodePoint decode_utf8(std::string_view text, std::size_t offset) {
    const auto first = static_cast<unsigned char>(text[offset]);
    if (first < 0x80) return {first, 1};

    std::size_t length = 0;
    char32_t value = 0;
    if (first >= 0xC2 && first <= 0xDF) {
        length = 2;
        value = first & 0x1F;
    } else if (first >= 0xE0 && first <= 0xEF) {
        length = 3;
        value = first & 0x0F;
    } else if (first >= 0xF0 && first <= 0xF4) {
        length = 4;
        value = first & 0x07;
    } else {
        return {};
    }
    if (offset + length > text.size()) return {};

    for (std::size_t index = 1; index < length; ++index) {
        const auto continuation = static_cast<unsigned char>(text[offset + index]);
        if ((continuation & 0xC0) != 0x80) return {};
        value = (value << 6) | (continuation & 0x3F);
    }
    if ((length == 3 && value < 0x800) || (length == 4 && value < 0x10000) ||
        (value >= 0xD800 && value <= 0xDFFF) || value > 0x10FFFF) {
        return {};
    }
    return {value, length};
}

char32_t fold_code_point(char32_t value) {
    const auto found = std::lower_bound(
        simple_case_fold_mappings.begin(), simple_case_fold_mappings.end(), value,
        [](const CaseFoldMapping& mapping, char32_t candidate) {
            return mapping.source < candidate;
        });
    if (found != simple_case_fold_mappings.end() && found->source == value) return found->target;
    return value;
}

void append_utf8(std::string& output, char32_t value) {
    if (value <= 0x7F) {
        output.push_back(static_cast<char>(value));
    } else if (value <= 0x7FF) {
        output.push_back(static_cast<char>(0xC0 | (value >> 6)));
        output.push_back(static_cast<char>(0x80 | (value & 0x3F)));
    } else if (value <= 0xFFFF) {
        output.push_back(static_cast<char>(0xE0 | (value >> 12)));
        output.push_back(static_cast<char>(0x80 | ((value >> 6) & 0x3F)));
        output.push_back(static_cast<char>(0x80 | (value & 0x3F)));
    } else {
        output.push_back(static_cast<char>(0xF0 | (value >> 18)));
        output.push_back(static_cast<char>(0x80 | ((value >> 12) & 0x3F)));
        output.push_back(static_cast<char>(0x80 | ((value >> 6) & 0x3F)));
        output.push_back(static_cast<char>(0x80 | (value & 0x3F)));
    }
}

} // namespace

std::optional<std::string> simple_case_fold(std::string_view text) {
    std::string result;
    result.reserve(text.size());
    for (std::size_t offset = 0; offset < text.size();) {
        const auto decoded = decode_utf8(text, offset);
        if (decoded.length == 0) return std::nullopt;
        append_utf8(result, fold_code_point(decoded.value));
        offset += decoded.length;
    }
    return result;
}

} // namespace ube::unicode
