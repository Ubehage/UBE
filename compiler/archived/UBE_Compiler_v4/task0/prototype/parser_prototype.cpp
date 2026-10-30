#include <algorithm>
#include <chrono>
#include <cstdint>
#include <fstream>
#include <iostream>
#include <limits>
#include <set>
#include <sstream>
#include <string>
#include <string_view>
#include <vector>

namespace {

constexpr std::size_t kMaxInputBytes = 16U * 1024U * 1024U;
constexpr std::size_t kMaxTokens = 1000000U;
constexpr std::size_t kMaxNodes = 2000000U;
constexpr std::size_t kMaxDiagnostics = 32U;

enum class TokenKind : std::uint8_t { Word, Number, String, Symbol, Newline, End };

struct Token {
    TokenKind kind{};
    std::uint32_t start{};
    std::uint32_t length{};
    std::uint32_t line{};
    std::string folded;
};

struct Diagnostic {
    std::string code;
    std::uint32_t start{};
    std::string message;
};

enum class LineKind : std::uint16_t {
    Empty,
    Header,
    Attribute,
    ConstDeclaration,
    VariableDeclaration,
    ProcedureStart,
    ProcedureEnd,
    IfStart,
    ElsePart,
    EndIf,
    WhileStart,
    Wend,
    Print,
    Assignment,
    Call,
    Unknown
};

struct SourceLine {
    std::size_t first{};
    std::size_t last{};
    std::uint32_t start{};
    std::uint32_t length{};
};

struct FullNode {
    std::uint16_t kind{};
    std::uint16_t flags{};
    std::uint32_t start{};
    std::uint32_t length{};
    std::uint32_t first_child{};
    std::uint32_t child_count{};
};

struct SelectiveNode {
    std::uint16_t kind{};
    std::uint16_t flags{};
    std::uint32_t start{};
    std::uint32_t length{};
};

struct Metrics {
    bool accepted{};
    std::size_t input_bytes{};
    std::size_t tokens{};
    std::size_t nodes{};
    std::size_t edges{};
    std::size_t syntax_bytes{};
    std::uint64_t work{};
    std::size_t recoveries{};
    std::size_t max_depth{};
    std::size_t grammar_coverage{};
    std::uint64_t span_hash{};
    std::uint64_t semantic_hash{};
    std::uint64_t elapsed_us{};
    std::vector<Diagnostic> diagnostics;
};

std::string FoldAscii(std::string_view value) {
    std::string result;
    result.reserve(value.size());
    for (const unsigned char byte : value) {
        if (byte >= static_cast<unsigned char>('A') && byte <= static_cast<unsigned char>('Z')) {
            result.push_back(static_cast<char>(byte + ('a' - 'A')));
        } else {
            result.push_back(static_cast<char>(byte));
        }
    }
    return result;
}

void HashNumber(std::uint64_t& hash, std::uint64_t value) {
    constexpr std::uint64_t prime = 1099511628211ULL;
    for (unsigned shift = 0; shift < 64; shift += 8) {
        hash ^= (value >> shift) & 0xffULL;
        hash *= prime;
    }
}

void HashText(std::uint64_t& hash, std::string_view value) {
    constexpr std::uint64_t prime = 1099511628211ULL;
    for (const unsigned char byte : value) {
        hash ^= byte;
        hash *= prime;
    }
}

bool IsWordStart(unsigned char byte) {
    return (byte >= 'A' && byte <= 'Z') || (byte >= 'a' && byte <= 'z') || byte == '_' || byte >= 0x80U;
}

bool IsWordPart(unsigned char byte) {
    return IsWordStart(byte) || (byte >= '0' && byte <= '9');
}

bool Lex(const std::string& source, std::vector<Token>& tokens, std::vector<Diagnostic>& diagnostics,
         std::uint64_t& work) {
    std::size_t cursor = 0;
    std::uint32_t line = 1;
    auto add = [&](TokenKind kind, std::size_t start, std::size_t length, std::string folded) {
        if (tokens.size() >= kMaxTokens) {
            if (diagnostics.size() < kMaxDiagnostics) {
                diagnostics.push_back({"T0P100", static_cast<std::uint32_t>(start), "token limit exceeded"});
            }
            return false;
        }
        tokens.push_back({kind, static_cast<std::uint32_t>(start), static_cast<std::uint32_t>(length), line,
                          std::move(folded)});
        return true;
    };

    while (cursor < source.size()) {
        ++work;
        const unsigned char byte = static_cast<unsigned char>(source[cursor]);
        if (byte == ' ' || byte == '\t') {
            ++cursor;
            continue;
        }
        if (byte == '\r' || byte == '\n') {
            const std::size_t start = cursor;
            if (byte == '\r' && cursor + 1 < source.size() && source[cursor + 1] == '\n') {
                cursor += 2;
            } else {
                ++cursor;
            }
            if (!add(TokenKind::Newline, start, cursor - start, "")) {
                return false;
            }
            ++line;
            continue;
        }
        if (byte == '\'') {
            while (cursor < source.size() && source[cursor] != '\r' && source[cursor] != '\n') {
                ++cursor;
                ++work;
            }
            continue;
        }
        if (byte == '"') {
            const std::size_t start = cursor++;
            bool closed = false;
            while (cursor < source.size()) {
                ++work;
                if (source[cursor] == '"') {
                    if (cursor + 1 < source.size() && source[cursor + 1] == '"') {
                        cursor += 2;
                        continue;
                    }
                    ++cursor;
                    closed = true;
                    break;
                }
                if (source[cursor] == '\r' || source[cursor] == '\n') {
                    break;
                }
                ++cursor;
            }
            if (!add(TokenKind::String, start, cursor - start, "")) {
                return false;
            }
            if (!closed && diagnostics.size() < kMaxDiagnostics) {
                diagnostics.push_back({"T0P101", static_cast<std::uint32_t>(start), "unterminated string"});
            }
            continue;
        }
        if (IsWordStart(byte)) {
            const std::size_t start = cursor++;
            while (cursor < source.size() && IsWordPart(static_cast<unsigned char>(source[cursor]))) {
                ++cursor;
                ++work;
            }
            if (!add(TokenKind::Word, start, cursor - start,
                     FoldAscii(std::string_view(source).substr(start, cursor - start)))) {
                return false;
            }
            continue;
        }
        if (byte >= '0' && byte <= '9') {
            const std::size_t start = cursor++;
            while (cursor < source.size()) {
                const unsigned char next = static_cast<unsigned char>(source[cursor]);
                if (!((next >= '0' && next <= '9') || next == '.')) {
                    break;
                }
                ++cursor;
                ++work;
            }
            if (!add(TokenKind::Number, start, cursor - start, "")) {
                return false;
            }
            continue;
        }
        const std::size_t start = cursor++;
        std::size_t length = 1;
        if (cursor < source.size()) {
            const std::string_view pair(source.data() + start, 2);
            if (pair == "<=" || pair == ">=" || pair == "<>") {
                ++cursor;
                length = 2;
            }
        }
        if (!add(TokenKind::Symbol, start, length, FoldAscii(std::string_view(source).substr(start, length)))) {
            return false;
        }
    }
    return add(TokenKind::End, source.size(), 0, "");
}

std::vector<SourceLine> MakeLines(const std::vector<Token>& tokens, std::uint64_t& work) {
    std::vector<SourceLine> result;
    std::size_t first = 0;
    for (std::size_t index = 0; index < tokens.size(); ++index) {
        ++work;
        if (tokens[index].kind != TokenKind::Newline && tokens[index].kind != TokenKind::End) {
            continue;
        }
        const std::size_t last = index;
        const std::uint32_t start = first < last ? tokens[first].start : tokens[index].start;
        const std::uint32_t end = first < last ? tokens[last - 1].start + tokens[last - 1].length : start;
        result.push_back({first, last, start, end - start});
        first = index + 1;
        if (tokens[index].kind == TokenKind::End) {
            break;
        }
    }
    return result;
}

bool WordIs(const std::vector<Token>& tokens, std::size_t index, std::string_view expected,
            std::uint64_t& work) {
    ++work;
    return index < tokens.size() && tokens[index].kind == TokenKind::Word && tokens[index].folded == expected;
}

std::size_t SkipModifiers(const std::vector<Token>& tokens, const SourceLine& line, std::uint64_t& work) {
    std::size_t index = line.first;
    while (index < line.last) {
        ++work;
        if (tokens[index].kind != TokenKind::Word) {
            break;
        }
        const std::string& word = tokens[index].folded;
        if (word != "public" && word != "private" && word != "friend" && word != "global" &&
            word != "static" && word != "inline" && word != "forceinline" && word != "export") {
            break;
        }
        ++index;
    }
    return index;
}

LineKind ClassifyHybrid(const std::vector<Token>& tokens, const SourceLine& line, std::uint64_t& work) {
    if (line.first == line.last) {
        return LineKind::Empty;
    }
    const std::size_t first = SkipModifiers(tokens, line, work);
    if (first >= line.last) {
        return LineKind::Unknown;
    }
    if (WordIs(tokens, first, "ube", work)) return LineKind::Header;
    if (WordIs(tokens, first, "attribute", work)) return LineKind::Attribute;
    if (WordIs(tokens, first, "const", work)) return LineKind::ConstDeclaration;
    if (WordIs(tokens, first, "dim", work)) return LineKind::VariableDeclaration;
    if (WordIs(tokens, first, "sub", work) || WordIs(tokens, first, "function", work) ||
        WordIs(tokens, first, "property", work)) return LineKind::ProcedureStart;
    if (WordIs(tokens, first, "if", work)) return LineKind::IfStart;
    if (WordIs(tokens, first, "elseif", work) || WordIs(tokens, first, "else", work)) return LineKind::ElsePart;
    if (WordIs(tokens, first, "while", work)) return LineKind::WhileStart;
    if (WordIs(tokens, first, "wend", work)) return LineKind::Wend;
    if (WordIs(tokens, first, "print", work)) return LineKind::Print;
    if (WordIs(tokens, first, "call", work)) return LineKind::Call;
    if (WordIs(tokens, first, "end", work) && first + 1 < line.last) {
        if (WordIs(tokens, first + 1, "if", work)) return LineKind::EndIf;
        if (WordIs(tokens, first + 1, "sub", work) || WordIs(tokens, first + 1, "function", work) ||
            WordIs(tokens, first + 1, "property", work)) return LineKind::ProcedureEnd;
    }
    for (std::size_t index = first; index < line.last; ++index) {
        ++work;
        if (tokens[index].kind == TokenKind::Symbol && tokens[index].folded == "=") {
            return LineKind::Assignment;
        }
    }
    if (tokens[first].kind == TokenKind::Word) return LineKind::Call;
    return LineKind::Unknown;
}

LineKind ClassifyTable(const std::vector<Token>& tokens, const SourceLine& line, std::uint64_t& work) {
    if (line.first == line.last) {
        return LineKind::Empty;
    }
    const std::size_t first = SkipModifiers(tokens, line, work);
    if (first >= line.last || tokens[first].kind != TokenKind::Word) {
        return LineKind::Unknown;
    }
    struct Entry { std::string_view word; LineKind kind; };
    static constexpr Entry entries[] = {
        {"ube", LineKind::Header}, {"attribute", LineKind::Attribute},
        {"const", LineKind::ConstDeclaration}, {"dim", LineKind::VariableDeclaration},
        {"sub", LineKind::ProcedureStart}, {"function", LineKind::ProcedureStart},
        {"property", LineKind::ProcedureStart}, {"if", LineKind::IfStart},
        {"elseif", LineKind::ElsePart}, {"else", LineKind::ElsePart},
        {"while", LineKind::WhileStart}, {"wend", LineKind::Wend},
        {"print", LineKind::Print}, {"call", LineKind::Call}
    };
    for (const Entry& entry : entries) {
        ++work;
        if (tokens[first].folded == entry.word) {
            return entry.kind;
        }
    }
    if (tokens[first].folded == "end" && first + 1 < line.last && tokens[first + 1].kind == TokenKind::Word) {
        ++work;
        if (tokens[first + 1].folded == "if") return LineKind::EndIf;
        if (tokens[first + 1].folded == "sub" || tokens[first + 1].folded == "function" ||
            tokens[first + 1].folded == "property") return LineKind::ProcedureEnd;
    }
    for (std::size_t index = first; index < line.last; ++index) {
        ++work;
        if (tokens[index].kind == TokenKind::Symbol && tokens[index].folded == "=") {
            return LineKind::Assignment;
        }
    }
    return LineKind::Call;
}

std::string_view ProductionName(LineKind kind) {
    switch (kind) {
        case LineKind::Header: return "native-source-header";
        case LineKind::Attribute: return "attribute-line";
        case LineKind::ConstDeclaration: return "const-declaration";
        case LineKind::VariableDeclaration: return "local-declaration";
        case LineKind::ProcedureStart: return "procedure-declaration";
        case LineKind::ProcedureEnd: return "procedure-declaration-end";
        case LineKind::IfStart: return "block-if";
        case LineKind::ElsePart: return "else-part";
        case LineKind::EndIf: return "block-if-end";
        case LineKind::WhileStart: return "while-statement";
        case LineKind::Wend: return "while-statement-end";
        case LineKind::Print: return "print-statement";
        case LineKind::Assignment: return "assignment-statement";
        case LineKind::Call: return "call-statement";
        case LineKind::Empty: return "empty-line";
        case LineKind::Unknown: return "unknown";
    }
    return "unknown";
}

int OperatorPrecedence(const Token& token) {
    if (token.kind == TokenKind::Word) {
        if (token.folded == "or" || token.folded == "orelse") return 1;
        if (token.folded == "and" || token.folded == "andalso") return 2;
        if (token.folded == "mod") return 6;
    }
    if (token.kind != TokenKind::Symbol) return -1;
    if (token.folded == "=" || token.folded == "<>" || token.folded == "<" ||
        token.folded == ">" || token.folded == "<=" || token.folded == ">=") return 3;
    if (token.folded == "&") return 4;
    if (token.folded == "+" || token.folded == "-") return 5;
    if (token.folded == "*" || token.folded == "/" || token.folded == "\\") return 6;
    if (token.folded == "^") return 7;
    return -1;
}

struct ExpressionRange { std::size_t first{}; std::size_t last{}; };

ExpressionRange FindExpression(const std::vector<Token>& tokens, const SourceLine& line, LineKind kind,
                               std::uint64_t& work) {
    std::size_t first = line.first;
    std::size_t last = line.last;
    if (kind == LineKind::Print || kind == LineKind::WhileStart) {
        first = std::min(first + 1, last);
    } else if (kind == LineKind::IfStart) {
        first = std::min(first + 1, last);
        for (std::size_t index = first; index < last; ++index) {
            ++work;
            if (tokens[index].kind == TokenKind::Word && tokens[index].folded == "then") {
                last = index;
                break;
            }
        }
    } else if (kind == LineKind::Assignment || kind == LineKind::ConstDeclaration) {
        for (std::size_t index = first; index < last; ++index) {
            ++work;
            if (tokens[index].kind == TokenKind::Symbol && tokens[index].folded == "=") {
                first = index + 1;
                break;
            }
        }
    } else {
        first = last;
    }
    return {first, last};
}

void AddDiagnostic(Metrics& metrics, std::string code, std::uint32_t start, std::string message) {
    if (metrics.diagnostics.size() < kMaxDiagnostics) {
        metrics.diagnostics.push_back({std::move(code), start, std::move(message)});
    }
    ++metrics.recoveries;
}

bool ParseTableExpression(const std::vector<Token>& tokens, ExpressionRange range, std::size_t maxDepth,
                          std::vector<FullNode>& nodes, std::vector<std::uint32_t>& edges, Metrics& metrics) {
    std::vector<std::size_t> operators;
    std::size_t depth = 0;
    for (std::size_t index = range.first; index < range.last; ++index) {
        ++metrics.work;
        const Token& token = tokens[index];
        if (token.kind == TokenKind::Symbol && token.folded == "(") {
            ++depth;
            metrics.max_depth = std::max(metrics.max_depth, depth);
            if (depth > maxDepth) {
                AddDiagnostic(metrics, "T0P201", token.start, "expression depth limit exceeded");
                return false;
            }
            operators.push_back(index);
        } else if (token.kind == TokenKind::Symbol && token.folded == ")") {
            bool matched = false;
            while (!operators.empty()) {
                const std::size_t top = operators.back();
                operators.pop_back();
                ++metrics.work;
                if (tokens[top].kind == TokenKind::Symbol && tokens[top].folded == "(") {
                    matched = true;
                    --depth;
                    break;
                }
                nodes.push_back({200, 0, tokens[top].start, tokens[top].length, 0, 0});
            }
            if (!matched) AddDiagnostic(metrics, "T0P202", token.start, "unmatched closing parenthesis");
        } else {
            const int precedence = OperatorPrecedence(token);
            if (precedence >= 0) {
                while (!operators.empty() && OperatorPrecedence(tokens[operators.back()]) >= precedence) {
                    const std::size_t top = operators.back();
                    operators.pop_back();
                    nodes.push_back({200, 0, tokens[top].start, tokens[top].length, 0, 0});
                    ++metrics.work;
                }
                operators.push_back(index);
            } else if (token.kind != TokenKind::Symbol || (token.folded != "," && token.folded != ".")) {
                nodes.push_back({201, 0, token.start, token.length, 0, 0});
            }
        }
        if (nodes.size() > kMaxNodes) {
            AddDiagnostic(metrics, "T0P203", token.start, "syntax node limit exceeded");
            return false;
        }
    }
    while (!operators.empty()) {
        const std::size_t top = operators.back();
        operators.pop_back();
        ++metrics.work;
        if (tokens[top].kind == TokenKind::Symbol && tokens[top].folded == "(") {
            AddDiagnostic(metrics, "T0P204", tokens[top].start, "missing closing parenthesis");
            continue;
        }
        nodes.push_back({200, 0, tokens[top].start, tokens[top].length, 0, 0});
    }
    static_cast<void>(edges);
    return true;
}

class PrattParser {
public:
    PrattParser(const std::vector<Token>& tokens, ExpressionRange range, std::size_t maxDepth,
                std::vector<SelectiveNode>& nodes, Metrics& metrics)
        : tokens_(tokens), cursor_(range.first), last_(range.last), maxDepth_(maxDepth), nodes_(nodes), metrics_(metrics) {}

