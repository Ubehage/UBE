#include <stdint.h>
#include <stdio.h>

extern int64_t ube_atomic_i32_create(int32_t initial_value);
extern void ube_atomic_i32_destroy(int64_t handle);
extern int32_t ube_atomic_i32_load(int64_t handle);
extern int32_t ube_atomic_i32_store(int64_t handle, int32_t value);
extern int32_t ube_atomic_i32_exchange(int64_t handle, int32_t value);
extern int32_t ube_atomic_i32_compare_exchange(int64_t handle, int32_t expected, int32_t replacement);
extern int32_t ube_atomic_i32_add(int64_t handle, int32_t delta);
extern int64_t ube_atomic_i64_create(int64_t initial_value);
extern void ube_atomic_i64_destroy(int64_t handle);
extern int64_t ube_atomic_i64_load(int64_t handle);
extern int32_t ube_atomic_i64_store(int64_t handle, int64_t value);
extern int64_t ube_atomic_i64_exchange(int64_t handle, int64_t value);
extern int64_t ube_atomic_i64_compare_exchange(int64_t handle, int64_t expected, int64_t replacement);
extern int64_t ube_atomic_i64_add(int64_t handle, int64_t delta);
extern int64_t ube_atomic_object_create(void);
extern void ube_atomic_object_destroy(int64_t handle);
extern int32_t ube_atomic_object_load(int64_t handle, void** destination);
extern int32_t ube_atomic_object_store(int64_t handle, void* value);
extern int32_t ube_atomic_object_exchange(int64_t handle, void* value, void** observed);
extern int32_t ube_atomic_object_compare_exchange(int64_t handle, void* expected, void* replacement, void** observed);

int main(void) {
    int64_t narrow = ube_atomic_i32_create(2);
    int64_t wide = ube_atomic_i64_create(INT64_C(4000000000));
    if (narrow == 0 || wide == 0) return 1;
    if (ube_atomic_i32_load(narrow) != 2) return 2;
    if (ube_atomic_i32_add(narrow, 3) != 5) return 3;
    if (ube_atomic_i32_compare_exchange(narrow, 5, 8) != 5) return 4;
    if (ube_atomic_i32_exchange(narrow, 9) != 8) return 5;
    if (ube_atomic_i32_store(narrow, 12) != 1 || ube_atomic_i32_load(narrow) != 12) return 6;
    if (ube_atomic_i64_load(wide) != INT64_C(4000000000)) return 7;
    if (ube_atomic_i64_add(wide, 9) != INT64_C(4000000009)) return 8;
    if (ube_atomic_i64_compare_exchange(wide, INT64_C(4000000009), INT64_C(5000000000)) != INT64_C(4000000009)) return 9;
    if (ube_atomic_i64_exchange(wide, 7) != INT64_C(5000000000)) return 10;
    if (ube_atomic_i64_store(wide, 11) != 1 || ube_atomic_i64_load(wide) != 11) return 11;
    int first_object = 1;
    int second_object = 2;
    int64_t object_cell = ube_atomic_object_create();
    void* observed = NULL;
    if (object_cell == 0) return 12;
    if (!ube_atomic_object_store(object_cell, &first_object)) return 13;
    if (!ube_atomic_object_load(object_cell, &observed) || observed != &first_object) return 14;
    if (!ube_atomic_object_compare_exchange(object_cell, &first_object, &second_object, &observed) || observed != &first_object) return 15;
    if (!ube_atomic_object_exchange(object_cell, NULL, &observed) || observed != &second_object) return 16;
    ube_atomic_object_destroy(object_cell);
    ube_atomic_i32_destroy(narrow);
    ube_atomic_i64_destroy(wide);
    puts("atomic probe passed");
    return 0;
}
