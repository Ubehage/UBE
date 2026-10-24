#ifndef UNICODE
#define UNICODE
#endif
#ifndef _UNICODE
#define _UNICODE
#endif
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <oleacc.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <wchar.h>

#define IDE_MAX_FILE_BYTES (16u * 1024u * 1024u)
#define IDE_MAX_ENTRIES 128
#define IDE_MAX_KEY 96
#define IDE_MAX_VALUE 2048

enum {
    IDE_DOCKED = 0,
    IDE_FLOATING = 1,
    IDE_HIDDEN = 2,
    IDE_AUTO_HIDDEN = 3
};

enum {
    CMD_FILE_NEW = 1001,
    CMD_FILE_OPEN,
    CMD_FILE_SAVE,
    CMD_FILE_EXIT,
    CMD_EDIT_UNDO = 1101,
    CMD_EDIT_REDO,
    CMD_VIEW_PROJECT = 1201,
    CMD_VIEW_PROPERTIES,
    CMD_VIEW_OUTPUT,
    CMD_FLOAT_PROJECT = 1301,
    CMD_DOCK_PROJECT,
    CMD_FLOAT_PROPERTIES,
    CMD_DOCK_PROPERTIES,
    CMD_FLOAT_OUTPUT,
    CMD_DOCK_OUTPUT,
    CMD_FOCUS_NEXT,
    CMD_RESET_LAYOUT,
    CMD_HELP_ABOUT = 1401
};

enum { CONTROL_DOCUMENT = 2001 };

typedef struct ConfigEntry {
    wchar_t key[IDE_MAX_KEY];
    wchar_t value[IDE_MAX_VALUE];
} ConfigEntry;

typedef struct Config {
    ConfigEntry entries[IDE_MAX_ENTRIES];
    int count;
} Config;

typedef struct ToolState {
    HWND window;
    HWND content;
    int mode;
    RECT floating;
    int kind;
    int group;
    int order;
} ToolState;

typedef struct LayoutState {
    RECT main_bounds;
    int maximized;
    ToolState project;
    ToolState properties;
    ToolState output;
} LayoutState;

typedef struct AppState {
    HINSTANCE instance;
    HWND main_window;
    HWND document;
    HWND status;
    HMENU main_menu;
    HFONT ui_font;
    HACCEL accelerators;
    Config config;
    LayoutState layout;
    const wchar_t *result_path;
    const wchar_t *document_input_path;
    const wchar_t *document_output_path;
    const wchar_t *document_action_path;
    wchar_t *initial_document_text;
    int document_enabled;
    int document_result_written;
    int suppress_document_change;
    int verifying;
    int result_written;
    int exit_code;
} AppState;

static const wchar_t MAIN_CLASS[] = L"UBE.IDE.MainWindow.Step2";
static const wchar_t TOOL_CLASS[] = L"UBE.IDE.ToolWindow.Step2";

static int write_document_snapshot(AppState *app);
static int write_document_result(AppState *app, const wchar_t *action);
static int write_document_checkpoint(AppState *app);

static int controlled_failure(const wchar_t *detail, int code) {
    fwprintf(stderr, L"UBE IDE native shell: %ls (code %d)\n", detail, code);
    return code;
}

static int read_utf8_file(const wchar_t *path, wchar_t **text_out) {
    HANDLE file = CreateFileW(path, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING,
                              FILE_ATTRIBUTE_NORMAL | FILE_FLAG_SEQUENTIAL_SCAN, NULL);
    if (file == INVALID_HANDLE_VALUE) return 0;
    LARGE_INTEGER size;
    if (!GetFileSizeEx(file, &size) || size.QuadPart < 0 || size.QuadPart > IDE_MAX_FILE_BYTES) {
        CloseHandle(file);
        return 0;
    }
    DWORD bytes = (DWORD)size.QuadPart;
    char *raw = (char *)HeapAlloc(GetProcessHeap(), 0, (SIZE_T)bytes + 1u);
    if (!raw) {
        CloseHandle(file);
        return 0;
    }
    DWORD got = 0;
    int ok = ReadFile(file, raw, bytes, &got, NULL) && got == bytes;
    CloseHandle(file);
    if (!ok) {
        HeapFree(GetProcessHeap(), 0, raw);
        return 0;
    }
    raw[bytes] = 0;
    if (bytes >= 3 && (unsigned char)raw[0] == 0xef && (unsigned char)raw[1] == 0xbb &&
        (unsigned char)raw[2] == 0xbf) {
        HeapFree(GetProcessHeap(), 0, raw);
        return 0;
    }
    int wide_count = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, raw, (int)bytes, NULL, 0);
    if (bytes != 0 && wide_count <= 0) {
        HeapFree(GetProcessHeap(), 0, raw);
        return 0;
    }
    wchar_t *wide = (wchar_t *)HeapAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY,
                                         ((SIZE_T)wide_count + 1u) * sizeof(wchar_t));
    if (!wide) {
        HeapFree(GetProcessHeap(), 0, raw);
        return 0;
    }
    if (wide_count > 0 && MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, raw, (int)bytes,
                                               wide, wide_count) != wide_count) {
        HeapFree(GetProcessHeap(), 0, raw);
        HeapFree(GetProcessHeap(), 0, wide);
        return 0;
    }
    HeapFree(GetProcessHeap(), 0, raw);
    *text_out = wide;
    return 1;
}

static wchar_t *trim_left(wchar_t *text) {
    while (*text == L' ' || *text == L'\t') ++text;
    return text;
}

static void trim_right(wchar_t *text) {
    size_t length = wcslen(text);
    while (length > 0 && (text[length - 1] == L' ' || text[length - 1] == L'\t' ||
                          text[length - 1] == L'\r')) {
        text[--length] = 0;
    }
}

static int parse_assignment(wchar_t *line, ConfigEntry *entry) {
    wchar_t *equals = wcschr(line, L'=');
    if (!equals) return 0;
    *equals = 0;
    wchar_t *key = trim_left(line);
    trim_right(key);
    wchar_t *raw = trim_left(equals + 1);
    trim_right(raw);
    size_t key_length = wcslen(key);
    size_t raw_length = wcslen(raw);
    if (key_length == 0 || key_length >= IDE_MAX_KEY || raw_length < 2 ||
        raw[0] != L'"' || raw[raw_length - 1] != L'"') return 0;
    wcscpy_s(entry->key, IDE_MAX_KEY, key);
    size_t source = 1, target = 0;
    while (source + 1 < raw_length) {
        wchar_t ch = raw[source++];
        if (ch == L'"') {
            if (source + 1 > raw_length || raw[source] != L'"') return 0;
            ++source;
        }
        if (target + 1 >= IDE_MAX_VALUE) return 0;
        entry->value[target++] = ch;
    }
    entry->value[target] = 0;
    return 1;
}

static int parse_config(wchar_t *text, Config *config) {
    config->count = 0;
    wchar_t *context = NULL;
    wchar_t *line = wcstok_s(text, L"\n", &context);
    if (!line) return 0;
    trim_right(line);
    if (wcscmp(line, L"UBE-IDE-Shell 1") != 0) return 0;
    while ((line = wcstok_s(NULL, L"\n", &context)) != NULL) {
        line = trim_left(line);
        trim_right(line);
        if (*line == 0) continue;
        if (config->count >= IDE_MAX_ENTRIES) return 0;
        if (!parse_assignment(line, &config->entries[config->count])) return 0;
        for (int i = 0; i < config->count; ++i) {
            if (_wcsicmp(config->entries[i].key, config->entries[config->count].key) == 0)
                return 0;
        }
        ++config->count;
    }
    return 1;
}

static const wchar_t *config_get(const Config *config, const wchar_t *key) {
    for (int i = 0; i < config->count; ++i) {
        if (_wcsicmp(config->entries[i].key, key) == 0) return config->entries[i].value;
    }
    return NULL;
}