    void Parse() {
        if (cursor_ < last_) {
            ParseExpression(0, 1);
        }
        while (cursor_ < last_) {
            AddDiagnostic(metrics_, "T0P205", tokens_[cursor_].start, "unexpected expression token");
            ++cursor_;
        }
    }

private:
    void ParseExpression(int minimum, std::size_t depth) {
        ++metrics_.work;
        metrics_.max_depth = std::max(metrics_.max_depth, depth);
        if (depth > maxDepth_ || cursor_ >= last_) {
            const std::uint32_t start = cursor_ < last_ ? tokens_[cursor_].start : 0;
            AddDiagnostic(metrics_, "T0P201", start, "expression depth limit exceeded or expression missing");
            return;
        }
        ParsePrimary(depth);
        while (cursor_ < last_) {
            const int precedence = OperatorPrecedence(tokens_[cursor_]);
            ++metrics_.work;
            if (precedence < minimum) break;
            const Token operation = tokens_[cursor_++];
            ParseExpression(precedence + 1, depth + 1);
            nodes_.push_back({200, 0, operation.start, operation.length});
        }
    }

    void ParsePrimary(std::size_t depth) {
        if (cursor_ >= last_) return;
        const Token token = tokens_[cursor_++];
        ++metrics_.work;
        if (token.kind == TokenKind::Symbol && token.folded == "(") {
            ParseExpression(0, depth + 1);
            if (cursor_ < last_ && tokens_[cursor_].kind == TokenKind::Symbol && tokens_[cursor_].folded == ")") {
                ++cursor_;
            } else {
                AddDiagnostic(metrics_, "T0P204", token.start, "missing closing parenthesis");
            }
            return;
        }
        if (token.kind == TokenKind::Symbol && (token.folded == "+" || token.folded == "-")) {
            ParsePrimary(depth + 1);
            nodes_.push_back({202, 0, token.start, token.length});
            return;
        }
        nodes_.push_back({201, 0, token.start, token.length});
        while (cursor_ < last_ && tokens_[cursor_].kind == TokenKind::Symbol && tokens_[cursor_].folded == "(") {
            const Token open = tokens_[cursor_++];
            ParseExpression(0, depth + 1);
            if (cursor_ < last_ && tokens_[cursor_].kind == TokenKind::Symbol && tokens_[cursor_].folded == ")") {
                ++cursor_;
            } else {
                AddDiagnostic(metrics_, "T0P204", open.start, "missing closing parenthesis");
                break;
            }
            nodes_.push_back({203, 0, token.start, token.length});
        }
    }

