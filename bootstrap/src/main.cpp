#include "ube/codegen.hpp"
#include "ube/lexer.hpp"
#include "ube/parser.hpp"
#include "ube/semantic.hpp"

#include <fstream>
#include <filesystem>
#include <iomanip>
#include <iostream>
#include <iterator>
#include <system_error>
#include <vector>

#ifdef _WIN32
#include <process.h>
#include <windows.h>
#endif

namespace {
std::string escaped(std::string_view text) {
    std::string out;
    for (char c : text) {
        if (c == '\r') out += "\\r";
        else if (c == '\n') out += "\\n";
        else if (c == '\t') out += "\\t";
        else out += c;
    }
    return out;
}

#ifdef _WIN32
std::filesystem::path find_clang() {
    if (const char* configured = std::getenv("UBE_CLANG")) {
        if (*configured != '\0' && std::filesystem::is_regular_file(configured)) return configured;
    }
    char found[MAX_PATH]{};
    if (SearchPathA(nullptr, "clang.exe", nullptr, MAX_PATH, found, nullptr) != 0) return found;
    const std::filesystem::path installed = "C:/Program Files/LLVM/bin/clang.exe";
    return std::filesystem::is_regular_file(installed) ? installed : std::filesystem::path{};
}

std::filesystem::path temporary_file() {
    char directory[MAX_PATH]{};
    if (GetTempPathA(MAX_PATH, directory) == 0) return {};
    char filename[MAX_PATH]{};
    if (GetTempFileNameA(directory, "ube", 0, filename) == 0) return {};
    return filename;
}

int run_process(const std::filesystem::path& executable,
                const std::vector<std::string>& arguments) {
    std::vector<const char*> raw_arguments;
    const auto executable_text = executable.string();
    // MinGW's spawn implementation does not quote argv[0] when constructing
    // the Windows command line. Keep argv[0] space-free while passing the full
    // executable path separately to _spawnv.
    raw_arguments.push_back("clang");
    for (const auto& argument : arguments) raw_arguments.push_back(argument.c_str());
    raw_arguments.push_back(nullptr);
    const auto result = _spawnv(_P_WAIT, executable_text.c_str(), raw_arguments.data());
    if (result == -1) {
        std::cerr << "ubec: could not start LLVM compiler: " << executable_text << '\n';
        return 2;
    }
    return static_cast<int>(result);
}

int compile_native(std::string_view ir, const char* compiler_path, const char* output_path) {
    const auto clang = find_clang();
    if (clang.empty()) {
        std::cerr << "ubec: clang was not found; install LLVM or set UBE_CLANG\n";
        return 2;
    }
    std::error_code path_error;
    const auto compiler = std::filesystem::absolute(compiler_path, path_error);
    if (path_error) {
        std::cerr << "ubec: cannot resolve compiler location: " << path_error.message() << '\n';
        return 2;
    }
    const auto runtime = compiler.parent_path() / "bootstrap_runtime.o";
    if (!std::filesystem::is_regular_file(runtime)) {
        std::cerr << "ubec: bootstrap runtime not found: " << runtime.string() << '\n';
        return 2;
    }
    const auto unicode_runtime = compiler.parent_path() / "bootstrap_unicode_runtime.o";
    if (!std::filesystem::is_regular_file(unicode_runtime)) {
        std::cerr << "ubec: bootstrap Unicode runtime not found: " << unicode_runtime.string() << '\n';
        return 2;
    }
    const auto temporary = temporary_file();
    if (temporary.empty()) {
        std::cerr << "ubec: could not create a temporary LLVM IR file\n";
        return 2;
    }
    {
        std::ofstream output(temporary, std::ios::binary | std::ios::trunc);
        if (!output) {
            std::cerr << "ubec: cannot write temporary LLVM IR file\n";
            std::error_code ignored;
            std::filesystem::remove(temporary, ignored);
            return 2;
        }
        output.write(ir.data(), static_cast<std::streamsize>(ir.size()));
        if (!output) {
            std::cerr << "ubec: failed while writing temporary LLVM IR file\n";
            std::error_code ignored;
            std::filesystem::remove(temporary, ignored);
            return 2;
        }
    }
    const std::vector<std::string> arguments = {
        "--target=x86_64-w64-windows-gnu", "-O2", "-x", "ir", temporary.string(),
        "-x", "none", runtime.string(), unicode_runtime.string(), "-o", output_path
    };
    const auto result = run_process(clang, arguments);
    std::error_code ignored;
    std::filesystem::remove(temporary, ignored);
    if (result != 0) std::cerr << "ubec: LLVM compilation failed with exit code " << result << '\n';
    return result;
}
#else
int compile_native(std::string_view, const char*, const char*) {
    std::cerr << "ubec: native compilation is not implemented on this host\n";
    return 2;
}
#endif
}

