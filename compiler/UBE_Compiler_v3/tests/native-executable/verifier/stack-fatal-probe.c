#include <windows.h>
#include <string.h>

static const char message[] = "error: insufficient execution stack\r\n";
__declspec(noreturn) static void fail_stack(void) {
    DWORD written = 0;
    (void)WriteFile(GetStdHandle(STD_ERROR_HANDLE), message, (DWORD)(sizeof(message)-1), &written, NULL);
    ExitProcess(1);
}
static DWORD WINAPI write_message(void *argument) {
    HANDLE ready = (HANDLE)argument;
    DWORD written = 0;
    if (!SetEvent(ready)) return 2;
    return WriteFile(GetStdHandle(STD_ERROR_HANDLE), message, (DWORD)(sizeof(message)-1), &written, NULL) ? 0 : GetLastError();
}
struct prepared_writer { HANDLE ready, release; };
static DWORD WINAPI prepared_message(void *argument) {
    struct prepared_writer *state = (struct prepared_writer *)argument;
    if (!SetEvent(state->ready) || WaitForSingleObject(state->release, 5000) != WAIT_OBJECT_0) return 2;
    DWORD written = 0;
    return WriteFile(GetStdHandle(STD_ERROR_HANDLE), message, (DWORD)(sizeof(message)-1), &written, NULL) ? 0 : GetLastError();
}
__declspec(noreturn) static void prepared_failure(void) {
    struct prepared_writer state = { CreateEventW(NULL, TRUE, FALSE, NULL), CreateEventW(NULL, TRUE, FALSE, NULL) };
    HANDLE writer = state.ready && state.release ? CreateThread(NULL, 0, prepared_message, &state, 0, NULL) : NULL;
    if (!writer || WaitForSingleObject(state.ready, 1000) != WAIT_OBJECT_0) ExitProcess(4);
    /* This event marks the simulated start of the fatal path. */
    if (!SetEvent(state.release)) ExitProcess(4);
    (void)WaitForSingleObject(writer, 100);
    TerminateProcess(GetCurrentProcess(), 1);
    ExitProcess(1);
}
__declspec(noreturn) static void cancelled_failure(void) {
    HANDLE ready = CreateEventW(NULL, TRUE, FALSE, NULL);
    HANDLE writer = ready ? CreateThread(NULL, 0, write_message, ready, 0, NULL) : NULL;
    if (!writer || WaitForSingleObject(ready, 1000) != WAIT_OBJECT_0 || WaitForSingleObject(writer, 100) != WAIT_TIMEOUT ||
        !CancelSynchronousIo(writer) || WaitForSingleObject(writer, 1000) != WAIT_OBJECT_0) ExitProcess(4);
    DWORD status = 0;
    if (!GetExitCodeThread(writer, &status) || status != ERROR_OPERATION_ABORTED) ExitProcess(4);
    CloseHandle(writer); CloseHandle(ready); ExitProcess(1);
}
__declspec(noreturn) static void threaded_failure(void) {
    HANDLE ready = CreateEventW(NULL, TRUE, FALSE, NULL);
    HANDLE writer = ready ? CreateThread(NULL, 0, write_message, ready, 0, NULL) : NULL;
    if (writer && WaitForSingleObject(ready, 1000) == WAIT_OBJECT_0) (void)WaitForSingleObject(writer, 100);
    TerminateProcess(GetCurrentProcess(), 1);
    ExitProcess(1);
}
int main(int argc, char **argv) {
    if (argc != 2) return 2;
    if (strcmp(argv[1], "ordinary") == 0) return 1;
    if (strcmp(argv[1], "threaded") == 0) threaded_failure();
    if (strcmp(argv[1], "prestarted") == 0) prepared_failure();
    if (strcmp(argv[1], "cancel") == 0) cancelled_failure();
    if (strcmp(argv[1], "closed") == 0) CloseHandle(GetStdHandle(STD_ERROR_HANDLE));
    else if (strcmp(argv[1], "nowait") == 0) {
        DWORD mode = PIPE_NOWAIT;
        if (!SetNamedPipeHandleState(GetStdHandle(STD_ERROR_HANDLE), &mode, NULL, NULL)) return (int)(100 + GetLastError());
    }
    else if (strcmp(argv[1], "fatal") != 0) return 2;
    fail_stack();
}