static int config_long(const Config *config, const wchar_t *key, long minimum, long maximum,
                       long *value_out) {
    const wchar_t *text = config_get(config, key);
    if (!text || !*text) return 0;
    wchar_t *end = NULL;
    long value = wcstol(text, &end, 10);
    if (!end || *end || value < minimum || value > maximum) return 0;
    *value_out = value;
    return 1;
}

static int load_tool_layout(const Config *config, const wchar_t *prefix, ToolState *tool) {
    wchar_t key[IDE_MAX_KEY];
#define READ_TOOL_LONG(name, low, high, destination)                                       \
    do {                                                                                   \
        _snwprintf_s(key, IDE_MAX_KEY, _TRUNCATE, L"%ls.%ls", prefix, L##name);          \
        if (!config_long(config, key, low, high, destination)) return 0;                   \
    } while (0)
    long mode = 0;
    READ_TOOL_LONG("Mode", 0, 3, &mode);
    tool->mode = (int)mode;
    READ_TOOL_LONG("Left", -100000, 100000, &tool->floating.left);
    READ_TOOL_LONG("Top", -100000, 100000, &tool->floating.top);
    long width = 0, height = 0;
    READ_TOOL_LONG("Width", 180, 8192, &width);
    READ_TOOL_LONG("Height", 120, 8192, &height);
    tool->floating.right = tool->floating.left + width;
    tool->floating.bottom = tool->floating.top + height;
    long group = 0, order = 0;
    READ_TOOL_LONG("Group", 0, 15, &group);
    READ_TOOL_LONG("Order", 0, 15, &order);
    tool->group = (int)group;
    tool->order = (int)order;
#undef READ_TOOL_LONG
    return 1;
}

static int load_layout(const Config *config, LayoutState *layout) {
    long width = 0, height = 0, maximized = 0;
    if (!config_long(config, L"Main.Left", -100000, 100000, &layout->main_bounds.left) ||
        !config_long(config, L"Main.Top", -100000, 100000, &layout->main_bounds.top) ||
        !config_long(config, L"Main.Width", 640, 8192, &width) ||
        !config_long(config, L"Main.Height", 480, 8192, &height) ||
        !config_long(config, L"Main.Maximized", 0, 1, &maximized)) return 0;
    layout->maximized = (int)maximized;
    layout->main_bounds.right = layout->main_bounds.left + width;
    layout->main_bounds.bottom = layout->main_bounds.top + height;
    layout->project.kind = 0;
    layout->properties.kind = 1;
    layout->output.kind = 2;
    return load_tool_layout(config, L"ProjectExplorer", &layout->project) &&
           load_tool_layout(config, L"Properties", &layout->properties) &&
           load_tool_layout(config, L"Output", &layout->output);
}

static int required_text_present(const Config *config) {
    static const wchar_t *keys[] = {
        L"Text.Shell.Title", L"Text.Menu.File", L"Text.Menu.Edit", L"Text.Menu.View",
        L"Text.Menu.Window", L"Text.Menu.Help", L"Text.Command.File.New",
        L"Text.Command.File.Open", L"Text.Command.File.Save", L"Text.Command.File.Exit",
        L"Text.Command.Edit.Undo", L"Text.Command.Edit.Redo",
        L"Text.Command.View.ProjectExplorer", L"Text.Command.View.Properties",
        L"Text.Command.View.Output", L"Text.Command.Window.FloatProjectExplorer",
        L"Text.Command.Window.DockProjectExplorer", L"Text.Command.Window.FloatProperties",
        L"Text.Command.Window.DockProperties", L"Text.Command.Window.FloatOutput",
        L"Text.Command.Window.DockOutput", L"Text.Command.Window.FocusNextPane",
        L"Text.Command.Window.ResetLayout", L"Text.Command.Help.About",
        L"Text.Tool.ProjectExplorer.Title", L"Text.Tool.Properties.Title",
        L"Text.Tool.Output.Title", L"Text.Document.Welcome.Title",
        L"Text.Document.Welcome.Text", L"Text.Status.Ready",
        L"Text.Shell.Placeholder.Project", L"Text.Shell.Placeholder.Properties",
        L"Text.Shell.Placeholder.Output"
    };
    for (size_t i = 0; i < sizeof(keys) / sizeof(keys[0]); ++i) {
        if (!config_get(config, keys[i])) return 0;
    }
    return 1;
}

static int rect_width(const RECT *rect) { return rect->right - rect->left; }
static int rect_height(const RECT *rect) { return rect->bottom - rect->top; }

static void repair_rect_to_monitor(RECT *rect, int minimum_width, int minimum_height) {
    int width = rect_width(rect);
    int height = rect_height(rect);
    if (width < minimum_width) width = minimum_width;
    if (height < minimum_height) height = minimum_height;
    HMONITOR monitor = MonitorFromRect(rect, MONITOR_DEFAULTTONEAREST);
    MONITORINFO info;
    ZeroMemory(&info, sizeof(info));
    info.cbSize = sizeof(info);
    if (!monitor || !GetMonitorInfoW(monitor, &info)) {
        info.rcWork.left = 0;
        info.rcWork.top = 0;
        info.rcWork.right = GetSystemMetrics(SM_CXSCREEN);
        info.rcWork.bottom = GetSystemMetrics(SM_CYSCREEN);
    }
    int work_width = rect_width(&info.rcWork);
    int work_height = rect_height(&info.rcWork);
    if (width > work_width) width = work_width;
    if (height > work_height) height = work_height;
    if (rect->left < info.rcWork.left) rect->left = info.rcWork.left;
    if (rect->top < info.rcWork.top) rect->top = info.rcWork.top;
    if (rect->left + width > info.rcWork.right) rect->left = info.rcWork.right - width;
    if (rect->top + height > info.rcWork.bottom) rect->top = info.rcWork.bottom - height;
    rect->right = rect->left + width;
    rect->bottom = rect->top + height;
}

typedef BOOL (WINAPI *SetDpiAwarenessContextFn)(DPI_AWARENESS_CONTEXT);
typedef UINT (WINAPI *GetDpiForWindowFn)(HWND);

static void enable_per_monitor_dpi(void) {
    HMODULE user32 = GetModuleHandleW(L"user32.dll");
    SetDpiAwarenessContextFn set_context = NULL;
    FARPROC procedure = user32 ? GetProcAddress(user32, "SetProcessDpiAwarenessContext") : NULL;
    if (procedure) memcpy(&set_context, &procedure, sizeof(set_context));
    if (set_context && set_context(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2)) return;
    SetProcessDPIAware();
}

static UINT window_dpi(HWND window) {
    HMODULE user32 = GetModuleHandleW(L"user32.dll");
    GetDpiForWindowFn get_dpi = NULL;
    FARPROC procedure = user32 ? GetProcAddress(user32, "GetDpiForWindow") : NULL;
    if (procedure) memcpy(&get_dpi, &procedure, sizeof(get_dpi));
    UINT dpi = get_dpi ? get_dpi(window) : 96u;
    return dpi ? dpi : 96u;
}

static void apply_font(HWND window, HFONT font) {
    if (window) SendMessageW(window, WM_SETFONT, (WPARAM)font, TRUE);
}

static HFONT create_ui_font(UINT dpi) {
    NONCLIENTMETRICSW metrics;
    ZeroMemory(&metrics, sizeof(metrics));
    metrics.cbSize = sizeof(metrics);
    if (SystemParametersInfoW(SPI_GETNONCLIENTMETRICS, sizeof(metrics), &metrics, 0)) {
        metrics.lfMessageFont.lfHeight = MulDiv(metrics.lfMessageFont.lfHeight, (int)dpi, 96);
        return CreateFontIndirectW(&metrics.lfMessageFont);
    }
    return (HFONT)GetStockObject(DEFAULT_GUI_FONT);
}

static ToolState *tool_from_window(HWND window) {
    return (ToolState *)GetWindowLongPtrW(window, GWLP_USERDATA);
}

static LRESULT CALLBACK tool_window_proc(HWND window, UINT message, WPARAM wparam, LPARAM lparam) {
    ToolState *tool = tool_from_window(window);
    if (message == WM_NCCREATE) {
        CREATESTRUCTW *create = (CREATESTRUCTW *)lparam;
        tool = (ToolState *)create->lpCreateParams;
        SetWindowLongPtrW(window, GWLP_USERDATA, (LONG_PTR)tool);
    }
    switch (message) {
        case WM_SIZE:
            if (tool && tool->content) {
                RECT client;
                GetClientRect(window, &client);
                MoveWindow(tool->content, 6, 6, max(0, rect_width(&client) - 12),
                           max(0, rect_height(&client) - 12), TRUE);
            }
            return 0;
        case WM_CLOSE:
            if (tool) {
                tool->mode = IDE_HIDDEN;
                ShowWindow(window, SW_HIDE);
                HWND owner = GetWindow(window, GW_OWNER);
                if (owner) PostMessageW(owner, WM_SIZE, 0, 0);
                return 0;
            }
            break;
        case WM_MOVE:
        case WM_EXITSIZEMOVE:
            if (tool && tool->mode == IDE_FLOATING && !IsIconic(window))
                GetWindowRect(window, &tool->floating);
            break;
        case WM_GETMINMAXINFO: {
            MINMAXINFO *limits = (MINMAXINFO *)lparam;
            limits->ptMinTrackSize.x = 180;
            limits->ptMinTrackSize.y = 120;
            return 0;
        }
    }
    return DefWindowProcW(window, message, wparam, lparam);
}

static const wchar_t *tool_title(const AppState *app, const ToolState *tool) {
    if (tool->kind == 0) return config_get(&app->config, L"Text.Tool.ProjectExplorer.Title");
    if (tool->kind == 1) return config_get(&app->config, L"Text.Tool.Properties.Title");
    return config_get(&app->config, L"Text.Tool.Output.Title");
}

static const wchar_t *tool_placeholder(const AppState *app, const ToolState *tool) {
    const wchar_t *workspace = NULL;
    if (tool->kind == 0) workspace = config_get(&app->config, L"Workspace.ProjectExplorer");
    else if (tool->kind == 1) workspace = config_get(&app->config, L"Workspace.Properties");
    else workspace = config_get(&app->config, L"Workspace.Output");
    if (workspace) return workspace;
    if (tool->kind == 0) return config_get(&app->config, L"Text.Shell.Placeholder.Project");
    if (tool->kind == 1) return config_get(&app->config, L"Text.Shell.Placeholder.Properties");
    return config_get(&app->config, L"Text.Shell.Placeholder.Output");
}

static int create_tool(AppState *app, ToolState *tool) {
    tool->window = CreateWindowExW(WS_EX_CONTROLPARENT, TOOL_CLASS, tool_title(app, tool),
                                   WS_CHILD | WS_CLIPSIBLINGS | WS_VISIBLE,
                                   0, 0, 100, 100, app->main_window, NULL, app->instance, tool);
    if (!tool->window) return 0;
    tool->content = CreateWindowExW(WS_EX_CLIENTEDGE, L"EDIT", tool_placeholder(app, tool),
                                    WS_CHILD | WS_VISIBLE | WS_TABSTOP | ES_MULTILINE |
                                    ES_AUTOVSCROLL | ES_READONLY | WS_VSCROLL,
                                    0, 0, 10, 10, tool->window, NULL, app->instance, NULL);
    if (!tool->content) return 0;
    apply_font(tool->content, app->ui_font);
    return 1;
}

static void set_tool_mode(AppState *app, ToolState *tool, int mode) {
    if (!tool->window) return;
    tool->mode = mode;
    if (mode == IDE_FLOATING) {
        RECT bounds = tool->floating;
        repair_rect_to_monitor(&bounds, 180, 120);
        tool->floating = bounds;
        ShowWindow(tool->window, SW_HIDE);
        SetParent(tool->window, NULL);
        SetWindowLongPtrW(tool->window, GWLP_HWNDPARENT, (LONG_PTR)app->main_window);
        SetWindowLongPtrW(tool->window, GWL_STYLE,
                          WS_OVERLAPPEDWINDOW | WS_CLIPCHILDREN | WS_CLIPSIBLINGS);
        SetWindowPos(tool->window, NULL, bounds.left, bounds.top, rect_width(&bounds),
                     rect_height(&bounds), SWP_FRAMECHANGED | SWP_NOZORDER | SWP_NOACTIVATE);
        ShowWindow(tool->window, app->verifying ? SW_HIDE : SW_SHOWNOACTIVATE);
    } else if (mode == IDE_DOCKED) {
        ShowWindow(tool->window, SW_HIDE);
        SetWindowLongPtrW(tool->window, GWLP_HWNDPARENT, 0);
        SetParent(tool->window, app->main_window);
        SetWindowLongPtrW(tool->window, GWL_STYLE,
                          WS_CHILD | WS_VISIBLE | WS_CLIPCHILDREN | WS_CLIPSIBLINGS);
        SetWindowPos(tool->window, NULL, 0, 0, 100, 100,
                     SWP_FRAMECHANGED | SWP_NOZORDER | SWP_NOACTIVATE);
        ShowWindow(tool->window, SW_SHOWNA);
    } else {
        ShowWindow(tool->window, SW_HIDE);
    }
    PostMessageW(app->main_window, WM_SIZE, 0, 0);
}

static void layout_children(AppState *app) {
    RECT client;
    GetClientRect(app->main_window, &client);
    UINT dpi = window_dpi(app->main_window);
    int gap = MulDiv(4, (int)dpi, 96);
    int status_height = MulDiv(24, (int)dpi, 96);
    int right_width = MulDiv(286, (int)dpi, 96);
    int output_height = MulDiv(190, (int)dpi, 96);
    int available_width = max(1, rect_width(&client));
    int available_height = max(1, rect_height(&client) - status_height);
    if (right_width > available_width / 2) right_width = available_width / 2;
    if (output_height > available_height / 2) output_height = available_height / 2;
    int has_right = app->layout.project.mode == IDE_DOCKED ||
                    app->layout.properties.mode == IDE_DOCKED;
    int has_output = app->layout.output.mode == IDE_DOCKED;
    int document_right = client.right - (has_right ? right_width + gap : 0);
    int document_bottom = client.bottom - status_height - (has_output ? output_height + gap : 0);
    MoveWindow(app->document, client.left, client.top, max(1, document_right - client.left),
               max(1, document_bottom - client.top), TRUE);
    MoveWindow(app->status, client.left, client.bottom - status_height, available_width,
               status_height, TRUE);
    if (has_right) {
        int right_left = document_right + gap;
        int right_height = document_bottom - client.top;
        int project_height = app->layout.project.mode == IDE_DOCKED &&
                             app->layout.properties.mode == IDE_DOCKED ?
                             (right_height - gap) / 2 : right_height;
        if (app->layout.project.mode == IDE_DOCKED)
            MoveWindow(app->layout.project.window, right_left, client.top, right_width,
                       max(1, project_height), TRUE);
        if (app->layout.properties.mode == IDE_DOCKED) {
            int top = app->layout.project.mode == IDE_DOCKED ? client.top + project_height + gap : client.top;
            MoveWindow(app->layout.properties.window, right_left, top, right_width,
                       max(1, document_bottom - top), TRUE);
        }
    }
    if (has_output)
        MoveWindow(app->layout.output.window, client.left, document_bottom + gap,
                   max(1, document_right - client.left), output_height, TRUE);
}

static HMENU make_menu(AppState *app) {
    HMENU bar = CreateMenu();
    HMENU file = CreatePopupMenu(), edit = CreatePopupMenu(), view = CreatePopupMenu();
    HMENU window = CreatePopupMenu(), help = CreatePopupMenu();
    if (!bar || !file || !edit || !view || !window || !help) return NULL;
#define ADD(menu, flags, id, key) AppendMenuW(menu, flags, id, config_get(&app->config, key))
    ADD(file, MF_STRING, CMD_FILE_NEW, L"Text.Command.File.New");
    ADD(file, MF_STRING, CMD_FILE_OPEN, L"Text.Command.File.Open");
    ADD(file, MF_STRING, CMD_FILE_SAVE, L"Text.Command.File.Save");
    AppendMenuW(file, MF_SEPARATOR, 0, NULL);
    ADD(file, MF_STRING, CMD_FILE_EXIT, L"Text.Command.File.Exit");
    ADD(edit, MF_STRING, CMD_EDIT_UNDO, L"Text.Command.Edit.Undo");
    ADD(edit, MF_STRING, CMD_EDIT_REDO, L"Text.Command.Edit.Redo");
    ADD(view, MF_STRING, CMD_VIEW_PROJECT, L"Text.Command.View.ProjectExplorer");
    ADD(view, MF_STRING, CMD_VIEW_PROPERTIES, L"Text.Command.View.Properties");
    ADD(view, MF_STRING, CMD_VIEW_OUTPUT, L"Text.Command.View.Output");
    ADD(window, MF_STRING, CMD_FLOAT_PROJECT, L"Text.Command.Window.FloatProjectExplorer");
    ADD(window, MF_STRING, CMD_DOCK_PROJECT, L"Text.Command.Window.DockProjectExplorer");
    AppendMenuW(window, MF_SEPARATOR, 0, NULL);
    ADD(window, MF_STRING, CMD_FLOAT_PROPERTIES, L"Text.Command.Window.FloatProperties");
    ADD(window, MF_STRING, CMD_DOCK_PROPERTIES, L"Text.Command.Window.DockProperties");
    AppendMenuW(window, MF_SEPARATOR, 0, NULL);
    ADD(window, MF_STRING, CMD_FLOAT_OUTPUT, L"Text.Command.Window.FloatOutput");
    ADD(window, MF_STRING, CMD_DOCK_OUTPUT, L"Text.Command.Window.DockOutput");
    AppendMenuW(window, MF_SEPARATOR, 0, NULL);
    ADD(window, MF_STRING, CMD_FOCUS_NEXT, L"Text.Command.Window.FocusNextPane");
    ADD(window, MF_STRING, CMD_RESET_LAYOUT, L"Text.Command.Window.ResetLayout");
    ADD(help, MF_STRING, CMD_HELP_ABOUT, L"Text.Command.Help.About");
    AppendMenuW(bar, MF_POPUP, (UINT_PTR)file, config_get(&app->config, L"Text.Menu.File"));
    AppendMenuW(bar, MF_POPUP, (UINT_PTR)edit, config_get(&app->config, L"Text.Menu.Edit"));
    AppendMenuW(bar, MF_POPUP, (UINT_PTR)view, config_get(&app->config, L"Text.Menu.View"));
    AppendMenuW(bar, MF_POPUP, (UINT_PTR)window, config_get(&app->config, L"Text.Menu.Window"));
    AppendMenuW(bar, MF_POPUP, (UINT_PTR)help, config_get(&app->config, L"Text.Menu.Help"));
#undef ADD
    return bar;
}

static ToolState *tool_for_view_command(AppState *app, int command) {
    if (command == CMD_VIEW_PROJECT) return &app->layout.project;
    if (command == CMD_VIEW_PROPERTIES) return &app->layout.properties;
    return &app->layout.output;
}

static int focus_candidate_available(AppState *app, HWND candidate) {
    if (candidate == app->document) return 1;
    if (candidate == app->layout.project.content) return app->layout.project.mode < IDE_HIDDEN;
    if (candidate == app->layout.properties.content) return app->layout.properties.mode < IDE_HIDDEN;
    if (candidate == app->layout.output.content) return app->layout.output.mode < IDE_HIDDEN;
    return 0;
}

static HWND focus_window_after(AppState *app, HWND focused) {
    HWND candidates[] = {app->document, app->layout.project.content,
                         app->layout.properties.content, app->layout.output.content};
    int count = (int)(sizeof(candidates) / sizeof(candidates[0]));
    int current = -1;
    for (int i = 0; i < count; ++i) if (focused == candidates[i]) current = i;
    for (int offset = 1; offset <= count; ++offset) {
        int index = (current + offset) % count;
        HWND candidate = candidates[index];
        if (candidate && focus_candidate_available(app, candidate)) return candidate;
    }
    return app->document;
}

static HWND next_focus_window(AppState *app) {
    return focus_window_after(app, GetFocus());
}

static void reset_layout(AppState *app) {
    app->layout.main_bounds.left = 80;
    app->layout.main_bounds.top = 60;
    app->layout.main_bounds.right = 1360;
    app->layout.main_bounds.bottom = 860;
    app->layout.maximized = 0;
    app->layout.project.floating = (RECT){880, 100, 1200, 460};
    app->layout.properties.floating = (RECT){900, 470, 1200, 770};
    app->layout.output.floating = (RECT){180, 560, 980, 780};
    app->layout.project.group = 1;
    app->layout.project.order = 0;
    app->layout.properties.group = 1;
    app->layout.properties.order = 1;
    app->layout.output.group = 2;
    app->layout.output.order = 0;
    set_tool_mode(app, &app->layout.project, IDE_DOCKED);
    set_tool_mode(app, &app->layout.properties, IDE_DOCKED);
    set_tool_mode(app, &app->layout.output, IDE_DOCKED);
    SetWindowPos(app->main_window, NULL, 80, 60, 1280, 800,
                 SWP_NOZORDER | SWP_NOACTIVATE);
}

static void route_command(AppState *app, int command) {
    switch (command) {
        case CMD_FILE_SAVE:
            if (app->document_enabled) {
                if (!write_document_result(app, L"Save")) {
                    app->exit_code = 22;
                    return;
                }
                PostMessageW(app->main_window, WM_CLOSE, 1, 0);
                return;
            }
            break;
        case CMD_EDIT_UNDO:
            if (app->document_enabled) SendMessageW(app->document, EM_UNDO, 0, 0);
            return;
        case CMD_EDIT_REDO:
            if (app->document_enabled) SendMessageW(app->document, EM_UNDO, 0, 0);
            return;
        case CMD_FILE_EXIT: PostMessageW(app->main_window, WM_CLOSE, 0, 0); return;
        case CMD_VIEW_PROJECT:
        case CMD_VIEW_PROPERTIES:
        case CMD_VIEW_OUTPUT: {
            ToolState *tool = tool_for_view_command(app, command);
            set_tool_mode(app, tool, tool->mode == IDE_HIDDEN ? IDE_DOCKED : IDE_HIDDEN);
            return;
        }
        case CMD_FLOAT_PROJECT: set_tool_mode(app, &app->layout.project, IDE_FLOATING); return;
        case CMD_DOCK_PROJECT: set_tool_mode(app, &app->layout.project, IDE_DOCKED); return;
        case CMD_FLOAT_PROPERTIES: set_tool_mode(app, &app->layout.properties, IDE_FLOATING); return;
        case CMD_DOCK_PROPERTIES: set_tool_mode(app, &app->layout.properties, IDE_DOCKED); return;
        case CMD_FLOAT_OUTPUT: set_tool_mode(app, &app->layout.output, IDE_FLOATING); return;
        case CMD_DOCK_OUTPUT: set_tool_mode(app, &app->layout.output, IDE_DOCKED); return;
        case CMD_FOCUS_NEXT: SetFocus(next_focus_window(app)); return;
        case CMD_RESET_LAYOUT: reset_layout(app); return;
        case CMD_HELP_ABOUT:
            MessageBoxW(app->main_window, config_get(&app->config, L"Text.Document.Welcome.Text"),
                        config_get(&app->config, L"Text.Shell.Title"), MB_OK | MB_ICONINFORMATION);
            return;
        default: {
            wchar_t label[IDE_MAX_VALUE] = L"";
            GetMenuStringW(app->main_menu, (UINT)command, label, IDE_MAX_VALUE, MF_BYCOMMAND);
            if (*label) SetWindowTextW(app->status, label);
            return;
        }
    }
}

static void capture_main_layout(AppState *app) {
    if (!IsIconic(app->main_window) && !IsZoomed(app->main_window))
        GetWindowRect(app->main_window, &app->layout.main_bounds);
    app->layout.maximized = IsZoomed(app->main_window) ? 1 : 0;
    ToolState *tools[] = {&app->layout.project, &app->layout.properties, &app->layout.output};
    for (int i = 0; i < 3; ++i) {
        if (tools[i]->mode == IDE_FLOATING && !IsIconic(tools[i]->window))
            GetWindowRect(tools[i]->window, &tools[i]->floating);
    }
}

static int append_utf8(HANDLE file, const wchar_t *text) {
    int bytes = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, text, -1, NULL, 0, NULL, NULL);
    if (bytes <= 0) return 0;
    if ((size_t)(bytes - 1) > IDE_MAX_FILE_BYTES) return 0;
    if (bytes == 1) return 1;
    char *buffer = (char *)HeapAlloc(GetProcessHeap(), 0, (SIZE_T)bytes);
    if (!buffer) return 0;
    int converted = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, text, -1,
                                        buffer, bytes, NULL, NULL);
    DWORD written = 0;
    int ok = converted == bytes && WriteFile(file, buffer, (DWORD)(bytes - 1), &written, NULL) &&
             written == (DWORD)(bytes - 1);
    HeapFree(GetProcessHeap(), 0, buffer);
    return ok;
}

