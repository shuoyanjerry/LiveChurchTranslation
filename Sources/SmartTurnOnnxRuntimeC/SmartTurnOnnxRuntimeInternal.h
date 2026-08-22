#ifndef SMART_TURN_ONNX_RUNTIME_INTERNAL_H
#define SMART_TURN_ONNX_RUNTIME_INTERNAL_H

#include "SmartTurnOnnxRuntimeC.h"

#include <onnxruntime/onnxruntime_c_api.h>
#include <stdlib.h>

struct STOrtSession {
    const OrtApi *api;
    OrtEnv *environment;
    OrtSession *session;
    OrtMemoryInfo *memory_info;
};

void st_copy_error(const char *message, char **out_error);
int32_t st_check_status(const OrtApi *api, OrtStatus *status, char **out_error);
void st_release_partial(STOrtSession *runtime);

#endif
