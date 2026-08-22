#include "SmartTurnOnnxRuntimeInternal.h"

#include <string.h>

void st_copy_error(const char *message, char **out_error) {
    if (out_error == NULL) {
        return;
    }
    *out_error = NULL;
    if (message == NULL) {
        return;
    }
    size_t count = strlen(message) + 1;
    char *copy = malloc(count);
    if (copy != NULL) {
        memcpy(copy, message, count);
        *out_error = copy;
    }
}

int32_t st_check_status(
    const OrtApi *api,
    OrtStatus *status,
    char **out_error
) {
    if (status == NULL) {
        return 0;
    }
    st_copy_error(api->GetErrorMessage(status), out_error);
    api->ReleaseStatus(status);
    return 1;
}

void st_release_partial(STOrtSession *runtime) {
    if (runtime == NULL || runtime->api == NULL) {
        free(runtime);
        return;
    }
    if (runtime->memory_info != NULL) {
        runtime->api->ReleaseMemoryInfo(runtime->memory_info);
    }
    if (runtime->session != NULL) {
        runtime->api->ReleaseSession(runtime->session);
    }
    if (runtime->environment != NULL) {
        runtime->api->ReleaseEnv(runtime->environment);
    }
    free(runtime);
}