static int write_utf8_atomic(const wchar_t *path, const wchar_t *text) {
    if (!path || !*path || !text) return 0;
    size_t path_length = wcslen(path);
    if (path_length > 30000) return 0;
    wchar_t *temporary = (wchar_t *)HeapAlloc(GetProcessHeap(), 0,
                                               (path_length + 32u) * sizeof(wchar_t));
    if (!temporary) return 0;
    _snwprintf_s(temporary, path_length + 32u, _TRUNCATE, L"%ls.tmp.%lu", path,
                 (unsigned long)GetCurrentProcessId());
    HANDLE file = CreateFileW(temporary, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS,
                              FILE_ATTRIBUTE_NORMAL, NULL);
    if (file == INVALID_HANDLE_VALUE) {
        HeapFree(GetProcessHeap(), 0, temporary);
        return 0;
    }
    int ok = append_utf8(file, text) && FlushFileBuffers(file);
    if (!CloseHandle(file)) ok = 0;
    if (ok) ok = MoveFileExW(temporary, path,
                              MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH);
    if (!ok) DeleteFileW(temporary);
    HeapFree(GetProcessHeap(), 0, temporary);
    return ok;
}

static wchar_t *document_text(AppState *app) {
    if (!app || !app->document) return NULL;
    int length = GetWindowTextLengthW(app->document);
    if (length < 0 || (size_t)length > IDE_MAX_FILE_BYTES) return NULL;
    wchar_t *text = (wchar_t *)HeapAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY,
                                         ((size_t)length + 1u) * sizeof(wchar_t));
    if (!text) return NULL;
    if (GetWindowTextW(app->document, text, length + 1) != length) {
        HeapFree(GetProcessHeap(), 0, text);
        return NULL;
    }
    return text;
}

