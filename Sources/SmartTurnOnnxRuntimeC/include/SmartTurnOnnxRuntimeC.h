#ifndef SMART_TURN_ONNX_RUNTIME_C_H
#define SMART_TURN_ONNX_RUNTIME_C_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct STOrtSession STOrtSession;

int32_t st_ort_create_session(
    const char *model_path,
    STOrtSession **out_session,
    char **out_error
);

int32_t st_ort_predict(
    STOrtSession *session,
    float *features,
    size_t feature_count,
    float *out_probability,
    char **out_error
);

void st_ort_destroy_session(STOrtSession *session);
void st_ort_free_error(char *error_message);
const char *st_ort_runtime_version(void);

#ifdef __cplusplus
}
#endif

#endif