int main(int argc, char** argv) {
    const bool compile_command = argc >= 2 && std::string_view(argv[1]) == "--compile";
    if ((!compile_command && (argc < 3 || argc > 4)) || (compile_command && argc != 5)) {
        std::cerr << "usage: ubec (--check | --dump-tokens) <source-file>\n"
                  << "       ubec --emit-llvm <source-file> [output.ll]\n"
                  << "       ubec --compile <source-file> -o <output.exe>\n";
        return 2;
    }
    const std::string_view command = argv[1];
    if (command != "--check" && command != "--dump-tokens" && command != "--emit-llvm" &&
        command != "--compile") {
        std::cerr << "ubec: unknown command: " << command << '\n'
                  << "usage: ubec (--check | --dump-tokens) <source-file>\n"
                  << "       ubec --emit-llvm <source-file> [output.ll]\n"
                  << "       ubec --compile <source-file> -o <output.exe>\n";
        return 2;
    }
    if (argc == 4 && command != "--emit-llvm") {
        std::cerr << "ubec: an output file is only valid with --emit-llvm\n";
        return 2;
    }
    if (command == "--compile" && std::string_view(argv[3]) != "-o") {
        std::cerr << "ubec: expected -o before the native output path\n";
        return 2;
    }
    std::ifstream input(argv[2], std::ios::binary);
    if (!input) {
        std::cerr << "ubec: cannot open " << argv[2] << '\n';
        return 2;
    }
    const std::string source{std::istreambuf_iterator<char>(input),
                             std::istreambuf_iterator<char>()};
    try {
        auto tokens = ube::Lexer(source).scan();
        if (command == "--check" || command == "--emit-llvm" || command == "--compile") {
            const auto module = ube::Parser(std::move(tokens)).parse_module();
            const auto semantics = ube::SemanticAnalyzer().analyze(module);
            if (command == "--emit-llvm") {
                const auto ir = ube::generate_llvm_ir(module, semantics);
                if (argc == 4) {
                    std::ofstream output(argv[3], std::ios::binary | std::ios::trunc);
                    if (!output) {
                        std::cerr << "ubec: cannot create " << argv[3] << '\n';
                        return 2;
                    }
                    output.write(ir.data(), static_cast<std::streamsize>(ir.size()));
                    if (!output) {
                        std::cerr << "ubec: failed while writing " << argv[3] << '\n';
                        return 2;
                    }
                } else {
                    std::cout << ir;
                }
            } else if (command == "--compile") {
                return compile_native(ube::generate_llvm_ir(module, semantics), argv[0], argv[4]);
            } else {
                std::cout << argv[2] << ": parsed " << module.procedures.size()
                          << " procedure(s)\n";
            }
        } else {
            for (const auto& token : tokens) {
                std::cout << token.location.line << ':' << token.location.column << '\t'
                          << std::left << std::setw(12) << ube::token_kind_name(token.kind) << '\t'
                          << escaped(token.lexeme) << '\n';
            }
        }
    } catch (const ube::LexError& error) {
        std::cerr << argv[2] << ':' << error.location().line << ':' << error.location().column
                  << ": error: " << error.what() << '\n';
        return 1;
    } catch (const ube::ParseError& error) {
        std::cerr << argv[2] << ':' << error.location().line << ':' << error.location().column
                  << ": error: " << error.what() << '\n';
        return 1;
    } catch (const ube::SemanticError& error) {
        std::cerr << argv[2] << ':' << error.location().line << ':' << error.location().column
                  << ": error: " << error.what() << '\n';
        return 1;
    } catch (const ube::CodegenError& error) {
        std::cerr << argv[2] << ':' << error.location().line << ':' << error.location().column
                  << ": error: " << error.what() << '\n';
        return 1;
    } catch (const std::exception& error) {
        std::cerr << "ubec: unable to process " << argv[2] << ": " << error.what() << '\n';
        return 1;
    }
}