static int write_document_snapshot(AppState *app) {
    if (!app || !app->document_enabled || !app->document_output_path) return 0;
    wchar_t *text = document_text(app);
    if (!text) return 0;
    int ok = write_utf8_atomic(app->document_output_path, text);
    HeapFree(GetProcessHeap(), 0, text);
    return ok;
}

static int write_document_result(AppState *app, const wchar_t *action) {
    if (!write_document_snapshot(app)) return 0;
    const wchar_t *stable_id = config_get(&app->config, L"Document.StableId");
    const wchar_t *base_version = config_get(&app->config, L"Document.BaseVersion");
    if (!stable_id || !base_version || !action) return 0;
    wchar_t result[512];
    int count = _snwprintf_s(result, sizeof(result) / sizeof(result[0]), _TRUNCATE,
        L"UBE-IDE-Document-Session 1\nStableId = \"%ls\"\nBaseVersion = \"%ls\"\nAction = \"%ls\"\n",
        stable_id, base_version, action);
    if (count <= 0 || !write_utf8_atomic(app->document_action_path, result)) return 0;
    app->document_result_written = 1;
    return 1;
}

static int write_document_checkpoint(AppState *app) {
    if (!write_document_result(app, L"Recover")) return 0;
    app->document_result_written = 0;
    return 1;
}