    const std::vector<Token>& tokens_;
    std::size_t cursor_;
    std::size_t last_;
    std::size_t maxDepth_;
    std::vector<SelectiveNode>& nodes_;
    Metrics& metrics_;
};

enum class BlockKind : std::uint8_t { Procedure, If, While };

Metrics Parse(const std::string& source, bool tableMode, std::size_t maxDepth) {
    const auto started = std::chrono::steady_clock::now();
    Metrics metrics;
    metrics.input_bytes = source.size();
    metrics.span_hash = 1469598103934665603ULL;
    metrics.semantic_hash = 1469598103934665603ULL;
    std::vector<Token> tokens;
    if (!Lex(source, tokens, metrics.diagnostics, metrics.work)) {
        metrics.recoveries = metrics.diagnostics.size();
        return metrics;
    }
    metrics.tokens = tokens.empty() ? 0 : tokens.size() - 1;
    for (const Token& token : tokens) {
        HashNumber(metrics.span_hash, token.start);
        HashNumber(metrics.span_hash, token.length);
        HashNumber(metrics.span_hash, static_cast<std::uint8_t>(token.kind));
    }
    const std::vector<SourceLine> lines = MakeLines(tokens, metrics.work);
    std::vector<FullNode> fullNodes;
    std::vector<std::uint32_t> fullEdges;
    std::vector<SelectiveNode> selectiveNodes;
    std::vector<BlockKind> blocks;
    std::set<std::string> coverage;
    bool sawHeader = false;
    bool sawAttribute = false;

    for (const SourceLine& line : lines) {
        const LineKind kind = tableMode ? ClassifyTable(tokens, line, metrics.work)
                                        : ClassifyHybrid(tokens, line, metrics.work);
        const std::string_view production = ProductionName(kind);
        coverage.emplace(production);
        HashText(metrics.semantic_hash, production);
        HashNumber(metrics.semantic_hash, line.start);
        HashNumber(metrics.semantic_hash, line.length);

        if (tableMode) {
            const std::uint32_t firstChild = static_cast<std::uint32_t>(fullEdges.size());
            const std::size_t parent = fullNodes.size();
            fullNodes.push_back({static_cast<std::uint16_t>(kind), 0, line.start, line.length, firstChild, 0});
            for (std::size_t index = line.first; index < line.last; ++index) {
                const std::size_t child = fullNodes.size();
                fullNodes.push_back({100, static_cast<std::uint16_t>(tokens[index].kind), tokens[index].start,
                                     tokens[index].length, 0, 0});
                fullEdges.push_back(static_cast<std::uint32_t>(child));
            }
            fullNodes[parent].child_count = static_cast<std::uint32_t>(fullEdges.size() - firstChild);
        } else if (kind != LineKind::Empty) {
            selectiveNodes.push_back({static_cast<std::uint16_t>(kind), 0, line.start, line.length});
        }

        if (kind == LineKind::ProcedureStart) {
            blocks.push_back(BlockKind::Procedure);
        } else if (kind == LineKind::IfStart) {
            blocks.push_back(BlockKind::If);
        } else if (kind == LineKind::WhileStart) {
            blocks.push_back(BlockKind::While);
        } else if (kind == LineKind::ElsePart) {
            if (blocks.empty() || blocks.back() != BlockKind::If) {
                AddDiagnostic(metrics, "T0P301", line.start, "Else without matching If");
            }
        } else if (kind == LineKind::EndIf) {
            if (blocks.empty() || blocks.back() != BlockKind::If) {
                AddDiagnostic(metrics, "T0P302", line.start, "End If without matching If");
            } else {
                blocks.pop_back();
            }
        } else if (kind == LineKind::Wend) {
            if (blocks.empty() || blocks.back() != BlockKind::While) {
                AddDiagnostic(metrics, "T0P303", line.start, "Wend without matching While");
            } else {
                blocks.pop_back();
            }
        } else if (kind == LineKind::ProcedureEnd) {
            while (!blocks.empty() && blocks.back() != BlockKind::Procedure) {
                const BlockKind missing = blocks.back();
                blocks.pop_back();
                AddDiagnostic(metrics, "T0P304", line.start,
                              missing == BlockKind::If ? "missing End If before procedure end"
                                                       : "missing Wend before procedure end");
            }
            if (blocks.empty()) {
                AddDiagnostic(metrics, "T0P305", line.start, "procedure end without matching header");
            } else {
                blocks.pop_back();
            }
        }
        if (kind == LineKind::Header) {
            if (sawHeader) {
                AddDiagnostic(metrics, "T0P308", line.start, "duplicate source header");
            }
            sawHeader = true;
        } else if (kind == LineKind::Attribute) {
            if (!sawHeader) {
                AddDiagnostic(metrics, "T0P309", line.start, "attribute precedes source header");
            }
            sawAttribute = true;
        } else if (kind == LineKind::Unknown) {
            AddDiagnostic(metrics, "T0P310", line.start, "unrecognized source line");
        }
        metrics.max_depth = std::max(metrics.max_depth, blocks.size());
        if (blocks.size() > maxDepth) {
            AddDiagnostic(metrics, "T0P306", line.start, "block depth limit exceeded");
            blocks.resize(maxDepth);
        }

        const ExpressionRange expression = FindExpression(tokens, line, kind, metrics.work);
        if (expression.first < expression.last) {
            coverage.emplace("expression");
            if (tableMode) {
                ParseTableExpression(tokens, expression, maxDepth, fullNodes, fullEdges, metrics);
            } else {
                PrattParser parser(tokens, expression, maxDepth, selectiveNodes, metrics);
                parser.Parse();
            }
        }
        if ((tableMode && fullNodes.size() > kMaxNodes) || (!tableMode && selectiveNodes.size() > kMaxNodes)) {
            AddDiagnostic(metrics, "T0P203", line.start, "syntax node limit exceeded");
            break;
        }
    }
    while (!blocks.empty()) {
        const BlockKind missing = blocks.back();
        blocks.pop_back();
        AddDiagnostic(metrics, "T0P307", static_cast<std::uint32_t>(source.size()),
                      missing == BlockKind::Procedure ? "missing procedure terminator"
                      : missing == BlockKind::If ? "missing End If" : "missing Wend");
    }
    if (!sawHeader) {
        AddDiagnostic(metrics, "T0P311", 0, "missing native source header");
    }
    if (!sawAttribute) {
        AddDiagnostic(metrics, "T0P312", 0, "missing UBE_Name attribute");
    }

    metrics.nodes = tableMode ? fullNodes.size() : selectiveNodes.size();
    metrics.edges = tableMode ? fullEdges.size() : 0;
    metrics.syntax_bytes = tableMode ? fullNodes.size() * sizeof(FullNode) + fullEdges.size() * sizeof(std::uint32_t)
                                     : selectiveNodes.size() * sizeof(SelectiveNode);
    metrics.grammar_coverage = coverage.size();
    metrics.accepted = metrics.diagnostics.empty();
    metrics.elapsed_us = static_cast<std::uint64_t>(
        std::chrono::duration_cast<std::chrono::microseconds>(std::chrono::steady_clock::now() - started).count());
    return metrics;
}

std::string JsonEscape(std::string_view value) {
    std::ostringstream output;
    for (const unsigned char byte : value) {
        switch (byte) {
            case '"': output << "\\\""; break;
            case '\\': output << "\\\\"; break;
            case '\n': output << "\\n"; break;
            case '\r': output << "\\r"; break;
            case '\t': output << "\\t"; break;
            default:
                if (byte < 0x20U) {
                    output << "?";
                } else {
                    output << static_cast<char>(byte);
                }
        }
    }
    return output.str();
}

void PrintMetrics(const std::string& mode, const Metrics& metrics) {
    std::cout << "{\"format\":\"ube-v4-task0-parser-measurement-1\",\"mode\":\"" << mode
              << "\",\"accepted\":" << (metrics.accepted ? "true" : "false")
              << ",\"input_bytes\":" << metrics.input_bytes
              << ",\"tokens\":" << metrics.tokens
              << ",\"nodes\":" << metrics.nodes
              << ",\"edges\":" << metrics.edges
              << ",\"syntax_bytes\":" << metrics.syntax_bytes
              << ",\"work\":" << metrics.work
              << ",\"recoveries\":" << metrics.recoveries
              << ",\"max_depth\":" << metrics.max_depth
              << ",\"grammar_coverage\":" << metrics.grammar_coverage
              << ",\"span_hash\":\"" << std::hex << metrics.span_hash
              << "\",\"semantic_hash\":\"" << metrics.semantic_hash << std::dec
              << "\",\"elapsed_us\":" << metrics.elapsed_us << ",\"diagnostics\":[";
    for (std::size_t index = 0; index < metrics.diagnostics.size(); ++index) {
        if (index != 0) std::cout << ',';
        const Diagnostic& diagnostic = metrics.diagnostics[index];
        std::cout << "{\"code\":\"" << JsonEscape(diagnostic.code) << "\",\"start\":" << diagnostic.start
                  << ",\"message\":\"" << JsonEscape(diagnostic.message) << "\"}";
    }
    std::cout << "]}\n";
}

bool ReadFile(const std::string& path, std::string& content, std::string& error) {
    std::ifstream input(path, std::ios::binary);
    if (!input) {
        error = "cannot open input file";
        return false;
    }
    input.seekg(0, std::ios::end);
    const std::streamoff length = input.tellg();
    if (length < 0 || static_cast<std::uint64_t>(length) > kMaxInputBytes) {
        error = "input size is invalid or exceeds 16 MiB";
        return false;
    }
    input.seekg(0, std::ios::beg);
    content.resize(static_cast<std::size_t>(length));
    if (length > 0 && !input.read(content.data(), length)) {
        error = "cannot read complete input file";
        return false;
    }
    return true;
}

}  // namespace