static int write_layout_atomic(AppState *app) {
    capture_main_layout(app);
    size_t path_length = wcslen(app->result_path);
    if (path_length > 30000) return 0;
    wchar_t *temporary = (wchar_t *)HeapAlloc(GetProcessHeap(), 0,
                                               (path_length + 16) * sizeof(wchar_t));
    if (!temporary) return 0;
    wcscpy_s(temporary, path_length + 16, app->result_path);
    wcscat_s(temporary, path_length + 16, L".tmp");
    HANDLE file = CreateFileW(temporary, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS,
                              FILE_ATTRIBUTE_NORMAL, NULL);
    if (file == INVALID_HANDLE_VALUE) {
        HeapFree(GetProcessHeap(), 0, temporary);
        return 0;
    }
    wchar_t output[4096];
    _snwprintf_s(output, sizeof(output) / sizeof(output[0]), _TRUNCATE,
        L"UBE-IDE-Layout 1\n"
        L"Main.Left = \"%ld\"\nMain.Top = \"%ld\"\nMain.Width = \"%ld\"\nMain.Height = \"%ld\"\nMain.Maximized = \"%d\"\n"
        L"ProjectExplorer.Mode = \"%d\"\nProjectExplorer.Left = \"%ld\"\nProjectExplorer.Top = \"%ld\"\nProjectExplorer.Width = \"%ld\"\nProjectExplorer.Height = \"%ld\"\n"
        L"Properties.Mode = \"%d\"\nProperties.Left = \"%ld\"\nProperties.Top = \"%ld\"\nProperties.Width = \"%ld\"\nProperties.Height = \"%ld\"\n"
        L"Output.Mode = \"%d\"\nOutput.Left = \"%ld\"\nOutput.Top = \"%ld\"\nOutput.Width = \"%ld\"\nOutput.Height = \"%ld\"\n"
        L"ProjectExplorer.Group = \"%d\"\nProjectExplorer.Order = \"%d\"\n"
        L"Properties.Group = \"%d\"\nProperties.Order = \"%d\"\n"
        L"Output.Group = \"%d\"\nOutput.Order = \"%d\"\n",
        app->layout.main_bounds.left, app->layout.main_bounds.top,
        (long)rect_width(&app->layout.main_bounds), (long)rect_height(&app->layout.main_bounds),
        app->layout.maximized,
        app->layout.project.mode, app->layout.project.floating.left, app->layout.project.floating.top,
        (long)rect_width(&app->layout.project.floating), (long)rect_height(&app->layout.project.floating),
        app->layout.properties.mode, app->layout.properties.floating.left, app->layout.properties.floating.top,
        (long)rect_width(&app->layout.properties.floating), (long)rect_height(&app->layout.properties.floating),
        app->layout.output.mode, app->layout.output.floating.left, app->layout.output.floating.top,
        (long)rect_width(&app->layout.output.floating), (long)rect_height(&app->layout.output.floating),
        app->layout.project.group, app->layout.project.order,
        app->layout.properties.group, app->layout.properties.order,
        app->layout.output.group, app->layout.output.order);
    int ok = append_utf8(file, output) && FlushFileBuffers(file);
    CloseHandle(file);
    if (ok) ok = MoveFileExW(temporary, app->result_path,
                              MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH);
    if (!ok) DeleteFileW(temporary);
    HeapFree(GetProcessHeap(), 0, temporary);
    app->result_written = ok;
    return ok;
}