int main(int argc, char** argv) {
    try {
        std::string mode;
        std::string inputPath;
        std::size_t maxDepth = 64;
        for (int index = 1; index < argc; ++index) {
            const std::string argument = argv[index];
            if (argument == "--mode" && index + 1 < argc) {
                mode = argv[++index];
            } else if (argument == "--input" && index + 1 < argc) {
                inputPath = argv[++index];
            } else if (argument == "--max-depth" && index + 1 < argc) {
                const std::string value = argv[++index];
                std::size_t consumed = 0;
                const unsigned long parsed = std::stoul(value, &consumed, 10);
                if (consumed != value.size() || parsed == 0 || parsed > 4096UL) {
                    std::cerr << "parser prototype: --max-depth must be 1..4096\n";
                    return 2;
                }
                maxDepth = static_cast<std::size_t>(parsed);
            } else {
                std::cerr << "parser prototype: unknown or incomplete argument: " << argument << '\n';
                return 2;
            }
        }
        if ((mode != "table" && mode != "hybrid") || inputPath.empty()) {
            std::cerr << "usage: parser_prototype --mode table|hybrid --input PATH [--max-depth N]\n";
            return 2;
        }
        std::string source;
        std::string error;
        if (!ReadFile(inputPath, source, error)) {
            std::cerr << "parser prototype: " << error << ": " << inputPath << '\n';
            return 2;
        }
        const Metrics metrics = Parse(source, mode == "table", maxDepth);
        PrintMetrics(mode, metrics);
        return 0;
    } catch (const std::bad_alloc&) {
        std::cerr << "parser prototype: memory allocation failed\n";
        return 2;
    } catch (const std::exception& exception) {
        std::cerr << "parser prototype: controlled failure: " << exception.what() << '\n';
        return 2;
    } catch (...) {
        std::cerr << "parser prototype: controlled unknown failure\n";
        return 2;
    }
}