static LRESULT CALLBACK main_window_proc(HWND window, UINT message, WPARAM wparam, LPARAM lparam) {
    AppState *app = (AppState *)GetWindowLongPtrW(window, GWLP_USERDATA);
    if (message == WM_NCCREATE) {
        CREATESTRUCTW *create = (CREATESTRUCTW *)lparam;
        app = (AppState *)create->lpCreateParams;
        SetWindowLongPtrW(window, GWLP_USERDATA, (LONG_PTR)app);
    }
    switch (message) {
        case WM_COMMAND:
            if (app && app->document_enabled && LOWORD(wparam) == CONTROL_DOCUMENT &&
                HIWORD(wparam) == EN_CHANGE && !app->suppress_document_change) {
                if (!write_document_checkpoint(app)) app->exit_code = 23;
                return 0;
            }
            if (app) route_command(app, LOWORD(wparam));
            return 0;
        case WM_SIZE:
            if (app && app->document) layout_children(app);
            return 0;
        case WM_DPICHANGED:
            if (app) {
                RECT *suggested = (RECT *)lparam;
                SetWindowPos(window, NULL, suggested->left, suggested->top,
                             rect_width(suggested), rect_height(suggested),
                             SWP_NOZORDER | SWP_NOACTIVATE);
                HFONT replacement = create_ui_font(HIWORD(wparam));
                if (replacement) {
                    HFONT old = app->ui_font;
                    app->ui_font = replacement;
                    apply_font(app->document, replacement);
                    apply_font(app->status, replacement);
                    apply_font(app->layout.project.content, replacement);
                    apply_font(app->layout.properties.content, replacement);
                    apply_font(app->layout.output.content, replacement);
                    if (old && old != GetStockObject(DEFAULT_GUI_FONT)) DeleteObject(old);
                }
            }
            return 0;
        case WM_GETMINMAXINFO: {
            MINMAXINFO *limits = (MINMAXINFO *)lparam;
            limits->ptMinTrackSize.x = 640;
            limits->ptMinTrackSize.y = 480;
            return 0;
        }
        case WM_CLOSE:
            if (app && app->document_enabled && !app->document_result_written) {
                const wchar_t *action = L"Close";
                if (SendMessageW(app->document, EM_GETMODIFY, 0, 0)) {
                    if (wparam == 1) {
                        action = L"Save";
                    } else if (app->verifying) {
                        action = L"Save";
                    } else {
                        int choice = MessageBoxW(window,
                            config_get(&app->config, L"Text.Prompt.CloseDirty.Message"),
                            config_get(&app->config, L"Text.Prompt.CloseDirty.Title"),
                            MB_YESNOCANCEL | MB_ICONWARNING);
                        if (choice == IDCANCEL) return 0;
                        action = choice == IDYES ? L"Save" : L"Discard";
                    }
                }
                if (!write_document_result(app, action)) {
                    app->exit_code = 22;
                    return 0;
                }
            }
            if (app && !write_layout_atomic(app)) app->exit_code = 20;
            DestroyWindow(window);
            return 0;
        case WM_DESTROY:
            PostQuitMessage(app ? app->exit_code : 1);
            return 0;
    }
    return DefWindowProcW(window, message, wparam, lparam);
}

static int register_classes(AppState *app) {
    WNDCLASSEXW main_class;
    ZeroMemory(&main_class, sizeof(main_class));
    main_class.cbSize = sizeof(main_class);
    main_class.hInstance = app->instance;
    main_class.lpfnWndProc = main_window_proc;
    main_class.lpszClassName = MAIN_CLASS;
    main_class.hCursor = LoadCursorW(NULL, IDC_ARROW);
    main_class.hIcon = LoadIconW(NULL, IDI_APPLICATION);
    main_class.hbrBackground = (HBRUSH)(COLOR_APPWORKSPACE + 1);
    if (!RegisterClassExW(&main_class) && GetLastError() != ERROR_CLASS_ALREADY_EXISTS) return 0;
    WNDCLASSEXW tool_class = main_class;
    tool_class.lpfnWndProc = tool_window_proc;
    tool_class.lpszClassName = TOOL_CLASS;
    tool_class.hbrBackground = (HBRUSH)(COLOR_BTNFACE + 1);
    return RegisterClassExW(&tool_class) || GetLastError() == ERROR_CLASS_ALREADY_EXISTS;
}

static int create_document_view(AppState *app, const wchar_t *text, int modified) {
    DWORD style = WS_CHILD | WS_VISIBLE | WS_TABSTOP | ES_MULTILINE | ES_AUTOVSCROLL |
                  ES_WANTRETURN | WS_VSCROLL;
    if (!app->document_enabled) style |= ES_READONLY;
    app->suppress_document_change = 1;
    app->document = CreateWindowExW(WS_EX_CLIENTEDGE, L"EDIT", text ? text : L"",
        style, 0, 0, 100, 100, app->main_window,
        (HMENU)(INT_PTR)CONTROL_DOCUMENT, app->instance, NULL);
    app->suppress_document_change = 0;
    if (!app->document) return 0;
    SendMessageW(app->document, EM_LIMITTEXT, IDE_MAX_FILE_BYTES, 0);
    SendMessageW(app->document, EM_SETMODIFY, modified ? TRUE : FALSE, 0);
    apply_font(app->document, app->ui_font);
    return 1;
}

static int create_application_windows(AppState *app) {
    repair_rect_to_monitor(&app->layout.main_bounds, 640, 480);
    app->main_window = CreateWindowExW(WS_EX_CONTROLPARENT, MAIN_CLASS,
        config_get(&app->config, L"Text.Shell.Title"), WS_OVERLAPPEDWINDOW | WS_CLIPCHILDREN,
        app->layout.main_bounds.left, app->layout.main_bounds.top,
        rect_width(&app->layout.main_bounds), rect_height(&app->layout.main_bounds),
        NULL, NULL, app->instance, app);
    if (!app->main_window) return 0;
    app->ui_font = create_ui_font(window_dpi(app->main_window));
    app->main_menu = make_menu(app);
    if (!app->main_menu || !SetMenu(app->main_window, app->main_menu)) return 0;
    const wchar_t *document_text_value = app->document_enabled
        ? app->initial_document_text
        : config_get(&app->config, L"Text.Document.Welcome.Text");
    if (!create_document_view(app, document_text_value, 0)) return 0;
    app->status = CreateWindowExW(0, L"STATIC", config_get(&app->config, L"Text.Status.Ready"),
        WS_CHILD | WS_VISIBLE | SS_LEFT | SS_CENTERIMAGE, 0, 0, 100, 24,
        app->main_window, NULL, app->instance, NULL);
    if (!app->status) return 0;
    apply_font(app->status, app->ui_font);
    if (!create_tool(app, &app->layout.project) || !create_tool(app, &app->layout.properties) ||
        !create_tool(app, &app->layout.output)) return 0;
    int project_mode = app->layout.project.mode;
    int properties_mode = app->layout.properties.mode;
    int output_mode = app->layout.output.mode;
    set_tool_mode(app, &app->layout.project, project_mode);
    set_tool_mode(app, &app->layout.properties, properties_mode);
    set_tool_mode(app, &app->layout.output, output_mode);
    ACCEL keys[] = {
        {FVIRTKEY | FCONTROL, 'N', CMD_FILE_NEW}, {FVIRTKEY | FCONTROL, 'O', CMD_FILE_OPEN},
        {FVIRTKEY | FCONTROL, 'S', CMD_FILE_SAVE}, {FVIRTKEY | FCONTROL, 'Z', CMD_EDIT_UNDO},
        {FVIRTKEY | FCONTROL, 'Y', CMD_EDIT_REDO}, {FVIRTKEY, VK_F6, CMD_FOCUS_NEXT},
        {FVIRTKEY | FCONTROL | FSHIFT, 'R', CMD_RESET_LAYOUT}
    };
    app->accelerators = CreateAcceleratorTableW(keys, sizeof(keys) / sizeof(keys[0]));
    if (!app->accelerators) return 0;
    layout_children(app);
    return 1;
}

static int verify_document_view(AppState *app) {
    if (!app->document_enabled || !app->initial_document_text) return 0;
    if (GetWindowLongPtrW(app->document, GWL_STYLE) & ES_READONLY) return 50;
    static const wchar_t edit_text[] = L"\r\n' Step 3 native document edit";
    SendMessageW(app->document, EM_SETSEL, (WPARAM)-1, (LPARAM)-1);
    SendMessageW(app->document, EM_REPLACESEL, TRUE, (LPARAM)edit_text);
    if (!SendMessageW(app->document, EM_GETMODIFY, 0, 0)) return 51;
    wchar_t *edited = document_text(app);
    if (!edited || !wcsstr(edited, L"Step 3 native document edit")) {
        if (edited) HeapFree(GetProcessHeap(), 0, edited);
        return 52;
    }
    if (!SendMessageW(app->document, EM_CANUNDO, 0, 0) ||
        !SendMessageW(app->document, EM_UNDO, 0, 0)) {
        HeapFree(GetProcessHeap(), 0, edited);
        return 53;
    }
    wchar_t *undone = document_text(app);
    if (!undone || wcsstr(undone, L"Step 3 native document edit")) {
        if (undone) HeapFree(GetProcessHeap(), 0, undone);
        HeapFree(GetProcessHeap(), 0, edited);
        return 54;
    }
    if (!SendMessageW(app->document, EM_UNDO, 0, 0)) {
        HeapFree(GetProcessHeap(), 0, undone);
        HeapFree(GetProcessHeap(), 0, edited);
        return 55;
    }
    wchar_t *redone = document_text(app);
    if (!redone || !wcsstr(redone, L"Step 3 native document edit")) {
        if (redone) HeapFree(GetProcessHeap(), 0, redone);
        HeapFree(GetProcessHeap(), 0, undone);
        HeapFree(GetProcessHeap(), 0, edited);
        return 56;
    }
    DestroyWindow(app->document);
    app->document = NULL;
    if (!create_document_view(app, redone, 1)) {
        HeapFree(GetProcessHeap(), 0, redone);
        HeapFree(GetProcessHeap(), 0, undone);
        HeapFree(GetProcessHeap(), 0, edited);
        return 57;
    }
    layout_children(app);
    wchar_t *recreated = document_text(app);
    int preserved = recreated && wcscmp(recreated, redone) == 0;
    if (recreated) HeapFree(GetProcessHeap(), 0, recreated);
    HeapFree(GetProcessHeap(), 0, redone);
    HeapFree(GetProcessHeap(), 0, undone);
    HeapFree(GetProcessHeap(), 0, edited);
    if (!preserved) return 58;
    if (!write_document_result(app, L"Save")) return 59;
    return 0;
}

static int verify_workspace(AppState *app) {
    const wchar_t *project_text = config_get(&app->config, L"Workspace.ProjectExplorer");
    const wchar_t *properties_text = config_get(&app->config, L"Workspace.Properties");
    const wchar_t *output_text = config_get(&app->config, L"Workspace.Output");
    if (!project_text || !properties_text || !output_text || !app->initial_document_text)
        return 60;
    wchar_t actual[IDE_MAX_VALUE];
    if (!GetWindowTextW(app->layout.project.content, actual, IDE_MAX_VALUE) ||
        wcscmp(actual, project_text) != 0) return 61;
    if (!GetWindowTextW(app->layout.properties.content, actual, IDE_MAX_VALUE) ||
        wcscmp(actual, properties_text) != 0) return 62;
    if (!GetWindowTextW(app->layout.output.content, actual, IDE_MAX_VALUE) ||
        wcscmp(actual, output_text) != 0) return 63;
    wchar_t *source_before = document_text(app);
    if (!source_before || wcscmp(source_before, app->initial_document_text) != 0) {
        if (source_before) HeapFree(GetProcessHeap(), 0, source_before);
        return 64;
    }
    HeapFree(GetProcessHeap(), 0, source_before);

    int restored_custom = app->layout.project.mode == IDE_FLOATING &&
        app->layout.properties.mode == IDE_HIDDEN &&
        app->layout.output.mode == IDE_AUTO_HIDDEN &&
        app->layout.output.group == app->layout.project.group;
    if (!restored_custom) {
        app->layout.project.floating = (RECT){220, 140, 650, 500};
        set_tool_mode(app, &app->layout.project, IDE_FLOATING);
        set_tool_mode(app, &app->layout.properties, IDE_HIDDEN);
        set_tool_mode(app, &app->layout.output, IDE_AUTO_HIDDEN);
        app->layout.output.group = app->layout.project.group;
        app->layout.output.order = 2;
        if (focus_window_after(app, app->layout.project.content) != app->document) return 65;
    } else {
        reset_layout(app);
        if (app->layout.project.mode != IDE_DOCKED ||
            app->layout.properties.mode != IDE_DOCKED ||
            app->layout.output.mode != IDE_DOCKED ||
            app->layout.output.group == app->layout.project.group) return 66;
    }
    wchar_t *source_after = document_text(app);
    int unchanged = source_after && wcscmp(source_after, app->initial_document_text) == 0;
    if (source_after) HeapFree(GetProcessHeap(), 0, source_after);
    if (!unchanged) return 67;
    if (!write_document_result(app, L"Close")) return 68;
    if (!write_layout_atomic(app)) return 69;
    app->exit_code = 0;
    DestroyWindow(app->main_window);
    return 0;
}

static int verify_shell(AppState *app) {
    if (config_get(&app->config, L"Workspace.Enabled")) return verify_workspace(app);
    RECT main_before = app->layout.main_bounds;
    if (!app->main_window || !app->document || !app->layout.project.window ||
        !app->layout.properties.window || !app->layout.output.window) return 30;
    if (GetMenuItemCount(app->main_menu) != 5) return 31;
    RECT document_rect, project_rect, properties_rect, output_rect;
    GetWindowRect(app->document, &document_rect);
    GetWindowRect(app->layout.project.window, &project_rect);
    GetWindowRect(app->layout.properties.window, &properties_rect);
    GetWindowRect(app->layout.output.window, &output_rect);
    if ((app->layout.project.mode == IDE_DOCKED && project_rect.left < document_rect.right) ||
        (app->layout.properties.mode == IDE_DOCKED && properties_rect.left < document_rect.right) ||
        (app->layout.output.mode == IDE_DOCKED && output_rect.top < document_rect.bottom)) return 32;
    if (app->layout.project.mode == IDE_FLOATING &&
        !MonitorFromWindow(app->layout.project.window, MONITOR_DEFAULTTONULL)) return 43;
    route_command(app, CMD_FLOAT_PROJECT);
    LONG_PTR style = GetWindowLongPtrW(app->layout.project.window, GWL_STYLE);
    if (app->layout.project.mode != IDE_FLOATING || (style & WS_CHILD)) return 33;
    route_command(app, CMD_DOCK_PROJECT);
    style = GetWindowLongPtrW(app->layout.project.window, GWL_STYLE);
    if (app->layout.project.mode != IDE_DOCKED || !(style & WS_CHILD)) return 34;
    RECT lost = {-90000, -90000, -89600, -89700};
    repair_rect_to_monitor(&lost, 180, 120);
    HMONITOR repaired_monitor = MonitorFromRect(&lost, MONITOR_DEFAULTTONULL);
    if (!repaired_monitor) return 35;
    if (window_dpi(app->main_window) < 96) return 36;
    IAccessible *accessible = NULL;
    HRESULT access_result = AccessibleObjectFromWindow(app->document, OBJID_CLIENT,
                                                        &IID_IAccessible, (void **)&accessible);
    if (FAILED(access_result) || !accessible) return 37;
    accessible->lpVtbl->Release(accessible);
    HWND focus_target = focus_window_after(app, app->document);
    if (focus_target != app->layout.project.content ||
        !(GetWindowLongPtrW(focus_target, GWL_STYLE) & WS_TABSTOP)) return 38;
    route_command(app, CMD_FLOAT_PROPERTIES);
    route_command(app, CMD_FLOAT_OUTPUT);
    if (app->layout.properties.mode != IDE_FLOATING || app->layout.output.mode != IDE_FLOATING)
        return 39;
    route_command(app, CMD_RESET_LAYOUT);
    if (app->layout.project.mode != IDE_DOCKED || app->layout.properties.mode != IDE_DOCKED ||
        app->layout.output.mode != IDE_DOCKED) return 40;
    if (rect_width(&main_before) < 640 || rect_height(&main_before) < 480) return 41;
    RECT dpi_bounds = {100, 100, 1000, 700};
    SendMessageW(app->main_window, WM_DPICHANGED, MAKEWPARAM(144, 144), (LPARAM)&dpi_bounds);
    RECT changed_bounds;
    GetWindowRect(app->main_window, &changed_bounds);
    if (changed_bounds.left != dpi_bounds.left || changed_bounds.top != dpi_bounds.top ||
        rect_width(&changed_bounds) != rect_width(&dpi_bounds) ||
        rect_height(&changed_bounds) != rect_height(&dpi_bounds)) return 44;
    SetWindowPos(app->main_window, NULL, main_before.left, main_before.top,
                 rect_width(&main_before), rect_height(&main_before),
                 SWP_NOZORDER | SWP_NOACTIVATE);
    if (app->document_enabled) {
        int document_status = verify_document_view(app);
        if (document_status != 0) return document_status;
    }
    if (!write_layout_atomic(app)) return 42;
    app->exit_code = 0;
    DestroyWindow(app->main_window);
    return 0;
}

static int run_message_loop(AppState *app) {
    ShowWindow(app->main_window, app->layout.maximized ? SW_SHOWMAXIMIZED : SW_SHOWNORMAL);
    UpdateWindow(app->main_window);
    MSG message;
    while (GetMessageW(&message, NULL, 0, 0) > 0) {
        if (!TranslateAcceleratorW(app->main_window, app->accelerators, &message)) {
            TranslateMessage(&message);
            DispatchMessageW(&message);
        }
    }
    return (int)message.wParam;
}

int wmain(int argc, wchar_t **argv) {
    const wchar_t *config_path = NULL;
    const wchar_t *result_path = NULL;
    const wchar_t *document_input_path = NULL;
    const wchar_t *document_output_path = NULL;
    const wchar_t *document_action_path = NULL;
    int verify = 0;
    for (int i = 1; i < argc; ++i) {
        if (wcscmp(argv[i], L"--config") == 0 && i + 1 < argc) config_path = argv[++i];
        else if (wcscmp(argv[i], L"--result") == 0 && i + 1 < argc) result_path = argv[++i];
        else if (wcscmp(argv[i], L"--document-input") == 0 && i + 1 < argc)
            document_input_path = argv[++i];
        else if (wcscmp(argv[i], L"--document-output") == 0 && i + 1 < argc)
            document_output_path = argv[++i];
        else if (wcscmp(argv[i], L"--document-action") == 0 && i + 1 < argc)
            document_action_path = argv[++i];
        else if (wcscmp(argv[i], L"--verify") == 0) verify = 1;
        else return controlled_failure(L"invalid command line", 2);
    }
    if (!config_path || !result_path) return controlled_failure(L"missing configuration", 2);
    enable_per_monitor_dpi();
    HRESULT ole_status = OleInitialize(NULL);
    if (FAILED(ole_status)) return controlled_failure(L"accessibility initialization failed", 3);
    wchar_t *configuration_text = NULL;
    if (!read_utf8_file(config_path, &configuration_text)) {
        OleUninitialize();
        return controlled_failure(L"configuration could not be read", 4);
    }
    AppState app;
    ZeroMemory(&app, sizeof(app));
    app.instance = GetModuleHandleW(NULL);
    app.result_path = result_path;
    app.verifying = verify;
    app.document_input_path = document_input_path;
    app.document_output_path = document_output_path;
    app.document_action_path = document_action_path;
    app.document_enabled = document_input_path || document_output_path || document_action_path;
    int valid = parse_config(configuration_text, &app.config) && required_text_present(&app.config) &&
                load_layout(&app.config, &app.layout);
    if (valid && config_get(&app.config, L"Workspace.Enabled")) {
        long workspace_enabled = 0;
        valid = config_long(&app.config, L"Workspace.Enabled", 1, 1, &workspace_enabled) &&
                config_get(&app.config, L"Workspace.ProjectExplorer") &&
                config_get(&app.config, L"Workspace.Properties") &&
                config_get(&app.config, L"Workspace.Output");
    }
    HeapFree(GetProcessHeap(), 0, configuration_text);
    if (valid && app.document_enabled) {
        long stable_id = 0, base_version = 0;
        valid = document_input_path && document_output_path && document_action_path &&
                config_long(&app.config, L"Document.Enabled", 1, 1, &stable_id) &&
                config_long(&app.config, L"Document.StableId", 1, 2147483647L, &stable_id) &&
                config_long(&app.config, L"Document.BaseVersion", 1, 2147483647L, &base_version) &&
                config_get(&app.config, L"Document.DisplayName") &&
                config_get(&app.config, L"Text.Prompt.CloseDirty.Title") &&
                config_get(&app.config, L"Text.Prompt.CloseDirty.Message");
        if (valid) valid = read_utf8_file(document_input_path, &app.initial_document_text);
    }
    if (!valid) {
        OleUninitialize();
        return controlled_failure(L"configuration is invalid", 5);
    }
    if (!register_classes(&app) || !create_application_windows(&app)) {
        if (app.main_window) DestroyWindow(app.main_window);
        OleUninitialize();
        if (app.initial_document_text) HeapFree(GetProcessHeap(), 0, app.initial_document_text);
        return controlled_failure(L"native window creation failed", 6);
    }
    int result = verify ? verify_shell(&app) : run_message_loop(&app);
    if (app.accelerators) DestroyAcceleratorTable(app.accelerators);
    if (app.ui_font && app.ui_font != GetStockObject(DEFAULT_GUI_FONT)) DeleteObject(app.ui_font);
    if (app.initial_document_text) HeapFree(GetProcessHeap(), 0, app.initial_document_text);
    OleUninitialize();
    if (result != 0) return controlled_failure(L"verification or message loop failed", result);
    if (!app.result_written) return controlled_failure(L"layout result was not published", 21);
    if (verify) wprintf(L"NATIVE SHELL PASS\n");
    return 0;
}
